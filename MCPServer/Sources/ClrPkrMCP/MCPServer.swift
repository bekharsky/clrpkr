import AppKit
import Foundation

final class MCPServer {
  private var picker: ScreenColorPicker?
  private var pendingRequestId: Any?

  // MARK: - Stdin read loop (runs on a background thread)

  func readLoop() {
    while let line = readLine(strippingNewline: true) {
      guard !line.isEmpty else { continue }
      DispatchQueue.main.async { [weak self] in
        self?.handle(line: line)
      }
    }
    // stdin closed — shut down gracefully
    DispatchQueue.main.async { NSApp.terminate(nil) }
  }

  // MARK: - JSON-RPC dispatch (runs on main thread)

  private func handle(line: String) {
    guard
      let data = line.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let method = json["method"] as? String
    else {
      return
    }

    let id = json["id"]

    switch method {
    case "initialize":
      respond(id: id, result: [
        "protocolVersion": "2024-11-05",
        "capabilities": ["tools": [String: Any]()],
        "serverInfo": ["name": "clrpkr-mcp", "version": "1.0.0"]
      ])

    case "notifications/initialized":
      break  // notification — no response expected

    case "ping":
      respond(id: id, result: [String: Any]())

    case "tools/list":
      respond(id: id, result: [
        "tools": [
          [
            "name": "pick_color",
            "description": "Opens an interactive magnifier overlay on screen. The user clicks any pixel to sample its color. Returns hex, rgb, and hsl values of the picked color. IMPORTANT: Always display the full color result to the user exactly as returned.",
            "inputSchema": ["type": "object", "properties": [String: Any]()]
          ] as [String: Any],
          [
            "name": "extract_palette",
            "description": "Opens a file-picker so the user can choose an image, picture, photo, or file. Extracts the dominant colors from it and returns hex, rgb, and hsl values for every color. Use this when the user says things like: 'extract colors from an image', 'create a palette from a picture', 'get colors from a file', 'extract palette from photo', 'what colors are in this image', 'pull colors from a picture'. IMPORTANT: Always display the COMPLETE palette table to the user exactly as returned — do not summarize or omit any rows.",
            "inputSchema": ["type": "object", "properties": [String: Any]()]
          ] as [String: Any]
        ]
      ])

    case "tools/call":
      guard
        let params = json["params"] as? [String: Any],
        let toolName = params["name"] as? String
      else {
        respondError(id: id, code: -32602, message: "Unknown tool or invalid params")
        return
      }
      guard pendingRequestId == nil else {
        respondError(id: id, code: -32000, message: "A tool call is already in progress")
        return
      }
      switch toolName {
      case "pick_color":
        pendingRequestId = id
        startPicker()
      case "extract_palette":
        pendingRequestId = id
        startPaletteExtraction()
      default:
        respondError(id: id, code: -32602, message: "Unknown tool: \(toolName)")
      }

    default:
      if id != nil {
        respondError(id: id, code: -32601, message: "Method not found: \(method)")
      }
    }
  }

  // MARK: - Picker lifecycle

  private func startPicker() {
    picker = ScreenColorPicker(
      hideWindow: {},
      showWindow: {},
      onPick: { [weak self] payload in
        self?.handlePick(payload)
      },
      onCancel: { [weak self] in
        self?.handleCancel()
      }
    )
    picker?.start()
  }

  private func handlePick(_ payload: PickedColorPayload) {
    let id = pendingRequestId
    pendingRequestId = nil
    picker = nil

    let r = payload.red, g = payload.green, b = payload.blue
    let hsl = rgbToHsl(r: r, g: g, b: b)

    let text = """
      hex: \(payload.hex)
      rgb: rgb(\(r), \(g), \(b))
      hsl: hsl(\(hsl.h), \(hsl.s)%, \(hsl.l)%)
      """

    respond(id: id, result: [
      "content": [["type": "text", "text": text] as [String: Any]]
    ])
  }

  private func handleCancel() {
    let id = pendingRequestId
    pendingRequestId = nil
    picker = nil
    respondError(id: id, code: -32000, message: "Color picking was cancelled")
  }

  // MARK: - Palette extraction lifecycle

  private func startPaletteExtraction() {
    pickImageAndExtractPalette { [weak self] filename, palette in
      self?.handlePaletteResult(filename: filename, palette: palette)
    }
  }

  private func handlePaletteResult(filename: String?, palette: [PaletteColorBucket]?) {
    let id = pendingRequestId
    pendingRequestId = nil

    guard let filename, let palette, !palette.isEmpty else {
      respondError(id: id, code: -32000, message: "Palette extraction was cancelled or the image could not be read")
      return
    }

    var content: [[String: Any]] = []

    // Text table
    var lines: [String] = [
      "Palette from: **\(filename)** (\(palette.count) colors)",
      "",
      "| Hex | RGB | HSL |",
      "|---|---|---|"
    ]
    for bucket in palette {
      let r = bucket.red, g = bucket.green, b = bucket.blue
      let hsl = rgbToHsl(r: r, g: g, b: b)
      lines.append("| `\(bucket.hex)` | rgb(\(r), \(g), \(b)) | hsl(\(hsl.h), \(hsl.s)%, \(hsl.l)%) |")
    }
    content.append(["type": "text", "text": lines.joined(separator: "\n")])

    respond(id: id, result: ["content": content])
  }

  // MARK: - JSON-RPC helpers

  private func respond(id: Any?, result: Any) {
    var response: [String: Any] = ["jsonrpc": "2.0", "result": result]
    if let id { response["id"] = id }
    writeJSON(response)
  }

  private func respondError(id: Any?, code: Int, message: String) {
    var response: [String: Any] = [
      "jsonrpc": "2.0",
      "error": ["code": code, "message": message] as [String: Any]
    ]
    if let id { response["id"] = id }
    writeJSON(response)
  }

  private func writeJSON(_ object: [String: Any]) {
    guard
      let data = try? JSONSerialization.data(withJSONObject: object),
      let line = String(data: data, encoding: .utf8)
    else { return }
    // Write directly to the fd so output is never buffered
    FileHandle.standardOutput.write((line + "\n").data(using: .utf8)!)
  }

  // MARK: - Color math

  private func rgbToHsl(r: Int, g: Int, b: Int) -> (h: Int, s: Int, l: Int) {
    let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
    let cMax = max(rf, gf, bf), cMin = min(rf, gf, bf)
    let l = (cMax + cMin) / 2
    guard cMax != cMin else { return (0, 0, Int(round(l * 100))) }
    let d = cMax - cMin
    let s = l > 0.5 ? d / (2 - cMax - cMin) : d / (cMax + cMin)
    var h: Double
    switch cMax {
    case rf: h = (gf - bf) / d + (gf < bf ? 6 : 0)
    case gf: h = (bf - rf) / d + 2
    default:  h = (rf - gf) / d + 4
    }
    return (Int(round(h / 6 * 360)), Int(round(s * 100)), Int(round(l * 100)))
  }
}

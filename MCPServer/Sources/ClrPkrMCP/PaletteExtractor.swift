// Palette extraction logic adapted from Runner/UI/ImagePaletteExtractor.swift
// and Runner/UI/ColorModels.swift.
import Cocoa
import CoreGraphics

// MARK: - Model

struct PaletteColorBucket {
  let color: NSColor
  let pixelCount: Int

  var rgbColor: NSColor { color.usingColorSpace(.deviceRGB) ?? color }

  var red:   Int { Int(round(rgbColor.redComponent   * 255)) }
  var green: Int { Int(round(rgbColor.greenComponent * 255)) }
  var blue:  Int { Int(round(rgbColor.blueComponent  * 255)) }

  var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

// MARK: - Extraction

enum ImagePaletteExtractor {
  static func extractPalette(from image: NSImage, maxColors: Int = 8) -> [PaletteColorBucket] {
    guard
      maxColors > 0,
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let bitmap = downsampledBitmap(from: cgImage)
    else { return [] }

    struct BucketAccumulator {
      var count = 0
      var redTotal = 0
      var greenTotal = 0
      var blueTotal = 0
    }

    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    let quantizationShift = 3
    let minimumAlpha = 24
    var buckets: [UInt32: BucketAccumulator] = [:]

    for y in 0..<height {
      for x in 0..<width {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let alpha = Int(round(color.alphaComponent * 255))
        guard alpha >= minimumAlpha else { continue }

        let r = Int(round(color.redComponent   * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent  * 255))
        let key = UInt32(r >> quantizationShift) << 10
          | UInt32(g >> quantizationShift) << 5
          | UInt32(b >> quantizationShift)

        var acc = buckets[key] ?? BucketAccumulator()
        acc.count      += 1
        acc.redTotal   += r
        acc.greenTotal += g
        acc.blueTotal  += b
        buckets[key] = acc
      }
    }

    let sorted = buckets.values.sorted { $0.count > $1.count }

    var palette: [PaletteColorBucket] = []
    for acc in sorted {
      let color = NSColor(
        srgbRed: CGFloat(acc.redTotal)   / CGFloat(acc.count * 255),
        green:   CGFloat(acc.greenTotal) / CGFloat(acc.count * 255),
        blue:    CGFloat(acc.blueTotal)  / CGFloat(acc.count * 255),
        alpha: 1
      )
      let tooClose = palette.contains { colorDistanceSquared($0.color, color) < 36 * 36 }
      guard !tooClose else { continue }
      palette.append(PaletteColorBucket(color: color, pixelCount: acc.count))
      if palette.count == maxColors { break }
    }
    return palette
  }

  // MARK: - Helpers

  private static func downsampledBitmap(from image: CGImage) -> NSBitmapImageRep? {
    let maxDimension = 72
    if image.width <= maxDimension, image.height <= maxDimension {
      return NSBitmapImageRep(cgImage: image)
    }
    let w = max(1, min(maxDimension, image.width))
    let h = max(1, min(maxDimension, image.height))
    guard let ctx = CGContext(
      data: nil, width: w, height: h,
      bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .medium
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let scaled = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: scaled)
  }

  private static func colorDistanceSquared(_ lhs: NSColor, _ rhs: NSColor) -> Int {
    let l = lhs.usingColorSpace(.deviceRGB) ?? lhs
    let r = rhs.usingColorSpace(.deviceRGB) ?? rhs
    let dr = Int(round((l.redComponent   - r.redComponent)   * 255))
    let dg = Int(round((l.greenComponent - r.greenComponent) * 255))
    let db = Int(round((l.blueComponent  - r.blueComponent)  * 255))
    return dr * dr + dg * dg + db * db
  }
}

// MARK: - File picker (must be called on the main thread)

/// Opens a native file-open panel and extracts the palette from the chosen image.
/// Calls `completion` on the main thread with `(filename, palette)` on success
/// or `(nil, nil)` when the user cancels.
func pickImageAndExtractPalette(completion: @escaping (_ filename: String?, _ palette: [PaletteColorBucket]?) -> Void) {
  let panel = NSOpenPanel()
  panel.title = "Choose an image"
  panel.prompt = "Extract Palette"
  panel.canChooseFiles = true
  panel.canChooseDirectories = false
  panel.allowsMultipleSelection = false
  panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .webP, .heic]

  NSApp.activate(ignoringOtherApps: true)
  let result = panel.runModal()

  guard result == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
    completion(nil, nil)
    return
  }
  let filename = url.lastPathComponent
  let palette = ImagePaletteExtractor.extractPalette(from: image)
  completion(filename, palette)
}

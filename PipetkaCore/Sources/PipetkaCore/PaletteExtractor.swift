// Palette extraction logic for Pipetka
import Cocoa
import Compression
import CoreGraphics

// MARK: - Extraction

public enum ImagePaletteExtractor {
  public static func extractPalette(from image: NSImage, maxColors: Int = 8) -> [PaletteColorBucket] {
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
public func pickImageAndExtractPalette(completion: @escaping (_ filename: String?, _ palette: [PaletteColorBucket]?) -> Void) {
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

// MARK: - Per-color swatch data URI

/// Returns a `data:image/png;base64,…` string for a 16×16 opaque color swatch.
/// Generates a minimal compressed PNG by hand (no EXIF, no extra chunks) for speed.
public func swatchDataURI(for bucket: PaletteColorBucket) -> String {
  let r = UInt8(clamping: bucket.red)
  let g = UInt8(clamping: bucket.green)
  let b = UInt8(clamping: bucket.blue)
  let png = minimalPNG(r: r, g: g, b: b, side: 16)
  return "data:image/png;base64," + png.base64EncodedString()
}

/// Builds a minimal side×side RGB PNG with zlib compression (~120 bytes for 16×16).
private func minimalPNG(r: UInt8, g: UInt8, b: UInt8, side: Int) -> Data {
  func crc32(_ data: [UInt8]) -> UInt32 {
    var c: UInt32 = 0xFFFF_FFFF
    for byte in data {
      c ^= UInt32(byte)
      for _ in 0..<8 {
        c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1
      }
    }
    return c ^ 0xFFFF_FFFF
  }

  func chunk(_ type: [UInt8], _ payload: [UInt8]) -> [UInt8] {
    let len = UInt32(payload.count)
    let typeAndPayload = type + payload
    let checksum = crc32(typeAndPayload)
    return withUnsafeBytes(of: len.bigEndian, Array.init)
      + typeAndPayload
      + withUnsafeBytes(of: checksum.bigEndian, Array.init)
  }

  let s = UInt32(side)
  // IHDR: side×side, 8-bit RGB, no interlace
  let ihdr = chunk(
    [0x49, 0x48, 0x44, 0x52],
    withUnsafeBytes(of: s.bigEndian, Array.init)
      + withUnsafeBytes(of: s.bigEndian, Array.init)
      + [8, 2, 0, 0, 0]
  )

  // Build raw scanlines using Up filter for great compression on solid colors:
  // Row 0: filter=0 (None), then R,G,B repeated
  // Rows 1+: filter=2 (Up), then all zeros (identical to row above)
  var raw: [UInt8] = []
  let firstRow: [UInt8] = [0] + Array(repeating: [r, g, b], count: side).flatMap { $0 }
  raw += firstRow
  let zeroRow: [UInt8] = [2] + Array(repeating: UInt8(0), count: side * 3)
  for _ in 1..<side { raw += zeroRow }

  // Compress with Apple's Compression framework (raw deflate)
  let rawData = Data(raw)
  let compressedData = rawData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
    let srcCount = srcPtr.count
    let dstSize = srcCount + 512  // generous upper bound
    var dst = Data(count: dstSize)
    let compressedSize = dst.withUnsafeMutableBytes { (dstPtr: UnsafeMutableRawBufferPointer) -> Int in
      compression_encode_buffer(
        dstPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), dstSize,
        srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), srcCount,
        nil, COMPRESSION_ZLIB
      )
    }
    return dst.prefix(compressedSize)
  }

  // Adler-32 of uncompressed data
  var a: UInt32 = 1, bv: UInt32 = 0
  for byte in raw { a = (a + UInt32(byte)) % 65521; bv = (bv + a) % 65521 }
  let adler = (bv << 16) | a

  // Wrap in zlib format: header + compressed deflate + adler32
  var zlib: [UInt8] = [0x78, 0x01]
  zlib += Array(compressedData)
  zlib += withUnsafeBytes(of: adler.bigEndian, Array.init)

  let idat = chunk([0x49, 0x44, 0x41, 0x54], zlib)
  let iend = chunk([0x49, 0x45, 0x4E, 0x44], [])

  let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
  return Data(signature + ihdr + idat + iend)
}

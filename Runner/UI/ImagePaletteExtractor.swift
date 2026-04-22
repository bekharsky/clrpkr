import Cocoa

enum ImagePaletteExtractor {
  static func extractPalette(from image: NSImage, maxColors: Int = 6) -> [PaletteColorBucket] {
    guard
      maxColors > 0,
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let bitmap = downsampledBitmap(from: cgImage)
    else {
      return []
    }

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
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
          continue
        }

        let alpha = Int(round(color.alphaComponent * 255))
        guard alpha >= minimumAlpha else {
          continue
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        let key = UInt32(red >> quantizationShift) << 10
          | UInt32(green >> quantizationShift) << 5
          | UInt32(blue >> quantizationShift)

        var accumulator = buckets[key] ?? BucketAccumulator()
        accumulator.count += 1
        accumulator.redTotal += red
        accumulator.greenTotal += green
        accumulator.blueTotal += blue
        buckets[key] = accumulator
      }
    }

    let sortedBuckets = buckets.values.sorted { lhs, rhs in
      lhs.count > rhs.count
    }

    var palette: [PaletteColorBucket] = []
    for bucket in sortedBuckets {
      let color = NSColor(
        srgbRed: CGFloat(bucket.redTotal) / CGFloat(bucket.count * 255),
        green: CGFloat(bucket.greenTotal) / CGFloat(bucket.count * 255),
        blue: CGFloat(bucket.blueTotal) / CGFloat(bucket.count * 255),
        alpha: 1
      )

      let isTooCloseToExisting = palette.contains { existing in
        colorDistanceSquared(color, existing.color) < 36 * 36
      }
      guard !isTooCloseToExisting else {
        continue
      }

      palette.append(PaletteColorBucket(color: color, pixelCount: bucket.count))
      if palette.count == maxColors {
        break
      }
    }

    return palette
  }

  private static func downsampledBitmap(from image: CGImage) -> NSBitmapImageRep? {
    let maxDimension = 72

    if image.width <= maxDimension, image.height <= maxDimension {
      return NSBitmapImageRep(cgImage: image)
    }

    let width = max(1, min(maxDimension, image.width))
    let height = max(1, min(maxDimension, image.height))

    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return nil
    }

    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let scaledImage = context.makeImage() else {
      return nil
    }

    return NSBitmapImageRep(cgImage: scaledImage)
  }

  private static func colorDistanceSquared(_ lhs: NSColor, _ rhs: NSColor) -> Int {
    let left = lhs.usingColorSpace(.deviceRGB) ?? lhs
    let right = rhs.usingColorSpace(.deviceRGB) ?? rhs
    let redDelta = Int(round((left.redComponent - right.redComponent) * 255))
    let greenDelta = Int(round((left.greenComponent - right.greenComponent) * 255))
    let blueDelta = Int(round((left.blueComponent - right.blueComponent) * 255))
    return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
  }
}

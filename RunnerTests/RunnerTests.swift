import Cocoa
import XCTest
@testable import clrpkr

class RunnerTests: XCTestCase {

  private func makePickedColor(red: Int, green: Int, blue: Int) -> PickedColor {
    PickedColor(
      color: NSColor(
        srgbRed: CGFloat(red) / 255,
        green: CGFloat(green) / 255,
        blue: CGFloat(blue) / 255,
        alpha: 1
      ),
      previewImage: nil,
      pickedAt: Date(timeIntervalSince1970: 0)
    )
  }

  private func makeImage(
    width: Int,
    height: Int,
    pixels: [(Int, Int, Int, Int)]
  ) -> NSImage {
    let bytesPerRow = width * 4
    var data = pixels.flatMap { pixel in
      [UInt8(pixel.0), UInt8(pixel.1), UInt8(pixel.2), UInt8(pixel.3)]
    }

    let bitmap = data.withUnsafeMutableBytes { bytes -> NSBitmapImageRep in
      NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: bytesPerRow,
        bitsPerPixel: 32
      )!
    }

    memcpy(bitmap.bitmapData, data, data.count)

    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(bitmap)
    return image
  }

  func testFormatColorHexRgbAndSwiftUIOutputs() {
    let item = makePickedColor(red: 255, green: 128, blue: 0)

    XCTAssertEqual(formatColor(item, format: .hex), "#FF8000")
    XCTAssertEqual(formatColor(item, format: .rgb), "rgb(255, 128, 0)")
    XCTAssertEqual(
      formatColor(item, format: .swiftUI),
      "Color(red: 1.000, green: 0.502, blue: 0.000)"
    )
  }

  func testFormatColorHslOutputForOrange() {
    let item = makePickedColor(red: 255, green: 128, blue: 0)

    XCTAssertEqual(formatColor(item, format: .hsl), "hsl(30 100% 50%)")
  }

  func testFormatHslOutputForGrayHasZeroSaturation() {
    let item = makePickedColor(red: 128, green: 128, blue: 128)

    XCTAssertEqual(formatHsl(item), "hsl(0 0% 50%)")
  }

  func testLensFrameUsesPreferredPlacementWhenSpaceAllows() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let mousePoint = CGPoint(x: 300, y: 600)

    let frame = PickerLensView.frameForLens(around: mousePoint, visibleFrame: visibleFrame)

    XCTAssertEqual(frame, CGRect(x: 326, y: 366, width: 184, height: 216))
  }

  func testLensFrameFlipsAndClampsNearScreenEdges() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
    let mousePoint = CGPoint(x: 390, y: 10)

    let frame = PickerLensView.frameForLens(around: mousePoint, visibleFrame: visibleFrame)

    XCTAssertEqual(frame, CGRect(x: 180, y: 28, width: 184, height: 216))
  }

  func testImagePaletteExtractorReturnsDominantColors() {
    let image = makeImage(
      width: 4,
      height: 2,
      pixels: [
        (255, 0, 0, 255), (255, 0, 0, 255), (255, 0, 0, 255), (0, 255, 0, 255),
        (255, 0, 0, 255), (0, 0, 255, 255), (0, 255, 0, 255), (0, 255, 0, 255)
      ]
    )

    let palette = ImagePaletteExtractor.extractPalette(from: image, maxColors: 3)

    XCTAssertEqual(palette.count, 3)
    XCTAssertEqual(
      palette.map { formatColor(makePickedColor(red: Int(round(($0.color.usingColorSpace(.deviceRGB) ?? $0.color).redComponent * 255)), green: Int(round(($0.color.usingColorSpace(.deviceRGB) ?? $0.color).greenComponent * 255)), blue: Int(round(($0.color.usingColorSpace(.deviceRGB) ?? $0.color).blueComponent * 255))), format: .hex) },
      ["#FF0000", "#00FF00", "#0000FF"]
    )
  }

  func testImagePaletteExtractorIgnoresFullyTransparentPixels() {
    let image = makeImage(
      width: 2,
      height: 2,
      pixels: [
        (0, 0, 0, 0), (0, 0, 0, 0),
        (255, 128, 0, 255), (255, 128, 0, 255)
      ]
    )

    let palette = ImagePaletteExtractor.extractPalette(from: image, maxColors: 3)

    XCTAssertEqual(palette.count, 1)
    let color = palette[0].color.usingColorSpace(.deviceRGB) ?? palette[0].color
    XCTAssertEqual(Int(round(color.redComponent * 255)), 255)
    XCTAssertEqual(Int(round(color.greenComponent * 255)), 128)
    XCTAssertEqual(Int(round(color.blueComponent * 255)), 0)
  }

}

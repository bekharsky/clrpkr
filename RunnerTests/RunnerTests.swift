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

}

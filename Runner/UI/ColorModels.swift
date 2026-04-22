import Cocoa

enum ColorFormat: Int, CaseIterable {
  case hex
  case rgb
  case hsl
  case swiftUI

  var label: String {
    switch self {
    case .hex:
      return "HEX"
    case .rgb:
      return "RGB"
    case .hsl:
      return "HSL"
    case .swiftUI:
      return "SwiftUI"
    }
  }
}

struct PickedColor {
  let id = UUID()
  let color: NSColor
  let previewImage: NSImage?
  let pickedAt: Date

  var rgbColor: NSColor {
    color.usingColorSpace(.deviceRGB) ?? color
  }

  var red: Int {
    Int(round(rgbColor.redComponent * 255))
  }

  var green: Int {
    Int(round(rgbColor.greenComponent * 255))
  }

  var blue: Int {
    Int(round(rgbColor.blueComponent * 255))
  }
}

struct RecentPickMenuItem {
  let text: String
  let color: NSColor
}

struct PaletteColorBucket {
  let color: NSColor
  let pixelCount: Int
}

func formatColor(_ item: PickedColor, format: ColorFormat) -> String {
  switch format {
  case .hex:
    return String(format: "#%02X%02X%02X", item.red, item.green, item.blue)
  case .rgb:
    return "rgb(\(item.red), \(item.green), \(item.blue))"
  case .hsl:
    return formatHsl(item)
  case .swiftUI:
    return String(
      format: "Color(red: %.3f, green: %.3f, blue: %.3f)",
      Double(item.red) / 255,
      Double(item.green) / 255,
      Double(item.blue) / 255
    )
  }
}

func formatHsl(_ item: PickedColor) -> String {
  let red = Double(item.red) / 255
  let green = Double(item.green) / 255
  let blue = Double(item.blue) / 255
  let maxValue = max(red, max(green, blue))
  let minValue = min(red, min(green, blue))
  let delta = maxValue - minValue

  var hue = 0.0
  let lightness = (maxValue + minValue) / 2
  let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))

  if delta != 0 {
    if maxValue == red {
      hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
    } else if maxValue == green {
      hue = 60 * (((blue - red) / delta) + 2)
    } else {
      hue = 60 * (((red - green) / delta) + 4)
    }
  }

  if hue < 0 {
    hue += 360
  }

  return "hsl(\(Int(round(hue))) \(Int(round(saturation * 100)))% \(Int(round(lightness * 100)))%)"
}

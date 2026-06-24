import AppKit

// MARK: - Color Models

public struct NamedColorMatch {
  public let name: String
  public let matchedRed: Int
  public let matchedGreen: Int
  public let matchedBlue: Int
  public let distanceSquared: Int
  
  public init(name: String, matchedRed: Int, matchedGreen: Int, matchedBlue: Int, distanceSquared: Int) {
    self.name = name
    self.matchedRed = matchedRed
    self.matchedGreen = matchedGreen
    self.matchedBlue = matchedBlue
    self.distanceSquared = distanceSquared
  }
}

public struct PaletteColorBucket {
  public let color: NSColor
  public let pixelCount: Int

  public var rgbColor: NSColor { color.usingColorSpace(.deviceRGB) ?? color }

  public var red:   Int { Int(round(rgbColor.redComponent   * 255)) }
  public var green: Int { Int(round(rgbColor.greenComponent * 255)) }
  public var blue:  Int { Int(round(rgbColor.blueComponent  * 255)) }

  public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
  
  public init(color: NSColor, pixelCount: Int) {
    self.color = color
    self.pixelCount = pixelCount
  }
}

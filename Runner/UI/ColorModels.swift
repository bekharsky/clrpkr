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

struct NamedColorMatch {
  let name: String
  let matchedRed: Int
  let matchedGreen: Int
  let matchedBlue: Int
  let distanceSquared: Int
}

struct PaletteColorBucket {
  let color: NSColor
  let pixelCount: Int
}

struct ImportedPalette {
  let id = UUID()
  let colors: [PickedColor]
  let previewImage: NSImage?
  let importedAt: Date
}

enum PaletteExportFormat: Int, CaseIterable {
  case cssVariables
  case scssVariables
  case tailwindColors
  case jsonTokens

  var label: String {
    switch self {
    case .cssVariables:
      return "CSS Variables"
    case .scssVariables:
      return "SCSS Variables"
    case .tailwindColors:
      return "Tailwind Colors"
    case .jsonTokens:
      return "JSON Tokens"
    }
  }
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

func namedColorMatch(for item: PickedColor) -> NamedColorMatch {
  NamedColorLookup.nearestMatch(red: item.red, green: item.green, blue: item.blue)
}

func namedColorName(for item: PickedColor) -> String {
  namedColorMatch(for: item).name
}

func historySubtitle(for item: PickedColor) -> String {
  "\(namedColorName(for: item)) • \(formatColor(item, format: .hex))"
}

func recentPickMenuText(for item: PickedColor, format: ColorFormat) -> String {
  "\(namedColorName(for: item)) - \(formatColor(item, format: format))"
}

func exportColors(_ items: [PickedColor], format: PaletteExportFormat) -> String {
  let entries = makeExportEntries(from: items)

  switch format {
  case .cssVariables:
    let body = entries.map { entry in
      "  --\(entry.slug): \(formatColor(entry.item, format: .hex)); /* \(entry.name) */"
    }.joined(separator: "\n")
    return ":root {\n\(body)\n}"
  case .scssVariables:
    return entries.map { entry in
      "$\(entry.slug): \(formatColor(entry.item, format: .hex)); // \(entry.name)"
    }.joined(separator: "\n")
  case .tailwindColors:
    let body = entries.map { entry in
      "      '\(entry.slug)': '\(formatColor(entry.item, format: .hex))', // \(entry.name)"
    }.joined(separator: "\n")
    return """
module.exports = {
  theme: {
    extend: {
      colors: {
\(body)
      }
    }
  }
}
"""
  case .jsonTokens:
    let body = entries.map { entry in
      """
  "\(entry.slug)": {
    "name": "\(escapeJSONString(entry.name))",
    "hex": "\(formatColor(entry.item, format: .hex))",
    "rgb": "\(formatColor(entry.item, format: .rgb))",
    "hsl": "\(formatColor(entry.item, format: .hsl))",
    "swiftUI": "\(formatColor(entry.item, format: .swiftUI))"
  }
"""
    }.joined(separator: ",\n")
    return "{\n\(body)\n}"
  }
}

private struct ExportEntry {
  let slug: String
  let name: String
  let item: PickedColor
}

private func makeExportEntries(from items: [PickedColor]) -> [ExportEntry] {
  var usedSlugs: [String: Int] = [:]

  return items.map { item in
    let name = namedColorName(for: item)
    let baseSlug = slugifyColorName(name)
    let count = usedSlugs[baseSlug, default: 0]
    usedSlugs[baseSlug] = count + 1
    let slug = count == 0 ? baseSlug : "\(baseSlug)-\(count + 1)"
    return ExportEntry(slug: slug, name: name, item: item)
  }
}

private func slugifyColorName(_ name: String) -> String {
  let lowercase = name.lowercased()
  let scalars = lowercase.unicodeScalars.map { scalar -> Character in
    CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
  }
  let raw = String(scalars)
  let collapsed = raw.replacingOccurrences(
    of: "-+",
    with: "-",
    options: .regularExpression
  )
  let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
  return trimmed.isEmpty ? "color" : trimmed
}

private func escapeJSONString(_ string: String) -> String {
  string
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

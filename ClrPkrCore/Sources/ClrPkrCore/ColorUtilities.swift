import Foundation

public enum ColorUtilities {
  /// Converts RGB (0-255) to HSL (h: 0-360, s: 0-100, l: 0-100)
  public static func rgbToHsl(r: Int, g: Int, b: Int) -> (h: Int, s: Int, l: Int) {
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

import AppKit
import SwiftUI
import Testing

@testable import DevtailKit

@MainActor
struct ANSIColorTests {

  @Test func defaultSwiftUIColorIsPrimary() {
    // SwiftUI Color has no stable equality across macOS; description is the
    // best we can do without round-tripping through NSColor.
    let color = ANSIColor.default.swiftUIColor
    #expect(String(describing: color).contains("primary"))
  }

  @Test func defaultNSColorIsLabelColor() {
    #expect(ANSIColor.default.nsColor == NSColor.labelColor)
  }

  @Test func standardRedMatchesExpectedRGB() {
    let color = ANSIColor.standard(1).nsColor
    let components = color.cgColor.components!
    #expect(abs(components[0] - 0.85) < 0.01)
    #expect(abs(components[1] - 0.25) < 0.01)
    #expect(abs(components[2] - 0.25) < 0.01)
  }

  @Test func standardGreenMatchesExpectedRGB() {
    let color = ANSIColor.standard(2).nsColor
    let components = color.cgColor.components!
    #expect(abs(components[0] - 0.25) < 0.01)
    #expect(abs(components[1] - 0.75) < 0.01)
    #expect(abs(components[2] - 0.35) < 0.01)
  }

  @Test func standardBlueMatchesExpectedRGB() {
    let color = ANSIColor.standard(4).nsColor
    let components = color.cgColor.components!
    #expect(abs(components[0] - 0.35) < 0.01)
    #expect(abs(components[1] - 0.45) < 0.01)
    #expect(abs(components[2] - 0.9) < 0.01)
  }

  @Test func standardAllIndicesProduceDistinctColors() {
    var seen: Set<String> = []
    for i in UInt8(0)...UInt8(7) {
      let c = ANSIColor.standard(i).nsColor
      let comps = c.cgColor.components!
      let key = "\(comps[0]),\(comps[1]),\(comps[2])"
      seen.insert(key)
    }
    #expect(seen.count == 8)
  }

  @Test func brightIsLighterThanStandard() {
    // Skip 0 (black/gray) and 7 (white) — luminance ordering flips for those.
    for i in UInt8(1)...UInt8(6) {
      let std = ANSIColor.standard(i).nsColor.cgColor.components!
      let bright = ANSIColor.bright(i).nsColor.cgColor.components!
      let stdLuma = std[0] + std[1] + std[2]
      let brightLuma = bright[0] + bright[1] + bright[2]
      #expect(brightLuma > stdLuma, "bright(\(i)) should be lighter than standard(\(i))")
    }
  }

  @Test func palette0To7MatchesStandard() {
    for i in UInt8(0)...UInt8(7) {
      let palette = ANSIColor.palette(i).nsColor.cgColor.components!
      let standard = ANSIColor.standard(i).nsColor.cgColor.components!
      #expect(palette[0] == standard[0])
      #expect(palette[1] == standard[1])
      #expect(palette[2] == standard[2])
    }
  }

  @Test func palette8To15MatchesBright() {
    for i in UInt8(8)...UInt8(15) {
      let palette = ANSIColor.palette(i).nsColor.cgColor.components!
      let bright = ANSIColor.bright(i - 8).nsColor.cgColor.components!
      #expect(palette[0] == bright[0])
      #expect(palette[1] == bright[1])
      #expect(palette[2] == bright[2])
    }
  }

  @Test func palette16Is6x6x6CubeOrigin() {
    // Index 16 is (0,0,0) in the 6x6x6 color cube — the zero branch.
    let color = ANSIColor.palette(16).nsColor.cgColor.components!
    #expect(color[0] == 0)
    #expect(color[1] == 0)
    #expect(color[2] == 0)
  }

  @Test func palette231IsCubeMaxWhite() {
    // Index 231 is (5,5,5) in the cube: 5*40+55 = 255, scaled to 1.0.
    let color = ANSIColor.palette(231).nsColor.cgColor.components!
    #expect(abs(color[0] - 1.0) < 0.01)
    #expect(abs(color[1] - 1.0) < 0.01)
    #expect(abs(color[2] - 1.0) < 0.01)
  }

  @Test func paletteGrayRampIsMonotonicallyIncreasing() {
    var prev: CGFloat = -1
    for i in UInt8(232)...UInt8(255) {
      let c = ANSIColor.palette(i).nsColor.cgColor.components!
      #expect(c[0] == c[1])
      #expect(c[1] == c[2])
      #expect(c[0] > prev)
      prev = c[0]
    }
  }

  @Test func rgbPassesThroughScaledTo01() {
    let c = ANSIColor.rgb(255, 128, 0).nsColor.cgColor.components!
    #expect(abs(c[0] - 1.0) < 0.01)
    #expect(abs(c[1] - 128.0 / 255.0) < 0.01)
    #expect(c[2] == 0)
  }

  @Test func rgbZero() {
    let c = ANSIColor.rgb(0, 0, 0).nsColor.cgColor.components!
    #expect(c[0] == 0)
    #expect(c[1] == 0)
    #expect(c[2] == 0)
  }

  @Test func swiftUIAndNSColorShareRGBViaBridge() {
    let sample = ANSIColor.rgb(100, 150, 200)
    let ns = sample.nsColor
    let bridged = NSColor(sample.swiftUIColor)
    let nsRGB = ns.usingColorSpace(.deviceRGB)!
    let bridgedRGB = bridged.usingColorSpace(.deviceRGB)!
    #expect(abs(nsRGB.redComponent - bridgedRGB.redComponent) < 0.01)
    #expect(abs(nsRGB.greenComponent - bridgedRGB.greenComponent) < 0.01)
    #expect(abs(nsRGB.blueComponent - bridgedRGB.blueComponent) < 0.01)
  }
}

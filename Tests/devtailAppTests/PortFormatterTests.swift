import Testing

@testable import devtail

@Suite
struct PortFormatterTests {

  @Test func labelOmitsThousandsSeparator() {
    // Regression: SwiftUI Text applies locale grouping to Int interpolation,
    // producing ":3,000" instead of ":3000". String(port) sidesteps that.
    #expect(PortFormatter.label(for: 3000) == ":3000")
    #expect(PortFormatter.label(for: 3) == ":3")
    #expect(PortFormatter.label(for: 65535) == ":65535")
    #expect(PortFormatter.label(for: 1_234_567) == ":1234567")
  }

  @Test func overflowFormatsCount() {
    #expect(PortFormatter.overflow(for: 1) == "+1")
    #expect(PortFormatter.overflow(for: 12) == "+12")
    #expect(PortFormatter.overflow(for: 1000) == "+1000")
  }
}

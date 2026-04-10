import Testing

@testable import DevtailKit

struct ANSIParserTests {

  private func parse(_ input: String) -> [TerminalAction] {
    var parser = ANSIParser()
    return parser.parse(input)
  }

  private func firstSpan(_ actions: [TerminalAction]) -> StyledSpan? {
    for action in actions {
      if case .text(let span) = action { return span }
    }
    return nil
  }

  @Test func plainTextPassesThrough() {
    let actions = parse("hello world")
    #expect(actions.count == 1)
    guard case .text(let span) = actions[0] else {
      Issue.record("Expected .text action")
      return
    }
    #expect(span.text == "hello world")
    #expect(span.style == ANSIStyle())
  }

  @Test func emptyStringProducesNoActions() {
    let actions = parse("")
    #expect(actions.isEmpty)
  }

  @Test func newlineProducesNewlineAction() {
    let actions = parse("\n")
    #expect(actions.count == 1)
    guard case .newline = actions[0] else {
      Issue.record("Expected .newline")
      return
    }
  }

  @Test func carriageReturnProducesCarriageReturnAction() {
    let actions = parse("\r")
    #expect(actions.count == 1)
    guard case .carriageReturn = actions[0] else {
      Issue.record("Expected .carriageReturn")
      return
    }
  }

  @Test func textBeforeAndAfterNewline() {
    let actions = parse("abc\ndef")
    #expect(actions.count == 3)
    if case .text(let s1) = actions[0] { #expect(s1.text == "abc") }
    guard case .newline = actions[1] else {
      Issue.record("Expected .newline")
      return
    }
    if case .text(let s2) = actions[2] { #expect(s2.text == "def") }
  }

  @Test func standardForegroundColors() {
    for code in 30...37 {
      let actions = parse("\u{1B}[\(code)mX")
      let span = firstSpan(actions)
      #expect(span != nil, "Code \(code) should produce text")
      #expect(span?.style.foreground == .standard(UInt8(code - 30)))
    }
  }

  @Test func standardBackgroundColors() {
    for code in 40...47 {
      let actions = parse("\u{1B}[\(code)mX")
      let span = firstSpan(actions)
      #expect(span != nil, "Code \(code) should produce text")
      #expect(span?.style.background == .standard(UInt8(code - 40)))
    }
  }

  @Test func brightForegroundColors() {
    for code in 90...97 {
      let actions = parse("\u{1B}[\(code)mX")
      let span = firstSpan(actions)
      #expect(span != nil, "Code \(code) should produce text")
      #expect(span?.style.foreground == .bright(UInt8(code - 90)))
    }
  }

  @Test func brightBackgroundColors() {
    for code in 100...107 {
      let actions = parse("\u{1B}[\(code)mX")
      let span = firstSpan(actions)
      #expect(span != nil, "Code \(code) should produce text")
      #expect(span?.style.background == .bright(UInt8(code - 100)))
    }
  }

  @Test func foreground256Color() {
    let actions = parse("\u{1B}[38;5;123mHi")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .palette(123))
    #expect(span?.text == "Hi")
  }

  @Test func background256Color() {
    let actions = parse("\u{1B}[48;5;200mBg")
    let span = firstSpan(actions)
    #expect(span?.style.background == .palette(200))
    #expect(span?.text == "Bg")
  }

  @Test func foreground256ColorZero() {
    let actions = parse("\u{1B}[38;5;0mX")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .palette(0))
  }

  @Test func foreground256Color255() {
    let actions = parse("\u{1B}[38;5;255mX")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .palette(255))
  }

  @Test func foregroundRGBColor() {
    let actions = parse("\u{1B}[38;2;255;128;0mTruecolor")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .rgb(255, 128, 0))
    #expect(span?.text == "Truecolor")
  }

  @Test func backgroundRGBColor() {
    let actions = parse("\u{1B}[48;2;10;20;30mBgRGB")
    let span = firstSpan(actions)
    #expect(span?.style.background == .rgb(10, 20, 30))
    #expect(span?.text == "BgRGB")
  }

  @Test func rgbColorAllZeros() {
    let actions = parse("\u{1B}[38;2;0;0;0mBlack")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .rgb(0, 0, 0))
  }

  @Test func rgbColorAllMax() {
    let actions = parse("\u{1B}[38;2;255;255;255mWhite")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .rgb(255, 255, 255))
  }

  @Test func boldStyle() {
    let actions = parse("\u{1B}[1mBold")
    let span = firstSpan(actions)
    #expect(span?.style.bold == true)
    #expect(span?.text == "Bold")
  }

  @Test func dimStyle() {
    let actions = parse("\u{1B}[2mDim")
    let span = firstSpan(actions)
    #expect(span?.style.dim == true)
  }

  @Test func italicStyle() {
    let actions = parse("\u{1B}[3mItalic")
    let span = firstSpan(actions)
    #expect(span?.style.italic == true)
  }

  @Test func underlineStyle() {
    let actions = parse("\u{1B}[4mUnderline")
    let span = firstSpan(actions)
    #expect(span?.style.underline == true)
  }

  @Test func strikethroughStyle() {
    let actions = parse("\u{1B}[9mStrike")
    let span = firstSpan(actions)
    #expect(span?.style.strikethrough == true)
  }

  @Test func resetClearsAllStyles() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[1;31m")
    let actions = parser.parse("\u{1B}[0mAfterReset")
    let span = firstSpan(actions)
    #expect(span?.style == ANSIStyle())
    #expect(span?.text == "AfterReset")
  }

  @Test func emptySGRResetsStyle() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[1;31m")
    let actions = parser.parse("\u{1B}[mReset")
    let span = firstSpan(actions)
    #expect(span?.style == ANSIStyle())
  }

  @Test func code22ResetsBoldAndDim() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[1;2m")
    let actions = parser.parse("\u{1B}[22mText")
    let span = firstSpan(actions)
    #expect(span?.style.bold == false)
    #expect(span?.style.dim == false)
  }

  @Test func code23ResetsItalic() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[3m")
    let actions = parser.parse("\u{1B}[23mText")
    let span = firstSpan(actions)
    #expect(span?.style.italic == false)
  }

  @Test func code24ResetsUnderline() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[4m")
    let actions = parser.parse("\u{1B}[24mText")
    let span = firstSpan(actions)
    #expect(span?.style.underline == false)
  }

  @Test func code29ResetsStrikethrough() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[9m")
    let actions = parser.parse("\u{1B}[29mText")
    let span = firstSpan(actions)
    #expect(span?.style.strikethrough == false)
  }

  @Test func code39ResetsDefaultForeground() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[31m")
    let actions = parser.parse("\u{1B}[39mText")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .default)
  }

  @Test func code49ResetsDefaultBackground() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[42m")
    let actions = parser.parse("\u{1B}[49mText")
    let span = firstSpan(actions)
    #expect(span?.style.background == .default)
  }
}

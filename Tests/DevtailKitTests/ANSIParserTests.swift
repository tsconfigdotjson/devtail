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

  private func allSpans(_ actions: [TerminalAction]) -> [StyledSpan] {
    actions.compactMap {
      if case .text(let span) = $0 { return span }
      return nil
    }
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

  @Test func eraseLineCode2K() {
    let actions = parse("\u{1B}[2K")
    #expect(actions.count == 1)
    guard case .eraseLine = actions[0] else {
      Issue.record("Expected .eraseLine")
      return
    }
  }

  @Test func eraseToEndOfLineCodeK() {
    let actions = parse("\u{1B}[K")
    #expect(actions.count == 1)
    guard case .eraseToEndOfLine = actions[0] else {
      Issue.record("Expected .eraseToEndOfLine")
      return
    }
  }

  @Test func eraseToEndOfLineCode0K() {
    let actions = parse("\u{1B}[0K")
    #expect(actions.count == 1)
    guard case .eraseToEndOfLine = actions[0] else {
      Issue.record("Expected .eraseToEndOfLine")
      return
    }
  }

  @Test func cursorUpDefault() {
    let actions = parse("\u{1B}[A")
    #expect(actions.count == 1)
    guard case .cursorUp(let n) = actions[0] else {
      Issue.record("Expected .cursorUp")
      return
    }
    #expect(n == 1)
  }

  @Test func cursorUpExplicitCount() {
    let actions = parse("\u{1B}[3A")
    #expect(actions.count == 1)
    guard case .cursorUp(let n) = actions[0] else {
      Issue.record("Expected .cursorUp")
      return
    }
    #expect(n == 3)
  }

  @Test func cursorUpZeroBecomesOne() {
    let actions = parse("\u{1B}[0A")
    guard case .cursorUp(let n) = actions[0] else {
      Issue.record("Expected .cursorUp")
      return
    }
    #expect(n == 1)
  }

  @Test func multipleSGRParams() {
    let actions = parse("\u{1B}[1;31;42mCombined")
    let span = firstSpan(actions)
    #expect(span?.style.bold == true)
    #expect(span?.style.foreground == .standard(1))
    #expect(span?.style.background == .standard(2))
    #expect(span?.text == "Combined")
  }

  @Test func multipleSGRParamsItalicBrightCyan() {
    let actions = parse("\u{1B}[3;96mTest")
    let span = firstSpan(actions)
    #expect(span?.style.italic == true)
    #expect(span?.style.foreground == .bright(6))
  }

  @Test func controlCharactersAreFiltered() {
    let input = "A\u{01}B\u{02}C\u{07}D"
    let actions = parse(input)
    let span = firstSpan(actions)
    #expect(span?.text == "ABCD")
  }

  @Test func tabCharacterPassesThrough() {
    let actions = parse("A\tB")
    let span = firstSpan(actions)
    #expect(span?.text == "A\tB")
  }

  @Test func incompleteEscapeSequenceIsSkipped() {
    let actions = parse("Hello\u{1B}")
    #expect(actions.count == 1)
    let span = firstSpan(actions)
    #expect(span?.text == "Hello")
  }

  @Test func escNotFollowedByBracketSkips() {
    let actions = parse("A\u{1B}XB")
    let spans = allSpans(actions)
    let combined = spans.map(\.text).joined()
    #expect(combined == "AXB")
  }

  @Test func incompleteCSISequenceIsSkipped() {
    let actions = parse("Hi\u{1B}[31")
    let span = firstSpan(actions)
    #expect(span?.text == "Hi")
  }

  @Test func stylePersistsAcrossParseCalls() {
    var parser = ANSIParser()
    _ = parser.parse("\u{1B}[1;31m")
    let actions = parser.parse("StyledText")
    let span = firstSpan(actions)
    #expect(span?.style.bold == true)
    #expect(span?.style.foreground == .standard(1))
    #expect(span?.text == "StyledText")
  }

  @Test func stylePersistsThenResets() {
    var parser = ANSIParser()
    let a1 = parser.parse("\u{1B}[32mGreen")
    let s1 = firstSpan(a1)
    #expect(s1?.style.foreground == .standard(2))

    let a2 = parser.parse("\u{1B}[0mPlain")
    let s2 = firstSpan(a2)
    #expect(s2?.style == ANSIStyle())
  }

  @Test func mixedTextAndEscapes() {
    let actions = parse("Hello \u{1B}[31mWorld\u{1B}[0m!")
    let spans = allSpans(actions)
    #expect(spans.count == 3)
    #expect(spans[0].text == "Hello ")
    #expect(spans[0].style.foreground == .default)
    #expect(spans[1].text == "World")
    #expect(spans[1].style.foreground == .standard(1))
    #expect(spans[2].text == "!")
    #expect(spans[2].style == ANSIStyle())
  }

  @Test func escapeSequenceAtStartOfString() {
    let actions = parse("\u{1B}[34mBlue text")
    let span = firstSpan(actions)
    #expect(span?.style.foreground == .standard(4))
    #expect(span?.text == "Blue text")
  }

  @Test func escapeSequenceAtEndOfString() {
    let actions = parse("Text\u{1B}[0m")
    let spans = allSpans(actions)
    #expect(spans.count == 1)
    #expect(spans[0].text == "Text")
  }

  @Test func multipleNewlinesInSequence() {
    let actions = parse("\n\n\n")
    #expect(actions.count == 3)
    for action in actions {
      guard case .newline = action else {
        Issue.record("Expected all .newline")
        return
      }
    }
  }

  @Test func separateCRAndLFProduceBothActions() {
    var parser = ANSIParser()
    let a1 = parser.parse("line1\r")
    let a2 = parser.parse("\nline2")
    #expect(a1.count == 2)
    if case .text(let s) = a1[0] { #expect(s.text == "line1") }
    guard case .carriageReturn = a1[1] else {
      Issue.record("Expected .carriageReturn")
      return
    }
    #expect(a2.count == 2)
    guard case .newline = a2[0] else {
      Issue.record("Expected .newline")
      return
    }
    if case .text(let s) = a2[1] { #expect(s.text == "line2") }
  }

  @Test func carriageReturnFollowedByText() {
    let actions = parse("old\rnew")
    #expect(actions.count == 3)
    if case .text(let s) = actions[0] { #expect(s.text == "old") }
    guard case .carriageReturn = actions[1] else {
      Issue.record("Expected .carriageReturn")
      return
    }
    if case .text(let s) = actions[2] { #expect(s.text == "new") }
  }

  @Test func extendedColor38WithInsufficientParams() {
    let actions = parse("\u{1B}[38;5mX")
    let span = firstSpan(actions)
    #expect(span?.text == "X")
  }

  @Test func extendedColor38ModeUnknown() {
    let actions = parse("\u{1B}[38;3;100mX")
    let span = firstSpan(actions)
    #expect(span?.text == "X")
    #expect(span?.style.foreground == .default)
  }

  @Test func truecolorWithInsufficientParams() {
    let actions = parse("\u{1B}[38;2;255;128mX")
    let span = firstSpan(actions)
    #expect(span?.text == "X")
    #expect(span?.style.foreground == .default)
  }

  @Test func unrecognizedCSIFinalCharIsIgnored() {
    let actions = parse("A\u{1B}[2JB")
    let spans = allSpans(actions)
    let combined = spans.map(\.text).joined()
    #expect(combined == "AB")
  }

  @Test func npmColoredOutput() {
    let input = "\u{1B}[1m\u{1B}[32m>\u{1B}[0m dev\n  next dev"
    let actions = parse(input)
    let spans = allSpans(actions)
    #expect(spans.count >= 2)
    #expect(spans[0].style.bold == true)
    #expect(spans[0].style.foreground == .standard(2))
    #expect(spans[0].text == ">")
  }

  @Test func progressBarWithCR() {
    let input = "Progress: 50%\rProgress: 100%"
    let actions = parse(input)
    #expect(actions.count == 3)
    if case .text(let s) = actions[0] { #expect(s.text == "Progress: 50%") }
    guard case .carriageReturn = actions[1] else {
      Issue.record("Expected .carriageReturn")
      return
    }
    if case .text(let s) = actions[2] { #expect(s.text == "Progress: 100%") }
  }
}

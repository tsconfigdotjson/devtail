import Testing

@testable import DevtailKit

struct ANSIParserEdgeCaseTests {

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

  @Test func malformedCSIWithInvalidInteriorCharIsTreatedAsText() {
    // `~` isn't a digit, `;`, `:`, `?`, or a terminator letter — parseCSI
    // bails out, so the ESC is skipped and the remaining bytes flow through
    // as plain text rather than mutating style.
    let actions = parse("before\u{1B}[3~5mafter")
    let text = allSpans(actions).map(\.text).joined()
    #expect(text == "before[3~5mafter")
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

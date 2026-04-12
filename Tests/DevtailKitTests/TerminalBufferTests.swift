import Testing

@testable import DevtailKit

extension TerminalLine {
  fileprivate var plainText: String {
    spans.map(\.text).joined()
  }
}

@MainActor
struct TerminalBufferTests {

  @Test func initialStateHasOneEmptyLine() {
    let buffer = TerminalBuffer()
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].isEmpty)
  }

  @Test func hasContentIsFalseInitially() {
    let buffer = TerminalBuffer()
    #expect(buffer.hasContent == false)
  }

  @Test func initialVersionIsZero() {
    let buffer = TerminalBuffer()
    #expect(buffer.version == 0)
  }

  @Test func appendPlainTextMakesHasContentTrue() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    #expect(buffer.hasContent == true)
  }

  @Test func appendPlainTextAddsToCurrentLine() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].plainText == "hello")
  }

  @Test func appendMultipleTimesAccumulatesContent() {
    let buffer = TerminalBuffer()
    buffer.append("hello ")
    buffer.append("world")
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].plainText == "hello world")
  }

  @Test func newlineIncrementsCursorAndAddsNewLine() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2")
    #expect(buffer.lines.count == 2)
    #expect(buffer.lines[0].plainText == "line1")
    #expect(buffer.lines[1].plainText == "line2")
  }

  @Test func multipleNewlinesCreateMultipleLines() {
    let buffer = TerminalBuffer()
    buffer.append("a\nb\nc\n")
    #expect(buffer.lines.count == 4)
    #expect(buffer.lines[0].plainText == "a")
    #expect(buffer.lines[1].plainText == "b")
    #expect(buffer.lines[2].plainText == "c")
    #expect(buffer.lines[3].isEmpty)
  }

  @Test func newlineAcrossMultipleAppends() {
    let buffer = TerminalBuffer()
    buffer.append("line1\n")
    buffer.append("line2")
    #expect(buffer.lines.count == 2)
    #expect(buffer.lines[0].plainText == "line1")
    #expect(buffer.lines[1].plainText == "line2")
  }

  @Test func carriageReturnClearsCurrentLineSpans() {
    let buffer = TerminalBuffer()
    buffer.append("old text\rnew text")
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].plainText == "new text")
  }

  @Test func carriageReturnOnEmptyLine() {
    let buffer = TerminalBuffer()
    buffer.append("\rtext")
    #expect(buffer.lines[0].plainText == "text")
  }

  @Test func eraseLineClearsCurrentLine() {
    let buffer = TerminalBuffer()
    buffer.append("some content\u{1B}[2K")
    #expect(buffer.lines[0].isEmpty)
  }

  @Test func eraseToEndOfLineClearsCurrentLine() {
    let buffer = TerminalBuffer()
    buffer.append("some content\u{1B}[K")
    #expect(buffer.lines[0].isEmpty)
  }

  @Test func eraseLineAfterNewlineOnlyAffectsCurrentLine() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2\u{1B}[2K")
    #expect(buffer.lines[0].plainText == "line1")
    #expect(buffer.lines[1].isEmpty)
  }

  @Test func cursorUpMovesBackAndClearsTargetLine() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2\n\u{1B}[2Areplaced")
    #expect(buffer.lines[0].plainText == "replaced")
  }

  @Test func cursorUpDoesntGoBelowZero() {
    let buffer = TerminalBuffer()
    buffer.append("only line\u{1B}[99Astill here")
    #expect(buffer.lines[0].plainText == "still here")
  }

  @Test func cursorUpBy1() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2\u{1B}[Areplaced")
    #expect(buffer.lines[0].plainText == "replaced")
  }

  @Test func versionIncrementsOnEveryAppend() {
    let buffer = TerminalBuffer()
    let v0 = buffer.version
    buffer.append("a")
    let v1 = buffer.version
    buffer.append("b")
    let v2 = buffer.version
    #expect(v1 == v0 + 1)
    #expect(v2 == v1 + 1)
  }

  @Test func versionIncrementsOnClear() {
    let buffer = TerminalBuffer()
    buffer.append("stuff")
    let vBefore = buffer.version
    buffer.clear()
    #expect(buffer.version == vBefore + 1)
  }

  @Test func clearResetsToInitialState() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2\nline3")
    buffer.clear()
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].isEmpty)
    #expect(buffer.hasContent == false)
  }

  @Test func clearResetsParser() {
    let buffer = TerminalBuffer()
    buffer.append("\u{1B}[31mred text")
    buffer.clear()
    buffer.append("plain")
    #expect(buffer.lines[0].spans[0].style == ANSIStyle())
  }

  @Test func bufferTrimsWhenExceedingMaxLines() {
    let buffer = TerminalBuffer(maxLines: 5)
    buffer.append("1\n2\n3\n4\n5\n6\n7")
    #expect(buffer.lines.count <= 5)
  }

  @Test func trimmedBufferKeepsLatestLines() {
    let buffer = TerminalBuffer(maxLines: 3)
    buffer.append("a\nb\nc\nd\ne")
    #expect(buffer.lines.count == 3)
    let texts = buffer.lines.map(\.plainText)
    #expect(texts.contains("e"))
  }

  @Test func cursorAdjustsAfterTrim() {
    let buffer = TerminalBuffer(maxLines: 3)
    buffer.append("1\n2\n3\n4\n5")
    buffer.append(" more")
    #expect(buffer.lines.last?.plainText.contains("more") == true)
  }

  @Test func trimWithExactMaxLinesDoesNotTrim() {
    let buffer = TerminalBuffer(maxLines: 3)
    buffer.append("a\nb\nc")
    #expect(buffer.lines.count == 3)
    #expect(buffer.lines[0].plainText == "a")
    #expect(buffer.lines[1].plainText == "b")
    #expect(buffer.lines[2].plainText == "c")
  }

  @Test func ansiColorsFlowThroughCorrectly() {
    let buffer = TerminalBuffer()
    buffer.append("\u{1B}[31mRed\u{1B}[0m Normal")
    let spans = buffer.lines[0].spans
    #expect(spans.count == 2)
    #expect(spans[0].style.foreground == .standard(1))
    #expect(spans[0].text == "Red")
    #expect(spans[1].style == ANSIStyle())
    #expect(spans[1].text == " Normal")
  }

  @Test func boldAndColorCombined() {
    let buffer = TerminalBuffer()
    buffer.append("\u{1B}[1;34mBoldBlue")
    let spans = buffer.lines[0].spans
    #expect(spans[0].style.bold == true)
    #expect(spans[0].style.foreground == .standard(4))
  }

  @Test func lineIDsAreUniqueAndIncrementing() {
    let buffer = TerminalBuffer()
    buffer.append("line1\nline2\nline3")
    let ids = buffer.lines.map(\.id)
    #expect(Set(ids).count == ids.count)
    for i in 1..<ids.count {
      #expect(ids[i] > ids[i - 1])
    }
  }

  @Test func lineIDsIncrementAcrossClears() {
    let buffer = TerminalBuffer()
    let firstID = buffer.lines[0].id
    buffer.clear()
    let secondID = buffer.lines[0].id
    #expect(secondID > firstID)
  }

  @Test func plainTextJoinsSpans() {
    let line = TerminalLine(
      id: 0,
      spans: [
        StyledSpan(text: "hello ", style: ANSIStyle()),
        StyledSpan(text: "world", style: ANSIStyle()),
      ]
    )
    #expect(line.plainText == "hello world")
  }

  @Test func isEmptyWithNoSpans() {
    let line = TerminalLine(id: 0, spans: [])
    #expect(line.isEmpty == true)
  }

  @Test func isEmptyWithEmptySpans() {
    let line = TerminalLine(
      id: 0,
      spans: [
        StyledSpan(text: "", style: ANSIStyle())
      ]
    )
    #expect(line.isEmpty == true)
  }

  @Test func isEmptyWithContent() {
    let line = TerminalLine(
      id: 0,
      spans: [
        StyledSpan(text: "x", style: ANSIStyle())
      ]
    )
    #expect(line.isEmpty == false)
  }

  @Test func plainTextOnEmptyLine() {
    let line = TerminalLine(id: 0)
    #expect(line.plainText == "")
  }

  @Test func appendEmptyString() {
    let buffer = TerminalBuffer()
    let vBefore = buffer.version
    buffer.append("")
    #expect(buffer.version == vBefore + 1)
    #expect(buffer.lines.count == 1)
    #expect(buffer.hasContent == false)
  }

  @Test func rapidAppends() {
    let buffer = TerminalBuffer()
    for i in 0..<100 {
      buffer.append("line\(i)\n")
    }
    #expect(buffer.lines.count == 101)
    #expect(buffer.lines[0].plainText == "line0")
    #expect(buffer.lines[99].plainText == "line99")
  }

  @Test func maxLinesOf1() {
    let buffer = TerminalBuffer(maxLines: 1)
    buffer.append("a\nb\nc")
    #expect(buffer.lines.count == 1)
    #expect(buffer.lines[0].plainText == "c")
  }
}

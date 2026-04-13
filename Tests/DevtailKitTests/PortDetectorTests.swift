import Darwin
import Foundation
import Testing

@testable import DevtailKit

@Suite
struct PortDetectorParseTests {

  @Test func parseProcessTreeHandlesTypicalPSOutput() {
    let out = """
          1     0
        500     1
        606     1
        643   606
        700   643
      """
    let tree = PortDetector.parseProcessTree(from: out)
    #expect(tree[0] == [1])
    #expect(tree[1]?.sorted() == [500, 606])
    #expect(tree[606] == [643])
    #expect(tree[643] == [700])
  }

  @Test func parseProcessTreeIgnoresMalformedLines() {
    let out = """
       garbage line
        42  7
       also bad
         9  42
      """
    let tree = PortDetector.parseProcessTree(from: out)
    #expect(tree[7] == [42])
    #expect(tree[42] == [9])
    #expect(tree.count == 2)
  }

  @Test func parseProcessTreeEmptyInputYieldsEmpty() {
    #expect(PortDetector.parseProcessTree(from: "").isEmpty)
  }

  @Test func descendantsWalksDeeply() {
    let tree: [Int32: [Int32]] = [
      1: [10, 11],
      10: [100, 101],
      100: [1000],
      11: [110],
    ]
    let result = PortDetector.descendants(of: 1, in: tree)
    #expect(result == Set<Int32>([1, 10, 11, 100, 101, 110, 1000]))
  }

  @Test func descendantsReturnsOnlyRootWhenNoChildren() {
    let result = PortDetector.descendants(of: 42, in: [:])
    #expect(result == Set<Int32>([42]))
  }

  @Test func descendantsTerminatesOnCycles() {
    // Shouldn't happen in practice, but guard against pathological input.
    let tree: [Int32: [Int32]] = [1: [2], 2: [1]]
    let result = PortDetector.descendants(of: 1, in: tree)
    #expect(result == Set<Int32>([1, 2]))
  }

  @Test func parseListeningPortsWildcardAndIPv4() {
    let out = """
      p606
      f10
      n*:7000
      f11
      n127.0.0.1:5000
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[606] == Set([7000, 5000]))
  }

  @Test func parseListeningPortsIPv6BracketNotation() {
    let out = """
      p838
      f29
      n[::1]:7679
      f30
      n[::]:8080
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[838] == Set([7679, 8080]))
  }

  @Test func parseListeningPortsDedupesAcrossIPFamilies() {
    // Same port appearing on IPv4 and IPv6 bindings — set semantics collapse.
    let out = """
      p606
      f10
      n*:3000
      f11
      n[::]:3000
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[606] == Set([3000]))
  }

  @Test func parseListeningPortsMultiplePIDs() {
    let out = """
      p101
      f7
      n*:1000
      p202
      f8
      n*:2000
      f9
      n*:2001
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[101] == Set([1000]))
    #expect(result[202] == Set([2000, 2001]))
  }

  @Test func parseListeningPortsSkipsNamesBeforeAnyPID() {
    let out = """
      n*:9999
      p42
      f1
      n*:1234
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[42] == Set([1234]))
    #expect(result.count == 1)
  }

  @Test func parseListeningPortsIgnoresUnparseablePorts() {
    let out = """
      p10
      f1
      n*:notaport
      f2
      n*:8080
      """
    let result = PortDetector.parseListeningPorts(from: out)
    #expect(result[10] == Set([8080]))
  }

  @Test func parseListeningPortsEmptyInputYieldsEmpty() {
    #expect(PortDetector.parseListeningPorts(from: "").isEmpty)
  }
}

@Suite(.serialized)
struct PortDetectorIntegrationTests {

  @Test func detectsPortBoundByCurrentProcess() throws {
    let (fd, port) = try bindEphemeralListener()
    defer { Darwin.close(fd) }

    let result = PortDetector.detect(rootPIDs: [getpid()])
    let ports = result[getpid()] ?? []
    #expect(ports.contains(port), "expected to see port \(port) in \(ports)")
  }

  @Test func returnsEmptyForEmptyRootSet() {
    #expect(PortDetector.detect(rootPIDs: []).isEmpty)
  }

  @Test func returnsEmptyPortsForUnrelatedPID() {
    // pid 1 (launchd) typically isn't listening on TCP ports we'd confuse with a dev server.
    let result = PortDetector.detect(rootPIDs: [1])
    // Either pid 1 isn't in the map, or its descendants don't include the caller's listener.
    let (fd, port) = (try? bindEphemeralListener()) ?? (-1, 0)
    defer { if fd >= 0 { Darwin.close(fd) } }
    let pid1Ports = result[1] ?? []
    #expect(!pid1Ports.contains(port))
  }

  private func bindEphemeralListener() throws -> (fd: Int32, port: Int) {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    #expect(fd >= 0)

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian
    addr.sin_port = 0
    var bindResult: Int32 = -1
    withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        bindResult = Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    #expect(bindResult == 0)
    #expect(Darwin.listen(fd, 4) == 0)

    var boundAddr = sockaddr_in()
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        Darwin.getsockname(fd, sa, &len)
      }
    }
    #expect(nameResult == 0)
    let port = Int(UInt16(bigEndian: boundAddr.sin_port))
    return (fd, port)
  }
}

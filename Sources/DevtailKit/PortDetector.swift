import Foundation

public enum PortDetector {
  public static func detect(rootPIDs: [Int32]) -> [Int32: [Int]] {
    guard !rootPIDs.isEmpty else { return [:] }
    let tree = buildChildTree()
    let listening = listeningPortsByPID()
    var out: [Int32: [Int]] = [:]
    for root in rootPIDs {
      let family = descendants(of: root, in: tree)
      var ports: Set<Int> = []
      for pid in family {
        if let p = listening[pid] { ports.formUnion(p) }
      }
      out[root] = ports.sorted()
    }
    return out
  }

  private static func buildChildTree() -> [Int32: [Int32]] {
    guard let out = runCapture("/bin/ps", ["-A", "-o", "pid=,ppid="]) else { return [:] }
    return parseProcessTree(from: out)
  }

  internal static func parseProcessTree(from psOutput: String) -> [Int32: [Int32]] {
    var tree: [Int32: [Int32]] = [:]
    for line in psOutput.split(separator: "\n") {
      let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
      guard parts.count >= 2,
        let pid = Int32(parts[0]),
        let ppid = Int32(parts[1])
      else { continue }
      tree[ppid, default: []].append(pid)
    }
    return tree
  }

  internal static func descendants(of root: Int32, in tree: [Int32: [Int32]]) -> Set<Int32> {
    var visited: Set<Int32> = [root]
    var stack: [Int32] = [root]
    while let cur = stack.popLast() {
      guard let kids = tree[cur] else { continue }
      for k in kids where !visited.contains(k) {
        visited.insert(k)
        stack.append(k)
      }
    }
    return visited
  }

  private static func listeningPortsByPID() -> [Int32: Set<Int>] {
    guard
      let out = runCapture(
        "/usr/sbin/lsof",
        ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-Fpn"]
      )
    else { return [:] }
    return parseListeningPorts(from: out)
  }

  internal static func parseListeningPorts(from lsofOutput: String) -> [Int32: Set<Int>] {
    var result: [Int32: Set<Int>] = [:]
    var pid: Int32 = 0
    for line in lsofOutput.split(separator: "\n") {
      guard let first = line.first else { continue }
      let rest = line.dropFirst()
      if first == "p" {
        pid = Int32(rest) ?? 0
      } else if first == "n", pid > 0,
        let colonIdx = rest.lastIndex(of: ":"),
        let port = Int(rest[rest.index(after: colonIdx)...])
      {
        result[pid, default: []].insert(port)
      }
    }
    return result
  }

  private static func runCapture(_ path: String, _ args: [String]) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: path)
    proc.arguments = args
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = Pipe()
    do {
      try proc.run()
    } catch {
      return nil
    }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    return String(data: data, encoding: .utf8)
  }
}

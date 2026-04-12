import Foundation
import Testing

@testable import DevtailKit

struct ProcessRunnerEnvTests {

  @Test func alwaysSetsForcedKeys() {
    let env = ProcessRunner.makeEnvironment()
    #expect(env["HOME"] == NSHomeDirectory())
    #expect(env["USER"] == NSUserName())
    #expect(env["FORCE_COLOR"] == "1")
    #expect(env["TERM"] == "xterm-256color")
  }

  @Test func inheritsPATHFromParent() {
    guard let parentPATH = ProcessInfo.processInfo.environment["PATH"] else { return }
    let env = ProcessRunner.makeEnvironment()
    #expect(env["PATH"] == parentPATH)
  }

  @Test func inheritedEnvKeysIncludesDevServerEssentials() {
    let required: Set<String> = ["PATH", "SHELL", "PWD", "TMPDIR", "LANG", "LC_ALL", "NODE_ENV"]
    let actual = Set(ProcessRunner.inheritedEnvKeys)
    #expect(required.isSubset(of: actual))
  }

  @Test func excludesUnlistedParentKeys() {
    let env = ProcessRunner.makeEnvironment()
    #expect(env["AWS_SECRET_ACCESS_KEY"] == nil)
    #expect(env["PRIVATE_API_KEY"] == nil)
  }

  @Test func inheritsNilKeysGracefully() {
    let env = ProcessRunner.makeEnvironment()
    #expect(!env.isEmpty)
  }
}

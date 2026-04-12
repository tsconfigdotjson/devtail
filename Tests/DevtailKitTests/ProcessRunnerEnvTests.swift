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
    // Our own process almost always has PATH set; if not, skip.
    guard let parentPATH = ProcessInfo.processInfo.environment["PATH"] else { return }
    let env = ProcessRunner.makeEnvironment()
    #expect(env["PATH"] == parentPATH)
  }

  @Test func inheritedEnvKeysIncludesDevServerEssentials() {
    // Regression guard — if these get dropped, dev servers break in
    // non-obvious ways (can't find node, locale issues, etc.).
    let required: Set<String> = ["PATH", "SHELL", "PWD", "TMPDIR", "LANG", "LC_ALL", "NODE_ENV"]
    let actual = Set(ProcessRunner.inheritedEnvKeys)
    #expect(required.isSubset(of: actual))
  }

  @Test func excludesUnlistedParentKeys() {
    // Fabricate a key that is definitely not in our allowlist and confirm it
    // doesn't leak into the subprocess env. We can't mutate the parent env
    // safely, but we can assert the key never appears in output.
    let env = ProcessRunner.makeEnvironment()
    #expect(env["AWS_SECRET_ACCESS_KEY"] == nil)
    #expect(env["PRIVATE_API_KEY"] == nil)
  }

  @Test func inheritsNilKeysGracefully() {
    // Make sure makeEnvironment doesn't crash if some allowlisted keys aren't
    // set in the parent. Just call it — if it returns without throwing we're
    // good.
    let env = ProcessRunner.makeEnvironment()
    #expect(!env.isEmpty)
  }
}

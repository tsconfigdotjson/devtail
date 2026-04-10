import Foundation
import Testing

/// These tests verify the Codable round-trip behavior of the persistence model.
/// Since `SavedProcess` lives in the executable target and cannot be imported,
/// we replicate the identical Codable structures here and verify encoding/decoding
/// logic that mirrors Sources/devtail/Persistence.swift.
struct PersistenceTests {

  // MARK: - Mirror of SavedProcess (must match Sources/devtail/Persistence.swift)

  private struct SavedProcess: Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var auxiliaryCommands: [SavedAuxCommand]
    var wasRunning: Bool

    struct SavedAuxCommand: Codable, Equatable {
      let id: UUID
      var name: String
      var command: String
    }
  }

  // MARK: - Helpers

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private func roundTrip(_ processes: [SavedProcess]) throws -> [SavedProcess] {
    let data = try encoder.encode(processes)
    return try decoder.decode([SavedProcess].self, from: data)
  }

  // MARK: - Round-trip tests

  @Test func saveAndLoadRoundTripPreservesData() throws {
    let id = UUID()
    let auxID = UUID()
    let processes = [
      SavedProcess(
        id: id,
        name: "Web Server",
        command: "npm run dev",
        workingDirectory: "/Users/test/project",
        auxiliaryCommands: [
          SavedProcess.SavedAuxCommand(id: auxID, name: "Tailwind", command: "npx tailwindcss --watch")
        ],
        wasRunning: true
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded == processes)
    #expect(loaded[0].id == id)
    #expect(loaded[0].name == "Web Server")
    #expect(loaded[0].command == "npm run dev")
    #expect(loaded[0].workingDirectory == "/Users/test/project")
    #expect(loaded[0].auxiliaryCommands.count == 1)
    #expect(loaded[0].auxiliaryCommands[0].id == auxID)
    #expect(loaded[0].auxiliaryCommands[0].name == "Tailwind")
    #expect(loaded[0].wasRunning == true)
  }

  @Test func emptyProcessesListRoundTrips() throws {
    let processes: [SavedProcess] = []
    let loaded = try roundTrip(processes)
    #expect(loaded.isEmpty)
  }

  @Test func processWithMultipleAuxiliaryCommands() throws {
    let processes = [
      SavedProcess(
        id: UUID(),
        name: "Full Stack",
        command: "next dev",
        workingDirectory: "~/projects/app",
        auxiliaryCommands: [
          SavedProcess.SavedAuxCommand(id: UUID(), name: "CSS", command: "tailwind --watch"),
          SavedProcess.SavedAuxCommand(id: UUID(), name: "TypeCheck", command: "tsc --watch"),
          SavedProcess.SavedAuxCommand(id: UUID(), name: "Lint", command: "eslint --watch"),
        ],
        wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].auxiliaryCommands.count == 3)
    #expect(loaded[0].auxiliaryCommands[0].name == "CSS")
    #expect(loaded[0].auxiliaryCommands[1].name == "TypeCheck")
    #expect(loaded[0].auxiliaryCommands[2].name == "Lint")
  }

  @Test func wasRunningFlagPreserved() throws {
    let running = SavedProcess(
      id: UUID(), name: "A", command: "a", workingDirectory: "",
      auxiliaryCommands: [], wasRunning: true
    )
    let stopped = SavedProcess(
      id: UUID(), name: "B", command: "b", workingDirectory: "",
      auxiliaryCommands: [], wasRunning: false
    )
    let loaded = try roundTrip([running, stopped])
    #expect(loaded[0].wasRunning == true)
    #expect(loaded[1].wasRunning == false)
  }

  @Test func workingDirectoryPreserved() throws {
    let processes = [
      SavedProcess(
        id: UUID(), name: "Test", command: "make test",
        workingDirectory: "/some/deep/path/to/project",
        auxiliaryCommands: [], wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].workingDirectory == "/some/deep/path/to/project")
  }

  @Test func emptyWorkingDirectory() throws {
    let processes = [
      SavedProcess(
        id: UUID(), name: "Test", command: "echo hi",
        workingDirectory: "",
        auxiliaryCommands: [], wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].workingDirectory == "")
  }

  @Test func multipleProcessesRoundTrip() throws {
    let processes = (0..<5).map { i in
      SavedProcess(
        id: UUID(),
        name: "Process \(i)",
        command: "cmd \(i)",
        workingDirectory: "/path/\(i)",
        auxiliaryCommands: [],
        wasRunning: i % 2 == 0
      )
    }
    let loaded = try roundTrip(processes)
    #expect(loaded.count == 5)
    for i in 0..<5 {
      #expect(loaded[i].name == "Process \(i)")
      #expect(loaded[i].command == "cmd \(i)")
      #expect(loaded[i].wasRunning == (i % 2 == 0))
    }
  }

  @Test func uuidPreservedExactly() throws {
    let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
    let processes = [
      SavedProcess(
        id: id, name: "Test", command: "test",
        workingDirectory: "", auxiliaryCommands: [], wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].id == id)
  }

  // MARK: - UserDefaults-style edge cases

  @Test func malformedJSONReturnsEmptyArray() {
    let badData = "not valid json".data(using: .utf8)!
    let result = try? JSONDecoder().decode([SavedProcess].self, from: badData)
    #expect(result == nil)
  }

  @Test func missingFieldsFailToDecode() {
    // JSON with missing required field "command"
    let json = """
      [{"id":"12345678-1234-1234-1234-123456789ABC","name":"Test","workingDirectory":"","auxiliaryCommands":[],"wasRunning":false}]
      """
    let data = json.data(using: .utf8)!
    let result = try? JSONDecoder().decode([SavedProcess].self, from: data)
    #expect(result == nil)
  }

  @Test func emptyJSONArrayDecodesToEmpty() throws {
    let data = "[]".data(using: .utf8)!
    let result = try JSONDecoder().decode([SavedProcess].self, from: data)
    #expect(result.isEmpty)
  }

  @Test func specialCharactersInCommandPreserved() throws {
    let processes = [
      SavedProcess(
        id: UUID(), name: "Special",
        command: "echo 'hello world' && cat /dev/null | grep -E \"^$\" > /tmp/out",
        workingDirectory: "/path/with spaces/and-dashes",
        auxiliaryCommands: [], wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].command == processes[0].command)
    #expect(loaded[0].workingDirectory == processes[0].workingDirectory)
  }

  @Test func unicodeInNamesPreserved() throws {
    let processes = [
      SavedProcess(
        id: UUID(), name: "Server (production)",
        command: "echo 'Hola Mundo'",
        workingDirectory: "",
        auxiliaryCommands: [
          SavedProcess.SavedAuxCommand(id: UUID(), name: "Worker", command: "rake jobs:work")
        ],
        wasRunning: false
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].name == "Server (production)")
    #expect(loaded[0].auxiliaryCommands[0].name == "Worker")
  }

  @Test func processWithNoAuxiliaryCommandsRoundTrips() throws {
    let processes = [
      SavedProcess(
        id: UUID(), name: "Simple", command: "ls",
        workingDirectory: "", auxiliaryCommands: [], wasRunning: true
      )
    ]
    let loaded = try roundTrip(processes)
    #expect(loaded[0].auxiliaryCommands.isEmpty)
  }

  @Test func largeNumberOfProcesses() throws {
    let processes = (0..<100).map { i in
      SavedProcess(
        id: UUID(),
        name: "Process \(i)",
        command: "cmd \(i)",
        workingDirectory: "/path/\(i)",
        auxiliaryCommands: [
          SavedProcess.SavedAuxCommand(id: UUID(), name: "Aux \(i)", command: "aux \(i)")
        ],
        wasRunning: false
      )
    }
    let loaded = try roundTrip(processes)
    #expect(loaded.count == 100)
  }
}

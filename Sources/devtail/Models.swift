import Foundation

struct ProcessConfig: Identifiable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var auxiliaryCommands: [AuxiliaryCommand]
    var isRunning: Bool
    var commandOutput: String

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "",
        auxiliaryCommands: [AuxiliaryCommand] = [],
        isRunning: Bool = false,
        commandOutput: String = ""
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.auxiliaryCommands = auxiliaryCommands
        self.isRunning = isRunning
        self.commandOutput = commandOutput
    }
}

struct AuxiliaryCommand: Identifiable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var output: String

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        output: String = ""
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.output = output
    }
}

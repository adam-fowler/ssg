import Foundation

@discardableResult public func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

/// Update the PATH environment variable to be the same as the shell that
/// triggered the app
public func updateShellEnvironmentPath() {
    let taskShell = Process()
    taskShell.launchPath = "/usr/bin/env"
    let shell = ProcessInfo.processInfo.environment["SHELL"]!
    taskShell.arguments = [shell, "-c", "eval $(/usr/libexec/path_helper -s) ; echo $PATH"]
    let pipeShell = Pipe()
    taskShell.standardOutput = pipeShell
    taskShell.standardError = pipeShell
    taskShell.launch()
    taskShell.waitUntilExit()
    let output = pipeShell.fileHandleForReading.readDataToEndOfFile()
    var outputShell = String(decoding: output, as: UTF8.self)
    outputShell = outputShell.replacingOccurrences(
        of: "\n", with: "", options: .literal, range: nil)
    print(outputShell)
    setenv("PATH", outputShell, 1)
}

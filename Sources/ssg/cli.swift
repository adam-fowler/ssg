import Foundation

@discardableResult public func shell(shell: String = "/usr/bin/env", _ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = shell
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

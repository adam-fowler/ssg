import Foundation

@discardableResult public func shell(shell: String = "/bin/bash/", _ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = shell
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

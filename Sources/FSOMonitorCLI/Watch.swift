import FSOMonitor
import Foundation
import ArgumentParser

@main
final class Watch: ParsableCommand {
    private static var monitor: FileSystemObjectMonitor?

    @Argument(help: "The file or folder path to monitor file system object events.")
    var path: String

    func run() throws {
        let semaphore = DispatchSemaphore(value: 0)
        Self.monitor = try FileSystemObjectMonitor(path: path, queue: .global(qos: .utility), eventMask: .all)
        Self.monitor?.delegate = self
        print("Watching '\(path)' for events ...")
        semaphore.wait()
    }
}

extension Watch: FileSystemObjectMonitorDelegate {
    func fileSystemObjectMonitorDidReceive(event: FileSystemObjectMonitor.Event) {
        print(event)
    }
}

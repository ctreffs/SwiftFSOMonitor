import FSOMonitor
import Foundation
import ArgumentParser

Watch.main()

final class Watch: ParsableCommand {
    private static var monitor: FileSystemObjectMonitor?

    @Argument(help: "The file or folder path to monitor file system object events.")
    var path: String

    func run() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let monitor = try FileSystemObjectMonitor(path: path)
        Self.monitor = monitor
        monitor.delegate = self
        monitor.start()

        print("Watching '\(path)' for events ...")
        semaphore.wait()
    }
}

extension Watch: FileSystemObjectMonitorDelegate {
    func fileSystemObjectMonitorDidObserveChange(monitor: FileSystemObjectMonitor, event: FileSystemObjectMonitor.Event) {
        print(event)
    }
}

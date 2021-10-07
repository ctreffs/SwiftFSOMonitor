import FSOMonitor
import Foundation
import ArgumentParser

@main
struct Watch: ParsableCommand {
    private static var monitor: FileSystemObjectMonitor?

    @Argument(help: "The file or folder path to monitor file system object events.")
    var path: String

    mutating func run() throws {
        let semaphore = DispatchSemaphore(value: 0)
        Self.monitor = try FileSystemObjectMonitor(path: path, queue: .global(qos: .background), eventMask: .all) { event in
            print(event)
        }
        print("Watching '\(path)' for events ...")
        semaphore.wait()
    }
}

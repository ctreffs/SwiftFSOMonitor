import Foundation

public protocol FileSystemObjectMonitorDelegate: AnyObject {
    func fileSystemObjectMonitorDidObserveChange(monitor: FileSystemObjectMonitor, event: FileSystemObjectMonitor.Event)
}

public final class FileSystemObjectMonitor {
    public typealias EventHandler = (Event) -> Void

    public struct Event {
        /// The file descriptor of the file or socket.
        public let handle: Int32
        /// The type of the last file system event.
        public let data: DispatchSource.FileSystemEvent
        /// The file descriptor attributes being monitored by the dispatch source.
        public let mask: DispatchSource.FileSystemEvent

        init(source: DispatchSourceFileSystemObject) {
            self.handle = source.handle
            self.data = source.data
            self.mask = source.mask
        }
    }

    enum Error: Swift.Error {
        case unableToOpenFile(String)
        case emptyPath
        case noFileURL(String)
    }

    /// A dispatch source to monitor a file descriptor.
    public private(set) var source: DispatchSourceFileSystemObject?

    /// A file descriptor for the monitored file system object.
    public let fileDescriptor: Int32

    /// The set of events you want to monitor
    public let eventMask: DispatchSource.FileSystemEvent

    /// A dispatch queue used for sending file object changes on.
    public let queue: DispatchQueue

    public weak var delegate: FileSystemObjectMonitorDelegate?

    init(fileDescriptor: Int32, eventMask: DispatchSource.FileSystemEvent, queue: DispatchQueue) {
        self.fileDescriptor = fileDescriptor
        self.eventMask = eventMask
        self.queue = queue
    }

    deinit {
        stop()
    }

    public func start() {
        guard source == nil else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                               eventMask: eventMask,
                                                               queue: queue)
        self.source = source

        source.setEventHandler { [unowned self] in
            self.delegate?.fileSystemObjectMonitorDidObserveChange(monitor: self,
                                                                   event: Event(source: source))
        }

        source.setCancelHandler { [unowned self] in
            close(self.fileDescriptor)

            self.source = nil
        }

        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            source.activate()
        } else {
            source.resume()
        }
    }

    public func stop() {
        guard let source = self.source else {
            return
        }

        source.cancel()
    }
}

extension FileSystemObjectMonitor {
    public convenience init(path: String, eventMask: DispatchSource.FileSystemEvent = .all, queue: DispatchQueue = .fileSystemObjectMonitorQueue) throws {
        guard !path.isEmpty else {
            throw Error.emptyPath
        }

        try self.init(url: URL(fileURLWithPath: path), eventMask: eventMask, queue: queue)
    }

    public convenience init(url: URL, eventMask: DispatchSource.FileSystemEvent = .all, queue: DispatchQueue = .fileSystemObjectMonitorQueue) throws {
        guard url.isFileURL else {
            throw Error.noFileURL(url.absoluteURL.path)
        }

        let absolutePath = url.absoluteURL.path

        let fileDescriptor = open(absolutePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw Error.unableToOpenFile(absolutePath)
        }
        self.init(fileDescriptor: fileDescriptor, eventMask: eventMask, queue: queue)
    }
}

extension DispatchQueue {
    public static let fileSystemObjectMonitorQueue = DispatchQueue(label: "com.ctreffs.fileSystemObjectMonitor",
                                                                   attributes: .concurrent)
}

extension DispatchSource.FileSystemEvent: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        return debugDescription
    }

    public var debugDescription: String {
        var out: Set<String> = []
        if self.contains(.delete) {
            out.insert("delete")
        }

        if self.contains(.write) {
            out.insert("write")
        }

        if self.contains(.extend) {
            out.insert("extend")
        }

        if self.contains(.attrib) {
            out.insert("attrib")
        }

        if self.contains(.link) {
            out.insert("link")
        }

        if self.contains(.rename) {
            out.insert("rename")
        }

        if self.contains(.revoke) {
            out.insert("revoke")
        }

        if self.contains(.funlock) {
            out.insert("funlock")
        }

        if self.contains(.all) {
            out.insert("all")
        }

        if out.isEmpty {
            out.insert("unknown(\(rawValue))")
        }

        return "[\(out.sorted().joined(separator: ","))]"
    }
}

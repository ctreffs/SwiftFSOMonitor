import Foundation

public protocol FileSystemObjectMonitorDelegate: AnyObject {
    func fileSystemObjectMonitorDidObserveChange(monitor: FileSystemObjectMonitor, event: FileSystemObjectMonitor.Event)
}

public final class FileSystemObjectMonitor {
    enum Error: Swift.Error {
        case unableToOpenFile(String)
        case emptyPath
        case noFileURL(String)
    }

    /// A dispatch source to monitor a file descriptor.
    internal var source: DispatchSourceFileSystemObject?

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

    /// Start monitoring file system object events.
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

    /// Stop monitoring file system object events.
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

extension FileSystemObjectMonitor {
    public struct Event {
        /// The file descriptor of the file or socket.
        public let handle: Int32
        /// The type of the last file system event.
        public let event: DispatchSource.FileSystemEvent

        /// File system object path url.
        public lazy var url: URL? = Self.makeURL(from: handle)

        private static func makeURL(from handle: Int32) -> URL? {
            var rawPath = [CChar](repeating: 0,
                                  count: Int(MAXPATHLEN))

            guard
                fcntl(handle, F_GETPATH, &rawPath) == 0,
                let path = String(validatingUTF8: rawPath)
            else { return nil }

            return URL(fileURLWithPath: path).absoluteURL
        }

        init(source: DispatchSourceFileSystemObject) {
            self.handle = source.handle
            self.event = source.data
        }
    }
}
extension FileSystemObjectMonitor.Event: CustomStringConvertible {
    public var description: String {
        "\(Self.makeURL(from: handle)?.absoluteString ?? "{invalid handle}") \(event)"
    }
}
extension FileSystemObjectMonitor.Event: Equatable { }
extension FileSystemObjectMonitor.Event: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(handle)
        hasher.combine(event.rawValue)
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

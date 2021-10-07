import Foundation

public protocol FileSystemObjectMonitorDelegate: AnyObject {
    func fileSystemObjectMonitorDidReceive(event: FileSystemObjectMonitor.Event)
}

public final class FileSystemObjectMonitor {
    public typealias SubscriptionHandle = UInt
    public typealias EventHandler = (Event) -> Void
    public typealias FileDescriptorHandle = Int32

    public struct Event {
        /// The file descriptor of the file or socket.
        public let handle: FileDescriptorHandle
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

    private let source: DispatchSourceFileSystemObject
    public private(set) var isMonitoring: Bool = false

    public weak var delegate: FileSystemObjectMonitorDelegate? {
        didSet {
            if !isMonitoring && delegate != nil {
                start()
            } else if isMonitoring && delegate == nil {
                stop()
            }
        }
    }

    public convenience init(path: String, queue: DispatchQueue = .main, eventMask: DispatchSource.FileSystemEvent = .all) throws {
        guard !path.isEmpty else {
            throw Error.emptyPath
        }

        try self.init(url: URL(fileURLWithPath: path), queue: queue, eventMask: eventMask)
    }

    public convenience init(url: URL, queue: DispatchQueue = .main, eventMask: DispatchSource.FileSystemEvent = .all) throws {
        guard url.isFileURL else {
            throw Error.noFileURL(url.absoluteURL.path)
        }

        let absolutePath = url.absoluteURL.path

        let fileDescriptor = open(absolutePath, O_EVTONLY) // O_RDONLY
        guard fileDescriptor >= 0 else {
            throw Error.unableToOpenFile(absolutePath)
        }
        try self.init(fileDescriptor: fileDescriptor, queue: queue, eventMask: eventMask)
    }

    init(fileDescriptor: Int32, queue: DispatchQueue, eventMask: DispatchSource.FileSystemEvent) throws {
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                               eventMask: eventMask,
                                                               queue: queue)
        self.source = source

        source.setEventHandler { [weak self] in
            self?.delegate?.fileSystemObjectMonitorDidReceive(event: Event(source: source))
        }

        source.setCancelHandler {
            if !source.isCancelled {
                source.cancel()
            }
            close(source.handle)
        }
    }

    deinit {
        if !source.isCancelled {
            source.cancel()
        }
        close(source.handle)
    }

    private func start() {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            source.activate()
        } else {
            source.resume()
        }

        isMonitoring = true
    }

    private func stop() {

        isMonitoring = false
    }
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

import Foundation

public final class FileSystemObjectMonitor {
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

    public convenience init(path: String, queue: DispatchQueue = .main, eventMask: DispatchSource.FileSystemEvent = .all, _ eventHandler: @escaping EventHandler) throws {
        guard !path.isEmpty else {
            throw Error.emptyPath
        }

        try self.init(url: URL(fileURLWithPath: path), queue: queue, eventMask: eventMask, eventHandler)
    }

    public convenience init(url: URL, queue: DispatchQueue = .main, eventMask: DispatchSource.FileSystemEvent = .all, _ eventHandler: @escaping EventHandler) throws {
        guard url.isFileURL else {
            throw Error.noFileURL(url.absoluteURL.path)
        }

        let absolutePath = url.absoluteURL.path

        let fileDescriptor = open(absolutePath, O_EVTONLY) // O_RDONLY
        guard fileDescriptor >= 0 else {
            throw Error.unableToOpenFile(absolutePath)
        }
        try self.init(fileDescriptor: fileDescriptor, queue: queue, eventMask: eventMask, eventHandler)
    }

    init(fileDescriptor: Int32, queue: DispatchQueue, eventMask: DispatchSource.FileSystemEvent, _ eventHandler: @escaping EventHandler) throws {
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                               eventMask: eventMask,
                                                               queue: queue)
        self.source = source

        source.setEventHandler {
            eventHandler(Event(source: source))
        }

        source.setCancelHandler {
            if !source.isCancelled {
                source.cancel()
            }
            close(source.handle)
        }

        if #available(macOS 10.12, *) {
            source.activate()
        } else {
            source.resume()
        }
    }

    deinit {
        if !source.isCancelled {
            source.cancel()
        }
        close(source.handle)
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

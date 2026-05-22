import OrzMCFoundation

public struct ManagedServerKey: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(versionId: String, softwareId: String) {
        self.rawValue = "\(versionId)#\(softwareId)"
    }

    public var description: String {
        rawValue
    }
}

public struct ServerProcessRegistry: Sendable {
    public init() {}

    public func filtered(
        _ processes: [ManagedServerKey: ProcessIdentifier],
        runningProcessIds: Set<ProcessIdentifier>
    ) -> [ManagedServerKey: ProcessIdentifier] {
        processes.filter { runningProcessIds.contains($0.value) }
    }

    public func hasManagedRunningServers(_ processes: [ManagedServerKey: ProcessIdentifier]) -> Bool {
        !processes.isEmpty
    }

    public func processIds(from processes: [ManagedServerKey: ProcessIdentifier]) -> [ProcessIdentifier] {
        Array(processes.values)
    }
}

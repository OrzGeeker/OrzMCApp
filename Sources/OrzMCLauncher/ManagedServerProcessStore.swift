import OrzMCFoundation

public struct ManagedServerProcessStore: Sendable {
    private var processes: [ManagedServerKey: ProcessIdentifier]
    private let registry: ServerProcessRegistry

    public init(
        processes: [ManagedServerKey: ProcessIdentifier] = [:],
        registry: ServerProcessRegistry = ServerProcessRegistry()
    ) {
        self.processes = processes
        self.registry = registry
    }

    public var hasManagedRunningServers: Bool {
        registry.hasManagedRunningServers(processes)
    }

    public mutating func record(_ processId: ProcessIdentifier, for key: ManagedServerKey) {
        processes[key] = processId
    }

    public func processId(for key: ManagedServerKey) -> ProcessIdentifier? {
        processes[key]
    }

    public func processIds() -> [ProcessIdentifier] {
        registry.processIds(from: processes)
    }

    public mutating func refresh(runningProcessIds: Set<ProcessIdentifier>) {
        processes = registry.filtered(processes, runningProcessIds: runningProcessIds)
    }

    public mutating func removeProcess(for key: ManagedServerKey) {
        processes.removeValue(forKey: key)
    }

    public mutating func removeAll() {
        processes.removeAll()
    }
}

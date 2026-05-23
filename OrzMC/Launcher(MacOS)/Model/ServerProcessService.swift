//
//  ServerProcessService.swift
//  OrzMC
//
//  Created by Codex on 2026/5/23.
//

import JokerKits
import OrzMCFoundation
import OrzMCLauncher

protocol ServerProcessCommanding: AnyObject {
    func runningServerPids() throws -> [String]
    func stop(processId: String) throws
}

final class ShellServerProcessCommander: ServerProcessCommanding {
    func runningServerPids() throws -> [String] {
        try Shell.allRunningServerPids()
    }

    func stop(processId: String) throws {
        try Shell.runCommand(with: ["kill", processId])
    }
}

struct ServerProcessService {
    private var store = ManagedServerProcessStore()
    private let commander: ServerProcessCommanding

    init(commander: ServerProcessCommanding = ShellServerProcessCommander()) {
        self.commander = commander
    }

    func key(versionId: String, software: SettingsModel.ServerSoftware) -> String {
        ManagedServerKey(versionId: versionId, softwareId: software.rawValue).rawValue
    }

    mutating func record(_ launchedServer: LaunchedServer) {
        store.record(
            ProcessIdentifier(launchedServer.pid),
            for: ManagedServerKey(versionId: launchedServer.versionId, softwareId: launchedServer.software.rawValue)
        )
    }

    mutating func refresh(runningPids: Set<String>) {
        store.refresh(runningProcessIds: Set(runningPids.map { ProcessIdentifier($0) }))
    }

    func runningServerPids() -> Set<String> {
        Set((try? commander.runningServerPids()) ?? [])
    }

    var hasManagedRunningServers: Bool {
        store.hasManagedRunningServers
    }

    func pids() -> [String] {
        store.processIds().map(\.rawValue)
    }

    func pid(versionId: String, software: SettingsModel.ServerSoftware) -> String? {
        store.processId(for: ManagedServerKey(versionId: versionId, softwareId: software.rawValue))?.rawValue
    }

    mutating func remove(versionId: String, software: SettingsModel.ServerSoftware) {
        store.removeProcess(for: ManagedServerKey(versionId: versionId, softwareId: software.rawValue))
    }

    func stop(processId: String) throws {
        try commander.stop(processId: processId)
    }

    func stop(processIds: [String]) throws {
        for pid in processIds {
            try stop(processId: pid)
        }
    }

    mutating func removeAll() {
        store.removeAll()
    }
}

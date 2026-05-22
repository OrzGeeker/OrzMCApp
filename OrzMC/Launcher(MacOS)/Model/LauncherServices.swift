//
//  LauncherServices.swift
//  OrzMC
//
//  Created by Codex on 2026/5/3.
//

import Game
import MojangAPI
import OrzMCFoundation
import OrzMCLauncher

typealias LaunchProgressHandler = @Sendable (Double) async -> Void

struct JavaRuntimeService {
    typealias Status = JavaRuntimeStatus

    private let policy = JavaRuntimePolicy()

    func status(currentMajorVersion: Int?, requiredMajorVersion: Int?) -> Status {
        policy.status(
            for: JavaRuntimeRequirement(
                currentMajorVersion: currentMajorVersion,
                requiredMajorVersion: requiredMajorVersion
            )
        )
    }
}

extension Version: @retroactive MinecraftVersionSummary {
    public var minecraftVersionId: String { id }

    public var minecraftVersionKind: MinecraftVersionKind {
        switch buildType {
        case .release:
            return .release
        case .snapshot:
            return .snapshot
        case .oldBeta:
            return .oldBeta
        case .oldAlpha:
            return .oldAlpha
        }
    }
}

struct VersionFilterService {
    private let filter = VersionListFilter()

    func filter(
        versions: [Version],
        searchText: String,
        releaseOnly: Bool
    ) -> [Version] {
        filter.filter(
            versions: versions,
            searchText: searchText,
            releaseOnly: releaseOnly
        )
    }
}

struct ServerProcessService {
    private let registry = ServerProcessRegistry()

    func key(versionId: String, software: SettingsModel.ServerSoftware) -> String {
        ManagedServerKey(versionId: versionId, softwareId: software.rawValue).rawValue
    }

    func filteredPIDMap(_ pidMap: [String: String], runningPids: Set<String>) -> [String: String] {
        let processes = pidMap.reduce(into: [ManagedServerKey: ProcessIdentifier]()) { result, element in
            result[ManagedServerKey(rawValue: element.key)] = ProcessIdentifier(element.value)
        }
        let runningProcessIds = Set(runningPids.map { ProcessIdentifier($0) })
        return registry.filtered(processes, runningProcessIds: runningProcessIds)
            .reduce(into: [String: String]()) { result, element in
                result[element.key.rawValue] = element.value.rawValue
            }
    }

    func hasManagedRunningServers(_ pidMap: [String: String]) -> Bool {
        registry.hasManagedRunningServers(processes(from: pidMap))
    }

    func pids(from pidMap: [String: String]) -> [String] {
        registry.processIds(from: processes(from: pidMap)).map(\.rawValue)
    }

    private func processes(from pidMap: [String: String]) -> [ManagedServerKey: ProcessIdentifier] {
        pidMap.reduce(into: [ManagedServerKey: ProcessIdentifier]()) { result, element in
            result[ManagedServerKey(rawValue: element.key)] = ProcessIdentifier(element.value)
        }
    }
}

struct LaunchedServer {
    let versionId: String
    let software: SettingsModel.ServerSoftware
    let pid: String
}

struct GameLaunchService {
    func startClient(
        version: Version,
        username: String,
        progressHandler: @escaping LaunchProgressHandler
    ) async throws {
        let clientInfo = ClientInfo(
            version: version,
            username: username,
            minMem: "512M",
            maxMem: "2G"
        )
        var launcher = GUIClient(
            clientInfo: clientInfo,
            progressHandler: progressHandler
        )
        try await launcher.start()
    }

    func startServer(
        version: Version,
        software: SettingsModel.ServerSoftware,
        enableJVMDebugger: Bool,
        jvmDebuggerArgs: String,
        progressHandler: @escaping LaunchProgressHandler
    ) async throws -> LaunchedServer? {
        var jvmArgs = [String]()
        if enableJVMDebugger, !jvmDebuggerArgs.isEmpty {
            jvmArgs.append(jvmDebuggerArgs)
        }

        let serverInfo = ServerInfo(
            version: version.id,
            gui: false,
            debug: false,
            forceUpgrade: false,
            demo: false,
            minMem: "512M",
            maxMem: "2G",
            jvmArgs: jvmArgs,
            onlineMode: false,
            showJarHelpInfo: false,
            jarOptions: nil
        )
        let launcher = GUIServer(
            serverInfo: serverInfo,
            serverType: software.gameType,
            selectedVersion: version,
            progressHandler: progressHandler
        )
        guard let process = try await launcher.start()
        else {
            return nil
        }
        return LaunchedServer(
            versionId: serverInfo.version,
            software: software,
            pid: String(process.processIdentifier)
        )
    }
}

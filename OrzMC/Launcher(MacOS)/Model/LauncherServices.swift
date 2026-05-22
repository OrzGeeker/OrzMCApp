//
//  LauncherServices.swift
//  OrzMC
//
//  Created by Codex on 2026/5/3.
//

import Game
import MojangAPI

typealias LaunchProgressHandler = @Sendable (Double) async -> Void

struct JavaRuntimeService {
    enum Status {
        case unknown
        case valid
        case invalid
    }

    func status(currentMajorVersion: Int?, requiredMajorVersion: Int?) -> Status {
        guard let currentMajorVersion, let requiredMajorVersion else {
            return .unknown
        }
        return currentMajorVersion >= requiredMajorVersion ? .valid : .invalid
    }
}

struct VersionFilterService {
    func filter(
        versions: [Version],
        searchText: String,
        releaseOnly: Bool
    ) -> [Version] {
        var filteredVersions = versions
        if !searchText.isEmpty {
            filteredVersions = filteredVersions.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
        }
        if releaseOnly {
            filteredVersions = filteredVersions.filter { $0.buildType == .release }
        }
        return filteredVersions
    }
}

struct ServerProcessService {
    func key(versionId: String, software: SettingsModel.ServerSoftware) -> String {
        "\(versionId)#\(software.rawValue)"
    }

    func filteredPIDMap(_ pidMap: [String: String], runningPids: Set<String>) -> [String: String] {
        pidMap.filter { runningPids.contains($0.value) }
    }

    func hasManagedRunningServers(_ pidMap: [String: String]) -> Bool {
        !pidMap.isEmpty
    }

    func pids(from pidMap: [String: String]) -> [String] {
        Array(pidMap.values)
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

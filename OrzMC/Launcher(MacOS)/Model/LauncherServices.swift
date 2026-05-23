//
//  LauncherServices.swift
//  OrzMC
//
//  Created by Codex on 2026/5/3.
//

import Game
import Foundation
import JokerKits
import MojangAPI
import OrzMCFoundation
import OrzMCLauncher

typealias LaunchProgressHandler = @Sendable (Double) async -> Void

typealias ServerPluginDownloadProgressHandler = @Sendable (ServerPluginDownloadProgress) async -> Void

struct ServerPluginDownloadProgress: Equatable {
    let title: String
    let fraction: Float
}

struct JavaRuntimeService {
    typealias Status = JavaRuntimeStatus

    private let policy = JavaRuntimePolicy()

    func currentMajorVersion() -> Int? {
        guard let currentJavaVersion = try? OracleJava.currentJDK()?.version
        else {
            return nil
        }
        return majorVersion(from: currentJavaVersion)
    }

    func majorVersion(from version: String) -> Int? {
        guard let majorVersionSubstring = version.split(separator: ".").first
        else {
            return nil
        }
        return Int(String(majorVersionSubstring))
    }

    func status(currentMajorVersion: Int?, requiredMajorVersion: Int?) -> Status {
        policy.status(
            for: JavaRuntimeRequirement(
                currentMajorVersion: currentMajorVersion,
                requiredMajorVersion: requiredMajorVersion
            )
        )
    }
}

struct GameCatalogService {
    func fetchVersions() async throws -> [Version] {
        try await Mojang.manifest().versions
    }

    func fetchGameInfo(for version: Version) async throws -> GameVersion? {
        try await version.gameVersion
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
    private var store = ManagedServerProcessStore()

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
        Set((try? Shell.allRunningServerPids()) ?? [])
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
        try Shell.runCommand(with: ["kill", processId])
    }

    func stop(processIds: [String]) throws {
        for pid in processIds {
            try Shell.runCommand(with: ["kill", pid])
        }
    }

    mutating func removeAll() {
        store.removeAll()
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

struct ServerPluginDownloadService {
    func downloadAllPaperPlugins(
        versionId: String,
        progressHandler: @escaping ServerPluginDownloadProgressHandler
    ) async throws {
        let updateDirPath = GameDir.serverPluginUpdate(
            version: versionId,
            type: Game.GameType.paper.rawValue
        ).dirPath
        try updateDirPath.makeDirIfNeed()

        let outputDirFileURL = URL(fileURLWithPath: updateDirPath)
        await progressHandler(
            ServerPluginDownloadProgress(
                title: "",
                fraction: Float.leastNonzeroMagnitude
            )
        )

        let paperPlugin = PaperPlugin()
        let allPlugins = try await paperPlugin.allPlugin()
        let totalCount = allPlugins.count

        for (index, plugin) in allPlugins.enumerated() {
            let downloadedCount = index + 1
            guard let downloadItem = try await plugin.downloadItem(
                outputFileDirURL: outputDirFileURL,
                version: nil
            ),
                  let pluginName = plugin.name
            else {
                continue
            }

            await progressHandler(
                ServerPluginDownloadProgress(
                    title: "\(pluginName)(\(downloadedCount)/\(totalCount))",
                    fraction: Float(downloadedCount) / Float(totalCount)
                )
            )
            try await Downloader.download(downloadItem)
        }

        await Shell.runCommand(with: ["open", outputDirFileURL.path])
        await progressHandler(
            ServerPluginDownloadProgress(
                title: "",
                fraction: 0
            )
        )
    }
}

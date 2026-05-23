//
//  GameModel.swift
//  OrzMC
//
//  Created by joker on 4/27/24.
//

import SwiftUI
import Game
import MojangAPI
import JokerKits

@MainActor
@Observable
final class GameModel {
    
    var settingsModel = SettingsModel()
    
    enum GameType: String, CaseIterable {
        case client, server
    }
    
    var versions = [Version]()
    
    var isLaunchingGame: Bool = false
    
    var selectedVersion: Version? {
        willSet {
            guard selectedVersion != newValue
            else {
                return
            }
            progress = 0.0
        }
        didSet {
            fetchGameInfo()
            fetchCurrentJavaMajorVersion()
        }
    }
    
    var username: String = ""
    
    var gameType: GameType = .client {
        willSet {
            guard gameType != newValue
            else {
                return
            }
            progress = 0.0
        }
    }
    
    var progress: Double = 0.0
    
    var isFetchingGameVersions: Bool = false

    var errorMessage: String?
    
    var isClient: Bool { gameType == .client }
    
    var isServer: Bool { gameType == .server }

    var canStartGame: Bool {
        guard selectedVersion != nil,
              !isFetchingGameVersions,
              !isLaunchingGame
        else {
            return false
        }
        if isClient {
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var gameInfoMap = [Version: GameVersion]()
    
    var currentJavaMajorVersion: Int?
    
    var isShowKillAllServerButton: Bool = false
    
    var serverPluginDownloadProgress: Float = 0
    
    var serverPluginDownloadProgressTitle: String = ""

    var runningServerPids = Set<String>()

    private let javaRuntimeService = JavaRuntimeService()

    private let gameCatalogService = GameCatalogService()

    private var serverProcessService = ServerProcessService()

    private let gameLaunchService = GameLaunchService()

    private let serverPluginDownloadService = ServerPluginDownloadService()
}

extension GameModel {
    
    var detailTitle: String {
        guard let selectedVersion
        else {
            return "Minecraft"
        }
        return "Minecraft - \(selectedVersion.id)"
    }
    
    var javaVersionTextColor: Color {
        
        switch javaRuntimeStatus {
        case .unknown:
            return .primary
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }
    
    var showJavaVersionArea: Bool { currentJavaMajorVersion != nil || selectedGameJavaMajorVersionRequired != nil }
    
    var progressDesc: String {
        return String(format: "%.2f%%", progress * 100)
    }
    
    var selectedGameJavaMajorVersionRequired: Int? {
        guard
            let selectedVersion,
            let gameInfo = gameInfoMap[selectedVersion],
            let javaVersion = gameInfo.javaVersion
        else {
            return nil
        }
        return Int(javaVersion.majorVersion)
    }
    
    typealias JavaRuntimeStatus = JavaRuntimeService.Status
    
    var javaRuntimeStatus: JavaRuntimeStatus {
        javaRuntimeService.status(
            currentMajorVersion: currentJavaMajorVersion,
            requiredMajorVersion: selectedGameJavaMajorVersionRequired
        )
    }
    
    var selectedServerPID: String? {
        guard isServer, let selectedVersion
        else {
            return nil
        }
        return serverProcessService.pid(versionId: selectedVersion.id, software: settingsModel.serverSoftware)
    }

    func isServerRunning(versionId: String, software: SettingsModel.ServerSoftware) -> Bool {
        guard let pid = serverProcessService.pid(versionId: versionId, software: software)
        else {
            return false
        }
        return runningServerPids.contains(pid)
    }
}

extension GameModel {
    
    func fetchCurrentJavaMajorVersion() {
        guard let currentJavaMajorVersion = javaRuntimeService.currentMajorVersion()
        else {
            return
        }
        self.currentJavaMajorVersion = currentJavaMajorVersion
    }
    
    func fetchGameVersions() async throws {
        versions = try await gameCatalogService.fetchVersions()
    }
    
    func fetchGameInfo() {
        guard let selectedVersion
        else {
            return
        }
        
        guard !gameInfoMap.keys.contains(selectedVersion)
        else {
            return
        }
        
        Task {
            do {
                guard let gameInfo = try await gameCatalogService.fetchGameInfo(for: selectedVersion)
                else { return }
                await MainActor.run {
                    gameInfoMap[selectedVersion] = gameInfo
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load game info: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func startGame() {
        guard canStartGame,
              let selectedVersion
        else {
            return
        }
        
        Task {
            self.isLaunchingGame = true
            defer {
                self.isLaunchingGame = false
            }
            
            do {
                switch gameType {
                case .client:
                    try await startClient(selectedVersion)
                case .server:
                    try await startServer(selectedVersion)
                }
            } catch {
                self.progress = 0
                self.errorMessage = "Failed to start \(gameType.rawValue): \(error.localizedDescription)"
            }
        }
    }
    
    func startClient(_ selectedVersion: Version) async throws {
        try await gameLaunchService.startClient(
            version: selectedVersion,
            username: username,
            progressHandler: progressHandler
        )
    }
    
    func startServer(_ selectedVersion: Version) async throws {
        guard let launchedServer = try await gameLaunchService.startServer(
            version: selectedVersion,
            software: settingsModel.serverSoftware,
            enableJVMDebugger: settingsModel.enableJVMDebugger,
            jvmDebuggerArgs: settingsModel.jvmDebuggerArgs,
            progressHandler: progressHandler
        )
        else {
            return
        }
        serverProcessService.record(launchedServer)
    }
    
    func checkRunningServer() {
        let pids = (try? Shell.allRunningServerPids()) ?? []
        let running = Set(pids)
        runningServerPids = running
        serverProcessService.refresh(runningPids: running)
        isShowKillAllServerButton = serverProcessService.hasManagedRunningServers
    }
    
    func stopAllRunningServer() {
        Task {
            do {
                let pids = serverProcessService.pids()
                for pid in pids {
                    try Shell.runCommand(with: ["kill", pid])
                }
                serverProcessService.removeAll()
                checkRunningServer()
            } catch {
                errorMessage = "Failed to stop servers: \(error.localizedDescription)"
            }
        }
    }

    func serverPID(versionId: String, software: SettingsModel.ServerSoftware) -> String? {
        serverProcessService.pid(versionId: versionId, software: software)
    }

    func stopServer(versionId: String, software: SettingsModel.ServerSoftware) {
        guard let pid = serverPID(versionId: versionId, software: software)
        else {
            return
        }
        do {
            try Shell.runCommand(with: ["kill", pid])
            serverProcessService.remove(versionId: versionId, software: software)
            checkRunningServer()
        } catch {
            errorMessage = "Failed to stop server: \(error.localizedDescription)"
        }
    }

    func serverKey(versionId: String, software: SettingsModel.ServerSoftware) -> String {
        serverProcessService.key(versionId: versionId, software: software)
    }

    func updateProgress(_ progress: Double) {
        self.progress = progress
    }

    var progressHandler: LaunchProgressHandler {
        { [weak self] progress in
            await MainActor.run {
                self?.updateProgress(progress)
            }
        }
    }
    
    func downloadAllServerPlugins() async throws {
        do {
            if (serverPluginDownloadProgress > 0) {
                return
            }
            guard let version = selectedVersion?.id
            else {
                return
            }
            try await serverPluginDownloadService.downloadAllPaperPlugins(
                versionId: version,
                progressHandler: serverPluginDownloadProgressHandler
            )
        } catch {
            serverPluginDownloadProgress = 0
            errorMessage = "Failed to download server plugins: \(error.localizedDescription)"
        }
    }

    var serverPluginDownloadProgressHandler: ServerPluginDownloadProgressHandler {
        { [weak self] progress in
            await MainActor.run {
                self?.serverPluginDownloadProgressTitle = progress.title
                self?.serverPluginDownloadProgress = progress.fraction
            }
        }
    }
}

//
//  GUIServer.swift
//  OrzMC
//
//  Created by joker on 4/27/24.
//

import Foundation
import DownloadAPI
import Game
import MojangAPI

struct GUIServer: Server, Sendable {
    
    let serverInfo: ServerInfo
    
    let serverType: GameType
    
    /// 用于 Vanilla 下载官方 server.jar 的 Mojang Version 元信息
    let selectedVersion: Version
    
    let gameModel: GameModel
    
    func start() async throws -> Process? {
        
        switch serverType {
        case .paper:
            return try await startPaperServer()
        case .vanilla:
            return try await startVanillaServer()
        }
    }
    
    // MARK: PaperMC
    public func startPaperServer() async throws -> Process? {
        
        let version = serverInfo.version
        
        guard let (build, name, _, _, _) = try await client.latestBuildInfo(
            project: DownloadAPIClient.Project.paper,
            version: version
        )
        else {
            return nil
        }
        
        let workDirectory = GameDir.server(version: serverInfo.version, type: GameType.paper.rawValue)
        let serverJarFileDirPath = workDirectory.dirPath
        let dirURL = URL(filePath: serverJarFileDirPath)
        if !FileManager.default.fileExists(atPath: dirURL.path()) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        let jarFileURL = dirURL.appending(path: name)
        
        if !FileManager.default.fileExists(atPath: jarFileURL.path()) {
            guard let (dataStream, total) = try await client.downloadBuild(
                project: DownloadAPIClient.Project.paper,
                version: version,
                build: build,
                bufferSize: 512 * 1024
            )
            else {
                return nil
            }
            
            var jarData = Data()
            var progress: Double = 0
            for try await byteChunkResult in dataStream {
                switch byteChunkResult {
                case .success(let byteChunk):
                    jarData.append(Data(byteChunk))
                    let curProgress = Double(jarData.count) / Double(total)
                    let delta = curProgress - progress
                    if delta > 0.01 || curProgress == 1 {
                        progress = curProgress
                        await MainActor.run {
                            self.gameModel.updateProgress(curProgress)
                        }
                    }
                case .failure(let error):
                    throw error
                }
            }
            
            if !FileManager.default.fileExists(atPath: dirURL.path()) {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
            try jarData.write(to: jarFileURL, options: .atomic)
        }
        await MainActor.run {
            self.gameModel.updateProgress(1)
        }
        let process = try await launchServer(jarFileURL.path(), workDirectory: workDirectory, jarArgs: [
            "--online-mode=\(serverInfo.onlineMode ? "true" : "false")",
            "--nojline",
            "--noconsole"
        ])
        
        return process
    }
    
    // MARK: Vanilla
    public func startVanillaServer() async throws -> Process? {
        
        let versionId = serverInfo.version
        let workDirectory = GameDir.server(version: versionId, type: GameType.vanilla.rawValue)
        let serverJarFileDirPath = workDirectory.dirPath
        
        let dirURL = URL(filePath: serverJarFileDirPath)
        if !FileManager.default.fileExists(atPath: dirURL.path()) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        
        // Mojang 官方 server.jar 下载地址来自 version json 的 downloads.server.url
        let gameVersion = try await selectedVersion.gameVersion
        guard let serverDownload = gameVersion?.downloads.server,
              let serverURL = URL(string: serverDownload.url)
        else {
            return nil
        }
        
        // 统一落盘为 server.jar，避免 Mojang URL 末尾文件名变动造成重复下载
        let jarFileURL = dirURL.appending(path: "server.jar")
        
        if !FileManager.default.fileExists(atPath: jarFileURL.path()) {
            await MainActor.run { self.gameModel.updateProgress(0) }
            
            let (dataStream, response) = try await URLSession.shared.bytes(from: serverURL)
            let totalBytes = Int(response.expectedContentLength)
            
            var jarData = Data()
            jarData.reserveCapacity(max(totalBytes, 0))
            
            var lastProgress: Double = 0
            for try await byte in dataStream {
                jarData.append(byte)
                
                guard totalBytes > 0 else { continue }
                let curProgress = Double(jarData.count) / Double(totalBytes)
                let delta = curProgress - lastProgress
                if delta > 0.01 || curProgress == 1 {
                    lastProgress = curProgress
                    await MainActor.run {
                        self.gameModel.updateProgress(curProgress)
                    }
                }
            }
            
            try jarData.write(to: jarFileURL, options: .atomic)
        }
        
        await MainActor.run {
            self.gameModel.updateProgress(1)
        }
        
        // Vanilla 通过 --nogui 关闭图形界面
        let process = try await launchServer(
            jarFileURL.path(),
            workDirectory: workDirectory,
            jarArgs: ["--nogui"]
        )
        return process
    }
    
    private let client = DownloadAPIClient()
}

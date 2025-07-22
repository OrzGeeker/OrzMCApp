//
//  GUIServer.swift
//  OrzMC
//
//  Created by joker on 4/27/24.
//

import Foundation
import DownloadAPI
import Game

struct GUIServer: Server, Sendable {
    
    let serverInfo: ServerInfo
    
    let serverType: GameType = .paper
    
    let gameModel: GameModel
    
    func start() async throws -> Process? {
        
        switch serverType {
        case .paper:
            return try await startPaperServer()
        case .vanilla:
            return try await VanillaServer(serverInfo: serverInfo).start()
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
    
    private let client = DownloadAPIClient()
}

//
//  LauncherTypes.swift
//  OrzMC
//
//  Created by Codex on 2026/5/23.
//

typealias LaunchProgressHandler = @Sendable (Double) async -> Void

typealias ServerPluginDownloadProgressHandler = @Sendable (ServerPluginDownloadProgress) async -> Void

struct ServerPluginDownloadProgress: Equatable {
    let title: String
    let fraction: Float
}

struct LaunchedServer {
    let versionId: String
    let software: SettingsModel.ServerSoftware
    let pid: String
}

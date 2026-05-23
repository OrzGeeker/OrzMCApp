//
//  GameCatalogService.swift
//  OrzMC
//
//  Created by Codex on 2026/5/23.
//

import MojangAPI

struct GameCatalogService {
    func fetchVersions() async throws -> [Version] {
        try await Mojang.manifest().versions
    }

    func fetchGameInfo(for version: Version) async throws -> GameVersion? {
        try await version.gameVersion
    }
}

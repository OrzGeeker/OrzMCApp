//
//  VersionFilterService.swift
//  OrzMC
//
//  Created by Codex on 2026/5/23.
//

import MojangAPI
import OrzMCLauncher

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

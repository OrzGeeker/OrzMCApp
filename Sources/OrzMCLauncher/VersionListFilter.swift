public enum MinecraftVersionKind: String, Equatable, Sendable {
    case release
    case snapshot
    case oldBeta = "old_beta"
    case oldAlpha = "old_alpha"
    case unknown
}

public protocol MinecraftVersionSummary: Sendable {
    var minecraftVersionId: String { get }
    var minecraftVersionKind: MinecraftVersionKind { get }
}

public struct VersionListFilter: Sendable {
    public init() {}

    public func filter<Version: MinecraftVersionSummary>(
        versions: [Version],
        searchText: String,
        releaseOnly: Bool
    ) -> [Version] {
        var filteredVersions = versions
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedSearchText.isEmpty {
            filteredVersions = filteredVersions.filter {
                $0.minecraftVersionId.localizedCaseInsensitiveContains(trimmedSearchText)
            }
        }

        if releaseOnly {
            filteredVersions = filteredVersions.filter { $0.minecraftVersionKind == .release }
        }

        return filteredVersions
    }
}

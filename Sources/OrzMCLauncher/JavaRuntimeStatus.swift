public enum JavaRuntimeStatus: Equatable, Sendable {
    case unknown
    case valid
    case invalid
}

public struct JavaRuntimeRequirement: Equatable, Sendable {
    public let currentMajorVersion: Int?
    public let requiredMajorVersion: Int?

    public init(currentMajorVersion: Int?, requiredMajorVersion: Int?) {
        self.currentMajorVersion = currentMajorVersion
        self.requiredMajorVersion = requiredMajorVersion
    }
}

public struct JavaRuntimePolicy: Sendable {
    public init() {}

    public func status(for requirement: JavaRuntimeRequirement) -> JavaRuntimeStatus {
        guard let currentMajorVersion = requirement.currentMajorVersion,
              let requiredMajorVersion = requirement.requiredMajorVersion
        else {
            return .unknown
        }
        return currentMajorVersion >= requiredMajorVersion ? .valid : .invalid
    }
}

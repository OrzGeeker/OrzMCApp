//
//  JavaRuntimeService.swift
//  OrzMC
//
//  Created by Codex on 2026/5/23.
//

import JokerKits
import OrzMCLauncher

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

//
//  LauncherServicesTests.swift
//  OrzMCTests
//
//  Created by Codex on 2026/5/3.
//

import MojangAPI
import XCTest
@testable import OrzMC

final class LauncherServicesTests: XCTestCase {
    func testJavaRuntimeStatus() {
        let service = JavaRuntimeService()

        XCTAssertEqual(service.status(currentMajorVersion: nil, requiredMajorVersion: 21), .unknown)
        XCTAssertEqual(service.status(currentMajorVersion: 17, requiredMajorVersion: 21), .invalid)
        XCTAssertEqual(service.status(currentMajorVersion: 21, requiredMajorVersion: 21), .valid)
        XCTAssertEqual(service.status(currentMajorVersion: 22, requiredMajorVersion: 21), .valid)
    }

    func testJavaMajorVersionParsing() {
        let service = JavaRuntimeService()

        XCTAssertEqual(service.majorVersion(from: "21.0.7"), 21)
        XCTAssertEqual(service.majorVersion(from: "17"), 17)
        XCTAssertNil(service.majorVersion(from: "not-a-version"))
    }

    func testServerProcessKeyAndPIDFiltering() {
        var service = ServerProcessService()

        XCTAssertEqual(service.key(versionId: "1.21.5", software: .paper), "1.21.5#Paper")
        XCTAssertFalse(service.hasManagedRunningServers)

        service.record(LaunchedServer(versionId: "1.21.5", software: .paper, pid: "100"))
        service.record(LaunchedServer(versionId: "1.20.6", software: .vanilla, pid: "200"))

        XCTAssertTrue(service.hasManagedRunningServers)
        XCTAssertEqual(Set(service.pids()), ["100", "200"])

        service.refresh(runningPids: ["200"])

        XCTAssertNil(service.pid(versionId: "1.21.5", software: .paper))
        XCTAssertEqual(service.pid(versionId: "1.20.6", software: .vanilla), "200")

        service.remove(versionId: "1.20.6", software: .vanilla)

        XCTAssertFalse(service.hasManagedRunningServers)
    }

    func testServerProcessServiceUsesInjectedCommander() throws {
        let commander = FakeServerProcessCommander(runningPids: ["300", "400"])
        let service = ServerProcessService(commander: commander)

        XCTAssertEqual(service.runningServerPids(), ["300", "400"])

        try service.stop(processId: "300")
        try service.stop(processIds: ["400", "500"])

        XCTAssertEqual(commander.stoppedPids, ["300", "400", "500"])
    }

    func testVersionFiltering() throws {
        let versions = try makeVersions()
        let service = VersionFilterService()

        XCTAssertEqual(service.filter(versions: versions, searchText: "", releaseOnly: true).map(\.id), ["1.21.5"])
        XCTAssertEqual(service.filter(versions: versions, searchText: "RC", releaseOnly: false).map(\.id), ["1.21.5-rc1"])
    }

    private func makeVersions() throws -> [Version] {
        let jsonData = """
        [
          {
            "id" : "1.21.5",
            "releaseTime" : "2025-03-25T12:14:58+00:00",
            "time" : "2025-03-25T12:24:50+00:00",
            "type" : "release",
            "url" : "https://example.com/1.21.5.json"
          },
          {
            "id" : "1.21.5-rc1",
            "releaseTime" : "2025-03-20T13:45:48+00:00",
            "time" : "2025-03-25T11:02:08+00:00",
            "type" : "snapshot",
            "url" : "https://example.com/1.21.5-rc1.json"
          }
        ]
        """.data(using: .utf8)!

        return try JSONDecoder().decode([Version].self, from: jsonData)
    }
}

private final class FakeServerProcessCommander: ServerProcessCommanding {
    let runningPids: [String]
    var stoppedPids = [String]()

    init(runningPids: [String]) {
        self.runningPids = runningPids
    }

    func runningServerPids() throws -> [String] {
        runningPids
    }

    func stop(processId: String) throws {
        stoppedPids.append(processId)
    }
}

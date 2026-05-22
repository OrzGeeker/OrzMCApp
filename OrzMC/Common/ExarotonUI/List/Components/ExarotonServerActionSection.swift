//
//  ExarotonServerActionSection.swift
//  OrzMC
//
//  Created by Codex on 2026/5/22.
//

import SwiftUI
import OrzMCRemoteHosting

struct ExarotonServerActionSection: View {
    @Environment(ExarotonServerModel.self) private var model

    let server: ExarotonServer
    let status: ServerStatus

    @Binding var serverRAM: Int32
    @Binding var isLoading: Bool

    private let actionPolicy = RemoteServerListPolicy()

    var body: some View {
        Section("Actions") {
            if serverRAM > 0 {
                Stepper(
                    "RAM: \(String(format: "%d", serverRAM)) GB",
                    value: $serverRAM,
                    in: 2...16,
                    step: 1
                )
                .disabled(isLoading || status != .OFFLINE)
            }

            Button("Start Server", systemImage: "restart.circle") {
                perform(.start)
            }
            .disabled(!canPerform(.start))

            Button("Stop Server", systemImage: "stop.fill") {
                perform(.stop)
            }
            .disabled(!canPerform(.stop))

            Button("Restart Server", systemImage: "restart.circle.fill") {
                perform(.restart)
            }
            .disabled(!canPerform(.restart))
        }
    }

    private func canPerform(_ action: RemoteServerAction) -> Bool {
        actionPolicy.canPerform(action, on: status.remoteHostingState)
    }

    private func perform(_ action: RemoteServerAction) {
        Task {
            guard let serverID = server.id else {
                model.errorMessage = "Server ID is missing."
                return
            }

            switch action {
            case .start:
                _ = await model.startServer(serverId: serverID)
            case .stop:
                _ = await model.stopServer(serverId: serverID)
            case .restart:
                _ = await model.restartServer(serverId: serverID)
            }
        }
    }
}

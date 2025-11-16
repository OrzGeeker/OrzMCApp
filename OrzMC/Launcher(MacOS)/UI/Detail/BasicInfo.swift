//
//  BasicInfo.swift
//  OrzMC
//
//  Created by joker on 2024/4/28.
//

import SwiftUI
import MojangAPI
import Game
import JokerKits

struct FormSectionHeader: View {
    let title: String
    var deleteBtnAction: ButtonAction
    typealias ButtonAction = () -> Void
    var body: some View {
        HStack {
            Text(title)
            Button(action: deleteBtnAction) {
                Image(systemName: "trash")
                    .foregroundColor(Color.red)
            }
            .buttonStyle(.plain)
        }
    }
}

struct FilePathEntry: View {
    let name: String
    let path: String
    var body: some View {
        HStack {
            Text(name)
                .bold()
                .foregroundStyle(Color.accentColor)
                .padding([.trailing], 5)
            
            Text(path)
                .foregroundStyle(path.isExist() ? Color.primary : Color.red)
            
            if path.isExist() {
                Spacer()
                Button(action: {
                    _ = try? Shell.runCommand(with: ["open", "\(path)"])
                }, label: {
                    Image(systemName: path.isDirPath() ? "folder" : "doc.plaintext")
                })
                .buttonStyle(.plain)
            }
        }
    }
}
struct BasicInfo: View {
    
    @Environment(GameModel.self) private var model
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        
        Form {
            if let serverDirPath, serverDirPath.isExist() {
                Section {
                    FilePathEntry(
                        name: "Game",
                        path: serverDirPath
                    )
                    if let serverPluginDirPath {
                        FilePathEntry(
                            name: "Plugins",
                            path: serverPluginDirPath
                        )
                        if let serverPluginUpdateDirPath {
                            VStack(alignment: .leading) {
                                FilePathEntry(
                                    name: "PluginsUpdate",
                                    path: serverPluginUpdateDirPath
                                )
                                .onLongPressGesture {
                                    Task {
                                        try await model.downloadAllServerPlugins()
                                    }
                                }
                                if (model.serverPluginDownloadProgress > 0) {
                                    HStack {
                                        Text(model.serverPluginDownloadProgressTitle)
                                        Spacer()
                                        ProgressView(value: model.serverPluginDownloadProgress)
                                            .progressViewStyle(.linear)
                                    }
                                        
                                }
                            }
                        }
                    }
                } header: {
                    FormSectionHeader(title: "Server") {
                        try? serverDirPath.remove()
                    }
                }
            }
            if let clientDirPath, clientDirPath.isExist() {
                Section {
                    FilePathEntry(
                        name: "Game",
                        path: clientDirPath
                    )
                } header: {
                    FormSectionHeader(title: "Client") {
                        try? clientDirPath.remove()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(model.detailTitle)
        .onReceive(timer) { _ in
            model.checkRunningServer()
        }
        .toolbar {
            if model.isShowKillAllServerButton {
                ToolbarItem {
                    Button {
                        model.stopAllRunningServer()
                    } label: {
                        Text("Stop All Servers")
                            .foregroundStyle(Color.accentColor)
                            .padding(4)
                            .bold()
                    }
                    .keyboardShortcut(.init(.init("k")), modifiers: .command)
                }
            }
        }
    }
}

extension BasicInfo {
    
    var serverDirPath: String? {
        guard let selectedVersion = model.selectedVersion
        else {
            return nil
        }
        return GameDir.server(version: selectedVersion.id, type: GameType.paper.rawValue).dirPath
    }
    
    var serverPluginDirPath: String? {
        guard let selectedVersion = model.selectedVersion
        else {
            return nil
        }
        return GameDir.serverPlugin(version: selectedVersion.id, type: GameType.paper.rawValue).dirPath
    }
    
    var serverPluginUpdateDirPath: String? {
        guard let selectedVersion = model.selectedVersion
        else {
            return nil
        }
        return GameDir.serverPluginUpdate(version: selectedVersion.id, type: GameType.paper.rawValue).dirPath
    }
    
    var clientDirPath: String? {
        guard let selectedVersion = model.selectedVersion
        else {
            return nil
        }
        return GameDir.client(version: selectedVersion.id, type: GameType.vanilla.rawValue).dirPath
    }
}


#Preview {
    
    @Previewable
    @State
    var gameModel = GameModel()
    
    BasicInfo()
        .frame(width: Constants.minWidth - Constants.sidebarWidth, height: Constants.minHeight)
        .environment(gameModel)
}

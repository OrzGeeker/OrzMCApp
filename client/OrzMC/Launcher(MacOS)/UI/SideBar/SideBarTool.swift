//
//  SideBarTool.swift
//  OrzMC
//
//  Created by wangzhizhou on 2025/4/7.
//

import SwiftUI

extension View {
    func sideBarTool(
        showOnlyRelease: Binding<Bool>,
        isFetchingGameVersions: Binding<Bool>,
        reloadAction: @escaping () -> Void
    ) -> some View {
        let sideBarModifier = SideBarToolModifier(
            showOnlyRelease: showOnlyRelease,
            isFetchingGameVersions: isFetchingGameVersions,
            reloadAction: reloadAction
        )
        return self.modifier(sideBarModifier)
    }
}

struct SideBarToolModifier: ViewModifier {
    let showOnlyRelease: Binding<Bool>
    let isFetchingGameVersions: Binding<Bool>
    let reloadAction: () -> Void
    func body(content: Content) -> some View {
        content.toolbar {
            SideBarTool(
                showOnlyRelease: showOnlyRelease,
                isFetchingGameVersions: isFetchingGameVersions
            ) {
                reloadAction()
            }
        }
    }
}

struct SideBarTool: View {
    @Binding var showOnlyRelease: Bool
    @Binding var isFetchingGameVersions: Bool
    let reloadList: () -> Void
    var body: some View {
        Toggle(isOn: $showOnlyRelease) {
            Text("Release Only")
                .padding(4)
                .foregroundStyle(showOnlyRelease ? Color.accentColor : Color.gray)
                .fontWeight(showOnlyRelease ? .medium : .regular)
        }
        .toggleStyle(.button)
        
        Button(action: {
            reloadList()
        }, label: {
            if isFetchingGameVersions {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        })
        .disabled(isFetchingGameVersions)
    }
}

#Preview {
    @Previewable @State var showOnlyRelease = false
    @Previewable @State var isFetchingGameVersions = false
    SideBarTool(
        showOnlyRelease: $showOnlyRelease,
        isFetchingGameVersions: $isFetchingGameVersions) {
        }
}

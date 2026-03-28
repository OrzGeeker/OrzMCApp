//
//  SettingsModel.swift
//  OrzMC
//
//  Created by wangzhizhou on 2024/9/26.
//

import Foundation
import Game

@Observable
final class SettingsModel {
    
    var enableJVMDebugger: Bool = false
    
    var jvmDebuggerArgs: String = ""
    
    enum ServerSoftware: String, CaseIterable, Identifiable {
        case paper = "Paper"
        case vanilla = "Vanilla"
        
        var id: String { rawValue }
        
        var gameType: GameType {
            switch self {
            case .paper:
                return .paper
            case .vanilla:
                return .vanilla
            }
        }
    }
    
    /// Server 端核心类型（Paper/Vanilla）。目前为全局设置。
    var serverSoftware: ServerSoftware = .paper
}

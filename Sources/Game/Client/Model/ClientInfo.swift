//
//  File.swift
//  
//
//  Created by joker on 2022/10/22.
//

import Foundation
import Fabric
import MojangAPI

public struct ClientInfo: Sendable {
    public var version: Version
    public var username: String
    var debug: Bool
    var authenticate: Bool
    var launcherProfile: LauncherProfile?
    
    // 正版授权
    var accountName: String?
    var accountPassword: String?
    var accessToken: String?
    var clientToken: String?
    
    // JVM启动内存占用参数
    var minMem: String
    var maxMem: String
    
    // Fabric
    var fabricModel: FabricModel?
    
    public init(
        version: Version,
        username: String,
        debug: Bool = false,
        authenticate: Bool = false,
        launcherProfile: LauncherProfile? = nil,
        accountName: String? = nil,
        accountPassword: String? = nil,
        accessToken: String? = nil,
        clientToken: String? = nil,
        minMem: String,
        maxMem: String,
        fabricModel: FabricModel? = nil) {
        self.version = version
        self.username = username
        self.debug = debug
        self.authenticate = authenticate
        self.launcherProfile = launcherProfile
        self.accountName = accountName
        self.accountPassword = accountPassword
        self.accessToken = accessToken
        self.clientToken = clientToken
        self.minMem = minMem
        self.maxMem = maxMem
        self.fabricModel = fabricModel
    }
}

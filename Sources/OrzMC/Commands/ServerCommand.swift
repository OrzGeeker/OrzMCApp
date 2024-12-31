import ConsoleKit
import JokerKits
import Game

struct ServerCommand: AsyncCommand {
    
    struct Signature: CommandSignature {
        @Flag(name: "debug", short: "d", help: Constants.DebugHelp.string)
        var debug: Bool
        
        @Flag(name: "gui", short: "g", help: Constants.serverGUIHelp.string)
        var gui: Bool
        
        @Flag(name: "force_upgrade", short: "f", help: Constants.serverForceUpgradeHelp.string)
        var forceUpgrade: Bool
        
        @Option(name: "type", short: "t", help: Constants.serverTypeHelp.string)
        var type: String?
        
        @Option(name: "version", short: "v", help: Constants.VersionHelp.string)
        var version: String?
        
        @Option(name: "ms", short: "s", help: Constants.serverMinMemHelp.string)
        var minMem: String?
        
        @Option(name: "mx", short: "x", help: Constants.serverMaxMemHelp.string)
        var maxMem: String?
        
        @Option(name: "online-mode", short: "o", help: Constants.serverOnlineModeHelp.string)
        var onlineMode: Bool?
        
        @Flag(name: "jar-help", short: "j", help: Constants.serverJarHelp.string)
        var jarHelp: Bool
        
        @Option(name: "jar-opts", short: "e", help: Constants.serverJarOptionHelp.string)
        var jarOpts: String?
        
        @Flag(name: "demo", help: Constants.serverDemoModeHelp.string)
        var demo: Bool
        
        @Flag(name: "kill-all", short: "k", help: Constants.serverKillAllHelp.string)
        var killAll: Bool
    }
    
    var help: String = Constants.serverHelp.string
    func run(using context: CommandContext, signature: Signature) async throws {
        let console = context.console
        let killAll = signature.killAll
        guard !killAll
        else {
            try await Shell.stopAll().forEach { stoppedPid in
                console.success(Constants.uiOutputServerStopped.string + stoppedPid)
            }
            return
        }
        let version = try await console.chooseGameVersion(signature.version)
        let gui = signature.gui
        let debug = signature.debug
        let minMem = signature.minMem ?? Constants.serverMinMemDefault
        let maxMem = signature.maxMem ?? Constants.serverMaxMemDefault
        let onlineMode = signature.onlineMode ?? false
        let forceUpgrade = signature.forceUpgrade
        let demo = signature.demo
        let jarHelp = signature.jarHelp
        let jarOpts = signature.jarOpts
        
        let serverInfo = ServerInfo(
            version:version.id,
            gui: gui,
            debug: debug,
            forceUpgrade: forceUpgrade,
            demo: demo,
            minMem: minMem,
            maxMem: maxMem,
            onlineMode: onlineMode,
            showJarHelpInfo: jarHelp,
            jarOptions: jarOpts,
            console: console
        )
        
        if let type = GameType(rawValue: signature.type ?? GameType.paper.rawValue) {
            console.success(Constants.uiOutputServerType.string + type.rawValue)
            switch type {
            case .paper:
                _ = try await PaperServer(serverInfo: serverInfo).start()
            case .vanilla:
                _ = try await VanillaServer(serverInfo: serverInfo).start()
            }
        }
        else{
            console.success(Constants.uiOutputServerType.string + GameType.paper.rawValue)
            _ = try await PaperServer(serverInfo: serverInfo).start()
        }
    }
}

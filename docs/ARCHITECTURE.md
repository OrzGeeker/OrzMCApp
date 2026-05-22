# OrzMC 架构演进说明

本文档记录当前项目向可商业化产品演进的目标架构、已完成改造和后续迁移顺序。原则是先建立稳定边界，再逐步拆分模块，避免一次性重排 Xcode 工程造成不可控风险。

## 目标分层

OrzMC 后续建议稳定为以下模块：

- `OrzMCApp-macOS`：macOS App 入口、窗口、菜单、系统集成和分发相关能力。
- `OrzMCMobileHelper-iOS`：iOS 辅助 App 入口和移动端界面。
- `OrzMCProtocol`：Minecraft SLP、Query、RCON 等协议编解码与网络访问。
- `OrzMCLauncher`：客户端/服务端启动编排、Java 检测、进程管理、版本选择和进度事件。
- `OrzMCRemoteHosting`：exaroton 等远程托管服务集成。
- `OrzMCDesignSystem`：跨 macOS/iOS 复用的视觉组件、格式化工具和空状态组件。
- `OrzMCFoundation`：路径、日志、错误类型、平台能力适配等基础能力。

## 当前已完成

- `GameModel` 不再直接构造 `GUIClient` / `GUIServer`，启动编排已收敛到 `GameLaunchService`。
- `GUIClient` / `GUIServer` 通过 `LaunchProgressHandler` 上报进度，不再直接依赖 `GameModel`。
- `ServerProcessService` 持有运行中服务判定和 PID 提取规则，避免 UI 层重复理解进程状态。
- 新增根目录 `Package.swift`，将现有 `OrzMC/MobileHelper(iOS)/Protocol` 暴露为 `OrzMCProtocol` SwiftPM target。
- 新增 `OrzMCProtocolTests`，让协议层可以脱离 App target 独立验证。

## 迁移顺序

1. 保持现有 Xcode App target 不变，先通过 SwiftPM 为稳定代码建立独立构建入口。
2. 优先迁移协议层，因为它与 UI、CoreData、分发和平台窗口能力耦合最低。
3. 继续把 `LauncherServices.swift` 拆成更小的领域服务，然后迁入 `OrzMCLauncher`。
4. 将 exaroton 相关模型、HTTP、WebSocket 和 UI 分离，先抽服务层，再抽 UI。
5. 当 SwiftPM 模块稳定后，再调整 Xcode target 依赖，让 App target 引用包产品，而不是直接编译全部源码。

## 维护规则

- 新业务能力优先写在服务层或 SwiftPM 模块中，SwiftUI View 只负责展示、用户输入和导航。
- `GameModel` 只作为界面状态协调器，不再新增下载、启动、网络协议、文件系统扫描等重逻辑。
- 新增可复用能力时必须配套单元测试，优先放在对应 SwiftPM test target。
- 涉及签名、公证、自动更新、发布流程的逻辑保持在 App 层，不进入核心业务模块。

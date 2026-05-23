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
- `LauncherServices.swift` 已改为 App 层适配器，Java 运行时判断、版本过滤、服务进程记录都委托给 `OrzMCLauncher`。
- `GameModel` 不再持有全局服务端 PID 表，受管理服务进程状态已收敛到 `ManagedServerProcessStore`，App 层仅负责把启动结果和系统进程列表同步进去。
- Paper 服务端插件批量下载已抽到 `ServerPluginDownloadService`，`GameModel` 只负责下载进度状态和错误展示。
- Minecraft 版本目录加载和当前 Java 主版本解析已抽到 `GameCatalogService` / `JavaRuntimeService`，`GameModel` 不再直接访问 Mojang manifest 或解析 JDK 版本字符串。
- 新增根目录 `Package.swift`，将核心能力逐步暴露为 SwiftPM products。
- `OrzMCFoundation` 已建立基础值类型边界，目前包含 `ProcessIdentifier`。
- `OrzMCLauncher` 已建立启动器领域边界，目前包含 Java 运行时判断、版本列表过滤、受管理服务进程记录。
- `OrzMCProtocol` 已将现有 `OrzMC/MobileHelper(iOS)/Protocol` 暴露为 SwiftPM target；Xcode App target 和 Xcode 单元测试已改为引用该 product，不再直接编译协议源码。
- `OrzMCRemoteHosting` 已建立远程托管服务抽象，目前包含远程服务器摘要、状态、动作和列表策略；exaroton 详情页动作可用性已接入该策略。
- `OrzMCDesignSystem` 已建立跨平台设计系统边界，目前包含内容状态模型和空状态组件；macOS 详情页未选择版本时已复用统一空状态。
- 已新增 SwiftPM 单元测试，让协议层、启动器规则、远程托管规则和设计系统状态可以脱离 App target 独立验证。
- `ExarotonServerDetail` 已拆出 `ExarotonServerActionSection`，详情页只负责页面组合和连接状态，服务器动作逻辑收敛到独立组件。

## 当前模块状态

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| `OrzMCApp-macOS` | 现有 Xcode target | 继续承载 App 生命周期、窗口、菜单、签名、公证、Sparkle 更新。 |
| `OrzMCMobileHelper-iOS` | 现有 Xcode target + App 已引用协议模块 | 继续承载 iOS 辅助端界面；协议实现由 `OrzMCProtocol` 提供。 |
| `OrzMCFoundation` | SwiftPM product + App 已引用 | 已可独立构建和测试，并作为基础依赖进入 App target。 |
| `OrzMCLauncher` | SwiftPM product + macOS 已引用 | 已可独立构建和测试；App 中 `LauncherServices` 已委托该模块，服务进程状态由 `ManagedServerProcessStore` 管理。 |
| `OrzMCProtocol` | SwiftPM product + App 已引用 | 已可独立构建和测试；当前复用现有协议源码路径，并作为 Xcode target 的单一协议来源。 |
| `OrzMCRemoteHosting` | SwiftPM product + App 已引用 | 已可独立构建和测试；exaroton 状态映射与动作策略已对接。 |
| `OrzMCDesignSystem` | SwiftPM product + App 已引用 | 已可独立构建和测试；macOS 空状态已接入。 |

## 迁移顺序

1. 保持现有 Xcode App target 不变，先通过 SwiftPM 为稳定代码建立独立构建入口。
2. 优先迁移协议层，因为它与 UI、CoreData、分发和平台窗口能力耦合最低。
3. `LauncherServices.swift` 保持为 App 适配器；新增启动器规则和纯状态管理优先进入 `OrzMCLauncher`，再由适配器暴露给 UI。
4. exaroton 继续按“领域规则进入 `OrzMCRemoteHosting`，第三方 SDK 适配留在 App 层，复杂 UI 拆成组件”的方式推进。
5. iOS 辅助端协议源码已切换为 `OrzMCProtocol` product；后续 iOS 新功能只在 App 层引用协议模块，不再把协议源码重新加入 App target Sources。

## 验证命令

SwiftPM 模块验证：

```bash
xcrun swift test --scratch-path /private/tmp/orzmc-spm-build
```

macOS App target 验证：

```bash
xcodebuild test -project OrzMC.xcodeproj -scheme OrzMC -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/orzmc-arch-derived
```

iOS App target 验证：

```bash
xcodebuild build -project OrzMC.xcodeproj -scheme OrzMC -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/orzmc-ios-derived
```

本地验证 iOS 构建时，需要 Xcode 安装的 iOS Simulator SDK 与可用模拟器运行时版本匹配。

## 维护规则

- 新业务能力优先写在服务层或 SwiftPM 模块中，SwiftUI View 只负责展示、用户输入和导航。
- `GameModel` 只作为界面状态协调器，不再新增下载、启动、网络协议、文件系统扫描、进程表维护等重逻辑。
- 新增可复用能力时必须配套单元测试，优先放在对应 SwiftPM test target。
- 涉及签名、公证、自动更新、发布流程的逻辑保持在 App 层，不进入核心业务模块。

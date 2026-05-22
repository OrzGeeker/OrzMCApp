# OrzMCApp
[![Publish Docs](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/publish-docs.yml/badge.svg)](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/publish-docs.yml)[![pages-build-deployment](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/pages/pages-build-deployment)
[![Release App](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/release-app.yml/badge.svg)](https://github.com/OrzGeeker/OrzMCApp/actions/workflows/release-app.yml)

OrzMC 是用于 macOS/iOS 的 Minecraft Java Edition 启动器与辅助应用。项目文档请查看：[项目文档](https://orzgeeker.github.io/OrzMCApp/)

## 安装要求

- macOS 启动器：macOS 14.0 Sonoma 或更新版本。
- iOS 辅助端：iOS 18.0 或更新版本；当前公开分发流程以 macOS 启动器为主。
- CPU 架构：Apple Silicon 与 Intel Mac 均可构建/运行；发布产物由 GitHub Actions 生成。
- 分发方式：macOS 版本通过 Developer ID 签名、公证，并使用 Sparkle 更新，不通过 Mac App Store 分发。
- Java 运行时：启动 Minecraft Java Edition 客户端或服务端时需要匹配所选游戏版本的 JDK。应用会检测当前 JDK 版本，并可按版本需求下载 JDK。
- 网络访问：首次获取 Minecraft 版本清单、下载游戏资源/JDK、访问 PaperMC/exaroton 等在线服务，以及 Sparkle 自动更新都需要网络连接。

工作流与发布配置说明，请查看 [WORKFLOW.md](https://github.com/OrzGeeker/OrzMCApp/blob/main/.github/workflows/WORKFLOW.md)。

macOS 独立分发流程请查看 [docs/release-macos.md](docs/release-macos.md)。

## 架构与本地验证

项目正在逐步拆分为 App 壳层与可复用 SwiftPM 模块，目标分层和迁移规则请查看 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

当前 SwiftPM 模块包括：

- `OrzMCFoundation`：基础值类型和跨模块通用能力。
- `OrzMCLauncher`：启动器领域规则，例如 Java 版本判断、版本过滤、受管理服务进程记录。
- `OrzMCProtocol`：Minecraft SLP、Query、RCON 协议实现。
- `OrzMCRemoteHosting`：远程托管服务抽象与列表/操作规则。
- `OrzMCDesignSystem`：跨平台 UI 状态模型和基础空状态组件。

本地验证命令：

```bash
xcrun swift test --scratch-path /private/tmp/orzmc-spm-build
xcodebuild test -project OrzMC.xcodeproj -scheme OrzMC -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/orzmc-arch-derived
```

# OrzMCApp

App used on MacOS/iOS

[Documentation](https://orzgeeker.github.io/OrzMCApp/)

## 发布工作流

- Release（综合）：手动触发，发布 macOS 应用与文档
- Release App：手动触发，仅发布 macOS 应用（使用 GitHub Actions 创建 Release 与上传资产，使用 notarytool + API Key 公证）
- Publish Docs：手动触发，仅发布文档到 GitHub Pages（使用 upload-pages-artifact + deploy-pages）
- Release iOS：手动触发，构建并导出 iOS IPA，支持可选的 TestFlight 上传

## Secrets 配置指引

在仓库 Settings → Secrets and variables → Actions 中新增以下 Secrets：

- macOS 应用发布（必须）
  - DEVELOPER_ID_CERT_P12：Developer ID Application 证书（Base64 p12）
  - DEVELOPER_ID_CERT_PASSWORD：证书密码
  - TEAM_ID：Apple 团队 ID
  - App Store Connect API Key（用于 notarytool 公证，仅支持 API Key）
    - APPSTORE_PRIVATE_KEY：API 私钥（Base64 .p8）
    - APPSTORE_KEY_ID：API Key ID
    - APPSTORE_ISSUER_ID：Issuer ID
  - SPARKLE_ED_PRIVATE_KEY：Sparkle 私钥（EdDSA，Base64 私钥文件，用于 appcast 签名）
  - GITHUB_TOKEN：用于创建 Release、上传资源、推送 gh-pages（一般可用默认自动注入）

- 文档发布（必须）
  - GITHUB_TOKEN

- iOS 发布（用于签名与 TestFlight 上传）
  - IOS_DIST_CERT_P12：Apple Distribution 证书（Base64 p12）
  - IOS_DIST_CERT_PASSWORD：证书密码
  - IOS_PROVISIONING_PROFILE：描述文件（Base64 .mobileprovision），若使用自动签名可不填
  - TEAM_ID：Apple 团队 ID（共用）
  - App Store Connect API Key（用于 TestFlight 上传）
    - APPSTORE_PRIVATE_KEY：App Store Connect API 私钥（Base64 .p8）
    - APPSTORE_KEY_ID：API Key ID
    - APPSTORE_ISSUER_ID：Issuer ID

建议：采用 App Store Connect API Key 方式管理发布（更稳、更安全），在工作流中已默认启用并强制要求 API Key；请配置 APPSTORE_PRIVATE_KEY（Base64 .p8）、APPSTORE_ISSUER_ID、APPSTORE_KEY_ID。

## iOS 工作流使用

- 在 Actions 选择 “Release iOS”，点击 Run workflow
- 工作流默认使用共享 Scheme：OrzMC 构建并归档 iOS 版本
- 可通过 Repository Variables 设置：
  - UPLOAD_TESTFLIGHT：设为 "true" 时在成功导出 IPA 后使用 App Store Connect API 上传；否则仅产出构建工件
  - 上传需配置 APPSTORE_PRIVATE_KEY/APPSTORE_KEY_ID/APPSTORE_ISSUER_ID，否则工作流会失败

## 仓库变量（可选）

- UPLOAD_TESTFLIGHT：设为 "true" 以在 iOS 构建成功后自动上传至 TestFlight
- NOTARY_TIMEOUT_DURATION：macOS 公证等待超时时间（默认 5m），如需调整可设置为 10m/15m 等
- IOS_BUNDLE_ID：推荐设置为 iOS 应用的 Bundle Identifier，用于与构建产物内 CFBundleIdentifier 进行匹配校验

## 编码与配置建议

- 将证书与私钥转为 Base64 以便保存至 Secrets：

  - p12 证书：
    - macOS 终端执行：

      ```bash
      base64 -i DeveloperID.p12 | pbcopy
      ```

  - App Store Connect 私钥（AuthKey_XXXXXX.p8）：
    - macOS 终端执行：

      ```bash
      base64 -i AuthKey_XXXXXX.p8 | pbcopy
      ```

- Sparkle EdDSA 密钥生成与配置：
  - 使用 Sparkle 的 generate_keys 生成与导入：

    ```bash
    /path/to/generate_keys           # 输出公钥（XML）
    /path/to/generate_keys -x key    # 导出私钥到文件
    /path/to/generate_keys -f key    # 将私钥导入钥匙串
    base64 -i key | pbcopy           # 配置到 SPARKLE_ED_PRIVATE_KEY
    ```

- App Store Connect API Key 生成：
  - 登录 App Store Connect → Users and Access → Keys → Generate API Key
  - 记录 Key ID 与 Issuer ID，下载 .p8 私钥文件并按上文编码后配置到 Secrets

## 常见问题

- 证书与描述文件：建议使用组织统一的 Developer ID 与 Apple Distribution 证书，避免个人证书过期导致发布失败。
- Sparkle 配置：SUFeedURL 与 SUPublicEDKey 由 CI 在构建过程中统一写入，避免本地与远端不一致。
- iOS 图标：已新增独立的 AppIcon-iOS 图标集，需按以下尺寸添加图片：
  - iPhone：20x20@2x/@3x、29x29@2x/@3x、40x40@2x/@3x、60x60@2x/@3x
  - App Store（ios-marketing）：1024x1024（请放入 AppIcon-iOS.appiconset）

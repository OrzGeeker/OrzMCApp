# 工作流与发布指南

## 工作流列表
- Release App：构建、导出、notarytool 公证、生成 appcast、创建 Release、上传资产
- Publish Docs：使用 docc 生成静态文档并发布到 gh-pages（根路径重定向到 /documentation/orzmc/）
- Release iOS：构建与导出 IPA，支持使用 App Store Connect API 上传到 TestFlight

## 必备 Secrets
- macOS 发布
  - DEVELOPER_ID_CERT_P12：Developer ID Application（Base64 p12）
  - DEVELOPER_ID_CERT_PASSWORD：证书密码
  - TEAM_ID：Apple 团队 ID
  - APPSTORE_PRIVATE_KEY：App Store Connect API 私钥（Base64 .p8）
  - APPSTORE_KEY_ID：API Key ID
  - APPSTORE_ISSUER_ID：Issuer ID
  - SPARKLE_ED_PRIVATE_KEY：Sparkle EdDSA 私钥（Base64 文件内容，用于 appcast 签名）
  - GITHUB_TOKEN：创建 Release 与上传资源（默认自动注入即可）
- 文档发布
  - GITHUB_TOKEN
- iOS 发布
  - IOS_DIST_CERT_P12、IOS_DIST_CERT_PASSWORD：Apple Distribution 证书（Base64 p12）及密码
  - IOS_PROVISIONING_PROFILE（可选）：描述文件（Base64 .mobileprovision）
  - TEAM_ID：Apple 团队 ID（共用）
  - APPSTORE_PRIVATE_KEY、APPSTORE_KEY_ID、APPSTORE_ISSUER_ID：用于 TestFlight 上传

## 仓库变量
- NOTARY_TIMEOUT_DURATION：macOS 公证等待超时（默认 5m，可设 10m/15m）
- IOS_BUNDLE_ID：与构建产物内 CFBundleIdentifier 匹配校验
- UPLOAD_TESTFLIGHT：设为 "true" 时在 iOS 导出后上传 TestFlight

## 使用说明
- Release App
  - 在 Actions 运行 "Release App"
  - 要求 Secrets 已配置；会生成 appcast.xml 并创建/复用同版本 tag 的 Release
- Publish Docs
  - 运行 "Publish Docs"，生成 docs 并发布到 gh-pages
  - 访问根路径会自动重定向到 /documentation/orzmc/
- Release iOS
  - 运行 "Release iOS"，默认构建共享 Scheme：OrzMC 并导出 IPA
  - 当 UPLOAD_TESTFLIGHT 为 "true" 且 API Key 已配置时上传至 TestFlight

## Sparkle EdDSA 私钥生成
- 构建后找到 generate_keys 工具路径：DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
- 生成私钥与公钥：

```bash
# 输出公钥（XML）
/path/to/generate_keys
# 导出私钥到文件
/path/to/generate_keys -x key
# 将私钥导入钥匙串（本地测试可选）
/path/to/generate_keys -f key
# 将私钥文件转 Base64 配置到 SPARKLE_ED_PRIVATE_KEY
base64 -i key | pbcopy
```

- 工作流使用 --ed-key-file 直接从私钥文件签名，不依赖钥匙串；确保 Info.plist 中 SUPublicEDKey 与私钥匹配

## 常见问题与诊断
- 公证 Invalid / Hardened Runtime 未启用
  - 导出后使用 Developer ID 证书二次签名：codesign --options runtime --timestamp 并严格校验
  - 失败时查看 codesign-info.txt 与 notarization-log.json（工作流会输出）
- Release 创建失败（already_exists）
  - 工作流已改为“查找或创建”，若已存在则复用 upload_url 上传资产
- generate_appcast not found
  - 统一使用 -derivedDataPath DerivedData；工作流会回退搜索默认 DerivedData 路径
- generate_appcast 缺私钥
  - 使用 --ed-key-file 读取 Secrets 中的私钥文件，无需钥匙串；缺失时工作流快速报错

## 文档访问
- docc 默认文档首页位于 /documentation/orzmc/
- 项目站点根路径（/<repo>/）已生成 index.html 重定向到文档首页


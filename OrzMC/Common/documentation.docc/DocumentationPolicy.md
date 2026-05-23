# 文档维护规则

@Metadata {
    @TitleHeading("")
}

项目文档统一维护在 `OrzMC/Common/documentation.docc` 中，并通过 Publish Docs 工作流发布到 GitHub Pages。

## 维护原则

- 架构、发布、工作流、排障、维护规则等长期文档都直接写成 DocC 文章。
- `README.md` 只保留项目简介、状态徽章和 DocC 文档总入口，不再维护重复的架构或发布说明。
- 不再新增 `docs/*.md` 作为长期文档来源；需要新增文档时，在 `documentation.docc` 下新增文章，并从 `Home.md` 的主题列表链接过去。
- 如果需要临时记录排障日志，可以放在 issue、PR 或 release notes 中；确认需要长期保留后再整理进 DocC。

## 发布方式

运行 Publish Docs 工作流后，DocC 会发布到：

```text
https://orzgeeker.github.io/OrzMCApp/documentation/orzmc/
```

本地或 CI 构建文档时，使用 Xcode 的 `docbuild` 生成 `OrzMC.doccarchive`，再通过 `xcrun docc process-archive transform-for-static-hosting` 转为静态站点。

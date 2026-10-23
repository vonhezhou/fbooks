# 流式阅读核心

Fbooks 将为可重排格式建立一个格式无关的流式阅读核心。它的目标是让
TXT、EPUB 以及未来能够可靠提取为流式内容的格式共享同一套阅读 UI、
懒加载、缓存、选择和样式逻辑；它不是浏览器，也不试图成为完整的
HTML5、EPUB3 或 Kindle 渲染系统。

漫画和 PDF 是页面式内容，继续使用各自的阅读器，不纳入此核心。

## 架构边界

```text
格式适配器（TXT / EPUB / future MOBI）
              ↓
      FlowReadingSession（应用层）
              ↓
FlowDocument / FlowChapter / FlowBlock（领域模型）
              ↓
       FlowDocumentRenderer（Flutter 展示层）
```

- **格式适配器** 只在 data 层：读取容器、解码资源、清洗不可信标记，按需
  生成流式章节。它不返回 Widget。
- **流式阅读会话** 暴露章节清单与 `loadChapter`，协调按需加载、会话缓存和
  可丢弃派生缓存。它不解析原始 HTML，也不依赖 Flutter。
- **流式文档模型** 是受控的语义树，不是原始 XHTML/HTML 字符串。
- **渲染器** 位于 `features/reader/presentation`，只消费流式模型；它集中
  实现排版、主题、选择、图片、表格和链接交互。

当前实现已将 TXT 与 EPUB 的会话、章节目录和 Flutter 入口迁至
`FlowReadingSession`、`FlowDocument`、`FlowChapter` 与
`FlowChapterRenderer`。TXT 直接使用 `FlowInline` 渲染；EPUB 仍通过
`FlowChapter.transitionalHtml` 交给 `flutter_html`。该字段是明确的过渡
适配器，不属于长期领域模型：下一轮把 EPUB 清洗为语义块后必须移除，其他
格式不得以它作为共享输出。

## 当前排版与分页

`FlowChapterRenderer` 使用窗口内实际可用宽度（扣除用户页边距）排版，
不再将桌面正文固定限制在 720 像素。`FlowContentViewport` 在同一渲染树上
提供默认左右分页和可选连续滚动；设置保存在 `TextReadingPreferences`。
分页读取布局后的文字行边界和图片区域，避免在普通文字行中间切页。
超过单页高度的不可分割内容仍可分段访问；这不是完整的 EPUB 印刷分页引擎。

翻页支持按钮、左右滑动、方向键和 Page Up / Page Down。章节末页继续
前进会进入下一章，章节首页后退会进入上一章末页；目录仍按章节跳转。

当前 `TextOffsetLocator` 保留章节和旧像素偏移，新增可选的段落索引与
UTF-16 字符偏移。窗口、字号、模式变化和重新打开时优先恢复文字锚点。
持久化编解码器兼容原有 `chapter:offset` 和新增的四段格式，无数据库
schema 变更。段落索引来自当前受控渲染树，并非 EPUB CFI；未来切换到语义
块时需要版本化锚点映射，不能假定渲染树索引跨实现版本稳定。

当前仍对已加载章节整体排版，分页结果按当前布局派生；大型 TXT 的分块
加载和超长章节的增量排版尚未实现。

## 受控中间表示

核心应以如下概念建模，具体 Dart 类型在实施时确定：

```text
FlowDocument
  - publicationId
  - chapters: FlowChapterManifest[]

FlowChapter
  - id, title
  - blocks: FlowBlock[]

FlowBlock
  - heading(level), paragraph, quote, code, list, image, table, divider

FlowInline
  - text, emphasis, strong, strike, code, subscript, superscript, link

FlowResourceRef
  - stable packaged-resource id, mime type, alternative text
```

样式只能使用核心明确支持的语义化属性，例如强调、对齐、前景色、有限
间距和表格单元格跨度。原始 CSS、脚本、DOM 事件、任意 URL 和任意 Widget
都不能穿过适配器边界。

## 格式适配

| 格式 | 适配策略 | 进入核心的条件 |
| --- | --- | --- |
| TXT | 直接按段落和换行生成 `FlowChapter`。 | 始终可转换。 |
| EPUB reflowable | 解析 spine XHTML、包内资源和受支持 CSS，再按 [EPUB 阅读呈现配置](epub-rendering-profile.md) 转为流式节点。 | 不包含需要固定版式、脚本或未支持媒体才能表达的内容。 |
| MOBI / KF7 / KF8 | 使用维护良好的、跨平台的解析器读取未加密内容，再转换为流式节点。 | 解析器可稳定提供文本、目录、图片和内部链接；DRM、固定版式和格式专属交互不进入核心。 |
| HTML 导入（若未来支持） | 先清洗为同一中间表示。 | 只接受本地、受限的可重排内容；不作为网页浏览功能。 |

MOBI 不是 EPUB 的别名。Kindle 的 MOBI 与 KF8 有不同的格式和 CSS 行为；
KF8 虽然 HTML/CSS 导向，仍必须经独立解析和受控转换后才能进入核心。
[Amazon 的 KF8 文档](https://kdp.amazon.com/en_US/help/topic/GR4KL488MXKPZ5BK)
也明确区分了 `amzn-mobi` 与 `amzn-kf8` 样式分支。

## 定位与进度

渲染核心可以报告视觉锚点，例如章节 ID、块 ID 和块内字符偏移；但它不得
直接把该锚点当作所有格式通用的持久化 `ReadingLocator`。

每个格式适配器负责将视觉锚点映射到其格式专属的位置：EPUB 未来可使用
CFI，TXT 使用文本位置，PDF 使用页码，漫画使用页码。这样可共享阅读 UI，
同时保持现有的格式专属进度约束。

## 清洗与缓存策略

1. 原始文件永远保留，不在导入时整体重写。
2. 章节首次被阅读时，适配器在后台转换为 `FlowChapter`。
3. 内存缓存覆盖当前阅读会话；可选磁盘缓存只存派生结果，键至少包含原始
   资产指纹、格式适配器版本、呈现配置版本和章节 ID。
4. 修改受支持节点、CSS 映射或资源处理规则时，递增相应版本并使派生缓存
   失效。
5. 适配器必须在转换时移除脚本、网络资源、事件处理器和不支持的内容；
   以可读文本或明确占位状态降级，不能让原始内容直接决定 Flutter 组件树。

## 实施顺序

1. [已完成] 在 domain/application 中定义第一版 `FlowDocument`、
   `FlowChapter`、`FlowInline` 与 `FlowReadingSession`，并迁移 TXT、EPUB
   的共享 Flutter 入口；不改动漫画与 PDF。
2. 用 TXT 适配器和 `FlowChapterRenderer` 验证基础排版、选择与进度映射。
3. 将 EPUB 从 `flutter_html` 过渡到同一节点模型，并以现有 EPUB 配置作为
   回归样本。
4. 增加可丢弃磁盘缓存和严格的清洗版本。
5. 评估 MOBI/KF7/KF8 的跨平台解析器；只有通过兼容性、授权和维护性评估
   后才在导入入口开放该格式。

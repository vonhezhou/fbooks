# Lessons

## 2026-11-03 — 真机复测先承接待验证的平台

- 多轮性能诊断保持一个连续设备会话，读完本轮结果、确认无需追加采样后
  再统一系统休眠，避免中途提前熄屏导致用户反复解锁。
- 从会话开始就显式绑定已确认的 ADB 目标；后续可能新增模拟器或无线连接，
  不能一直依赖默认设备。标识只存仓库外的私有采样配置，不进入报告。

- 用户在指出 Android 尚待复测后说“已连接真机”，应先检查 Android 连接，
  承接当前未完成的平台验证，不因前面多数采样使用 iPhone 就默认回到 iOS。
- 任何要求解锁或建立隧道的提问前，先确认目标平台和连接状态；已有可用的
  Android ADB 连接时直接推进，避免让用户操作无关手机。

## 2026-11-03 — 翻页体验优先验证动力学与纸面约束

- 不把释放动力学和过渡曲面的伸缩与文字细节一起归为可延后项。落点、
  释放速度衔接、回弹及反向接管会直接影响手感，纸面伸缩会破坏材质观感。
- 本项目先完成这两项的体验验收，再推进正式阅读器接入。过渡文字允许
  暂时不可读，不为改善文字像素指标牺牲手势连续性或纸张形状。
- 完整极限的局部长度测试通过，不代表中间混合姿态不可伸长；位置接管
  连续，也不代表释放和再次接管的速度连续。分别检查，不能相互替代。

## 2026-11-03 — 翻页边角必须验证可达上限

- 有限的进度与倾斜参数不能证明纸张没有被过度拉伸。边角拖动需验证固定
  书脊约束下的可达范围，覆盖上下角、内外牵拉、越界和动画接管。
- 正常停驻画面的拟合不能替代极端手势验证；超出范围时应限制控制目标，
  不以画布裁剪隐藏形变，也不把近似控制约束称为不可伸长纸张的物理模型。
- 原生翻页采样须区分直接陡拖与已起卷后再陡拖；两者可能由不同手势状态
  处理。每条路径结束后检查源页，未恢复时停止后续采集并恢复，不能只记录
  失败后继续采下一页。文字质量改善需同机 GPU 配对，不能混用软件栅格结果。
- 离线图像须先按真机 DPR 栅格化，再使用相同算法归一化；直接以 1× 输出
  对比 3× 真机纹理会把重采样差异误当成几何差异。起手方向应越过设备的
  抖动范围再判定，不能用首个可能被像素取整为等斜的微小步进锁定方向。

## 2026-08-29 — Do not retain overlapping built-in collection semantics

- When product feedback distinguishes a specific queue such as “Read later”,
  do not leave another system collection such as “Saved” with overlapping
  meaning. Confirm the canonical collection and remove the redundant one from
  the product model and UI.
- For Fbooks, the canonical deferred-reading collection is `Read later`; the
  previous `Reading list` label must be renamed and the `Saved` system
  collection must not be exposed or created.
- A “Finished” system collection must be driven by explicit reading-completion
  state, with automatic completion at the final valid locator and a manual
  correction action; do not infer completion from a merely recent progress
  timestamp.

## 2026-08-29 — Preserve the user's requested legacy-feature scope

- When asked to synchronise a legacy screen's capabilities, treat the audited
  legacy checklist as the delivery contract. Do not stop after implementing a
  related data-model slice while selection mode, batch actions, or the other
  named screen remains absent.
- Before reporting progress, compare every requested legacy capability against
  the current implementation and explicitly continue any unmatched item.

## 2026-08-29 — Carry over interaction structure, not just feature labels

- When a legacy screen is the explicit reference, preserve its scalable
  interaction model. For library sorting, use a sort-field choice plus a
  separate ascending/descending choice; do not flatten their Cartesian product
  into a growing list of options.
- Consolidate related filters under one overflow menu when the reference does
  so, and audit each legacy single-book action before replacing its menu.

## 2026-08-29 — Menu parity needs an explicit action matrix

- Do not call a legacy context menu synchronised after adding only a few new
  actions. Build and check off the legacy action matrix (open, details,
  favourite, completion, collection membership, deletion, and any supported
  platform action) for both single and selected books.

## 2026-08-29 — Treat collection membership as collection management

- Do not flatten a potentially long list of user-created collections into a
  context menu. For single or bulk membership changes, open a dedicated
  management surface that lets users select existing collections, create one,
  and delete custom collections while protecting system collections.

## 2026-08-29 — Preserve legacy pointer gesture semantics

- When a legacy book-library interaction is the reference, do not rely only on
  an overflow button: long press on a book must enter selection mode and select
  that book, while a pointer secondary click must open that book's single-item
  action menu at the pointer location.
- Apply the same gesture contract to both card and list representations; a
  display-mode switch must not silently remove selection or context-menu access.

## 2026-08-29 — Dark theme must cover the whole primary screen

- Do not combine a theme-aware sidebar or card with hard-coded light page
  surfaces or foreground colors in the same primary screen.
- Before claiming dark-mode support, verify Library, Collections, Plugins, and
  Settings at desktop width in both brightness modes and check text contrast
  for headings, filters, empty states, and cards.

## 2026-08-29 — Keep visible brand surfaces in sync

- When updating the launcher icon or product capitalization, audit the
  in-app brand mark, `MaterialApp.title`, and the relevant native window or
  bundle display name; changing only generated launcher assets leaves the UI
  visibly inconsistent.
- Add a widget test for the in-app brand mark and displayed name at the layout
  where the mark is visible.

## 2026-08-29 — Desktop caption must own its height outside an app bar

- `PreferredSizeWidget.preferredSize` is only applied automatically by
  `Scaffold.appBar`. When a desktop caption is embedded directly in a `Column`,
  constrain its height in the widget itself before using any expanding child.
- For responsive window chrome, add a widget test that resizes from the wide
  desktop shell to the compact shell and asserts that no layout exception is
  reported.

## 2026-08-29 — Keep primary desktop page edges on one shared grid

- Put a desktop page's heading, controls, filters, and primary content inside
  one outer padding boundary. Do not give those sections independently chosen
  horizontal margins, which makes their left edges visibly drift apart.
- When an item-level action overlays a visual card, constrain it to the visual
  hierarchy (currently 32 × 32) and use a theme-aware, subdued surface rather
  than the default large white icon-button treatment.

## 2026-08-29 — Compare legacy reader support by executable path

- When auditing whether a reader capability was inherited, follow the complete
  picker → importer → provider → session path; an enum value, presentation
  label, or archived helper alone is not evidence that the format is usable.
- For archive-memory claims, inspect the archive package's actual file-backed
  and lazy-decompression behavior before proposing a replacement; distinguish
  lazy ZIP entry access from caching decompressed page bytes in the session.

## 2026-08-29 — Honour ComicInfo page-level cover declarations

- CBZ cover selection must read `ComicInfo.xml`'s `Pages/Page` entries and
  prefer a page whose `Type` is `FrontCover` over filename and directory
  heuristics; a metadata file can define the cover even when its filename is
  non-descriptive.
- Add a regression fixture with a non-descriptive image name and a
  `FrontCover` page declaration whenever changing archive-cover selection.

## 2026-09-04 — Separate card media from card metadata padding

- When a library-card cover should be edge-to-edge, never wrap the whole card
  in a shared padding widget. Make the cover its own top media region and add
  padding only around the title, progress, and actions below it.
- Use the 1:1.6 width-to-height ebook-cover ratio for library cards, and
  calculate each tile as the cover height plus a fixed metadata-footer height
  through a custom grid delegate. Do not use the overall card aspect ratio or
  an `Expanded` metadata region, which makes text whitespace depend on width.
- Verify the computed cover and footer heights at both narrow and desktop
  widths so the metadata area cannot overflow.

## 2026-09-30 — Validate pages within chapters and responsive text layout

- Chapter navigation does not provide text pagination. Validate a long single
  TXT chapter and a long EPUB chapter with real page boundaries before claiming
  paginated reading support.
- Use the actual available viewport width and height for layout; do not silently
  cap desktop body width when the requested behavior is to fit the window.
- Keep text lines intact at page boundaries and test phone, tablet, and desktop
  widths, including resizing and typography changes while reading.
- Preserve a text anchor across reflow and reopening; retain legacy pixel
  offsets as a compatibility fallback rather than treating them as stable text
  positions. Verify both paged and continuous modes.

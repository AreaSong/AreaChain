---
name: areachain-ui
description: "仅用于 AreaChain 仓库的 SwiftUI/AppKit 界面实现、布局与交互优化、原生界面问题检查；按本项目双语、Daybook 样式、输入和窗口契约实施并交接验收。不适用于其他项目、纯领域/脚本改动或独立安装发布。"
---

# AreaChain 原生界面

把通用开发流程应用到 AreaChain 的真实界面入口，不重新定义本项目的风格或数据语义。只读检查/方案请求不隐含修改授权。

## 确认所属项目

- 从本技能目录向上三级定位 [仓库根](../../..)，确认存在 `AreaChain.xcodeproj` 与 `AreaChain/App/AreaChainApp.swift`；不按当前工作目录或文件夹名称猜测目标。
- 先遵循 [项目 AGENTS.md](../../../AGENTS.md)。本技能只服务该仓库及其工作副本；用户目标属于其他项目时停止套用这里的具体约定。
- `areasong-development` 已发现且请求匹配时，由它协调需求、风险和交付；本技能补充项目界面方法，不再生成第二份计划。没有个人级通用技能时仍可按本技能和项目规则推进，不自动安装全局依赖。

## 输入：先识别宿主和行为边界

- 定位目标宿主：菜单栏浮层、工作台具体页面、任务检查器或手记小窗；确定是否涉及共用组件的其他消费者。
- 区分要改变的布局/视觉/交互与应保持的数据、提交方式、焦点、选择、草稿和快捷键；仅当存在影响范围、结果或风险的未决设计选择时，给出推荐并请求确认，明确可逆的局部调整不逐项审批。
- 检查现有修改和直接调用链。下面是定位索引，不要求每个任务全量读取所有文件。

| 关注点 | 项目来源 | 核对重点 |
|---|---|---|
| 双语与显示格式 | [Localizable.xcstrings](../../../AreaChain/Resources/Localizable.xcstrings)、[L10n.swift](../../../AreaChain/Domain/L10n.swift)、[AppPreferences.swift](../../../AreaChain/Services/AppPreferences.swift) | `en` / `zh-Hans`、格式参数、相关提示及可访问性名称；用户正文和机器值不翻译 |
| 样式与宿主差异 | [DaybookPalette.swift](../../../AreaChain/Theme/DaybookPalette.swift)、[DaybookMetrics.swift](../../../AreaChain/Theme/DaybookMetrics.swift)、[WorkspaceLayout.swift](../../../AreaChain/Theme/WorkspaceLayout.swift) | 复用语义色、尺寸与字号令牌；两宿主外观一致，只有 `workspaceEmbedded` 决定的布局/能力差异 |
| 输入与浮层 | [Theme 组件目录](../../../AreaChain/Theme)、[使用说明](../../../docs/usage.md) | 复用原生文本、语法输入、候选和属性组件；按入口核对 Return、⌘Return、Esc、失焦及组合输入 |
| 窗口与编辑会话 | [AppWindows.swift](../../../AreaChain/Services/AppWindows.swift)、[Diary 目录](../../../AreaChain/Features/Diary)、[架构说明](../../../docs/architecture.md) | 路由、窗口复用、关闭/退出、脏草稿和外部修改冲突；布局调整不重建唯一编辑会话 |
| 事件与数据 | [DayBoardMutations.swift](../../../AreaChain/Features/Tasks/DayBoardMutations.swift)、[ModelChanges.swift](../../../AreaChain/Services/ModelChanges.swift) | 沿原有领域/仓储/事务路径；保存成功才发布变更，失败不丢草稿 |

## 实施方式

1. 找到已有界面基线和共享样式来源；未查看实际界面时只陈述代码证据，不声称已经完成视觉比较。
2. 按实际影响使用适用的 UI/UX 技能；局部问题做聚焦检索，SwiftUI 建议仍核对 macOS 适用性。不能因 iOS 示例改写 AppKit 的输入、焦点或窗口机制。
3. 新 UI 或视觉重塑需要设计技能时，沿用本项目已确认的语言与风格约束；其他专项技能不改变工程技术栈，不生成互相冲突的设计体系。
4. 优先在目标组件/宿主修改；共享参数的变化必须检查真实消费者。同步本次文案、状态和可访问性信息，不顺手清理整个文案库。
5. 明确控件初值与模型、切换与重置、无结果、选择和计数的一致性；输入尚未提交时，无关 UI 变化不能隐式提交或清空文本。
6. 隐私相关界面若改变解锁、遮罩、复制、附件访问或凭据语义，先按高风险边界确认；不能用界面优化授权推导真实数据转换或系统凭据操作。

## 验收交接

- 将变更文件、受影响宿主、保持/改变的行为，以及拟声明的结果交给已发现的 [areachain-verify](../areachain-verify/SKILL.md)；没有该技能时使用项目现有验证文档和脚本，不伪称已调用。
- 用户仅要方案时，交接验证计划而不执行；用户要求检查时，可在已授权范围和安全条件下执行相应验证，但检查不隐含修复或真实系统写入。缺少必需运行环境则明确未验证部分。
- 验证涵盖本次相关的中英文、浅深色、正常/最小尺寸、关键输入与状态；共享组件覆盖相关宿主，不机械穷举全应用。
- 原生界面用原生证据。网页、Electron 截图、单次离屏绘制或控件动作派发，都不能自动证明实际键盘、输入法、焦点、撤销和运行时序通过。

## 输出

简洁交付目标宿主与改动、复用的规范来源、关键行为保持情况、实际验证与未覆盖项。修改行为时维护必要原有说明；不默认创建新设计系统文件、安装应用、提交或发布。

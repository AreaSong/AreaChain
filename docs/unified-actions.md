# 统一动作与三大基类架构（Unified Actions & Base Architecture）

本文件是 AreaChain 全软件**可操作功能、输入控件、独立窗口、Linux 风格命令行搜索、持久化双向撤销/重做及外部接口门禁**的唯一架构规范与完整指令手册。该体系已全量落地并由自动化测试（`BaseArchitectureGateTests`）与工作流门禁（`scripts/check_workflow.py`）强制守护。

---

## 核心原则：唯一真相源，派生重载，绝不双写

全软件严格遵循 **「三大唯一基类 + 单点注册自动派生」** 原则，禁止在页面、菜单栏或搜索框中各自手写平行实现：

1. **所有可操作动作唯一基类 [`BaseAction`](../AreaChain/Services/BaseAction.swift)（契约见 [`BaseActionContract.swift`](../AreaChain/Domain/BaseActionContract.swift)）**：
   - 软件内任何一个可以点击的按钮、切换的开关、触发的命令或快捷键动作，都必须继承自 `BaseAction` 并统一注册到 [`ActionRegistry.shared`](../AreaChain/Services/ActionRegistry.swift)。
   - 页面按钮（通过 [`DaybookActionButton`](../AreaChain/Theme/DaybookActionButton.swift)）、快捷键、统一搜索框 Linux CLI 命令（`/command` 与管道 ` > `）以及外部接口（[`ExternalActionGateway`](../AreaChain/Services/ExternalActionGateway.swift) 的 `areachain://` URL Scheme）最终调用的是**同一个 `BaseAction` 实例**。
   - 动作一旦注册，系统从 `ActionRegistry` 自动派生：搜索框动作匹配、Tab 参数补全、工作台「搜索与指令」页全量动作目录及 CLI 帮助说明，**绝不手写第二份命令表**。
2. **所有文本输入框唯一基类 [`BaseTextInput`](../AreaChain/Theme/BaseTextInput.swift)（AppKit 宿主见 [`BaseTextInputNative.swift`](../AreaChain/Theme/BaseTextInputNative.swift)）**：
   - 全软件只有一套输入底层：统一封装 AppKit `NSTextField` / `NSTextView` 的中文输入法组合态保护（`hasMarkedText` 期间不乱触发提交或丢字）、光标与选区同步、系统级原生撤销栈（`allowsUndo`）、Daybook 边框/圆角/焦环令牌、左/右侧自定义插槽（`prefix` / `suffix`）与语法着色插件（`SyntaxHighlightPlugin`）。
   - 通过配置模式派生 `.singleLine`（单行输入/搜索/快速录入）、`.multiLine(minHeight:maxHeight:)`（多行备注/手记正文）与 `.secure`（私密口令输入），业务页面不再私自拼装裸 `TextField` 或 `TextEditor`。
3. **所有独立窗口唯一基类 [`BaseWindow`](../AreaChain/Services/BaseWindow.swift)（注册中心 `WindowRegistry.shared`）**：
   - 全软件全部 6 个独立窗口控制器（工作台/设置/回收站 `PanelWindowController`、手记小窗 `DiaryWindowController`、剪贴板浮层 `ClipboardHistoryPanel`、快速录入浮窗 `QuickEntryPanelController`、附件预览窗 `AttachmentImageViewerWindowController`、控件预览窗 `ControlsPreviewWindowController`）全部继承自 `BaseWindow`。
   - 基类内置窗口生命周期、未保存草稿关闭拦截、置顶状态切换（`isPinned`）、尺寸档位调整（`compact` / `standard` / `expanded`）、居中复位，以及基于可见主窗口数量的 Dock 图标策略（`.regular` / `.accessory`）自动切换，并自动映射为标准窗口管理动作。

---

## 新功能必须满足的规则

以后每次新增或修改功能，实施与验收都必须逐条核对以下硬性规则：

1. **凡是可操作的功能，都必须继承 `BaseAction` 并登记到 [`StandardActionCatalog`](../AreaChain/Services/Actions/StandardActionCatalog.swift)**：
   - 无论该功能在任务页、日程表、手记、剪贴板、设置、回收站还是独立小窗，只要用户能点、能切换、能触发，就必须定义为 `BaseAction` 子类，声明稳定 `ActionID`、中英文标题、`commandNames`（命令与简写）、`parameters`、`permissionLevel`（权限等级）与 `riskLevel`（风险等级）。
2. **所有动作都必须能从统一搜索框以 Linux CLI 风格执行**：
   - 支持 `/命令 参数` 直接执行（如 `/todo 买牛奶 !p1 @15:30 #生活 // 备注`、`/theme dark`、`/win-pin`）。
   - 支持 `搜索词 > 命令 参数` 管道操作（如 `买牛奶 > move tomorrow`、`周报 > prio p1`）。
   - 支持不带 `/` 直接输入动作中英文名或别名匹配执行。
3. **零表单轻快交互（Zero-Form CLI Feedback）**：
   - 普通动作（`riskLevel == .direct`）回车**立即执行**，搜索框底部 [`UnifiedSearchCLIPanel`](../AreaChain/Features/Search/UnifiedSearchCLIBridge.swift) 显示单行状态回显，**不弹出重型表单卡片**。
   - 破坏性动作（`riskLevel == .confirm`，如删除、彻底清除、清空回收站）回车后在搜索框下方显示**单行内联二次确认提示**，再次按 `Return`（或附带 `--confirm` / `--yes`）立即执行，按 `Esc` 取消。
4. **修改类动作必须接入持久化修改明细与双向撤销/重做（[`ActionHistoryStore`](../AreaChain/Services/ActionHistoryStore.swift)）**：
   - 每次修改自动记录对象标题、字段名及修改前后的可读值（[`ActionFieldChange`](../AreaChain/Domain/BaseActionContract.swift)：`字段 旧值 → 新值`），滚动持久化最近 1000 条记录至 `areachain-action-history.json`，重启软件不丢失。
   - 同时支持快捷键 `⌘Z`（后退 Undo）/ `⇧⌘Z`（前进 Redo）与搜索框命令 `/undo`（`/u`）、`/redo`（`/r`）、`/history [关键词]`（`/h`）。
5. **界面按钮必须绑定 `ActionID`，可见文字支持中英双语，样式只用 Daybook 令牌**：
   - 新增动作按钮优先使用 [`DaybookActionButton`](../AreaChain/Theme/DaybookActionButton.swift) 绑定 `ActionID`，自动共享启用状态、本地化文案与快捷键提示。
   - 所有界面可见文案同时提供简体中文与英文（维护在 [`Localizable.xcstrings`](../AreaChain/Resources/Localizable.xcstrings)），严禁把内部类名或机器标识直接展示给用户。

---

## 必须继承的安全规则

1. **三档权限分级（`ActionPermissionLevel`）与外部调用门禁**：
   - 每个 `BaseAction` 必须声明 `permissionLevel`：
     - `.normal`（普通）：新建/修改待办、打卡、窗口切换、视图切换等日常操作。
     - `.privacy`（隐私）：手记读写、私密锁状态、剪贴板历史读取与贴回等涉及个人敏感数据的操作。
     - `.system`（系统）：备份导入导出、清空回收站、权限变更等系统级高风险操作。
   - 外部接口网关 [`ExternalActionGateway`](../AreaChain/Services/ExternalActionGateway.swift)（支持 `areachain://action/<ActionID>?...` 与 `areachain://cli?cmd=...`）严格受设置页 `AppPreferences.externalAccessPolicy` 四档开关控制：
     - `disabled`（完全关闭外部调用）
     - `normalOnly`（仅允许 `.normal` 普通动作，**默认档位**）
     - `normalAndPrivacy`（允许 `.normal` 与已解锁状态下的 `.privacy` 动作）
     - `allIncludingSystem`（允许全部动作，但 `.confirm` 破坏性动作仍强制要求确认标志）
2. **私密锁（`PrivacyVault`）对动作执行与历史明细的双重保护**：
   - 当私密锁处于锁定状态（`!isVaultUnlocked`）时，所有 `permissionLevel == .privacy` 的动作自动返回 `.requiresUnlock` 拒绝执行，且禁止通过命令参数泄露未解锁手记内容。
   - 标记为 `isSensitive == true` 的历史记录在锁定时自动脱敏为 `私密操作（已锁定隐藏明细）`，且屏蔽对敏感字段明文的关键词搜索探测，防止通过 `/history 关键词` 侧信道套取私密手记内容；同时阻止在锁定状态下撤销/重做敏感记录。
3. **跨重启持久化载荷不存敏感明文**：
   - `areachain-action-history.json` 中的 `ActionUndoPayload` 仅保存目标 UUID 与非敏感状态快照，绝不落盘手记明文长正文或钥匙串密码凭据。
4. **事务保存成功才入栈**：
   - 所有数据写入复用 [`ModelChanges.swift`](../AreaChain/Services/ModelChanges.swift) 事务保存，只有落库成功才向 `ActionHistoryStore` 登记修改明细并发布界面刷新；保存失败保留用户输入草稿并回显错误。

---

## Linux 风格命令行语法速查（[`ActionCLIParser`](../AreaChain/Domain/ActionCLIParser.swift)）

统一搜索框（菜单栏顶部与工作台顶部共用）原生支持四种输入形态：

| 形态 | 语法示例 | 说明 |
| --- | --- | --- |
| **1. 斜杠命令（`/`）** | `/todo 买牛奶 !p1 @15:30 #生活 // 顺便买面包` | `/` 开头直接进入纯命令模式；支持位置参数、双引号包裹空格、`--key=value`、`--key value`、`--flag` 以及内联自然语言标记（日期、`@HH:mm`、`!p0..p3`、`#标签`、`// 备注`） |
| **2. 管道操作（` > `）** | `买牛奶 > move tomorrow` | 左侧先定位目标对象（或留空默认作用于当前页面选中项），右侧对目标执行动作 |
| **3. 动作名直达** | `暗色模式` / `置顶窗口` / `清空回收站` | 不带 `/` 时同时检索内容与动作名称/中英文别名，匹配动作可直接回车或点击触发 |
| **4. 双向历史与审计** | `/undo` · `/redo` · `/history 牛奶` | 随时后退一步、前进一步，或按关键词过滤查看最近 1000 条字段级修改明细 |

---

## 全软件标准 `BaseAction` 动作目录（7 大族）

所有标准动作由 [`StandardActionCatalog`](../AreaChain/Services/Actions/StandardActionCatalog.swift) 在启动时统一装配至 `ActionRegistry.shared`：

### 1. 窗口、导航与历史族（[`WindowAndNavActions.swift`](../AreaChain/Services/Actions/WindowAndNavActions.swift) + [`ActionHistoryStore.swift`](../AreaChain/Services/ActionHistoryStore.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `history.undo` | `/undo`, `/u`, `/撤销`, `/上一步` | 撤销上一步 | `.normal` / `.direct` |
| `history.redo` | `/redo`, `/r`, `/重做`, `/下一步` | 前进一步 | `.normal` / `.direct` |
| `history.query` | `/history`, `/h`, `/hist`, `/历史` | 查看修改历史 | `.normal` / `.direct` |
| `win.open` | `/open-window`, `/win-open`, `/打开窗口` | 打开窗口 | `.normal` / `.direct` |
| `win.close` | `/close-window`, `/win-close`, `/关闭窗口` | 关闭窗口 | `.normal` / `.direct` |
| `win.pin` | `/pin-window`, `/win-pin`, `/置顶窗口` | 置顶窗口 | `.normal` / `.direct` |
| `win.unpin` | `/unpin-window`, `/win-unpin`, `/取消置顶` | 取消置顶 | `.normal` / `.direct` |
| `win.size` | `/window-size`, `/win-size`, `/窗口尺寸` | 窗口尺寸档位 | `.normal` / `.direct` |
| `win.center` | `/center-window`, `/win-center`, `/窗口居中` | 窗口居中 | `.normal` / `.direct` |
| `nav.tab` | `/tab`, `/go`, `/去页面` | 切换工作台页面 | `.normal` / `.direct` |
| `nav.focusSearch` | `/focus-search`, `/聚焦搜索` | 聚焦搜索框 | `.normal` / `.direct` |

### 2. 待办任务族（[`TaskMutationActions.swift`](../AreaChain/Services/Actions/TaskMutationActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `todo.create` | `/todo`, `/add`, `/t`, `/新建任务` | 新建待办 | `.normal` / `.direct` |
| `todo.done` | `/done`, `/complete`, `/完成` | 完成待办 | `.normal` / `.direct` |
| `todo.reopen` | `/reopen`, `/undone`, `/重开` | 重开待办 | `.normal` / `.direct` |
| `todo.rename` | `/rename`, `/title`, `/改名` | 改名待办 | `.normal` / `.direct` |
| `todo.notes` | `/notes`, `/note`, `/备注` | 修改待办备注 | `.normal` / `.direct` |
| `todo.move` | `/move`, `/defer`, `/推迟`, `/改期` | 移动待办日期 | `.normal` / `.direct` |
| `todo.priority` | `/priority`, `/prio`, `/p`, `/优先级` | 设置待办优先级 | `.normal` / `.direct` |
| `todo.remind` | `/remind`, `/at`, `/提醒` | 设置待办提醒 | `.normal` / `.direct` |
| `todo.clearRemind` | `/clear-remind`, `/unremind`, `/清除提醒` | 清除待办提醒 | `.normal` / `.direct` |
| `todo.due` | `/due`, `/deadline`, `/截止` | 设置待办截止日期 | `.normal` / `.direct` |
| `todo.clearDue` | `/clear-due`, `/undue`, `/清除截止` | 清除待办截止日期 | `.normal` / `.direct` |
| `todo.tagAdd` | `/tag-add`, `/贴标签` | 为待办添加标签 | `.normal` / `.direct` |
| `todo.tagRemove` | `/tag-remove`, `/tag-rm`, `/移除标签` | 移除待办标签 | `.normal` / `.direct` |
| `todo.delete` | `/todo-delete`, `/rm`, `/del`, `/delete`, `/删除任务` | 删除待办（移入回收站） | `.normal` / `.confirm` |

### 3. 例行习惯与子任务族（[`RoutineAndSubtaskActions.swift`](../AreaChain/Services/Actions/RoutineAndSubtaskActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `routine.create` | `/routine`, `/habit`, `/新建习惯` | 新建习惯 | `.normal` / `.direct` |
| `routine.check` | `/check`, `/checkin`, `/打卡` | 打卡习惯 | `.normal` / `.direct` |
| `routine.uncheck` | `/uncheck`, `/取消打卡` | 取消打卡 | `.normal` / `.direct` |
| `routine.rename` | `/routine-rename`, `/改名习惯` | 改名习惯 | `.normal` / `.direct` |
| `routine.notes` | `/routine-notes`, `/习惯备注` | 修改习惯备注 | `.normal` / `.direct` |
| `routine.schedule` | `/routine-schedule`, `/routine-freq`, `/习惯频次` | 设置习惯频次 | `.normal` / `.direct` |
| `routine.pause` | `/routine-pause`, `/暂停习惯` | 暂停习惯 | `.normal` / `.direct` |
| `routine.resume` | `/routine-resume`, `/恢复习惯` | 恢复习惯 | `.normal` / `.direct` |
| `routine.remind` | `/routine-remind`, `/习惯提醒` | 设置习惯提醒 | `.normal` / `.direct` |
| `routine.delete` | `/routine-delete`, `/routine-rm`, `/删除习惯` | 删除习惯 | `.normal` / `.confirm` |
| `subtask.add` | `/subtask-add`, `/subtask`, `/sub`, `/添加子任务` | 添加子任务 | `.normal` / `.direct` |
| `subtask.done` | `/subtask-done`, `/sub-done`, `/完成子任务` | 完成子任务 | `.normal` / `.direct` |
| `subtask.reopen` | `/subtask-reopen`, `/重开子任务` | 重开子任务 | `.normal` / `.direct` |
| `subtask.rename` | `/subtask-rename`, `/sub-rename`, `/改名子任务` | 改名子任务 | `.normal` / `.direct` |
| `subtask.delete` | `/subtask-delete`, `/sub-rm`, `/删除子任务` | 删除子任务 | `.normal` / `.confirm` |

### 4. 日程表与规划面板族（[`PlanningBoardActions.swift`](../AreaChain/Services/Actions/PlanningBoardActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `cal.layout` | `/cal-layout`, `/月历布局` | 切换月历布局 | `.normal` / `.direct` |
| `cal.today` | `/cal-today`, `/回到今天` | 回到今天 | `.normal` / `.direct` |
| `cal.prev` | `/cal-prev`, `/上一天` | 上一天 | `.normal` / `.direct` |
| `cal.next` | `/cal-next`, `/下一天` | 下一天 | `.normal` / `.direct` |
| `cal.selectDay` | `/day`, `/跳转到日期` | 跳转到指定日期 | `.normal` / `.direct` |
| `quadrant.move` | `/quad-move`, `/移入象限` | 移入四象限 | `.normal` / `.direct` |
| `gantt.shift` | `/gantt-shift`, `/甘特顺延` | 甘特图日期顺延 | `.normal` / `.direct` |

### 5. 手记与标签族（[`DiaryAndTagActions.swift`](../AreaChain/Services/Actions/DiaryAndTagActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `diary.save` | `/diary`, `/journal`, `/写手记` | 写手记 | `.privacy` / `.direct` |
| `diary.append` | `/diary-append`, `/追加手记` | 追加手记 | `.privacy` / `.direct` |
| `diary.mood` | `/mood`, `/心情` | 设置手记心情 | `.privacy` / `.direct` |
| `diary.tagAdd` | `/diary-tag-add`, `/手记贴标签` | 为手记添加标签 | `.privacy` / `.direct` |
| `diary.tagRemove` | `/diary-tag-remove`, `/手记移除标签` | 移除手记标签 | `.privacy` / `.direct` |
| `diary.delete` | `/diary-delete`, `/diary-rm`, `/删除手记` | 删除手记（移入回收站） | `.privacy` / `.confirm` |
| `tag.create` | `/tag-create`, `/tag`, `/new-tag`, `/新建标签` | 新建标签 | `.normal` / `.direct` |
| `tag.rename` | `/tag-rename`, `/改名标签` | 改名标签 | `.normal` / `.direct` |
| `tag.color` | `/tag-color`, `/标签颜色` | 设置标签颜色 | `.normal` / `.direct` |
| `tag.delete` | `/tag-delete`, `/删除标签` | 删除标签 | `.normal` / `.confirm` |

### 6. 剪贴板与回收站族（[`ClipboardAndTrashActions.swift`](../AreaChain/Services/Actions/ClipboardAndTrashActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `clip.paste` | `/clip-paste`, `/贴回剪贴板`, `/贴回` | 贴回剪贴板 | `.privacy` / `.direct` |
| `clip.pin` | `/clip-pin`, `/置顶剪贴板`, `/固定剪贴板` | 置顶剪贴板 | `.privacy` / `.direct` |
| `clip.unpin` | `/clip-unpin`, `/取消置顶剪贴板` | 取消置顶剪贴板 | `.privacy` / `.direct` |
| `clip.toTodo` | `/clip-to-todo`, `/clip-todo`, `/转为待办` | 剪贴板转为待办 | `.privacy` / `.direct` |
| `clip.toDiary` | `/clip-to-diary`, `/clip-diary`, `/转为手记` | 剪贴板转为手记 | `.privacy` / `.direct` |
| `clip.delete` | `/clip-delete`, `/clip-rm`, `/删除剪贴板` | 删除剪贴板条目 | `.privacy` / `.confirm` |
| `clip.clear` | `/clip-clear`, `/清空剪贴板` | 清空剪贴板 | `.privacy` / `.confirm` |
| `clip.toggleCapture` | `/clip-capture`, `/切换剪贴板捕获`, `/剪贴板监听` | 切换剪贴板捕获 | `.privacy` / `.direct` |
| `trash.restore` | `/trash-restore`, `/restore`, `/恢复回收站`, `/恢复` | 恢复回收站条目 | `.normal` / `.direct` |
| `trash.purge` | `/trash-purge`, `/purge`, `/彻底删除` | 彻底删除单条回收站记录 | `.system` / `.confirm` |
| `trash.empty` | `/trash-empty`, `/empty-trash`, `/清空回收站` | 清空回收站 | `.system` / `.confirm` |

### 7. 设置、安全与数据备份族（[`SettingsAndPrivacyActions.swift`](../AreaChain/Services/Actions/SettingsAndPrivacyActions.swift)）

| `ActionID` | 主命令与常用别名 | 中文名称 | 权限 / 风险 |
| --- | --- | --- | --- |
| `pref.theme` | `/theme`, `/appearance`, `/外观`, `/主题` | 切换外观主题 | `.normal` / `.direct` |
| `pref.language` | `/lang`, `/language`, `/语言` | 切换界面语言 | `.normal` / `.direct` |
| `pref.truncation` | `/truncation`, `/省略方式` | 切换省略方式 | `.normal` / `.direct` |
| `pref.calendarSync` | `/cal-sync`, `/日历同步` | 切换日历同步 | `.normal` / `.direct` |
| `pref.stampApp` | `/stamp-app`, `/记录来源应用` | 切换记录来源应用 | `.normal` / `.direct` |
| `privacy.lock` | `/lock`, `/锁定隐私` | 锁定隐私保险箱 | `.privacy` / `.direct` |
| `privacy.unlock` | `/unlock`, `/解锁隐私` | 解锁隐私保险箱 | `.privacy` / `.direct` |
| `data.exportJSON` | `/export-json`, `/导出快照` | 导出快照 | `.system` / `.direct` |
| `data.importJSON` | `/import-json`, `/导入快照` | 导入快照 | `.system` / `.direct` |
| `data.exportBackup` | `/backup-export`, `/导出加密备份` | 导出加密备份 | `.system` / `.direct` |
| `data.restoreBackup` | `/backup-restore`, `/恢复加密备份` | 恢复加密备份 | `.system` / `.confirm` |

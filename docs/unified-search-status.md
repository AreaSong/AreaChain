# 统一搜索现状总览

本文是统一搜索与指令体系的**现状总览**：只记当前状态、覆盖、缺口和每批必读入口，不记更新时间和过程。设计、规则与仍有效的决定以[权威设计](unified-search-commands.md)为准；过程与证据在 git 历史和提交说明里。每批怎样更新本文见[技能路由的路由维护](../skill-routing.md#路由维护)。

## 目标与阶段

- **目标**：工作台和菜单栏共用一套搜索与指令，覆盖 §8 全部 48 项用户功能；现有按钮、菜单与指令共用业务逻辑（[§1](unified-search-commands.md#1-已确认的产品与查询规则)）。
- **当前形态**：统一搜索已接入正式版，是唯一的全局搜索入口，没有开关、没有退回旧搜索的办法。唯一装配点 `UnifiedSearchProductionAssembly` 构造工作台与菜单栏两个控制器；装配失败时两宿主搜索框显示不阻塞的说明。
- 阶段划分见 [§9.1](unified-search-commands.md#91-建议的分阶段边界)：
  - **阶段 1 领域协议**：已实现（目录、解析、查询会话、草稿、计划、转交）。
  - **阶段 2 只读数据**：注入快照提供者与 SwiftData／文件只读适配已实现，读取仍在主线程同步进行。
  - **阶段 3 业务动作适配**：普通设置、任务、子任务、习惯、批量、转换、标签、手记等指令已实现；系统类、永久删除类与附件系统动作只“打开原页面”；手记写入只对普通手记直接执行，受保护目标打开原页面。逐项见下表。
  - **阶段 4 共享界面**：两宿主每条指令都有去处。目录 247 条指令（不含分组与范围）中，工作台可执行 160、打开原页面 86、目录不可用 1；菜单栏可执行 64、在工作台完成 178、目录不可用 5；两宿主“未接上”均为 0。唯一判断入口是 `UnifiedSearchController.disposition(for:)`。保留的页面内筛选：手记页、手记小窗、标签管理、剪贴板历史、附件中心。
  - 阶段 5～7（队列执行与撤销、独立系统流程、模板与全目录收口）：未开始。

## 功能覆盖表

状态只用：**已接正式版 / 已接正式版（部分） / 已接正式版＋打开原页面 / 打开原页面 / 隔离实现 / 未开始 / 待核实**。所有“已接正式版”的行都待用户在日用版逐项验收。“打开原页面”指指令只导航到原页面、由原页面完成操作，不在指令里执行；对照只在 [CommandOriginalPage](../AreaChain/Domain/CommandOriginalPage.swift)。“部分”时在“已覆盖／未覆盖”列写清哪些动作没有完成。“已复核”只指按[指定只读复核入口](../skill-routing.md#指定只读复核入口)通过的部分。功能名称见 §8 对应行（ID 链接）。

| ID | 功能 | 状态 | 已覆盖／未覆盖 |
|---|---|---|---|
| [T1](unified-search-commands.md#T1) | 新建任务、标题、备注 | 已接正式版 | 已：todo.create、todo.title（已复核）、todo.notes（长文受控借用）、todo.cancelTitle（去掉宿主保留的标题草稿）；原界面文字里的私密／预设标签不再关联 |
| [T2](unified-search-commands.md#T2) | 完成、改期、提醒、优先级、标签、截止 | 已接正式版 | 已：todo.move／priority／reminder／completion／tags／createTag／due（已复核）、todo.cancelCompletion（复用 0.4 秒反悔窗口）；move／priority／reminder／tags／due 允许带备注对象 |
| [T3](unified-search-commands.md#T3) | 复制、回收 | 已接正式版 | 已：todo.copy、todo.trash；带备注对象可复制、可回收（确认面板说明备注随对象进回收站）；未复核 |
| [T4](unified-search-commands.md#T4) | 子任务 | 已接正式版 | 已：subtask.create／title／completion／tags（已复核）、subtask.delete、subtask.order、subtask.cancelTitle；父待办带备注仍拒绝 |
| [T5](unified-search-commands.md#T5) | 重复事项定义 | 已接正式版 | 已：routine.title／weekdays／reminder／priority／tags、routine.create、routine.enabled（以上已复核）、routine.trash、routine.order、routine.capture／routine.notes（经长文受控借用执行） |
| [T6](unified-search-commands.md#T6) | 指定日完成／撤回／跳过、检查日、连击 | 已接正式版 | 已：occurrence.complete／skip／reopen、inspector.day 定位（以上已复核）、routine.streak（复用 HabitStreakLogic，只读）、occurrence.inspect（沿月历点日期换检查日，不打卡） |
| [T7](unified-search-commands.md#T7) | 批量任务／习惯 | 已接正式版 | 已：batch.move／tags（允许带备注）、batch.completion／enabled（以上已复核）、batch.trash（允许带备注）、selection.clear |
| [T8](unified-search-commands.md#T8) | 待办↔重复事项转换 | 已接正式版 | 已：todo.toRoutine、routine.toTodo；带备注对象可转换（损失清单列出“备注原样搬到新对象”）；未复核 |
| [T9](unified-search-commands.md#T9) | 页面筛选、全部事项、排序、延至今日 | 已接正式版（部分） | 已：tasks.order、tasks.postponeYesterday、tasks.filter／clearFilter（今日／待处理／全部事项，与页面双向同步）、tasks.kind／status、tasks.sections（昨天／即将）、tasks.select（待处理／全部事项）；未：今日区收起（始终展开）、今日页与标签清单的多选指令 |
| [T10](unified-search-commands.md#T10) | 剪贴板加今天 | 已接正式版 | 已：capture.clipboard（无 Run 模式，提交才读剪贴板；已复核）；读到私密／预置标签整条不写并说明，菜单栏入口跳过标签照常保存 |
| [B1](unified-search-commands.md#B1) | 日历导航与改期 | 已接正式版 | 已：calendar.mode／step／today／day／dayList（页面指令，月周与选中日写页面那一份）、calendar.create（转交 todo.create）；拖拽改期沿 todo.move；calendar.step 只留 offset，月周跟随当前视图 |
| [B2](unified-search-commands.md#B2) | 四象限 | 已接正式版 | 已：quadrant.day／step／inspect（页面指令）、create／priority／complete／copy（转交 todo.create／todo.priority 或 routine.priority／todo.completion 或 occurrence.complete／todo.copy 标题段）；copy 不接习惯 |
| [B3](unified-search-commands.md#B3) | 安排页平移与完成 | 已接正式版 | 已：gantt.step／currentMonth／select／inspect（页面指令）、gantt.shift（GanttRescheduleService，一次事务、保留间隔、越出当月拒绝）、gantt.complete（转交 batch.completion） |
| [J1](unified-search-commands.md#J1) | 手记新建与正文 | 已接正式版＋打开原页面 | 已：diary.create（快速新增的自动分类）、diary.body replace／append（长文受控借用；clear 按目录静态拒绝）、diary.save／reload／discard（只作用于已打开的小窗会话）、diary.tags（见 J2）；打开原页面：受保护或保存后会变成受保护、加私密标签、超过 64KiB 的已有正文 → 手记页 |
| [J2](unified-search-commands.md#J2) | 手记组织 | 已接正式版＋打开原页面 | 已：diary.pinned、diary.move、diary.tags（普通标签加减／替换／清空；加私密标签拒绝）；打开原页面：diary.privateMark／reveal／mask 与受保护手记 → 手记页 |
| [J3](unified-search-commands.md#J3) | 手记复制、转任务、回收 | 已接正式版＋打开原页面 | 已：diary.copy（整篇／标题／备注，PrivateClipboard）、diary.toTodo、diary.trash（共用独立确认、只能单项）；打开原页面：受保护手记 → 手记页 |
| [G1](unified-search-commands.md#G1) | 标签新建、改名、颜色、排序、搜索与视图 | 已接正式版（部分） | 已：tag.create／rename／color、tag.order、tag.cancel、tag.search／view／deleted（取法即标签页的 TagListQuery）、go.tagList；未：新建时设为私密（需解锁） |
| [G2](unified-search-commands.md#G2) | 标签合并、解绑、软删／恢复、清理 | 已接正式版＋打开原页面 | 已：tag.merge（涉及私密标签整条拒绝）、tag.unlinkObject（受保护手记拒绝）、tag.trash／tag.restore（共用独立确认、只能单项）；打开原页面：tag.delete、tag.cleanup → 标签页；tag.unlinkGlobal 目录 unavailable（原界面没有该功能，不算缺口） |
| [A1](unified-search-commands.md#A1) | 图片附件 | 已接正式版＋打开原页面 | 已：图片元数据只读查询、普通图片查阅（已复核）、image.browse／image.preview／image.trash；打开原页面：image.pick／paste／capture → 焦点对象的详情（手记打开手记页，习惯定义须先选执行日） |
| [C1](unified-search-commands.md#C1) | 剪贴板浏览与搜索 | 已接正式版 | 已：显式 /clipboard 只读提供者与文件只读适配；clipboard.browse／search（与历史页 visibleItems 同一取法）；默认不进普通搜索 |
| [C2](unified-search-commands.md#C2) | 剪贴板复制／粘贴 | 已接正式版 | 已：clipboard.copy／paste／pastePlain（ClipboardHistoryActions，写入失败不报成功）；粘贴到其他应用需辅助功能权限，只在执行时询问 |
| [C3](unified-search-commands.md#C3) | 剪贴板置顶、删除、清空 | 已接正式版＋打开原页面 | 已：clipboard.pinned、clipboard.copyLetter；打开原页面：delete、prune、empty → 剪贴板页 |
| [C4](unified-search-commands.md#C4) | 记录暂停、跳过、忽略来源 | 打开原页面 | clipboard.recording／skipNext／ignoreApp → 剪贴板页 |
| [C5](unified-search-commands.md#C5) | 剪贴板偏好 | 打开原页面 | 全部 13 条（含 add／removePattern、add／removeType、unignoreApp）→ 剪贴板页的“剪贴板选项”（设置页没有剪贴板分节） |
| [C6](unified-search-commands.md#C6) | 剪贴板小窗 | 已接正式版 | 已：clipboard.openWindow／closeWindow／pinWindow／workspace（沿 ClipboardHistoryPanel 现有窗口管理，只有一个面板） |
| [S1](unified-search-commands.md#S1) | 语言、外观、标题省略、捕获来源 | 已接正式版（部分） | 已：四项设置的单项指令（正式版沿用 AppPreferences 旧键）；未：多项共同提交（聚合文件后端只在隔离宿主装配）；未复核 |
| [S2](unified-search-commands.md#S2) | 登录启动 | 打开原页面 | setting.login、loginSettings → 设置“启动”分节 |
| [S3](unified-search-commands.md#S3) | 通知权限与测试 | 打开原页面 | notification.status／request／test／settings → 设置“通知”分节 |
| [S4](unified-search-commands.md#S4) | 通知完成与延后 | 已接正式版＋打开原页面 | 已：notification.open 沿 inspector.open 打开对象；complete／snooze 只说明并给出改用 todo.completion／occurrence.complete／todo.reminder 的入口，不另写执行 |
| [S5](unified-search-commands.md#S5) | 日历同步 | 打开原页面 | calendarSync.enabled／status／retry／settings／conflicts → 设置“系统日历”分节；openLocal 也打开该分节（搜索里没有冲突对象来源） |
| [S6](unified-search-commands.md#S6) | iCloud 说明 | 打开原页面 | setting.icloud → 设置“iCloud”分节 |
| [S7](unified-search-commands.md#S7) | 快捷键配置 | 打开原页面 | shortcut.record／reset／resetAll／cancel → 快捷键页 |
| [P1](unified-search-commands.md#P1) | 创建私密锁 | 打开原页面 | privacy.create／setupMethod／setupTags／protectExisting → 隐私与解锁页；不新增隐私转换执行路径 |
| [P2](unified-search-commands.md#P2) | 隐私管理 | 已接正式版＋打开原页面 | 已：privacy.lock 直接执行（沿“立即锁定”，锁定撤权）；打开原页面：unlock、systemUnlock、set／change／removePassword、idle、tags → 隐私与解锁页 |
| [P3](unified-search-commands.md#P3) | 解除单条手记保护 | 打开原页面 | privacy.unprotect → 隐私与解锁页 |
| [P4](unified-search-commands.md#P4) | 隐私维护重试 | 打开原页面 | privacy.retryImages／retryKeys／quitForCleanup → 隐私与解锁页 |
| [D1](unified-search-commands.md#D1) | 回收站 | 已接正式版＋打开原页面 | 已：显式回收范围的墓碑只读搜索、trash.restore（与回收站页同一写入 TrashRestoreService，共用独立确认、只能单项，受保护拒绝）；打开原页面：trash.delete、trash.empty → 回收站（定位焦点项）、trash.browse → 回收站页（类别在页面筛选里选） |
| [D2](unified-search-commands.md#D2) | JSON 导出导入 | 打开原页面 | data.export／selectImport／validateImport／previewImport／applyImport → 数据与备份页；不新增导入执行路径 |
| [D3](unified-search-commands.md#D3) | 加密备份与恢复 | 打开原页面 | backup.export／inspect／preview／restore → 数据与备份页；不新增备份恢复执行路径 |
| [D4](unified-search-commands.md#D4) | 重置并退出 | 打开原页面 | recovery.status、recovery.resetQuit → 数据与备份页（降级提示就在该页）；resetQuit 目录仍 unavailable |
| [N1](unified-search-commands.md#N1) | 全页面与标签清单导航 | 已接正式版 | 已：16 个 go 入口、go.tagList（均已复核） |
| [N2](unified-search-commands.md#N2) | 工作台、浮层与面板 | 已接正式版（部分） | 已：workspace.open／reveal／close、overlay.toggle、routine.addPanel／managePanel（沿 AppWindows 与今日页原面板，不新建窗口）；未：overlay.mode（浮层的任务／手记页没有外部切换入口，只说明） |
| [N3](unified-search-commands.md#N3) | 检查器与选择 | 已接正式版 | 已：inspector.open／inspector.day（已复核）、selection.all／clear（沿页面投影）、inspector.close（沿检查器关闭按钮，先失焦保存） |
| [N4](unified-search-commands.md#N4) | 手记小窗 | 已接正式版 | 已：diaryWindow.open（受保护手记拒绝）／draft（不写入，受保护草稿留给原页面）／pinned／close（沿小窗原有确认）、diaryWindow.save（复用小窗会话保存，受保护会话只前置小窗） |
| [N5](unified-search-commands.md#N5) | 总览统计 | 已接正式版 | 已：stats.* 八项只读（DashboardStatsReader，与总览页同一投影，私密手记口径不变）、stats.openDay、活动行打开（沿总览路由；stats.openActivity 指向 stats.activity 的列表） |
| [N6](unified-search-commands.md#N6) | 帮助与示例 | 打开原页面 | help.syntax（语法帮助卡）、help.page（来时页面的说明）、help.example（只预填示例到搜索框，不执行） |
| [N7](unified-search-commands.md#N7) | 版本、反馈与链接 | 打开原页面 | support.* 七条 → 设置“版本／支持／关于”分节；不在指令里打开外部网址 |
| [N8](unified-search-commands.md#N8) | 退出与未保存确认 | 已接正式版 | 已：app.quit 走 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记），同意后才调注入的 terminate |

合计 48 项：已接正式版 20（T1～T8、T10、B1～B3、C1、C2、C6、N1、N3、N4、N5、N8）；已接正式版（部分）4（T9、G1、N2、S1）；已接正式版＋打开原页面 9（J1～J3、G2、A1、C3、S4、P2、D1）；打开原页面 15（C4、C5、S2、S3、S5、S6、S7、P1、P3、P4、D2、D3、D4、N6、N7）；隔离实现、未开始、待核实均为 0。

## 未闭合缺口

只记仍未解决的问题；关闭某条时删去对应行。

- **用户验收**：日用版逐域试用由用户进行；真实库、真实附件目录、真实钥匙串与真实系统授权均未在执行会话里验证。替换日常应用前的全量回归按用户确认视为完成，明细未入库。
- **人工与平台验收**：真人输入法、VoiceOver、最低支持系统、真实多窗口、原生截图逐类查看均未做；工作台操作面板里的按钮在原生用例中改用 AXPress 验证，真实鼠标点击未验证。
- **正常签名构建**：正常开发描述文件到期后正常构建记为阻塞，不续签、不改个人签名配置；当前到期时间用 `security cms -D -i` 读内嵌描述文件核对。Widget 内嵌描述文件签名后被替换、导致正常构建签名核验失败的问题仍记为阻塞。
- **页面筛选与查询**：页内搜索合并、页面筛选与查询的其余双向同步未做；菜单栏手记页签的标签筛选不作用于搜索结果（菜单栏搜索页面固定为今日任务，筛选胶囊只在任务页签显示）。
- **菜单栏打开结果**：工作台查询的页面上下文不同时可能找不到同一对象，只停在结果页。
- **受保护内容**：受保护手记的写入、复制与转换只打开原页面；受保护内容查阅与敏感执行／转交不开放。C2B 原生接受与锁定交错未解决：敏感输入不开放，mutable textStorage 只能事后检测。
- **有备注对象资格**：仍未放宽 todo.title／subtask.title（`//` 派生备注另行定界）、完成、建标签、子任务与习惯字段类、删子任务时的父待办。
- **手记小窗指令**：diary.save／reload／discard 只作用于已打开的小窗会话（手记页卡片的编辑会话是页面私有状态，宿主没有入口）；有未保存内容的重载只前置小窗由用户确认。
- **打开原页面的限制**：设置与剪贴板分节只在说明里指明，页面不自动滚动；image.preview 只能打开当前结果里可见的普通图片。
- **隔离宿主共享目录**：隔离宿主中 @附件 关联（会改写共享池索引）、手记卡片“取消保护”、输入联想读共享池仍走共享目录。
- **目录未决项**：tag.cleanup（预置标签范围）、backup.export（无锁可达性）未定稿。来源：[§9.4](unified-search-commands.md#94-未决问题与单独授权边界)。
- **现状差距**：备份未配置锁的可达性、剪贴板历史读取失败返回空、重置吞掉删除错误。来源：[§9.4](unified-search-commands.md#94-未决问题与单独授权边界)。
- **性能**：读取仍在主线程同步进行；新查询延迟、长文编辑、最大候选规模与内存均未建立基线。来源：[§9.3](unified-search-commands.md#93-后续回归入口与证据缺口)。
- **已知历史问题**：标题多目标面板消失的根因未判定；DetailSubtaskCompletionTests 两项 Expected Failure 保留；原生日期格按钮在统一搜索测试宿主里找不到标识（`nativeBooleanWeekdaysDayAndTime` 等）；`SubtaskModelTests.addTagSkipsDiaryPresetNames` 在未改动 HEAD 上同样失败。
- **待批准的低级整改**：T 系列补复核留下的 9 条低级整改，待单独批准的修复批次。

## 既有失败

逐条登记在 [`scripts/known_test_failures.json`](../scripts/known_test_failures.json)（门禁只改变归类，测试照常运行）。现存 32 条，首次复现提交都是 d77da2e（统一搜索接入正式版之前的基线，未再向前二分）：CalendarSpanConsumerTests（3）、CalendarWeekConsumerTests、CalendarWeekLayoutTests（2）、DashboardScrollTests、DaybookScrollNativeTests、DiaryTitleHoverTests（2）、MenuBarHelpSurfaceTests、MenuBarStatusImageTests、PasswordRetryDiagnosticTests（2，诊断型）、PrivacyAutolockPickerTests（2）、PrivacyButtonConsumerTests、ScrollAssemblyConsumerTests、SearchMultilineDiagnosticTests、UnifiedSearchOperationInteractionTests、UnifiedSearchSettingInteractionTests、WeekdayConsumerBaselineTests、WorkspaceInspectorSizingTests（2）、WorkspaceMenuConsumerTests、WorkspaceRenderingTests、YesterdayCardActionTests（3）、YesterdayCardConsumerTests（3）。

- 各批只跑定向测试；全量回归只在替换日常应用之前或用户明确要求时运行（见[质量门禁](quality-gates.md)）。
- 焦点前置失败（拿不到 key window）在桌面空闲重跑后通过的不登记；TagHelpSurfaceConsumerTests 两项基线失败现已通过；DashboardRenderingTests 的 segv 两次对照都未复现。

## 补复核待办

- **仍待复核**：阶段 2 只读数据、阶段 4A 共享界面、3A 普通设置、3T 普通任务新增与标题，以及复制与回收（T-M4）、待办与重复事项互转（T-M5）。
- **已复核通过**的部分在上表各行标注“已复核”；各轮复核结论与记录在案的低级意见见对应提交说明。

## 每批最少必读

执行一个批次时，按下面顺序读，读够即停。

1. 本总览全文。
2. 主文档 §8 中本批涉及的行：用行首锚点定位，例如 `grep -n 'id="G1"' docs/unified-search-commands.md`。
3. 主文档 §1～§6 中与本批相关的规则小节。
4. 主文档 §9 的“仍有效的决定”中本域条目；需要追溯历史时按“历史交接记录”给出的 `git show` 查看。
5. 涉及未决项时读 [§9.4](unified-search-commands.md#94-未决问题与单独授权边界)；涉及目录 ID 时，以 `CommandCatalog` 源码和 §8 映射为准。
6. [技能路由](../skill-routing.md)的“指定只读复核入口”与“路由维护”，[组件目录](component-catalog.md)中本域条目；新简单修改指令先看组件目录的“简单指令共用骨架”。

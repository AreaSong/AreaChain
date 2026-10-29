# 统一搜索现状总览

本文是统一搜索与指令体系的**现状总览**：只记当前状态、覆盖、缺口和每批必读入口。设计、规则与仍有效的决定以[权威设计](unified-search-commands.md)为准，逐批历史证据在 git 历史里，本文不复制。每批怎样更新本文见[技能路由的路由维护](../skill-routing.md#路由维护)。

最后更新：2026-10-30，代码清理：注释与测试命名去掉进度字样（§9.110）；2026-10-29，统一搜索收口：两宿主指令全部有去处、锁定后可重新输入、补验 ffe27a3 与 6b3dba6（§9.109）；2026-10-28，修复批 M-7G 失焦恢复与指令可用性（§9.108）；同日修复批 M-7F 恢复三处旧行为（§9.107）；2026-10-23，收尾批 M-7 删除旧全局搜索（§9.106）；恢复原界面手记隐私规则（§9.105）；修复批 M-6R 接入前阻断修复（§9.104）。

## 目标与阶段

- **目标**：工作台和菜单栏共用一套搜索与指令，覆盖 §8 全部 48 项用户功能；现有按钮、菜单与指令共用业务逻辑（[§1](unified-search-commands.md#1-已确认的产品与查询规则)）。
- **当前方向**（2026-10-18 用户决定；2026-10-22 M-6 决策）：功能已在隔离环境补齐并于 M-6 接入正式版；2026-10-23 收尾批 M-7 删除旧全局搜索与开关，统一搜索成为唯一入口；2026-10-29 用户确认替换前全量回归（Z-2）视为完成，日常应用已替换。
- 阶段划分见 [§9.1](unified-search-commands.md#91-建议的分阶段边界)，当前状态一句话一行：
  - **阶段 1 领域协议**：1A～1D 已实现（目录、解析、查询会话、草稿、计划、转交），仅 1A～1D 自身证据，见 §9.6～§9.13。
  - **阶段 2 只读数据**：2A～2J 注入快照提供者与 2K-1～2K-8 SwiftData／文件只读适配已在隔离环境实现；真实宿主的异步调度与生产接线未做，见 §9.14～§9.44。
  - **阶段 3 业务动作适配**：进行中；普通设置（3A）、任务／子任务／习惯／批量／转换／标签等指令已在隔离环境逐批实现；系统类、永久删除类与附件系统动作自 M-3 起“打开原页面”。覆盖见下表；手记写入 J1～J3 自 M-4 起只对普通手记直接执行，受保护目标打开原页面，未开始为 0。
  - **阶段 4 共享界面**：已完成：旧全局搜索已删除，统一搜索为唯一入口（M-7，没有开关、没有退路）。唯一装配点 `UnifiedSearchProductionAssembly` 构造工作台与菜单栏两个控制器；装配失败时两宿主搜索框显示不阻塞的说明。保留的页面内筛选：手记页、手记小窗、标签管理、剪贴板历史、附件中心（未与统一搜索合并，留待用户决定）。2026-10-29 收口：两宿主每条指令都有去处（工作台未接上 0；菜单栏没接上的 178 条改为“在工作台完成”，Return 显示工作台并交出同一文字），锁定后两宿主可由显式动作重新输入。仍未做、待用户决定：页内搜索合并、页面筛选与查询双向同步（§9.1 阶段 4 其余部分）。见 §9.103、§9.106、§9.109。
  - 阶段 5～7（队列执行与撤销、独立系统流程、模板与全目录收口）：未开始。

## 功能覆盖表

状态只用：**未开始 / 隔离实现 / 隔离实现且已复核 / 打开原页面 / 已接正式版 / 待核实**；M-6 起“已接正式版”后括注“待用户验收”，直到用户在日用版逐项试过。“打开原页面”（M-3，2026-10-20 用户决策 1、2）指指令只导航到原页面、由原页面完成操作，不在指令里执行，**不算隔离实现**；对照只在 [CommandOriginalPage](../AreaChain/Domain/CommandOriginalPage.swift)。一行内既有隔离实现又有打开原页面的动作时写“隔离实现＋打开原页面”。一行内只有部分动作完成时写“隔离实现（部分）”，并在“已覆盖／未覆盖”列写清哪些动作完成、哪些没有；不把未覆盖动作算作已实现。“已复核”只指按[指定只读复核入口](../skill-routing.md#指定只读复核入口)通过的部分。功能名称见 §8 对应行（ID 链接）。

| ID | 功能 | 状态 | 已覆盖／未覆盖 | 里程碑 | 交接 |
|---|---|---|---|---|---|
| [T1](unified-search-commands.md#T1) | 新建任务、标题、备注 | 已接正式版（待用户验收） | 已：todo.create、todo.title（G-1a 已复核）；todo.notes（L-M1b）；todo.cancelTitle（M-1，去掉宿主保留的标题草稿）；原界面文字里的私密／预设标签不再关联（M-1 A，已接正式版行为） | 3T、T-M1、T-M6、L-M1b、M-1 | §9.95、§9.96 |
| [T2](unified-search-commands.md#T2) | 完成、改期、提醒、优先级、标签、截止 | 已接正式版（待用户验收） | 已：todo.move／priority／reminder（T-M1）、completion／tags／createTag／due（T-M2），均 G-1a 已复核；todo.cancelCompletion（M-1，复用 0.4 秒反悔窗口）；move／priority／reminder／tags／due 自 M-1 起允许带备注对象 | T-M1、T-M2、M-1 | §9.74、§9.96 |
| [T3](unified-search-commands.md#T3) | 复制、回收 | 已接正式版（待用户验收） | 已：todo.copy、todo.trash；M-1 起带备注对象可复制、可回收（确认面板说明备注随对象进回收站）；未复核 | T-M4、M-1 | §9.90、§9.96 |
| [T4](unified-search-commands.md#T4) | 子任务 | 已接正式版（待用户验收） | 已：subtask.create／title／completion／tags（T-M3，G-1a 已复核）、subtask.delete（T-M4）、subtask.order（T-M6）、subtask.cancelTitle（M-1）；父待办带备注仍拒绝 | T-M3、T-M4、T-M6、M-1 | §9.75、§9.96 |
| [T5](unified-search-commands.md#T5) | 重复事项定义 | 已接正式版（待用户验收） | 已：routine.title／weekdays／reminder／priority／tags（R-M1）、routine.create（R-M2）、routine.enabled（R-M3）、routine.trash（T-M4）、routine.order（T-M6）、routine.capture／routine.notes（T-M6 规格，L-M1b 经长文受控借用执行）；title／weekdays／reminder／priority／tags、create、enabled 已复核（M-5，R-M1～R-M3 通过） | R-M1～R-M3、T-M4、T-M6、L-M1b | §9.76、§9.78、§9.95 |
| [T6](unified-search-commands.md#T6) | 指定日完成／撤回／跳过、检查日、连击 | 已接正式版（待用户验收） | 已：occurrence.complete／skip／reopen（R-M3，M-5 已复核）、inspector.day 定位（N-M1，M-5 已复核）、routine.streak（M-1，复用 HabitStreakLogic，只读）、occurrence.inspect（沿月历点日期换检查日，不打卡，§9.109） | R-M3、N-M1、M-1 | §9.78、§9.96 |
| [T7](unified-search-commands.md#T7) | 批量任务／习惯 | 已接正式版（待用户验收） | 已：batch.move／tags（B-M1，M-1 起允许带备注）、batch.completion／enabled（B-M2），均 M-5 已复核、batch.trash（T-M4，M-1 起允许带备注）、selection.clear（M-1） | B-M1、B-M2、T-M4、M-1 | §9.79、§9.96 |
| [T8](unified-search-commands.md#T8) | 待办↔重复事项转换 | 已接正式版（待用户验收） | 已：todo.toRoutine、routine.toTodo；M-1 起带备注对象可转换（损失清单列出“备注原样搬到新对象”）；未复核 | T-M5、M-1 | §9.91、§9.96 |
| [T9](unified-search-commands.md#T9) | 页面筛选、全部事项、排序、延至今日 | 已接正式版（部分，待用户验收） | 已：tasks.order、tasks.postponeYesterday（T-M6）；tasks.filter／clearFilter（今日／待处理／全部事项，与页面双向同步）、tasks.kind／status、tasks.sections（昨天／即将）、tasks.select（待处理／全部事项）（M-1）；未：今日区收起（始终展开）、今日页与标签清单的多选指令 | 2A～2J、4A、T-M6、M-1 | §9.93、§9.96 |
| [T10](unified-search-commands.md#T10) | 剪贴板加今天 | 已接正式版（已复核，待用户验收） | 已：capture.clipboard（T-M6，无 Run 模式，提交才读剪贴板；T-M6 指定复核通过）；M-1 起读到私密／预置标签整条不写并说明（L7），菜单栏入口跳过标签照常保存 | T-M6 | §9.93 |
| [B1](unified-search-commands.md#B1) | 日历导航与改期 | 已接正式版（待用户验收） | 已：calendar.mode／step／today／day／dayList（页面指令，月周与选中日写页面那一份）、calendar.create（转交 todo.create）；拖拽改期沿 todo.move（T-M1）。核实：原组合只覆盖导航与改期，页面动作在 M-2 补齐；calendar.step 只留 offset，月周跟随当前视图 | N-M1、M-2 | §9.97 |
| [B2](unified-search-commands.md#B2) | 四象限 | 已接正式版（待用户验收） | 已：quadrant.day／step／inspect（页面指令）、create／priority／complete／copy（转交 todo.create／todo.priority 或 routine.priority／todo.completion 或 occurrence.complete／todo.copy 标题段）；quadrant.complete 的 1A 未决（习惯 skip 语义）已由 R-M3 D1 定，M-2 解决；copy 不接习惯 | N-M1、M-2 | §9.97 |
| [B3](unified-search-commands.md#B3) | 安排页平移与完成 | 已接正式版（待用户验收） | 已：gantt.step／currentMonth／select／inspect（页面指令）、gantt.shift（X-1 骨架，GanttRescheduleService，一次事务、保留间隔、越出当月拒绝）、gantt.complete（转交 batch.completion） | N-M1、M-2 | §9.97 |
| [J1](unified-search-commands.md#J1) | 手记新建与正文 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.create（快速新增的自动分类）、diary.body replace／append（L-M1b 借用，手记出口；clear 按目录静态拒绝）、diary.save／reload／discard（只作用于已打开的小窗会话）、diary.tags（见 J2）；打开原页面：受保护或保存后会变成受保护、加私密标签、超过 64KiB 的已有正文 → 手记页（M-4） | C-M1～C-M3、M-4 | §9.99 |
| [J2](unified-search-commands.md#J2) | 手记组织 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.pinned、diary.move、diary.tags（普通标签加减／替换／清空；加私密标签拒绝，privateTagTransition 已解决）；打开原页面：diary.privateMark／reveal／mask 与受保护手记 → 手记页（M-4） | M-4 | §9.99 |
| [J3](unified-search-commands.md#J3) | 手记复制、转任务、回收 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.copy（整篇／标题／备注，PrivateClipboard）、diary.toTodo、diary.trash（共用独立确认、只能单项）；打开原页面：受保护手记 → 手记页（M-4） | M-4 | §9.99 |
| [G1](unified-search-commands.md#G1) | 标签新建、改名、颜色、排序、搜索与视图 | 已接正式版（部分，待用户验收） | 已：tag.create／rename／color（X-1）、tag.order（M-1）、tag.cancel、tag.search／view／deleted（M-2，取法即标签页的 TagListQuery）、go.tagList（N-M2）；未：新建时设为私密（需解锁） | X-1、2F、N-M2、T-M6、M-1、M-2 | §9.92、§9.97 |
| [G2](unified-search-commands.md#G2) | 标签合并、解绑、软删／恢复、清理 | 已接正式版（待用户验收）＋打开原页面 | 已：tag.merge（决策 3：涉及私密标签整条拒绝）、tag.unlinkObject（受保护手记拒绝）、tag.trash／tag.restore（共用独立确认、只能单项）；打开原页面：tag.delete、tag.cleanup → 标签页（M-3）；tag.unlinkGlobal 目录 unavailable（原界面没有该功能，不算缺口） | M-2、M-3 | §9.97、§9.98 |
| [A1](unified-search-commands.md#A1) | 图片附件 | 已接正式版（待用户验收）＋打开原页面 | 已：图片元数据只读查询（2E、2K-6）、普通图片查阅（N-M2，M-5F 整改后已复核）、image.browse／image.preview／image.trash（M-2）；打开原页面：image.pick／paste／capture → 焦点对象的详情（手记打开手记页，习惯定义须先选执行日）（M-3） | 2K-6、N-M2、M-2、M-3 | §9.97、§9.98 |
| [C1](unified-search-commands.md#C1) | 剪贴板浏览与搜索 | 已接正式版（待用户验收） | 已：显式 /clipboard 只读提供者与文件只读适配（2G、2K-5）；clipboard.browse／search（M-2，与历史页 visibleItems 同一取法，原生等价验收逐行比对）；默认不进普通搜索不变 | 2G、2K-5、M-2 | §9.97 |
| [C2](unified-search-commands.md#C2) | 剪贴板复制／粘贴 | 已接正式版（待用户验收） | 已：clipboard.copy／paste／pastePlain（ClipboardHistoryActions，写入失败不报成功；QA 中门与按键全为 fake、私有命名剪贴板）；真实辅助功能权限与 ⌘V 未接线 | M-2 | §9.97 |
| [C3](unified-search-commands.md#C3) | 剪贴板置顶、删除、清空 | 已接正式版（待用户验收）＋打开原页面 | 已：clipboard.pinned、clipboard.copyLetter（M-2）；打开原页面：delete、prune、empty → 剪贴板页（M-3） | M-2、M-3 | §9.97、§9.98 |
| [C4](unified-search-commands.md#C4) | 记录暂停、跳过、忽略来源 | 打开原页面 | clipboard.recording／skipNext／ignoreApp → 剪贴板页（M-3，决策 2） | M-3 | §9.98 |
| [C5](unified-search-commands.md#C5) | 剪贴板偏好 | 打开原页面 | 全部 13 条（含 add／removePattern、add／removeType、unignoreApp）→ 剪贴板页的“剪贴板选项”（设置页没有剪贴板分节，M-3 核实） | M-3 | §9.98 |
| [C6](unified-search-commands.md#C6) | 剪贴板小窗 | 已接正式版（待用户验收） | 已：clipboard.openWindow／closeWindow／pinWindow／workspace（沿 ClipboardHistoryPanel 现有窗口管理，只有一个面板）；真实窗口适配读共享会话，生产接线另需授权 | M-2 | §9.97 |
| [S1](unified-search-commands.md#S1) | 语言、外观、标题省略、捕获来源 | 已接正式版（待用户验收） | 单项与共同提交（聚合文件后端）都在隔离宿主；未复核 | 3A | §9.62 |
| [S2](unified-search-commands.md#S2) | 登录启动 | 打开原页面 | setting.login、loginSettings → 设置“启动”分节（M-3） | M-3 | §9.98 |
| [S3](unified-search-commands.md#S3) | 通知权限与测试 | 打开原页面 | notification.status／request／test／settings → 设置“通知”分节（M-3） | M-3 | §9.98 |
| [S4](unified-search-commands.md#S4) | 通知完成与延后 | 已接正式版（待用户验收）＋打开原页面 | 已：notification.open 沿 inspector.open 打开对象；complete／snooze 只说明并给出改用 todo.completion／occurrence.complete／todo.reminder 的入口，不另写执行（M-3） | M-3 | §9.98 |
| [S5](unified-search-commands.md#S5) | 日历同步 | 打开原页面 | calendarSync.enabled／status／retry／settings／conflicts → 设置“系统日历”分节；openLocal 也改为打开该分节（搜索里没有冲突对象来源，偏离原“直接执行”，见 §9.98）（M-3） | M-3 | §9.98 |
| [S6](unified-search-commands.md#S6) | iCloud 说明 | 打开原页面 | setting.icloud → 设置“iCloud”分节（M-3） | M-3 | §9.98 |
| [S7](unified-search-commands.md#S7) | 快捷键配置 | 打开原页面 | shortcut.record／reset／resetAll／cancel → 快捷键页（M-3） | M-3 | §9.98 |
| [P1](unified-search-commands.md#P1) | 创建私密锁 | 打开原页面 | privacy.create／setupMethod／setupTags／protectExisting → 隐私与解锁页（M-3）；不新增隐私转换执行路径 | M-3 | §9.98 |
| [P2](unified-search-commands.md#P2) | 隐私管理 | 已接正式版（待用户验收）＋打开原页面 | 已：privacy.lock 直接执行（沿“立即锁定”，锁定撤权，M-3）；打开原页面：unlock、systemUnlock、set／change／removePassword、idle、tags → 隐私与解锁页 | M-3 | §9.98 |
| [P3](unified-search-commands.md#P3) | 解除单条手记保护 | 打开原页面 | privacy.unprotect → 隐私与解锁页（M-3） | M-3 | §9.98 |
| [P4](unified-search-commands.md#P4) | 隐私维护重试 | 打开原页面 | privacy.retryImages／retryKeys／quitForCleanup → 隐私与解锁页（M-3） | M-3 | §9.98 |
| [D1](unified-search-commands.md#D1) | 回收站 | 已接正式版（待用户验收）＋打开原页面 | 已：显式回收范围的墓碑只读搜索（2H、2K-7）、trash.restore（M-3：与回收站页同一写入 TrashRestoreService，共用独立确认、只能单项，受保护拒绝）；打开原页面：trash.delete、trash.empty → 回收站（定位焦点项）、trash.browse → 回收站页（类别在页面筛选里选，§9.109） | 2H、2K-7、M-3 | §9.43、§9.98 |
| [D2](unified-search-commands.md#D2) | JSON 导出导入 | 打开原页面 | data.export／selectImport／validateImport／previewImport／applyImport → 数据与备份页（M-3）；不新增导入执行路径 | M-3 | §9.98 |
| [D3](unified-search-commands.md#D3) | 加密备份与恢复 | 打开原页面 | backup.export／inspect／preview／restore → 数据与备份页（M-3）；不新增备份恢复执行路径 | M-3 | §9.98 |
| [D4](unified-search-commands.md#D4) | 重置并退出 | 打开原页面 | recovery.status、recovery.resetQuit → 数据与备份页（降级提示就在该页，M-3）；resetQuit 目录仍 unavailable | M-3 | §9.98 |
| [N1](unified-search-commands.md#N1) | 全页面与标签清单导航 | 已接正式版（待用户验收） | 已：16 个 go 入口（N-M1，M-5 已复核）、go.tagList（N-M2，M-5F 整改后已复核） | N-M1、N-M2 | §9.84 |
| [N2](unified-search-commands.md#N2) | 工作台、浮层与面板 | 已接正式版（部分，待用户验收） | 已：workspace.open／reveal／close、overlay.toggle、routine.addPanel／managePanel（沿 AppWindows 与今日页原面板，不新建窗口，M-3）；未：overlay.mode（浮层的任务／手记页没有外部切换入口，只说明） | M-3 | §9.98 |
| [N3](unified-search-commands.md#N3) | 检查器与选择 | 已接正式版（待用户验收） | 已：inspector.open／inspector.day（N-M1，M-5 已复核）、selection.all／clear（M-1，沿页面投影）、inspector.close（沿检查器关闭按钮，先失焦保存，§9.109） | N-M1、M-1 | §9.84、§9.96 |
| [N4](unified-search-commands.md#N4) | 手记小窗 | 已接正式版（待用户验收） | 已：diaryWindow.open（受保护手记拒绝）／draft（不写入，受保护草稿留给原页面）／pinned／close（沿小窗原有确认）（M-3）；diaryWindow.save（复用小窗会话保存，受保护会话只前置小窗，M-4） | M-3、M-4 | §9.98、§9.99 |
| [N5](unified-search-commands.md#N5) | 总览统计 | 已接正式版（待用户验收） | 已：stats.* 八项只读（DashboardStatsReader，与总览页同一投影，私密手记口径不变）、stats.openDay、活动行打开（沿总览路由；搜索里没有活动对象，stats.openActivity 指向 stats.activity 的列表）（M-3） | M-3 | §9.98 |
| [N6](unified-search-commands.md#N6) | 帮助与示例 | 打开原页面 | help.syntax（语法帮助卡）、help.page（来时页面的说明）、help.example（只预填示例到搜索框，不执行）（M-3） | M-3 | §9.98 |
| [N7](unified-search-commands.md#N7) | 版本、反馈与链接 | 打开原页面 | support.* 七条 → 设置“版本／支持／关于”分节；不在指令里打开外部网址（M-3） | M-3 | §9.98 |
| [N8](unified-search-commands.md#N8) | 退出与未保存确认 | 已接正式版（待用户验收） | 已：app.quit 走 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记），同意后才调注入的 terminate；QA 中为 fake（M-3） | M-3 | §9.98 |

合计 48 项：隔离实现 20（T1～T8、S1、N1、N3、N4、N5、N8、B1～B3、C1、C2、C6）；隔离实现且已复核 1（T10）；隔离实现（部分）3（T9、G1、N2）；隔离实现＋打开原页面 9（G2、A1、C3、S4、P2、D1、J1～J3）；打开原页面 15（C4、C5、S2、S3、S5、S6、S7、P1、P3、P4、D2、D3、D4、N6、N7）；待核实 0；未开始 0；已接正式版 0（M-1 A 的原界面私密标签修复属正式版行为修复，不计入指令接线）。

## 未闭合缺口

合并去重自各交接节，每条附来源；关闭某条时只改本节对应行。

- **M-7 与旧版不同的六项**（2026-10-28 用户决定）：
  - **已恢复**（修复批 M-7F，§9.107）：正式版检查器标题／子任务／备注失焦即保存（隔离宿主仍沿 N-M1 只留草稿）；`#`／`!`／`@` 候选（`#` 只列已有标签）；菜单栏任务筛选缩小搜索结果、底栏胶囊可单个移除。
  - **保持现状，用户决定**：不带 `@` 的裸时刻不当提醒条件（需写 `@09:30`）；结果上空格不切换完成（完成走指令）；Esc 关候选后焦点留在输入框、不清空查询。
  - M-7F 遗留：菜单栏手记页签的标签筛选不作用于搜索结果（菜单栏搜索页面固定为今日任务，胶囊只在任务页签显示）；页面筛选与查询的其余双向同步（工作台页面、页内搜索合并）仍属阶段 4 未做部分。来源：§9.106、§9.107。
- **指定只读复核**：G-1a 已关闭 T-M1～T-M3 的复核缺口；X-1、T-M6、L-M1b、合并批 M-1～M-4 已通过（见各自交接）；合并批 M-5 关闭 R-M1～R-M3、B-M1、B-M2、P-M1～P-M3、N-M1、C-M1 的复核缺口；N-M2、C-M2 经修复批次 M-5F 整改后通过，缺口关闭（§9.101）；其余里程碑（2*、4A、3A、3T、T-M4、T-M5）仍未经指定复核。来源：§9.100。来源：§9.89、§9.91。
- **正常签名构建**：正常开发描述文件曾于 2026-10-07、2026-10-22 到期，各里程碑的正常 Debug 证据因此 partial；当前描述文件 2026-11-04 10:35 UTC 到期（`security cms -D -i` 读内嵌描述文件，2026-10-29），到期后正常构建记为阻塞，不续签、不改个人签名配置。M-4 集中验证时正常构建在签名核验失败（Widget 内嵌描述文件签名后被替换），记为阻塞。来源：§9.75、§9.89。
- **人工与平台验收**：真人输入法、VoiceOver、最低支持系统、真实多窗口、原生截图逐类查看均未做。来源：§9.85、§9.89。
- **C2B 原生接受与锁定交错**：敏感输入不开放，mutable textStorage 只能事后检测。来源：§9.52、§9.86。
- **生产接线授权**：已关闭（合并批 M-6，2026-10-22 用户授权）。唯一装配点接真实依赖；提醒授权、日历／小组件刷新、剪贴板、粘贴、窗口与退出只在执行对应指令后调用。来源：§9.103。
- **用户验收待办（M-6 新增，2026-10-29 更新）**：旧搜索已删除，**没有退回旧搜索的办法**。2026-10-29 用户确认替换前全量回归（Z-2）视为完成，日常应用已替换；仓库里没有 Z-2 的提交，明细（通过数、耗时、失败分类）未入库。日用版按 M-6 报告的验收清单逐域试用仍由用户进行；真实库、真实附件目录、真实钥匙串与真实系统授权均未在执行会话里验证。来源：§9.103。
- **大库读取卡顿**：已修复（修复批 M-6R 检查点 B）。逐条正文读取改为 O(1) 复查、整表事实只在读取边界与发布前全量确认；同一合成库输入到首批结果约 216 秒降到约 2 秒，500 篇手记约 30 秒降到约 0.4 秒。仍在主线程同步读取。来源：§9.104。
- **全量测试**：Z-2 按用户 2026-10-29 确认视为完成，明细未入库；此后各批只跑定向测试。M-6R 检查点 C 的定性仍有效：35 类在 d77da2e 与当前 HEAD 逐条对照，没有 M-6 引入的失败；两项隐私测试由 0789245 引入，已在读取侧修复；其余既有失败见下节“既有失败”。装配失败的说明 M-6R 放在设置“搜索”分节，M-7 起改在两宿主搜索框里。来源：§9.104。
- **M-7G 目录级核对**：已关闭（§9.109）。247 条指令（除分组、范围）：工作台可执行 160、打开原页面 86、目录不可用 1、未接上 0；菜单栏可执行 64、在工作台完成 178、目录不可用 5、未接上 0。唯一判断入口仍是 `UnifiedSearchController.disposition(for:)`。锁定后再打字两宿主都由显式动作经宿主可信页面重建，不再需要重新进入页面或重新装配。
- **菜单栏限制（M-6）**：导航、打开原页面与页面指令已改为“在工作台完成”（§9.109）：Return 显示工作台，同一文字交给工作台按它自己的 Return 路径执行；工作台有未完成草稿或待执行列表时不转交，工作台显示被挡说明。仍有：打开结果时工作台查询的页面上下文不同可能找不到同一对象（只停在结果页）。来源：§9.103。
- **长文受控借用**：已实现，M-6 起接正式版（托管订阅装配事件中心即 default 上的保险箱锁定、隐私变化与遮罩；装配销毁时 discard）。L-M1b 按 §9.94 与 2026-10-20 用户确认实现托管、一次性借用与带键摘要，接通 todo.notes／routine.notes／routine.capture；守卫改按目录类型判定，clear 漏口已复现并堵上。只开放普通长文（受保护、required、unknown 仍拒）；（历史：M-6 之前默认未装配、托管只听隔离环境私有事件中心，M-6 已转接。）来源：§9.95。
- **原界面备注私密标签缺口**：已修复（合并批 M-1 检查点 A）。任务、子任务、习惯一侧从文字解析标签时照常保存文字，跳过私密与预设标签并提示；判定与指令侧 L7 共用 `InputTagResolver.protection`，差别只在结果（指令整条拒绝）；手记一侧不变。来源：§9.96。
- **正文与受保护内容**：普通手记正文保存已在隔离环境实现（M-4，§9.99）；受保护手记的写入、复制与转换只打开原页面；受保护内容查阅与敏感执行／转交不开放。来源：§9.85、§9.88。
- **有备注对象资格**：M-1 B 已把 11 处适配改为自读备注取带键摘要，并放宽字段类、回收、转换、复制；仍未放宽：todo.title／subtask.title（`//` 派生备注另行定界）、完成、建标签、子任务与习惯字段类、删子任务时的父待办。来源：§9.96。
- **已知历史问题**：T-M1 标题多目标面板消失的根因未判定；DetailSubtaskCompletionTests 两项 Expected Failure 保留；原生日期格按钮在统一搜索测试宿主里找不到标识（`nativeBooleanWeekdaysDayAndTime` 等）；`SubtaskModelTests.addTagSkipsDiaryPresetNames` 在未改动 HEAD 上同样失败。来源：§9.73、§9.89。
- **工作台操作面板鼠标点击**：M-1 原生用例中，合成鼠标事件到不了工作台窗口操作面板里的按钮（缓冲版本与输入焦点均不变，原因未判定），改用 AXPress 验证同一按钮；真实鼠标点击未验证。来源：§9.96。
- **G-1a 低级整改清单 9 条**：待单独批准的修复批次。
- **M-5 整改清单 9 条**（全部关闭）：两条中级（N-M2 附件回退共享目录、C-M2 URL 打开不分分支）与第 5 条测试缺口已由修复批次 M-5F 关闭（§9.101）；其余六条低级（第 3、4、6～9 条）已由合并批 M-6 检查点 A 关闭：第 3 条定为既有行为并在 §9.76 末尾加注说明理由，第 4 条加注，第 6～8 条补直接测试 `MultiPlanRevisionGateTests`，第 9 条把 `RoutineCreateBoundaryTests` 断言细化到 dateChanged／sortChanged。M-5F 另登记的一条后续（隔离宿主附件选图／粘贴写入与回收站清除仍走共享目录）已由修复批次 M-5G 处理（§9.102）；M-5G 新登记后续：隔离宿主中 @附件 关联（会改写共享池索引）、手记卡片“取消保护”、输入联想读共享池仍走共享目录。来源：§9.100。
- **目录未决项**：tag.cleanup（预置标签范围）、backup.export（无锁可达性）等仍未定稿；diary.tags 已按 M-4 决策 2 解决；习惯 skip 语义已由 R-M3 的 D1 处理；tag.merge 已按决策 3、quadrant.complete 已按 R-M3 语义在 M-2 解决。来源：§9.6、§9.78、§9.97。
- **留给 M-3 打开原页面**：已关闭（合并批 M-3 A）。tag.delete／cleanup、clipboard.delete／prune／empty、C4、C5、image.pick／paste／capture 与 S2、S3、S5～S7、P1～P4（除 privacy.lock）、D1 永久删除、D2～D4、N6、N7 都只导航到原页面，对照唯一在 CommandOriginalPage。来源：§9.98。
- **M-3 偏离与限制**：calendarSync.openLocal 改为打开设置“系统日历”分节（搜索里没有冲突对象来源）；C5 指向剪贴板页的“剪贴板选项”（设置页没有剪贴板分节）；分节只在说明里指明，页面不自动滚动；overlay.mode 只说明（浮层切页没有外部入口）；stats.openActivity 没有活动对象来源，改在 stats.activity 的列表里打开；diaryWindow.save 已在 M-4 接通。来源：§9.98。
- **M-3 生产接线前置**：WorkspaceSystemCommands 的工作台显示／关闭、浮层开关、手记小窗管理、退出确认与 terminate、保险箱，以及 trash.restore 规格装配都只在隔离夹具里注入；接正式版需逐项授权（真实 AppWindows／StatusItemController／DiaryWindows.shared／NSApp.terminate）。来源：§9.98。 M-6 已接：真实 AppWindows／StatusItemController／DiaryWindows.shared；退出走 AppDelegate 原确认（`confirmTerminationForCommand`），trash.restore 规格已装配。
- **M-2 生产接线前置**：剪贴板粘贴的真实辅助功能权限与 ⌘V、小窗真实窗口适配（读共享会话）、手记解绑标签的保险箱、附件存储根均只在隔离夹具里注入；image.preview 只能打开当前结果里可见的普通图片。来源：§9.97。 M-6 已接：页面宿主、剪贴板历史复制／粘贴（粘贴到其他应用仍需辅助功能权限，只在执行时询问）、手记仓储的真实保险箱与共享附件根。
- **M-4 限制与生产接线前置**：diary.save／reload／discard 只作用于已打开的小窗会话（手记页卡片的编辑会话是页面私有状态，宿主没有入口）；有未保存内容的重载只前置小窗由用户确认；手记规格、页面宿主的手记会话与剪贴板依赖只在隔离夹具里注入，接正式版需逐项授权。来源：§9.99。 M-6 已接手记规格、页面宿主与托管的真实隐私锁事件；diary.save／reload／discard 只作用于已打开小窗的限制不变。
- **现状差距**：备份未配置锁的可达性、剪贴板历史读取失败返回空、重置吞掉删除错误。来源：[§9.4](unified-search-commands.md#94-未决问题与单独授权边界)。
- **性能基线**：新查询延迟、长文编辑、最大候选规模与内存均未建立基线。来源：[§9.3](unified-search-commands.md#93-后续回归入口与证据缺口)。

## 既有失败

修复批 M-6R 检查点 C 定性，逐条登记在 [`scripts/known_test_failures.json`](../scripts/known_test_failures.json)（门禁只改变归类，测试照常运行）。现存 32 条，首次复现提交都是 d77da2e（M-6 之前的基线，未再向前二分）：CalendarSpanConsumerTests（3）、CalendarWeekConsumerTests、CalendarWeekLayoutTests（2）、DashboardScrollTests、DaybookScrollNativeTests、DiaryTitleHoverTests（2）、MenuBarHelpSurfaceTests、MenuBarStatusImageTests、PasswordRetryDiagnosticTests（2，诊断型）、PrivacyAutolockPickerTests（2）、PrivacyButtonConsumerTests、ScrollAssemblyConsumerTests、SearchMultilineDiagnosticTests、UnifiedSearchOperationInteractionTests、UnifiedSearchSettingInteractionTests、WeekdayConsumerBaselineTests、WorkspaceInspectorSizingTests（2）、WorkspaceMenuConsumerTests、WorkspaceRenderingTests、YesterdayCardActionTests（3）、YesterdayCardConsumerTests（3）。

- 0789245 引起的 7 条原界面隐私失败已随 2026-10-23 用户决定恢复原规则而修复并移出登记表，见 §9.105。
- 焦点前置失败（拿不到 key window）在桌面空闲重跑后通过的不登记；TagHelpSurfaceConsumerTests 两项基线失败、当前通过；DashboardRenderingTests 的 segv 两次对照都未复现。

## 补复核待办

- **仍待复核**：T-M4（复制与回收）、T-M5（待办与重复事项互转）的指定复核尚未安排。
- **已复核通过**（Claude Code `verifier`，不通过的轮次都已整改并再复核）：X-1、L-M1b、T-M6、G-1a（T-M1～T-M3）、合并批 M-1～M-6（M-5 覆盖 R、B、P、N、C 系列）、修复批 M-5F、M-5G、M-6R、收尾批 M-7、修复批 M-7F、统一搜索收口（2026-10-29）。各轮结论与记录在案的低级意见见对应提交说明和权威设计的历史交接记录。

## 每批最少必读

执行一个批次时，按下面顺序读，读够即停；主文档已移出逐批交接，篇幅约 330 行，仍只读相关段落。

1. 本总览全文。
2. 主文档 §8 中本批涉及的行：用行首锚点定位，例如 `grep -n 'id="G1"' docs/unified-search-commands.md`。
3. 主文档 §1～§6 中与本批相关的规则小节。
4. 主文档 §9 的“仍有效的决定”中本域条目；需要追溯某个历史节时按“历史交接记录”给出的 `git show` 查看。
5. 涉及未决项时读 [§9.4](unified-search-commands.md#94-未决问题与单独授权边界)；涉及目录 ID 时，以 `CommandCatalog` 源码和 §8 映射为准。
6. [技能路由](../skill-routing.md)的“指定只读复核入口”与“路由维护”，[组件目录](component-catalog.md)中本域条目；新简单修改指令先看组件目录的“简单指令共用骨架”。

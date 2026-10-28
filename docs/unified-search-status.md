# 统一搜索现状总览

本文是统一搜索与指令体系的**现状总览**：只记当前状态、覆盖、缺口和每批必读入口。设计、规则与历史证据仍以[权威设计](unified-search-commands.md)为准，本文不复制。每批怎样更新本文见[技能路由的路由维护](../skill-routing.md#路由维护)。

最后更新：2026-10-28，修复批 M-7F 恢复三处旧行为（[§9.107](unified-search-commands.md#9107-修复批-m-7f恢复三处旧行为)）；2026-10-23，收尾批 M-7 删除旧全局搜索（[§9.106](unified-search-commands.md#9106-收尾批-m-7删除旧全局搜索)）；恢复原界面手记隐私规则（[§9.105](unified-search-commands.md#9105-用户决定恢复原界面手记隐私规则)）；修复批 M-6R 接入前阻断修复（[§9.104](unified-search-commands.md#9104-修复批-m-6r接入前阻断修复)）。

## 目标与阶段

- **目标**：工作台和菜单栏共用一套搜索与指令，覆盖 §8 全部 48 项用户功能；现有按钮、菜单与指令共用业务逻辑（[§1](unified-search-commands.md#1-已确认的产品与查询规则)）。
- **当前方向**（2026-10-18 用户决定；2026-10-22 M-6 决策）：功能已在隔离环境补齐并于 M-6 接入正式版；2026-10-23 用户决定跳过替换前全量回归与真实数据验收，收尾批 M-7 删除旧全局搜索与开关，统一搜索成为唯一入口。
- 阶段划分见 [§9.1](unified-search-commands.md#91-建议的分阶段边界)，当前状态一句话一行：
  - **阶段 1 领域协议**：1A～1D 已实现（目录、解析、查询会话、草稿、计划、转交），仅 1A～1D 自身证据，见 [§9.6](unified-search-commands.md#96-阶段-1a-目录决策与证据)～§9.13。
  - **阶段 2 只读数据**：2A～2J 注入快照提供者与 2K-1～2K-8 SwiftData／文件只读适配已在隔离环境实现；真实宿主的异步调度与生产接线未做，见 [§9.14](unified-search-commands.md#914-阶段-2atodo-只读快照提供者与类型化结果)～[§9.44](unified-search-commands.md#944-阶段-2k-8全来源标签使用统计的只读存储适配与受门禁发布)。
  - **阶段 3 业务动作适配**：进行中；普通设置（3A）、任务／子任务／习惯／批量／转换／标签等指令已在隔离环境逐批实现；系统类、永久删除类与附件系统动作自 M-3 起“打开原页面”。覆盖见下表；手记写入 J1～J3 自 M-4 起只对普通手记直接执行，受保护目标打开原页面，未开始为 0。
  - **阶段 4 共享界面**：已完成：旧全局搜索已删除，统一搜索为唯一入口（M-7，没有开关、没有退路）。唯一装配点 `UnifiedSearchProductionAssembly` 构造工作台与菜单栏两个控制器；装配失败时两宿主搜索框显示不阻塞的说明。保留的页面内筛选：手记页、手记小窗、标签管理、剪贴板历史、附件中心（未与统一搜索合并，留待用户决定）。§9.1 阶段 4 中“删除重复页内搜索、页面筛选与查询双向同步”未做。见 [§9.103](unified-search-commands.md#9103-合并批-m-6接入正式版)、[§9.106](unified-search-commands.md#9106-收尾批-m-7删除旧全局搜索)。
  - 阶段 5～7（队列执行与撤销、独立系统流程、模板与全目录收口）：未开始。

## 功能覆盖表

状态只用：**未开始 / 隔离实现 / 隔离实现且已复核 / 打开原页面 / 已接正式版 / 待核实**；M-6 起“已接正式版”后括注“待用户验收”，直到用户在日用版逐项试过。“打开原页面”（M-3，2026-10-20 用户决策 1、2）指指令只导航到原页面、由原页面完成操作，不在指令里执行，**不算隔离实现**；对照只在 [CommandOriginalPage](../AreaChain/Domain/CommandOriginalPage.swift)。一行内既有隔离实现又有打开原页面的动作时写“隔离实现＋打开原页面”。一行内只有部分动作完成时写“隔离实现（部分）”，并在“已覆盖／未覆盖”列写清哪些动作完成、哪些没有；不把未覆盖动作算作已实现。“已复核”只指按[指定只读复核入口](../skill-routing.md#指定只读复核入口)通过的部分。功能名称见 §8 对应行（ID 链接）。

| ID | 功能 | 状态 | 已覆盖／未覆盖 | 里程碑 | 交接 |
|---|---|---|---|---|---|
| [T1](unified-search-commands.md#T1) | 新建任务、标题、备注 | 已接正式版（待用户验收） | 已：todo.create、todo.title（G-1a 已复核）；todo.notes（L-M1b）；todo.cancelTitle（M-1，去掉宿主保留的标题草稿）；原界面文字里的私密／预设标签不再关联（M-1 A，已接正式版行为） | 3T、T-M1、T-M6、L-M1b、M-1 | [§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T2](unified-search-commands.md#T2) | 完成、改期、提醒、优先级、标签、截止 | 已接正式版（待用户验收） | 已：todo.move／priority／reminder（T-M1）、completion／tags／createTag／due（T-M2），均 G-1a 已复核；todo.cancelCompletion（M-1，复用 0.4 秒反悔窗口）；move／priority／reminder／tags／due 自 M-1 起允许带备注对象 | T-M1、T-M2、M-1 | [§9.74](unified-search-commands.md#974-里程碑-t-m2完成标签与截止时间的隔离闭环)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T3](unified-search-commands.md#T3) | 复制、回收 | 已接正式版（待用户验收） | 已：todo.copy、todo.trash；M-1 起带备注对象可复制、可回收（确认面板说明备注随对象进回收站）；未复核 | T-M4、M-1 | [§9.90](unified-search-commands.md#990-里程碑-t-m4复制与回收)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T4](unified-search-commands.md#T4) | 子任务 | 已接正式版（待用户验收） | 已：subtask.create／title／completion／tags（T-M3，G-1a 已复核）、subtask.delete（T-M4）、subtask.order（T-M6）、subtask.cancelTitle（M-1）；父待办带备注仍拒绝 | T-M3、T-M4、T-M6、M-1 | [§9.75](unified-search-commands.md#975-里程碑-t-m3普通子任务的隔离闭环)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T5](unified-search-commands.md#T5) | 重复事项定义 | 已接正式版（待用户验收） | 已：routine.title／weekdays／reminder／priority／tags（R-M1）、routine.create（R-M2）、routine.enabled（R-M3）、routine.trash（T-M4）、routine.order（T-M6）、routine.capture／routine.notes（T-M6 规格，L-M1b 经长文受控借用执行）；title／weekdays／reminder／priority／tags、create、enabled 已复核（M-5，R-M1～R-M3 通过） | R-M1～R-M3、T-M4、T-M6、L-M1b | [§9.76](unified-search-commands.md#976-里程碑-r-m1习惯定义五字段的隔离闭环)、[§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现) |
| [T6](unified-search-commands.md#T6) | 指定日完成／撤回／跳过、检查日、连击 | 已接正式版（待用户验收） | 已：occurrence.complete／skip／reopen（R-M3，M-5 已复核）、inspector.day 定位（N-M1，M-5 已复核）、routine.streak（M-1，复用 HabitStreakLogic，只读） | R-M3、N-M1、M-1 | [§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T7](unified-search-commands.md#T7) | 批量任务／习惯 | 已接正式版（待用户验收） | 已：batch.move／tags（B-M1，M-1 起允许带备注）、batch.completion／enabled（B-M2），均 M-5 已复核、batch.trash（T-M4，M-1 起允许带备注）、selection.clear（M-1） | B-M1、B-M2、T-M4、M-1 | [§9.79](unified-search-commands.md#979-里程碑-b-m1固定多目标改期与混合标签共同提交)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T8](unified-search-commands.md#T8) | 待办↔重复事项转换 | 已接正式版（待用户验收） | 已：todo.toRoutine、routine.toTodo；M-1 起带备注对象可转换（损失清单列出“备注原样搬到新对象”）；未复核 | T-M5、M-1 | [§9.91](unified-search-commands.md#991-里程碑-t-m5待办与重复事项互转)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T9](unified-search-commands.md#T9) | 页面筛选、全部事项、排序、延至今日 | 已接正式版（部分，待用户验收） | 已：tasks.order、tasks.postponeYesterday（T-M6）；tasks.filter／clearFilter（今日／待处理／全部事项，与页面双向同步）、tasks.kind／status、tasks.sections（昨天／即将）、tasks.select（待处理／全部事项）（M-1）；未：今日区收起（始终展开）、今日页与标签清单的多选指令 | 2A～2J、4A、T-M6、M-1 | [§9.93](unified-search-commands.md#993-里程碑-t-m6任务类修改收尾)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T10](unified-search-commands.md#T10) | 剪贴板加今天 | 已接正式版（已复核，待用户验收） | 已：capture.clipboard（T-M6，无 Run 模式，提交才读剪贴板；T-M6 指定复核通过）；M-1 起读到私密／预置标签整条不写并说明（L7），菜单栏入口跳过标签照常保存 | T-M6 | [§9.93](unified-search-commands.md#993-里程碑-t-m6任务类修改收尾) |
| [B1](unified-search-commands.md#B1) | 日历导航与改期 | 已接正式版（待用户验收） | 已：calendar.mode／step／today／day／dayList（页面指令，月周与选中日写页面那一份）、calendar.create（转交 todo.create）；拖拽改期沿 todo.move（T-M1）。核实：原组合只覆盖导航与改期，页面动作在 M-2 补齐；calendar.step 只留 offset，月周跟随当前视图 | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [B2](unified-search-commands.md#B2) | 四象限 | 已接正式版（待用户验收） | 已：quadrant.day／step／inspect（页面指令）、create／priority／complete／copy（转交 todo.create／todo.priority 或 routine.priority／todo.completion 或 occurrence.complete／todo.copy 标题段）；quadrant.complete 的 1A 未决（习惯 skip 语义）已由 R-M3 D1 定，M-2 解决；copy 不接习惯 | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [B3](unified-search-commands.md#B3) | 安排页平移与完成 | 已接正式版（待用户验收） | 已：gantt.step／currentMonth／select／inspect（页面指令）、gantt.shift（X-1 骨架，GanttRescheduleService，一次事务、保留间隔、越出当月拒绝）、gantt.complete（转交 batch.completion） | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [J1](unified-search-commands.md#J1) | 手记新建与正文 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.create（快速新增的自动分类）、diary.body replace／append（L-M1b 借用，手记出口；clear 按目录静态拒绝）、diary.save／reload／discard（只作用于已打开的小窗会话）、diary.tags（见 J2）；打开原页面：受保护或保存后会变成受保护、加私密标签、超过 64KiB 的已有正文 → 手记页（M-4） | C-M1～C-M3、M-4 | [§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入) |
| [J2](unified-search-commands.md#J2) | 手记组织 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.pinned、diary.move、diary.tags（普通标签加减／替换／清空；加私密标签拒绝，privateTagTransition 已解决）；打开原页面：diary.privateMark／reveal／mask 与受保护手记 → 手记页（M-4） | M-4 | [§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入) |
| [J3](unified-search-commands.md#J3) | 手记复制、转任务、回收 | 已接正式版（待用户验收）＋打开原页面 | 已：diary.copy（整篇／标题／备注，PrivateClipboard）、diary.toTodo、diary.trash（共用独立确认、只能单项）；打开原页面：受保护手记 → 手记页（M-4） | M-4 | [§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入) |
| [G1](unified-search-commands.md#G1) | 标签新建、改名、颜色、排序、搜索与视图 | 已接正式版（部分，待用户验收） | 已：tag.create／rename／color（X-1）、tag.order（M-1）、tag.cancel、tag.search／view／deleted（M-2，取法即标签页的 TagListQuery）、go.tagList（N-M2）；未：新建时设为私密（需解锁） | X-1、2F、N-M2、T-M6、M-1、M-2 | [§9.92](unified-search-commands.md#992-提速基建-x-1)、[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [G2](unified-search-commands.md#G2) | 标签合并、解绑、软删／恢复、清理 | 已接正式版（待用户验收）＋打开原页面 | 已：tag.merge（决策 3：涉及私密标签整条拒绝）、tag.unlinkObject（受保护手记拒绝）、tag.trash／tag.restore（共用独立确认、只能单项）；打开原页面：tag.delete、tag.cleanup → 标签页（M-3）；tag.unlinkGlobal 目录 unavailable（原界面没有该功能，不算缺口） | M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [A1](unified-search-commands.md#A1) | 图片附件 | 已接正式版（待用户验收）＋打开原页面 | 已：图片元数据只读查询（2E、2K-6）、普通图片查阅（N-M2，M-5F 整改后已复核）、image.browse／image.preview／image.trash（M-2）；打开原页面：image.pick／paste／capture → 焦点对象的详情（手记打开手记页，习惯定义须先选执行日）（M-3） | 2K-6、N-M2、M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C1](unified-search-commands.md#C1) | 剪贴板浏览与搜索 | 已接正式版（待用户验收） | 已：显式 /clipboard 只读提供者与文件只读适配（2G、2K-5）；clipboard.browse／search（M-2，与历史页 visibleItems 同一取法，原生等价验收逐行比对）；默认不进普通搜索不变 | 2G、2K-5、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [C2](unified-search-commands.md#C2) | 剪贴板复制／粘贴 | 已接正式版（待用户验收） | 已：clipboard.copy／paste／pastePlain（ClipboardHistoryActions，写入失败不报成功；QA 中门与按键全为 fake、私有命名剪贴板）；真实辅助功能权限与 ⌘V 未接线 | M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [C3](unified-search-commands.md#C3) | 剪贴板置顶、删除、清空 | 已接正式版（待用户验收）＋打开原页面 | 已：clipboard.pinned、clipboard.copyLetter（M-2）；打开原页面：delete、prune、empty → 剪贴板页（M-3） | M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C4](unified-search-commands.md#C4) | 记录暂停、跳过、忽略来源 | 打开原页面 | clipboard.recording／skipNext／ignoreApp → 剪贴板页（M-3，决策 2） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C5](unified-search-commands.md#C5) | 剪贴板偏好 | 打开原页面 | 全部 13 条（含 add／removePattern、add／removeType、unignoreApp）→ 剪贴板页的“剪贴板选项”（设置页没有剪贴板分节，M-3 核实） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C6](unified-search-commands.md#C6) | 剪贴板小窗 | 已接正式版（待用户验收） | 已：clipboard.openWindow／closeWindow／pinWindow／workspace（沿 ClipboardHistoryPanel 现有窗口管理，只有一个面板）；真实窗口适配读共享会话，生产接线另需授权 | M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [S1](unified-search-commands.md#S1) | 语言、外观、标题省略、捕获来源 | 已接正式版（待用户验收） | 单项与共同提交（聚合文件后端）都在隔离宿主；未复核 | 3A | [§9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线) |
| [S2](unified-search-commands.md#S2) | 登录启动 | 打开原页面 | setting.login、loginSettings → 设置“启动”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S3](unified-search-commands.md#S3) | 通知权限与测试 | 打开原页面 | notification.status／request／test／settings → 设置“通知”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S4](unified-search-commands.md#S4) | 通知完成与延后 | 已接正式版（待用户验收）＋打开原页面 | 已：notification.open 沿 inspector.open 打开对象；complete／snooze 只说明并给出改用 todo.completion／occurrence.complete／todo.reminder 的入口，不另写执行（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S5](unified-search-commands.md#S5) | 日历同步 | 打开原页面 | calendarSync.enabled／status／retry／settings／conflicts → 设置“系统日历”分节；openLocal 也改为打开该分节（搜索里没有冲突对象来源，偏离原“直接执行”，见 §9.98）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S6](unified-search-commands.md#S6) | iCloud 说明 | 打开原页面 | setting.icloud → 设置“iCloud”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S7](unified-search-commands.md#S7) | 快捷键配置 | 打开原页面 | shortcut.record／reset／resetAll／cancel → 快捷键页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P1](unified-search-commands.md#P1) | 创建私密锁 | 打开原页面 | privacy.create／setupMethod／setupTags／protectExisting → 隐私与解锁页（M-3）；不新增隐私转换执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P2](unified-search-commands.md#P2) | 隐私管理 | 已接正式版（待用户验收）＋打开原页面 | 已：privacy.lock 直接执行（沿“立即锁定”，锁定撤权，M-3）；打开原页面：unlock、systemUnlock、set／change／removePassword、idle、tags → 隐私与解锁页 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P3](unified-search-commands.md#P3) | 解除单条手记保护 | 打开原页面 | privacy.unprotect → 隐私与解锁页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P4](unified-search-commands.md#P4) | 隐私维护重试 | 打开原页面 | privacy.retryImages／retryKeys／quitForCleanup → 隐私与解锁页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D1](unified-search-commands.md#D1) | 回收站 | 已接正式版（待用户验收）＋打开原页面 | 已：显式回收范围的墓碑只读搜索（2H、2K-7）、trash.restore（M-3：与回收站页同一写入 TrashRestoreService，共用独立确认、只能单项，受保护拒绝）；打开原页面：trash.delete、trash.empty → 回收站（定位焦点项） | 2H、2K-7、M-3 | [§9.43](unified-search-commands.md#943-阶段-2k-7完整墓碑只读适配与受门禁回收站搜索)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D2](unified-search-commands.md#D2) | JSON 导出导入 | 打开原页面 | data.export／selectImport／validateImport／previewImport／applyImport → 数据与备份页（M-3）；不新增导入执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D3](unified-search-commands.md#D3) | 加密备份与恢复 | 打开原页面 | backup.export／inspect／preview／restore → 数据与备份页（M-3）；不新增备份恢复执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D4](unified-search-commands.md#D4) | 重置并退出 | 打开原页面 | recovery.status、recovery.resetQuit → 数据与备份页（降级提示就在该页，M-3）；resetQuit 目录仍 unavailable | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N1](unified-search-commands.md#N1) | 全页面与标签清单导航 | 已接正式版（待用户验收） | 已：16 个 go 入口（N-M1，M-5 已复核）、go.tagList（N-M2，M-5F 整改后已复核） | N-M1、N-M2 | [§9.84](unified-search-commands.md#984-里程碑-n-m1导航与返回搜索) |
| [N2](unified-search-commands.md#N2) | 工作台、浮层与面板 | 已接正式版（部分，待用户验收） | 已：workspace.open／reveal／close、overlay.toggle、routine.addPanel／managePanel（沿 AppWindows 与今日页原面板，不新建窗口，M-3）；未：overlay.mode（浮层的任务／手记页没有外部切换入口，只说明） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N3](unified-search-commands.md#N3) | 检查器与选择 | 已接正式版（待用户验收） | 已：inspector.open／inspector.day（N-M1，M-5 已复核）、selection.all／clear（M-1，沿页面投影） | N-M1、M-1 | [§9.84](unified-search-commands.md#984-里程碑-n-m1导航与返回搜索)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [N4](unified-search-commands.md#N4) | 手记小窗 | 已接正式版（待用户验收） | 已：diaryWindow.open（受保护手记拒绝）／draft（不写入，受保护草稿留给原页面）／pinned／close（沿小窗原有确认）（M-3）；diaryWindow.save（复用小窗会话保存，受保护会话只前置小窗，M-4） | M-3、M-4 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)、[§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入) |
| [N5](unified-search-commands.md#N5) | 总览统计 | 已接正式版（待用户验收） | 已：stats.* 八项只读（DashboardStatsReader，与总览页同一投影，私密手记口径不变）、stats.openDay、活动行打开（沿总览路由；搜索里没有活动对象，stats.openActivity 指向 stats.activity 的列表）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N6](unified-search-commands.md#N6) | 帮助与示例 | 打开原页面 | help.syntax（语法帮助卡）、help.page（来时页面的说明）、help.example（只预填示例到搜索框，不执行）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N7](unified-search-commands.md#N7) | 版本、反馈与链接 | 打开原页面 | support.* 七条 → 设置“版本／支持／关于”分节；不在指令里打开外部网址（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N8](unified-search-commands.md#N8) | 退出与未保存确认 | 已接正式版（待用户验收） | 已：app.quit 走 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记），同意后才调注入的 terminate；QA 中为 fake（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |

合计 48 项：隔离实现 20（T1～T8、S1、N1、N3、N4、N5、N8、B1～B3、C1、C2、C6）；隔离实现且已复核 1（T10）；隔离实现（部分）3（T9、G1、N2）；隔离实现＋打开原页面 9（G2、A1、C3、S4、P2、D1、J1～J3）；打开原页面 15（C4、C5、S2、S3、S5、S6、S7、P1、P3、P4、D2、D3、D4、N6、N7）；待核实 0；未开始 0；已接正式版 0（M-1 A 的原界面私密标签修复属正式版行为修复，不计入指令接线）。

## 未闭合缺口

合并去重自各交接节，每条附来源；关闭某条时只改本节对应行。

- **M-7 与旧版不同的六项**（2026-10-28 用户决定）：
  - **已恢复**（修复批 M-7F，[§9.107](unified-search-commands.md#9107-修复批-m-7f恢复三处旧行为)）：正式版检查器标题／子任务／备注失焦即保存（隔离宿主仍沿 N-M1 只留草稿）；`#`／`!`／`@` 候选（`#` 只列已有标签）；菜单栏任务筛选缩小搜索结果、底栏胶囊可单个移除。
  - **保持现状，用户决定**：不带 `@` 的裸时刻不当提醒条件（需写 `@09:30`）；结果上空格不切换完成（完成走指令）；Esc 关候选后焦点留在输入框、不清空查询。
  - M-7F 遗留：菜单栏手记页签的标签筛选不作用于搜索结果（菜单栏搜索页面固定为今日任务，胶囊只在任务页签显示）；页面筛选与查询的其余双向同步（工作台页面、页内搜索合并）仍属阶段 4 未做部分。来源：[§9.106](unified-search-commands.md#9106-收尾批-m-7删除旧全局搜索)、[§9.107](unified-search-commands.md#9107-修复批-m-7f恢复三处旧行为)。
- **指定只读复核**：G-1a 已关闭 T-M1～T-M3 的复核缺口；X-1、T-M6、L-M1b、合并批 M-1～M-4 已通过（见各自交接）；合并批 M-5 关闭 R-M1～R-M3、B-M1、B-M2、P-M1～P-M3、N-M1、C-M1 的复核缺口；N-M2、C-M2 经修复批次 M-5F 整改后通过，缺口关闭（[§9.101](unified-search-commands.md#9101-修复批次-m-5fn-m2-与-c-m2-中级整改)）；其余里程碑（2*、4A、3A、3T、T-M4、T-M5）仍未经指定复核。来源：[§9.100](unified-search-commands.md#9100-合并批-m-5补复核-rbpnc-系列)。来源：[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)、[§9.91](unified-search-commands.md#991-里程碑-t-m5待办与重复事项互转)。
- **正常签名构建**：正常开发描述文件曾于 2026-10-07 到期，各里程碑的正常 Debug 证据因此 partial；当前描述文件 2026-10-22 到期，到期后正常构建记为阻塞，不续签、不改个人签名配置。M-4 集中验证时正常构建在签名核验失败（Widget 内嵌描述文件签名后被替换），记为阻塞。来源：[§9.75](unified-search-commands.md#975-里程碑-t-m3普通子任务的隔离闭环)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **人工与平台验收**：真人输入法、VoiceOver、最低支持系统、真实多窗口、原生截图逐类查看均未做。来源：[§9.85](unified-search-commands.md#985-里程碑-n-m2标签导航普通手记全文与普通图片查阅)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **C2B 原生接受与锁定交错**：敏感输入不开放，mutable textStorage 只能事后检测。来源：[§9.52](unified-search-commands.md#952-阶段-4a-3c2b原生接受与锁定交错的隔离可行性)、[§9.86](unified-search-commands.md#986-里程碑-c-m1命令长文原生编辑与受控组合输入)。
- **生产接线授权**：已关闭（合并批 M-6，2026-10-22 用户授权）。唯一装配点接真实依赖；提醒授权、日历／小组件刷新、剪贴板、粘贴、窗口与退出只在执行对应指令后调用。来源：[§9.103](unified-search-commands.md#9103-合并批-m-6接入正式版)。
- **用户验收待办（M-6 新增，M-7 更新）**：按用户 2026-10-23 决定，旧搜索已在验收前删除（M-7），开关一并移除，**没有退回旧搜索的办法**。安装前备份、安装后按 M-6 报告的验收清单逐域试用（含中文输入法、锁定后搜索）；真实库、真实附件目录、真实钥匙串与真实系统授权均未在执行会话里验证。M-6R、§9.105 与 M-7 只跑过定向测试，**M-6R 之后未跑全量**，留给 `--single` 替换前那次 `--profile full`。来源：[§9.103](unified-search-commands.md#9103-合并批-m-6接入正式版)。
- **大库读取卡顿**：已修复（修复批 M-6R 检查点 B）。逐条正文读取改为 O(1) 复查、整表事实只在读取边界与发布前全量确认；同一合成库输入到首批结果约 216 秒降到约 2 秒，500 篇手记约 30 秒降到约 0.4 秒。仍在主线程同步读取。来源：[§9.104](unified-search-commands.md#9104-修复批-m-6r接入前阻断修复)。
- **全量测试未判定失败**：已定性（修复批 M-6R 检查点 C）。35 类在 d77da2e 与当前 HEAD 逐条对照，没有 M-6 引入的失败；两项隐私测试由 0789245 引入，已在读取侧修复；其余既有失败见下节“既有失败”。装配失败的说明 M-6R 放在设置“搜索”分节，M-7 起改在两宿主搜索框里。来源：[§9.104](unified-search-commands.md#9104-修复批-m-6r接入前阻断修复)。
- **菜单栏限制（M-6）**：菜单栏控制器没有工作台路由与页面指令；打开结果时先显示工作台，再用同一查询在工作台读取并打开同一对象（页面上下文不同可能找不到，只停在结果页）。导航类与页面类指令请在工作台执行。来源：[§9.103](unified-search-commands.md#9103-合并批-m-6接入正式版)。
- **长文受控借用**：已实现，M-6 起接正式版（托管订阅装配事件中心即 default 上的保险箱锁定、隐私变化与遮罩；装配销毁时 discard）。L-M1b 按 §9.94 与 2026-10-20 用户确认实现托管、一次性借用与带键摘要，接通 todo.notes／routine.notes／routine.capture；守卫改按目录类型判定，clear 漏口已复现并堵上。只开放普通长文（受保护、required、unknown 仍拒）；（历史：M-6 之前默认未装配、托管只听隔离环境私有事件中心，M-6 已转接。）来源：[§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)。
- **原界面备注私密标签缺口**：已修复（合并批 M-1 检查点 A）。任务、子任务、习惯一侧从文字解析标签时照常保存文字，跳过私密与预设标签并提示；判定与指令侧 L7 共用 `InputTagResolver.protection`，差别只在结果（指令整条拒绝）；手记一侧不变。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **正文与受保护内容**：普通手记正文保存已在隔离环境实现（M-4，[§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入)）；受保护手记的写入、复制与转换只打开原页面；受保护内容查阅与敏感执行／转交不开放。来源：[§9.85](unified-search-commands.md#985-里程碑-n-m2标签导航普通手记全文与普通图片查阅)、[§9.88](unified-search-commands.md#988-里程碑-c-m3长文上限与超限引导)。
- **有备注对象资格**：M-1 B 已把 11 处适配改为自读备注取带键摘要，并放宽字段类、回收、转换、复制；仍未放宽：todo.title／subtask.title（`//` 派生备注另行定界）、完成、建标签、子任务与习惯字段类、删子任务时的父待办。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **已知历史问题**：T-M1 标题多目标面板消失的根因未判定；DetailSubtaskCompletionTests 两项 Expected Failure 保留；原生日期格按钮在统一搜索测试宿主里找不到标识（`nativeBooleanWeekdaysDayAndTime` 等）；`SubtaskModelTests.addTagSkipsDiaryPresetNames` 在未改动 HEAD 上同样失败。来源：[§9.73](unified-search-commands.md#973-里程碑-t-m1普通任务修改与受限依赖执行)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **工作台操作面板鼠标点击**：M-1 原生用例中，合成鼠标事件到不了工作台窗口操作面板里的按钮（缓冲版本与输入焦点均不变，原因未判定），改用 AXPress 验证同一按钮；真实鼠标点击未验证。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **G-1a 低级整改清单 9 条**：待单独批准的修复批次。
- **M-5 整改清单 9 条**（全部关闭）：两条中级（N-M2 附件回退共享目录、C-M2 URL 打开不分分支）与第 5 条测试缺口已由修复批次 M-5F 关闭（[§9.101](unified-search-commands.md#9101-修复批次-m-5fn-m2-与-c-m2-中级整改)）；其余六条低级（第 3、4、6～9 条）已由合并批 M-6 检查点 A 关闭：第 3 条定为既有行为并在 §9.76 末尾加注说明理由，第 4 条加注，第 6～8 条补直接测试 `MultiPlanRevisionGateTests`，第 9 条把 `RoutineCreateBoundaryTests` 断言细化到 dateChanged／sortChanged。M-5F 另登记的一条后续（隔离宿主附件选图／粘贴写入与回收站清除仍走共享目录）已由修复批次 M-5G 处理（[§9.102](unified-search-commands.md#9102-修复批次-m-5g隔离宿主附件写入与删除不落共享目录)）；M-5G 新登记后续：隔离宿主中 @附件 关联（会改写共享池索引）、手记卡片“取消保护”、输入联想读共享池仍走共享目录。来源：[§9.100](unified-search-commands.md#9100-合并批-m-5补复核-rbpnc-系列)。
- **目录未决项**：tag.cleanup（预置标签范围）、backup.export（无锁可达性）等仍未定稿；diary.tags 已按 M-4 决策 2 解决；习惯 skip 语义已由 R-M3 的 D1 处理；tag.merge 已按决策 3、quadrant.complete 已按 R-M3 语义在 M-2 解决。来源：[§9.6](unified-search-commands.md#96-阶段-1a-目录决策与证据)、[§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。
- **留给 M-3 打开原页面**：已关闭（合并批 M-3 A）。tag.delete／cleanup、clipboard.delete／prune／empty、C4、C5、image.pick／paste／capture 与 S2、S3、S5～S7、P1～P4（除 privacy.lock）、D1 永久删除、D2～D4、N6、N7 都只导航到原页面，对照唯一在 CommandOriginalPage。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- **M-3 偏离与限制**：calendarSync.openLocal 改为打开设置“系统日历”分节（搜索里没有冲突对象来源）；C5 指向剪贴板页的“剪贴板选项”（设置页没有剪贴板分节）；分节只在说明里指明，页面不自动滚动；overlay.mode 只说明（浮层切页没有外部入口）；stats.openActivity 没有活动对象来源，改在 stats.activity 的列表里打开；diaryWindow.save 已在 M-4 接通。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- **M-3 生产接线前置**：WorkspaceSystemCommands 的工作台显示／关闭、浮层开关、手记小窗管理、退出确认与 terminate、保险箱，以及 trash.restore 规格装配都只在隔离夹具里注入；接正式版需逐项授权（真实 AppWindows／StatusItemController／DiaryWindows.shared／NSApp.terminate）。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。 M-6 已接：真实 AppWindows／StatusItemController／DiaryWindows.shared；退出走 AppDelegate 原确认（`confirmTerminationForCommand`），trash.restore 规格已装配。
- **M-2 生产接线前置**：剪贴板粘贴的真实辅助功能权限与 ⌘V、小窗真实窗口适配（读共享会话）、手记解绑标签的保险箱、附件存储根均只在隔离夹具里注入；image.preview 只能打开当前结果里可见的普通图片。来源：[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。 M-6 已接：页面宿主、剪贴板历史复制／粘贴（粘贴到其他应用仍需辅助功能权限，只在执行时询问）、手记仓储的真实保险箱与共享附件根。
- **M-4 限制与生产接线前置**：diary.save／reload／discard 只作用于已打开的小窗会话（手记页卡片的编辑会话是页面私有状态，宿主没有入口）；有未保存内容的重载只前置小窗由用户确认；手记规格、页面宿主的手记会话与剪贴板依赖只在隔离夹具里注入，接正式版需逐项授权。来源：[§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入)。 M-6 已接手记规格、页面宿主与托管的真实隐私锁事件；diary.save／reload／discard 只作用于已打开小窗的限制不变。
- **现状差距**：备份未配置锁的可达性、剪贴板历史读取失败返回空、重置吞掉删除错误。来源：[§9.4](unified-search-commands.md#94-未决问题与单独授权边界)。
- **性能基线**：新查询延迟、长文编辑、最大候选规模与内存均未建立基线。来源：[§9.3](unified-search-commands.md#93-后续回归入口与证据缺口)。

## 既有失败

修复批 M-6R 检查点 C 定性，逐条登记在 [`scripts/known_test_failures.json`](../scripts/known_test_failures.json)（门禁只改变归类，测试照常运行）。现存 33 条，首次复现提交都是 d77da2e（M-6 之前的基线，未再向前二分）：CalendarSpanConsumerTests（3）、CalendarWeekConsumerTests、CalendarWeekLayoutTests（2）、DashboardScrollTests、DaybookScrollNativeTests、DiaryTitleHoverTests（2）、MenuBarHelpSurfaceTests、MenuBarPopoverRenderingTests.popoutButton…、MenuBarStatusImageTests、PasswordRetryDiagnosticTests（2，诊断型）、PrivacyAutolockPickerTests（2）、PrivacyButtonConsumerTests、ScrollAssemblyConsumerTests、SearchMultilineDiagnosticTests、UnifiedSearchOperationInteractionTests、UnifiedSearchSettingInteractionTests、WeekdayConsumerBaselineTests、WorkspaceInspectorSizingTests（2）、WorkspaceMenuConsumerTests、WorkspaceRenderingTests、YesterdayCardActionTests（3）、YesterdayCardConsumerTests（3）。

- 0789245 引起的 7 条原界面隐私失败已随 2026-10-23 用户决定恢复原规则而修复并移出登记表，见 [§9.105](unified-search-commands.md#9105-用户决定恢复原界面手记隐私规则)。
- 焦点前置失败（拿不到 key window）在桌面空闲重跑后通过的不登记；TagHelpSurfaceConsumerTests 两项基线失败、当前通过；DashboardRenderingTests 的 segv 两次对照都未复现。

## 补复核待办

- **修复批 M-7F**（2026-10-28）：Claude Code `verifier` 复核结论见 [§9.107](unified-search-commands.md#9107-修复批-m-7f恢复三处旧行为)。
- **收尾批 M-7**（2026-10-23～28）：Claude Code `verifier` 第一轮不通过（6 条整改），整改后第二轮**通过**（2 条低级意见已记录），见 [§9.106](unified-search-commands.md#9106-收尾批-m-7删除旧全局搜索)。
- **修复批 M-6R**（2026-10-23）：Claude Code `verifier` 复核**通过**（4 条低级意见已记录），见 [§9.104](unified-search-commands.md#9104-修复批-m-6r接入前阻断修复)。
- **G-1a**（T-M1～T-M3）：已完成，三份结论均“通过”，见 [§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **合并批 M-6**（2026-10-22～23）：Claude Code `verifier` 第一轮不通过（文档缺口），整改后第二轮通过；代码各项第一轮即符合。全量未判定失败仍是缺口，见[§9.103](unified-search-commands.md#9103-合并批-m-6接入正式版)。
- **合并批 M-5**（原 G-1b～G-1e，2026-10-22）：
  - [x] R 组（R-M1～R-M3）：三份结论均“通过”，见 §9.76～§9.78 的 M-5 段。
  - [x] B+P1 组（B-M1、B-M2、P-M1）：三份结论均“通过”（多项计划 P-M1 不对应单独功能行），见 §9.79～§9.81 的 M-5 段。
  - [x] P+N1 组（P-M2、P-M3、N-M1）：三份结论均“通过”，首轮原生焦点失败经重跑判为环境原因，见 §9.82～§9.84 的 M-5 段。
  - [x] N2+C 组（N-M2、C-M1、C-M2）：C-M1“通过”；N-M2、C-M2“不通过”（各一条中级），见 §9.85～§9.87 的 M-5 段。
- **修复批次 M-5G**（2026-10-22）：隔离宿主附件写入与删除改走宿主注入存储、无存储时禁用，指定复核“通过”，见 [§9.102](unified-search-commands.md#9102-修复批次-m-5g隔离宿主附件写入与删除不落共享目录)。
- **修复批次 M-5F**（2026-10-22）：N-M2、C-M2 整改后指定复核“通过”（N-M2 第一轮不通过、修复后第二轮通过），见 [§9.101](unified-search-commands.md#9101-修复批次-m-5fn-m2-与-c-m2-中级整改) 与 §9.85、§9.87 末尾的 M-5F 段。
- **G-1b～G-1e**：已由合并批 M-5 执行（见上）。原定挪到接入正式版之前执行。提示词原放在被忽略的 `build/prompts/`，该目录后被清理；2026-10-19 已按同一模板重新生成到被忽略的 `.agents/prompts/`：G-1b（R-M1～R-M3）、G-1c（B-M1、B-M2、P-M1）、G-1d（P-M2、P-M3、N-M1）、G-1e（N-M2、C-M1、C-M2）。
- L-M1b：指定复核第二轮通过，见 [§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)。
- 合并批 M-1：指定复核第二轮通过，见 [§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- 合并批 M-2：指定复核通过（两条低级意见已整改），见 [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。
- 合并批 M-3：指定复核通过（三条低级意见已整改），见 [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- 合并批 M-4：指定复核通过（三条低级意见记录在案、未改代码），见 [§9.99](unified-search-commands.md#999-合并批-m-4普通手记写入)。
- T-M4、T-M5 的指定复核另需安排；X-1 已复核通过，见 [§9.92](unified-search-commands.md#992-提速基建-x-1)；T-M6 已复核通过，见 [§9.93](unified-search-commands.md#993-里程碑-t-m6任务类修改收尾)。

## 每批最少必读

执行一个批次时，按下面顺序读，读够即停；不要整篇读主文档（约 1.5MB）。

1. 本总览全文。
2. 主文档 §8 中本批涉及的行：用行首锚点定位，例如 `grep -n 'id="G1"' docs/unified-search-commands.md`。
3. 主文档 §1～§5 中与本批相关的规则小节（约第 44–190 行，只读相关段落）。
4. 本批所在业务域最近一个交接节的“规则”和“未覆盖”两段；用 `grep -n '^### 9\.' docs/unified-search-commands.md` 定位。
5. 涉及未决项时读 [§9.4](unified-search-commands.md#94-未决问题与单独授权边界)；涉及目录 ID 时读 [§9.6](unified-search-commands.md#96-阶段-1a-目录决策与证据) 的命名与未决声明段。
6. [技能路由](../skill-routing.md)的“指定只读复核入口”与“路由维护”，[组件目录](component-catalog.md)中本域条目；新简单修改指令先看组件目录的“简单指令共用骨架（X-1）”。

不必读：§9.5～§9.72 的阶段证据和长日志，除非本批要改它们定义的接口。

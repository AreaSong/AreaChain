# 统一搜索现状总览

本文是统一搜索与指令体系的**现状总览**：只记当前状态、覆盖、缺口和每批必读入口。设计、规则与历史证据仍以[权威设计](unified-search-commands.md)为准，本文不复制。每批怎样更新本文见[技能路由的路由维护](../skill-routing.md#路由维护)。

最后更新：2026-10-21，合并批 M-3（[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)）。

## 目标与阶段

- **目标**：工作台和菜单栏共用一套搜索与指令，覆盖 §8 全部 48 项用户功能；现有按钮、菜单与指令共用业务逻辑（[§1](unified-search-commands.md#1-已确认的产品与查询规则)）。
- **当前方向**（2026-10-18 用户决定）：先在隔离环境补齐全部功能，再做正式版接线；补复核 G-1b～G-1e 挪到接入正式版之前。
- 阶段划分见 [§9.1](unified-search-commands.md#91-建议的分阶段边界)，当前状态一句话一行：
  - **阶段 1 领域协议**：1A～1D 已实现（目录、解析、查询会话、草稿、计划、转交），仅 1A～1D 自身证据，见 [§9.6](unified-search-commands.md#96-阶段-1a-目录决策与证据)～§9.13。
  - **阶段 2 只读数据**：2A～2J 注入快照提供者与 2K-1～2K-8 SwiftData／文件只读适配已在隔离环境实现；真实宿主的异步调度与生产接线未做，见 [§9.14](unified-search-commands.md#914-阶段-2atodo-只读快照提供者与类型化结果)～[§9.44](unified-search-commands.md#944-阶段-2k-8全来源标签使用统计的只读存储适配与受门禁发布)。
  - **阶段 3 业务动作适配**：进行中；普通设置（3A）、任务／子任务／习惯／批量／转换／标签等指令已在隔离环境逐批实现；系统类、永久删除类与附件系统动作自 M-3 起“打开原页面”。覆盖见下表，未开始只剩手记写入 J1～J3（M-4）。
  - **阶段 4 共享界面**：4A 公共输入、结果列表、参数、对象、计划与长文编辑只在隔离宿主装配；正式版没有构造 `UnifiedSearchController`，生产入口未接线。
  - 阶段 5～7（队列执行与撤销、独立系统流程、模板与全目录收口）：未开始。

## 功能覆盖表

状态只用：**未开始 / 隔离实现 / 隔离实现且已复核 / 打开原页面 / 已接正式版 / 待核实**。“打开原页面”（M-3，2026-10-20 用户决策 1、2）指指令只导航到原页面、由原页面完成操作，不在指令里执行，**不算隔离实现**；对照只在 [CommandOriginalPage](../AreaChain/Domain/CommandOriginalPage.swift)。一行内既有隔离实现又有打开原页面的动作时写“隔离实现＋打开原页面”。一行内只有部分动作完成时写“隔离实现（部分）”，并在“已覆盖／未覆盖”列写清哪些动作完成、哪些没有；不把未覆盖动作算作已实现。“已复核”只指按[指定只读复核入口](../skill-routing.md#指定只读复核入口)通过的部分。功能名称见 §8 对应行（ID 链接）。

| ID | 功能 | 状态 | 已覆盖／未覆盖 | 里程碑 | 交接 |
|---|---|---|---|---|---|
| [T1](unified-search-commands.md#T1) | 新建任务、标题、备注 | 隔离实现 | 已：todo.create、todo.title（G-1a 已复核）；todo.notes（L-M1b）；todo.cancelTitle（M-1，去掉宿主保留的标题草稿）；原界面文字里的私密／预设标签不再关联（M-1 A，已接正式版行为） | 3T、T-M1、T-M6、L-M1b、M-1 | [§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T2](unified-search-commands.md#T2) | 完成、改期、提醒、优先级、标签、截止 | 隔离实现 | 已：todo.move／priority／reminder（T-M1）、completion／tags／createTag／due（T-M2），均 G-1a 已复核；todo.cancelCompletion（M-1，复用 0.4 秒反悔窗口）；move／priority／reminder／tags／due 自 M-1 起允许带备注对象 | T-M1、T-M2、M-1 | [§9.74](unified-search-commands.md#974-里程碑-t-m2完成标签与截止时间的隔离闭环)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T3](unified-search-commands.md#T3) | 复制、回收 | 隔离实现 | 已：todo.copy、todo.trash；M-1 起带备注对象可复制、可回收（确认面板说明备注随对象进回收站）；未复核 | T-M4、M-1 | [§9.90](unified-search-commands.md#990-里程碑-t-m4复制与回收)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T4](unified-search-commands.md#T4) | 子任务 | 隔离实现 | 已：subtask.create／title／completion／tags（T-M3，G-1a 已复核）、subtask.delete（T-M4）、subtask.order（T-M6）、subtask.cancelTitle（M-1）；父待办带备注仍拒绝 | T-M3、T-M4、T-M6、M-1 | [§9.75](unified-search-commands.md#975-里程碑-t-m3普通子任务的隔离闭环)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T5](unified-search-commands.md#T5) | 重复事项定义 | 隔离实现 | 已：routine.title／weekdays／reminder／priority／tags（R-M1）、routine.create（R-M2）、routine.enabled（R-M3）、routine.trash（T-M4）、routine.order（T-M6）、routine.capture／routine.notes（T-M6 规格，L-M1b 经长文受控借用执行）；R-M1～R-M3 待 G-1b 补复核 | R-M1～R-M3、T-M4、T-M6、L-M1b | [§9.76](unified-search-commands.md#976-里程碑-r-m1习惯定义五字段的隔离闭环)、[§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现) |
| [T6](unified-search-commands.md#T6) | 指定日完成／撤回／跳过、检查日、连击 | 隔离实现 | 已：occurrence.complete／skip／reopen（R-M3）、inspector.day 定位（N-M1）、routine.streak（M-1，复用 HabitStreakLogic，只读） | R-M3、N-M1、M-1 | [§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T7](unified-search-commands.md#T7) | 批量任务／习惯 | 隔离实现 | 已：batch.move／tags（B-M1，M-1 起允许带备注）、batch.completion／enabled（B-M2）、batch.trash（T-M4，M-1 起允许带备注）、selection.clear（M-1） | B-M1、B-M2、T-M4、M-1 | [§9.79](unified-search-commands.md#979-里程碑-b-m1固定多目标改期与混合标签共同提交)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T8](unified-search-commands.md#T8) | 待办↔重复事项转换 | 隔离实现 | 已：todo.toRoutine、routine.toTodo；M-1 起带备注对象可转换（损失清单列出“备注原样搬到新对象”）；未复核 | T-M5、M-1 | [§9.91](unified-search-commands.md#991-里程碑-t-m5待办与重复事项互转)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T9](unified-search-commands.md#T9) | 页面筛选、全部事项、排序、延至今日 | 隔离实现（部分） | 已：tasks.order、tasks.postponeYesterday（T-M6）；tasks.filter／clearFilter（今日／待处理／全部事项，与页面双向同步）、tasks.kind／status、tasks.sections（昨天／即将）、tasks.select（待处理／全部事项）（M-1）；未：今日区收起（始终展开）、今日页与标签清单的多选指令 | 2A～2J、4A、T-M6、M-1 | [§9.93](unified-search-commands.md#993-里程碑-t-m6任务类修改收尾)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [T10](unified-search-commands.md#T10) | 剪贴板加今天 | 隔离实现且已复核 | 已：capture.clipboard（T-M6，无 Run 模式，提交才读剪贴板；T-M6 指定复核通过）；M-1 起读到私密／预置标签整条不写并说明（L7），菜单栏入口跳过标签照常保存 | T-M6 | [§9.93](unified-search-commands.md#993-里程碑-t-m6任务类修改收尾) |
| [B1](unified-search-commands.md#B1) | 日历导航与改期 | 隔离实现 | 已：calendar.mode／step／today／day／dayList（页面指令，月周与选中日写页面那一份）、calendar.create（转交 todo.create）；拖拽改期沿 todo.move（T-M1）。核实：原组合只覆盖导航与改期，页面动作在 M-2 补齐；calendar.step 只留 offset，月周跟随当前视图 | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [B2](unified-search-commands.md#B2) | 四象限 | 隔离实现 | 已：quadrant.day／step／inspect（页面指令）、create／priority／complete／copy（转交 todo.create／todo.priority 或 routine.priority／todo.completion 或 occurrence.complete／todo.copy 标题段）；quadrant.complete 的 1A 未决（习惯 skip 语义）已由 R-M3 D1 定，M-2 解决；copy 不接习惯 | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [B3](unified-search-commands.md#B3) | 安排页平移与完成 | 隔离实现 | 已：gantt.step／currentMonth／select／inspect（页面指令）、gantt.shift（X-1 骨架，GanttRescheduleService，一次事务、保留间隔、越出当月拒绝）、gantt.complete（转交 batch.completion） | N-M1、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [J1](unified-search-commands.md#J1) | 手记新建与正文 | 未开始 | 长文编辑底座（C-M1～C-M3）已在隔离宿主，正文保存 handler 未做 | C-M1～C-M3 | [§9.88](unified-search-commands.md#988-里程碑-c-m3长文上限与超限引导) |
| [J2](unified-search-commands.md#J2) | 手记组织 | 未开始 | — | — | — |
| [J3](unified-search-commands.md#J3) | 手记复制、转任务、回收 | 未开始 | — | — | — |
| [G1](unified-search-commands.md#G1) | 标签新建、改名、颜色、排序、搜索与视图 | 隔离实现（部分） | 已：tag.create／rename／color（X-1）、tag.order（M-1）、tag.cancel、tag.search／view／deleted（M-2，取法即标签页的 TagListQuery）、go.tagList（N-M2）；未：新建时设为私密（需解锁） | X-1、2F、N-M2、T-M6、M-1、M-2 | [§9.92](unified-search-commands.md#992-提速基建-x-1)、[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [G2](unified-search-commands.md#G2) | 标签合并、解绑、软删／恢复、清理 | 隔离实现＋打开原页面 | 已：tag.merge（决策 3：涉及私密标签整条拒绝）、tag.unlinkObject（受保护手记拒绝）、tag.trash／tag.restore（共用独立确认、只能单项）；打开原页面：tag.delete、tag.cleanup → 标签页（M-3）；tag.unlinkGlobal 目录 unavailable（原界面没有该功能，不算缺口） | M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [A1](unified-search-commands.md#A1) | 图片附件 | 隔离实现＋打开原页面 | 已：图片元数据只读查询（2E、2K-6）、普通图片查阅（N-M2）、image.browse／image.preview／image.trash（M-2）；打开原页面：image.pick／paste／capture → 焦点对象的详情（手记打开手记页，习惯定义须先选执行日）（M-3） | 2K-6、N-M2、M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C1](unified-search-commands.md#C1) | 剪贴板浏览与搜索 | 隔离实现 | 已：显式 /clipboard 只读提供者与文件只读适配（2G、2K-5）；clipboard.browse／search（M-2，与历史页 visibleItems 同一取法，原生等价验收逐行比对）；默认不进普通搜索不变 | 2G、2K-5、M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [C2](unified-search-commands.md#C2) | 剪贴板复制／粘贴 | 隔离实现 | 已：clipboard.copy／paste／pastePlain（ClipboardHistoryActions，写入失败不报成功；QA 中门与按键全为 fake、私有命名剪贴板）；真实辅助功能权限与 ⌘V 未接线 | M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [C3](unified-search-commands.md#C3) | 剪贴板置顶、删除、清空 | 隔离实现＋打开原页面 | 已：clipboard.pinned、clipboard.copyLetter（M-2）；打开原页面：delete、prune、empty → 剪贴板页（M-3） | M-2、M-3 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C4](unified-search-commands.md#C4) | 记录暂停、跳过、忽略来源 | 打开原页面 | clipboard.recording／skipNext／ignoreApp → 剪贴板页（M-3，决策 2） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C5](unified-search-commands.md#C5) | 剪贴板偏好 | 打开原页面 | 全部 13 条（含 add／removePattern、add／removeType、unignoreApp）→ 剪贴板页的“剪贴板选项”（设置页没有剪贴板分节，M-3 核实） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [C6](unified-search-commands.md#C6) | 剪贴板小窗 | 隔离实现 | 已：clipboard.openWindow／closeWindow／pinWindow／workspace（沿 ClipboardHistoryPanel 现有窗口管理，只有一个面板）；真实窗口适配读共享会话，生产接线另需授权 | M-2 | [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板) |
| [S1](unified-search-commands.md#S1) | 语言、外观、标题省略、捕获来源 | 隔离实现 | 单项与共同提交（聚合文件后端）都在隔离宿主；未复核 | 3A | [§9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线) |
| [S2](unified-search-commands.md#S2) | 登录启动 | 打开原页面 | setting.login、loginSettings → 设置“启动”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S3](unified-search-commands.md#S3) | 通知权限与测试 | 打开原页面 | notification.status／request／test／settings → 设置“通知”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S4](unified-search-commands.md#S4) | 通知完成与延后 | 隔离实现＋打开原页面 | 已：notification.open 沿 inspector.open 打开对象；complete／snooze 只说明并给出改用 todo.completion／occurrence.complete／todo.reminder 的入口，不另写执行（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S5](unified-search-commands.md#S5) | 日历同步 | 打开原页面 | calendarSync.enabled／status／retry／settings／conflicts → 设置“系统日历”分节；openLocal 也改为打开该分节（搜索里没有冲突对象来源，偏离原“直接执行”，见 §9.98）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S6](unified-search-commands.md#S6) | iCloud 说明 | 打开原页面 | setting.icloud → 设置“iCloud”分节（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [S7](unified-search-commands.md#S7) | 快捷键配置 | 打开原页面 | shortcut.record／reset／resetAll／cancel → 快捷键页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P1](unified-search-commands.md#P1) | 创建私密锁 | 打开原页面 | privacy.create／setupMethod／setupTags／protectExisting → 隐私与解锁页（M-3）；不新增隐私转换执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P2](unified-search-commands.md#P2) | 隐私管理 | 隔离实现＋打开原页面 | 已：privacy.lock 直接执行（沿“立即锁定”，锁定撤权，M-3）；打开原页面：unlock、systemUnlock、set／change／removePassword、idle、tags → 隐私与解锁页 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P3](unified-search-commands.md#P3) | 解除单条手记保护 | 打开原页面 | privacy.unprotect → 隐私与解锁页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [P4](unified-search-commands.md#P4) | 隐私维护重试 | 打开原页面 | privacy.retryImages／retryKeys／quitForCleanup → 隐私与解锁页（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D1](unified-search-commands.md#D1) | 回收站 | 隔离实现＋打开原页面 | 已：显式回收范围的墓碑只读搜索（2H、2K-7）、trash.restore（M-3：与回收站页同一写入 TrashRestoreService，共用独立确认、只能单项，受保护拒绝）；打开原页面：trash.delete、trash.empty → 回收站（定位焦点项） | 2H、2K-7、M-3 | [§9.43](unified-search-commands.md#943-阶段-2k-7完整墓碑只读适配与受门禁回收站搜索)、[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D2](unified-search-commands.md#D2) | JSON 导出导入 | 打开原页面 | data.export／selectImport／validateImport／previewImport／applyImport → 数据与备份页（M-3）；不新增导入执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D3](unified-search-commands.md#D3) | 加密备份与恢复 | 打开原页面 | backup.export／inspect／preview／restore → 数据与备份页（M-3）；不新增备份恢复执行路径 | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [D4](unified-search-commands.md#D4) | 重置并退出 | 打开原页面 | recovery.status、recovery.resetQuit → 数据与备份页（降级提示就在该页，M-3）；resetQuit 目录仍 unavailable | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N1](unified-search-commands.md#N1) | 全页面与标签清单导航 | 隔离实现 | 已：16 个 go 入口（N-M1）、go.tagList（N-M2）；未复核 | N-M1、N-M2 | [§9.84](unified-search-commands.md#984-里程碑-n-m1导航与返回搜索) |
| [N2](unified-search-commands.md#N2) | 工作台、浮层与面板 | 隔离实现（部分） | 已：workspace.open／reveal／close、overlay.toggle、routine.addPanel／managePanel（沿 AppWindows 与今日页原面板，不新建窗口，M-3）；未：overlay.mode（浮层的任务／手记页没有外部切换入口，只说明） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N3](unified-search-commands.md#N3) | 检查器与选择 | 隔离实现 | 已：inspector.open／inspector.day（N-M1）、selection.all／clear（M-1，沿页面投影） | N-M1、M-1 | [§9.84](unified-search-commands.md#984-里程碑-n-m1导航与返回搜索)、[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾) |
| [N4](unified-search-commands.md#N4) | 手记小窗 | 隔离实现（部分） | 已：diaryWindow.open（受保护手记拒绝）／draft（不写入，受保护草稿留给原页面）／pinned／close（沿小窗原有确认）（M-3）；未：diaryWindow.save（写正文，归 M-4） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N5](unified-search-commands.md#N5) | 总览统计 | 隔离实现 | 已：stats.* 八项只读（DashboardStatsReader，与总览页同一投影，私密手记口径不变）、stats.openDay、活动行打开（沿总览路由；搜索里没有活动对象，stats.openActivity 指向 stats.activity 的列表）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N6](unified-search-commands.md#N6) | 帮助与示例 | 打开原页面 | help.syntax（语法帮助卡）、help.page（来时页面的说明）、help.example（只预填示例到搜索框，不执行）（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N7](unified-search-commands.md#N7) | 版本、反馈与链接 | 打开原页面 | support.* 七条 → 设置“版本／支持／关于”分节；不在指令里打开外部网址（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |
| [N8](unified-search-commands.md#N8) | 退出与未保存确认 | 隔离实现 | 已：app.quit 走 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记），同意后才调注入的 terminate；QA 中为 fake（M-3） | M-3 | [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口) |

合计 48 项：隔离实现 19（T1～T8、S1、N1、N3、N5、N8、B1～B3、C1、C2、C6）；隔离实现且已复核 1（T10）；隔离实现（部分）4（T9、G1、N2、N4）；隔离实现＋打开原页面 6（G2、A1、C3、S4、P2、D1）；打开原页面 15（C4、C5、S2、S3、S5、S6、S7、P1、P3、P4、D2、D3、D4、N6、N7）；待核实 0；未开始 3（J1～J3，留给 M-4）；已接正式版 0（M-1 A 的原界面私密标签修复属正式版行为修复，不计入指令接线）。

## 未闭合缺口

合并去重自各交接节，每条附来源；关闭某条时只改本节对应行。

- **指定只读复核**：G-1a 已关闭 T-M1～T-M3 的复核缺口；X-1、T-M6、L-M1b、合并批 M-1、合并批 M-2、合并批 M-3 已通过（见各自交接）；其余里程碑（2*、4A、3A、3T、R、B、P、N、C 系列、T-M4、T-M5）仍未经指定复核；合并批 M-3 见其交接。来源：[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)、[§9.91](unified-search-commands.md#991-里程碑-t-m5待办与重复事项互转)。
- **正常签名构建**：正常开发描述文件曾于 2026-10-07 到期，各里程碑的正常 Debug 证据因此 partial；当前描述文件 2026-10-22 到期，到期后正常构建记为阻塞，不续签、不改个人签名配置。来源：[§9.75](unified-search-commands.md#975-里程碑-t-m3普通子任务的隔离闭环)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **人工与平台验收**：真人输入法、VoiceOver、最低支持系统、真实多窗口、原生截图逐类查看均未做。来源：[§9.85](unified-search-commands.md#985-里程碑-n-m2标签导航普通手记全文与普通图片查阅)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **C2B 原生接受与锁定交错**：敏感输入不开放，mutable textStorage 只能事后检测。来源：[§9.52](unified-search-commands.md#952-阶段-4a-3c2b原生接受与锁定交错的隔离可行性)、[§9.86](unified-search-commands.md#986-里程碑-c-m1命令长文原生编辑与受控组合输入)。
- **生产接线授权**：所有适配器默认未装配，正式版没有统一搜索构造点；接入前需逐项授权装配、用生产刷新替换 fake，并确认提醒、日历、小组件的真实副作用。来源：[§9.90](unified-search-commands.md#990-里程碑-t-m4复制与回收)、[§9.91](unified-search-commands.md#991-里程碑-t-m5待办与重复事项互转)。
- **长文受控借用**：已实现（隔离）。L-M1b 按 §9.94 与 2026-10-20 用户确认实现托管、一次性借用与带键摘要，接通 todo.notes／routine.notes／routine.capture；守卫改按目录类型判定，clear 漏口已复现并堵上。只开放普通长文（受保护、required、unknown 仍拒）；默认未装配；托管只听隔离环境私有事件中心，接正式版须转接隐私锁事件。来源：[§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)。
- **原界面备注私密标签缺口**：已修复（合并批 M-1 检查点 A）。任务、子任务、习惯一侧从文字解析标签时照常保存文字，跳过私密与预设标签并提示；判定与指令侧 L7 共用 `InputTagResolver.protection`，差别只在结果（指令整条拒绝）；手记一侧不变。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **正文与受保护内容**：手记正文保存 handler 未做；受保护内容查阅与敏感执行／转交不开放。来源：[§9.85](unified-search-commands.md#985-里程碑-n-m2标签导航普通手记全文与普通图片查阅)、[§9.88](unified-search-commands.md#988-里程碑-c-m3长文上限与超限引导)。
- **有备注对象资格**：M-1 B 已把 11 处适配改为自读备注取带键摘要，并放宽字段类、回收、转换、复制；仍未放宽：todo.title／subtask.title（`//` 派生备注另行定界）、完成、建标签、子任务与习惯字段类、删子任务时的父待办。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **已知历史问题**：T-M1 标题多目标面板消失的根因未判定；DetailSubtaskCompletionTests 两项 Expected Failure 保留；原生日期格按钮在统一搜索测试宿主里找不到标识（`nativeBooleanWeekdaysDayAndTime` 等）；`SubtaskModelTests.addTagSkipsDiaryPresetNames` 在未改动 HEAD 上同样失败。来源：[§9.73](unified-search-commands.md#973-里程碑-t-m1普通任务修改与受限依赖执行)、[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **工作台操作面板鼠标点击**：M-1 原生用例中，合成鼠标事件到不了工作台窗口操作面板里的按钮（缓冲版本与输入焦点均不变，原因未判定），改用 AXPress 验证同一按钮；真实鼠标点击未验证。来源：[§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- **G-1a 低级整改清单 9 条**：待单独批准的修复批次。来源：[§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **目录未决项**：tag.cleanup（预置标签范围）、backup.export（无锁可达性）、diary.tags（保护转换）等仍未定稿；习惯 skip 语义已由 R-M3 的 D1 处理；tag.merge 已按决策 3、quadrant.complete 已按 R-M3 语义在 M-2 解决。来源：[§9.6](unified-search-commands.md#96-阶段-1a-目录决策与证据)、[§9.78](unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)、[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。
- **留给 M-3 打开原页面**：已关闭（合并批 M-3 A）。tag.delete／cleanup、clipboard.delete／prune／empty、C4、C5、image.pick／paste／capture 与 S2、S3、S5～S7、P1～P4（除 privacy.lock）、D1 永久删除、D2～D4、N6、N7 都只导航到原页面，对照唯一在 CommandOriginalPage。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- **M-3 偏离与限制**：calendarSync.openLocal 改为打开设置“系统日历”分节（搜索里没有冲突对象来源）；C5 指向剪贴板页的“剪贴板选项”（设置页没有剪贴板分节）；分节只在说明里指明，页面不自动滚动；overlay.mode 只说明（浮层切页没有外部入口）；stats.openActivity 没有活动对象来源，改在 stats.activity 的列表里打开；diaryWindow.save 归 M-4。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- **M-3 生产接线前置**：WorkspaceSystemCommands 的工作台显示／关闭、浮层开关、手记小窗管理、退出确认与 terminate、保险箱，以及 trash.restore 规格装配都只在隔离夹具里注入；接正式版需逐项授权（真实 AppWindows／StatusItemController／DiaryWindows.shared／NSApp.terminate）。来源：[§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
- **M-2 生产接线前置**：剪贴板粘贴的真实辅助功能权限与 ⌘V、小窗真实窗口适配（读共享会话）、手记解绑标签的保险箱、附件存储根均只在隔离夹具里注入；image.preview 只能打开当前结果里可见的普通图片。来源：[§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。
- **现状差距**：备份未配置锁的可达性、剪贴板历史读取失败返回空、重置吞掉删除错误。来源：[§9.4](unified-search-commands.md#94-未决问题与单独授权边界)。
- **性能基线**：新查询延迟、长文编辑、最大候选规模与内存均未建立基线。来源：[§9.3](unified-search-commands.md#93-后续回归入口与证据缺口)。

## 补复核待办

- **G-1a**（T-M1～T-M3）：已完成，三份结论均“通过”，见 [§9.89](unified-search-commands.md#989-补复核-g-1at-系列)。
- **G-1b～G-1e**：挪到接入正式版之前执行。提示词原放在被忽略的 `build/prompts/`，该目录后被清理；2026-10-19 已按同一模板重新生成到被忽略的 `.agents/prompts/`：G-1b（R-M1～R-M3）、G-1c（B-M1、B-M2、P-M1）、G-1d（P-M2、P-M3、N-M1）、G-1e（N-M2、C-M1、C-M2）。
- L-M1b：指定复核第二轮通过，见 [§9.95](unified-search-commands.md#995-里程碑-l-m1b长文受控借用实现)。
- 合并批 M-1：指定复核第二轮通过，见 [§9.96](unified-search-commands.md#996-合并批-m-1任务域收尾)。
- 合并批 M-2：指定复核通过（两条低级意见已整改），见 [§9.97](unified-search-commands.md#997-合并批-m-2看板标签附件剪贴板)。
- 合并批 M-3：指定复核通过（三条低级意见已整改），见 [§9.98](unified-search-commands.md#998-合并批-m-3导航窗口与系统入口)。
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

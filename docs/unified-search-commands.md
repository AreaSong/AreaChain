# 统一搜索与指令体系

## 0. 状态、权威范围与基线

当前状态、功能覆盖与缺口见 [§10 现状总览](#10-现状总览)；其余各节是目标设计、功能映射与仍有效的决定。

本文是该体系唯一的目标设计来源，只记规则、映射与仍有效的决定，批次证据不写入本文，不复制计划、不另建自动执行器。当前行为仍见[功能清单](features.md)、[使用说明](usage.md)、[架构](architecture.md)；目标与现状有差异时以本文的“目标”理解未来工作，不能据此宣称当前产品已有能力。实现继续遵循[项目规则](../AGENTS.md)、[技能路由](../skill-routing.md)、[组件目录](component-catalog.md)与[质量门禁](quality-gates.md)。本文件不授予安全边界变更、真实数据写入、系统权限、安装或发布权限。


## 1. 已确认的产品与查询规则

### 统一能力与指令发现

- 工作台和菜单栏共用搜索能力、查询语法、指令目录及交互机制，各自拥有会话；普通搜索入口能力完整，特殊对象选择器才能使用明确声明的受限配置，并解释限制。
- 页内筛选有意保留：手记页、手记小窗、标签管理、剪贴板历史、附件中心各自的筛选框只缩小正在看的这一页，不并进统一搜索，也不与统一搜索的查询做双向同步；统一搜索负责跨全应用查找与执行指令，两件事不同。条件是同一个普通词在页内与统一搜索里的匹配规则只有一个来源（与 `BoardSearch.matches` 同口径）。任务页的默认范围（如 `/tasks`、`/diaries`）可见、可编辑、可删除，任务页筛选与统一查询读写同一上下文。
- 普通文字搜索内容；输入 `/` 发现指令，支持中文关键词及别名。标准路径用斜杠，例如 `/setting/language/chinese`；输入 `/set` 或 `/setting` 就补全，无须完整路径或末尾斜杠。路径与稳定功能标识不随界面翻译改变。
- `/tasks` 表示内容范围，`/go/…` 表示导航，两者严格区分。内容范围不限制全局应用指令；在 `/diaries` 中也能发现语言设置等指令。
- 覆盖现有全部用户功能和实际业务动作，不能只导航到页面，也不能只实现示例指令。长文在入口内下方编辑区也能完成，仍可提供更适合长文的工作台/独立编辑器入口。
- 现有按钮、菜单、设置页与指令共用业务逻辑。统一的是能力与提交契约；文件选择、系统认证等原生交互仍使用现有机制。
- 普通全局搜索默认排除剪贴板历史与已删除内容；剪贴板需显式 `/clipboard`，剪贴板页自动带此范围；回收站需显式范围。

### 页面上下文的状态转移

“自动条件”带页面来源，“用户条件”带用户来源。显示相同的文本不代表来源相同；不能只从输入字符串猜测是否允许改写页面。

| 事件 | 查询与页面的目标行为 |
|---|---|
| 进入页面，只有自动范围/自动条件 | 呈现原页面，不因默认范围本身打开统一结果。 |
| 输入关键词或主动添加查询条件（包括主动指定范围） | 显示统一结果；结果与条件保持一致。 |
| 仍与当前页面绑定时修改页面筛选/查询条件 | 双向同步到同一上下文；转换必须能往返，不能循环回写或复制两套可编辑状态。 |
| 页面切换 | 替换旧页面的自动条件，保留用户关键词；用户明确指定的范围不得静默覆盖。 |
| 删除默认范围 | 当前页面上下文记录已删除意图，不因重绘、重新聚焦或刷新自动补回。 |
| 改成其他范围，或离开原页面上下文 | 查询成为独立上下文，不继续改写原页面筛选；原页面保留自己的状态。 |
| 清除查询 | 退出统一结果并返回进入结果时的原页面，保留草稿和滚动位置；清除查询不等于清除操作草稿。 |
| 有操作草稿时切页 | 页面自动条件只能影响查询；操作的固定目标、参数、正文及待执行内容保持不变。 |

独立查询与页面再次绑定必须是明确的动作，不能因路径文字碰巧相同而自动绑定。跨页后的“原页面”指进入该次结果上下文时保存的返回位置；重新在另一个页面建立上下文时更新返回位置。页面自动范围的映射及删除标记跨“离开后再进入”的保留时限以查询状态实现为准，不能削弱当前页内不补回的规则。

### 手记不可读正文与搜索投影

- 正文不可读不等于空正文；标签、归属日、创建时间等允许读取的元数据仍可判断。可读字段足以证明匹配或不匹配时正常判断；依赖不可读正文才可决定的对象为未知，不进入确定命中，也不伪装完整零结果。
- 正向文字可由正文或任一关联标签名证明；排除文字不能因正文不可读自动成立。AND 有确定不匹配则不匹配，否则有未知则未知；OR 有确定匹配则匹配，否则有未知则未知。所有分支先求值并保留身份/安全诊断，不以短路隐藏问题。
- 搜索不自动触发解锁。私密及无法确认公开的结果始终用现有隐藏标题；即使注入快照正文可读且参与匹配，结果也不携带正文、片段、正文长度、正文命中范围或其他正文派生展示。正文命中理由至多为无内容的通用说明。
- 标签名字、私密标签集合是调用方提供的事实，缺失不等于已提供空集合；不能可靠判定敏感性时不得默认公开。`DiarySnapshot.isContentAvailable` 决定正文能否参与匹配，占位文字不作为真实正文。

### 图片查询语义（关联、元数据匹配与记录存在性）

- 普通文字、短语和排除文字只匹配图片文件名；不读取图片内容，不做 OCR。
- `date` 使用所属记录业务日期，`created` 使用图片附件自身创建时间；`#标签` 使用所属记录标签。
- 优先级、提醒、完成状态只使用所属类型真实存在的字段；条件与命中依据须标明“所属记录属性”，并保留类型化所属身份。手记没有任务完成态、优先级或提醒；习惯状态必须有明确执行日并复用既定记录与历史证据规则。
- `has:image` 查询带图片的记录，不是图片自身属性。是否允许已授权私密记录使用该条件，留待真实隐私适配，不在此阶段开放。

### 回收站分组与恢复描述

- 随父任务删除的子任务和图片默认归在父项下，可展开，不重复计入顶层结果；子项保持独立身份。搜索只命中子项时须显示具体命中及父关系，不能因折叠隐藏命中。
- 父任务删除前已独立删除的子任务不属于本次级联，不暗示恢复父项会恢复它。先核实真实父子/类型化拥有者关系，再用既有精确删除戳判断，不引入容差或按天近似。
- 图片拥有者仍被删除时说明需先恢复拥有者；可搜索不等于已有独立恢复入口。缺少既有能力时声明不可直接恢复，不新增业务操作。
- 缺失、未提供、部分覆盖和歧义分别保留；关系不确定时不猜测。父已恢复后仍有墓碑的子项不继续归入当前级联组。
- 私密手记沿隐藏标题；私密/保护资料不足的图片不发布文件名、内容、访问能力，也不从分组成员、计数或诊断位置泄露。新增披露须另行定界。
- 恢复条件仅是读取说明，提交前仍须重新检查身份、删除状态、权限、数据及业务规则，不是授权或成功保证。

## 2. 补全、预览、编辑与键盘

输入框是稳定锚点：默认上方补全、下方即时预览。补全回答“下一步可以填什么”，预览显示“已填内容、目标与实际执行效果”。两者可以同时存在，参数只有一份权威状态。

| 场景 | 呈现与编辑契约 |
|---|---|
| 简单设置 | 显示当前值 → 新值，明确尚未提交。 |
| 多属性 | 默认摘要，可展开；点击属性直接编辑同一字段。 |
| 长正文 | 下方展开可滚动原生正文编辑区，支持全文编辑、换行、选区、输入法与撤销；不把长文塞入路径参数。 |
| 多对象 | 显示确定数量与示例，展开检查所有目标并移除；不把当前结果数量当作固定目标数量。 |
| 待执行列表 | 同时只编辑一项，下方汇总所有项；可展开、修改、移除，未完成参数明确标记。 |
| 输入语法/条件块/预览控件 | 都更新同一份语义状态；文本原生编辑缓冲保留光标与组合文本，不能形成第二份业务参数。 |
| 空间与焦点 | 按需展开并限制最大高度，空间不足时自动避让、压缩可滚动区域；避免遮住编辑焦点，结果刷新和预览更新不抢焦点。 |
| 视觉与可访问性 | 指令、范围、参数有语义颜色，并用文字或图标区分；中英文、浅深色、最小窗口、减弱动态效果遵循现有令牌与可访问性规则。 |

键盘优先级由获得焦点的输入组件协调：输入法组词优先，其次当前候选/局部编辑层，再是当前输入的编辑与提交规则，最后才是宿主快捷键。

| 按键 | 行为 |
|---|---|
| ↑ / ↓ | 候选活动时选择候选；结果层获得选择焦点时按统一结果序列移动（含附件）。正文编辑时保留原生光标行为。 |
| Tab / Return | 当前候选活动时接受补全；接受写指令或参数不执行写入。 |
| Return | 无待接受候选时，打开选中的结果或明确的导航目标；多行正文中换行。 |
| ⌘Return / 明确命名按钮 | 提交已校验的写操作；例如“保存 3 项修改”，不能用含混“确定”隐藏效果。 |
| Esc | 先关闭当前候选或局部编辑层，再收起面板；不直接丢弃操作草稿。 |

不得注册一份绕过输入组件的宿主提交快捷键。候选、正文、只读预览、系统 sheet 和结果导航各有明确焦点归属。UI/UX 技能检索返回了 Web 焦点遮挡与 iOS `FocusState` 建议，未找到适用于本项目 AppKit 组合文本的直接实现依据；这里只采纳焦点可见这一通用检查，具体实现以现有原生桥接及其测试为准，不替换 AppKit。

## 3. 会话、草稿与转交

以下是目标责任划分，不是已经存在的 Swift 类型或公共 API：

| 状态 | 权威所有者与生命周期 | 不变量 |
|---|---|---|
| 查询 | 每个入口的会话；含用户关键词、范围/条件来源、排序、页面绑定和返回位置 | 内容范围不约束全局指令；页面不能重写用户显式范围。 |
| 操作草稿 | 每个入口的会话；含操作标识、固定目标、字段修改、正文、编辑基线、待执行列表 | 默认只存本次运行内存；收起浮层、点击外部、切页不提交、不丢弃。 |
| 展示 | 同一会话的派生状态及局部焦点/展开状态 | 补全、预览、输入共享语义状态；页面拆除不销毁唯一草稿。 |
| 执行 | 明确的执行协调者；保存每项运行内状态、成功结果、依赖及重试身份 | 执行中防重复提交，迟到结果不能覆盖新草稿；收起面板不等于取消执行。 |
| 最近使用/固定/模板 | 独立偏好边界，按第 6 节限制持久化 | 不以“历史”名义自动保存正文、对象或路径。 |

开始另一项独立操作时，已有修改要提供“保留、放弃、取消”处理；保留后应可恢复，不能藏成不可找回的草稿。保存失败保留正文与参数；关闭窗口及退出保护未保存内容。私密草稿复用锁定封存/遮罩机制，默认不增加磁盘正文持久化。

菜单栏与工作台分别拥有会话。主动“在工作台继续”转交完整查询、参数、正文、固定目标及待执行内容；目标已有草稿时不能覆盖。转交按“检查目标可接收 → 目标接管成功 → 源撤去提交所有权”完成，失败仍由源保留。成功后不能留下两份可分别提交的副本。正在执行或等待授权时暂不转交；转交不是提交，也不是重新解析后改变目标。该所有权规则需要运行内原子切换与失败测试，不要求新增磁盘协议。

## 4. 多项操作、字段与执行契约

本节描述产品目标。哪些指令已具备真实执行、事务、重试、取消及撤销能力，以各指令适配的实际实现和 §10 覆盖表为准，不能由本节或协议状态推导已经接线。

### 目标与队列

- 支持多个设置、多个对象和多个字段。目标可以是单对象、明确选中的多对象、显式选择的“当前全部结果”；确认后固定对象集合，后续结果增减不能静默扩大目标。
- 对象引用应包含类型和稳定标识；打卡还带明确日期。父子结果可归组但独立选择，不能把父对象和子对象的操作混淆。
- 混合类型只提供共同操作；非共同操作必须说明适用子集，用户明确选择后执行，不静默跳过其他对象。
- 同一对象同一字段的普通赋值合并成最终值；追加正文等顺序敏感操作保留顺序。不能跨有语义依赖的步骤随意合并。
- 默认按列表顺序执行；依赖显式，前置失败暂停依赖项，不依赖失败项的独立操作继续；已约定为共同保存的设置组保持组内一致性，成功项不重复执行。这是用户已确认的目标，队列执行尚未实现。参数未完成不能静默跳过，应在统一提交校验中标记并阻止其被当作可执行项。
- 导航、退出、隐私转换、永久删除、恢复备份等需独立处理的高风险操作，不混入普通修改队列。

### 字段语义

| 字段/动作 | 未指定、赋值与清空语义 |
|---|---|
| 任意字段 | 未指定保持原值；“未指定”与“明确清空”须能区分。多对象原值不同显示“多个不同值”，不能用空白代替。 |
| 标题、日期、优先级等 | 明确赋值替换原值，遵守原有校验和适用对象；不是输入为空就清空。 |
| 备注 | 替换、追加、清空，默认替换。 |
| 标签 | 添加、移除、替换全部、清空，默认添加；搜索 `#标签` 不创建标签，不存在时“新建并添加”是显式写操作。 |
| 提醒 | 设置与明确取消分开；不把搜索时刻或截止时刻当提醒。 |
| 正文 | 新建、全文编辑、追加、清空；遵守现有正文校验，不能因提供“清空”而绕过非空限制。 |
| 批量正文 | 必须显式选择，逐篇预览；不能把一篇内容静默覆盖全部。 |
| 习惯 | 习惯定义与某日完成/跳过记录分开；当日动作也必须展示明确日期。 |
| 日期 | 搜索日期、导航日期、修改日期分别表达，预览显示具体字段及实际民事日期；相对日期提交/模板使用时展示解析结果。 |

### 提交、部分失败、冲突与撤销

1. 提交前统一检查参数完整性、目标存活、权限及受影响字段的当前值；执行中禁重复提交。固定集合中对象被删除/权限失效必须报不可执行，不能以重新搜索补足数量。
2. 可共同保存的本地设置作为组处理；外部操作分别反映真实结果。当前 `UserDefaults` 逐项写入并未提供这种事务能力，需要独立实现与故障验证，不能声称通过 `ModelChanges` 就能原子保存任意设置。
3. 冲突逐字段比较编辑基线、当前实际值、待提交值；无关字段变化不造成不必要冲突。提供采用当前值、明确确认自己的修改、继续编辑。对象删除和权限失效不能强行覆盖；确认自己的修改仍需重新校验。
4. 无冲突独立项可继续，冲突项与依赖项保留；原子设置组有冲突时整组暂停。正文冲突保留双方内容，不自动拼接。
5. 成功清除已提交草稿，保留原查询；失败与未执行项保留。结果逐项区分本地保存、通知、日历/文件等外部效果。底层已提交但外部效果失败，不得重放本地创建或普通赋值。
6. 重试只针对可重试的失败/未执行步骤，不重复成功项或创建对象。目标身份、操作身份及结果状态应支持本次运行内安全重试；不能凭 `toggle` 或再次调用新增 API 假定幂等。进程重启后的执行恢复不在默认内存草稿承诺中，未知外部结果先核验再重试。
7. 仅底层支持时提供取消执行；收起浮层不等于取消，取消也不自动撤回已提交步骤。
8. 仅真正可恢复的操作提供执行后撤销；撤销前检查后续修改与对象存活，不覆盖用户后来的编辑。文本编辑撤销、完成驻留反悔、业务执行撤销是不同层次。

## 5. 安全与产品边界

- 私密内容、认证、系统权限走现有 `DiaryPrivacy`、`DiaryContent`、`PrivacyAccess`、`PrivacyVault` 及相应服务，不让搜索索引、预览、模板、诊断或历史绕开遮罩与锁定。锁定/认证代次变化后使不再有效的预览和授权失效。
- 密码、密钥不作为可见路径参数，不进入历史或模板；使用现有安全输入和系统认证交互。不可为了完整指令路径把凭据编码进字符串。
- 隐私转换、永久删除、恢复备份等保持独立门禁；新增涉及加密、敏感处理、权限、迁移或跨系统一致性的实现，仍按项目高风险规则单独确认。本设计不是这类实施或真实数据操作的追加授权。
- 附件只接入现有图片能力；任意文件、重命名、转移、替换等扩展不自动加入。剪贴板历史里的文件 URL 仍属现有剪贴板能力，不等于通用附件。
- iCloud 只有当前不同步说明，不能生造开关。统一搜索的日期表达也不意味着改写所有旧捕获入口的自然语言日期规则。
- 已有批量事务、部分撤销或日历幂等能力只能按原适用范围复用，不能宣称已有通用批量重试、冲突处理或执行后撤销。

## 6. 搜索、历史与模板

- 多关键词默认全部满足，可以分别命中不同适用字段；不同筛选维度取交集，同维度明确“任一/全部”。支持精确短语与显式排除条件，语法需与引号标签/转义规则协调。
- 不静默模糊匹配；无结果时可提供近似建议，用户选择后才改查询。剪贴板原有模糊搜索选项需在接入时显式表达，不得让普通统一查询暗中继承它。
- 默认相关性排序，可切换最近排序；排序分四档，时间精度与并列次序以 `ContentQuerySorter` 为准；不能把当前日期倒序当成相关性。
- 结果显示命中片段、命中字段、类型、所属对象；私密投影仍优先于展示丰富度。附件进入同一键盘序列；父子可归组但仍独立选择。
- 最近使用仅持久化功能标识，不默认保存完整输入、正文、对象或路径。支持固定指令和用户主动保存的查询/操作模板。
- 模板只预填，不自动执行；相对日期使用时显示实际日期，失效引用明确提示。主动保存模板时明确展示要保存的字段，敏感凭据始终排除；正文/对象引用的允许范围和私密模板策略需在实施前单独定界。

## 7. 已核实的搜索与公共复用基线

可复用入口以[组件目录](component-catalog.md)和[架构](architecture.md)为准。

## 8. 用户功能覆盖映射

表内分类对应**目标产品能力**，各行的实际状态见 §10 覆盖表。已确认的 `/tasks`、`/diaries`、`/clipboard`、`/go/…`、`/setting/language/chinese` 保持不变；其余稳定 ID、叶子路径与中英文名称/别名以 `CommandCatalog` 为准。同一行中的多个动作必须各有目录条目或明确的参数化动作，不能用该行一个“打开页面”替代。

### 8.1 任务、手记、标签与图片

| ID / 用户功能 → 指令分类 | 已核实业务入口（文件:行 / 符号） | 差距与验证要求 |
|---|---|---|
| <a id="T1"></a>T1 新建任务、编辑/取消标题、备注保存 → 任务写操作 | [DayBoardMutations+Capture.swift](../AreaChain/Features/Tasks/DayBoardMutations+Capture.swift)：6 `addCapturedTodo`、88 `editTodoWithSyntax`、127 `saveNotes`；[TaskRow+Menus.swift](../AreaChain/Features/Tasks/TaskRow+Menus.swift)：45 | 复用 NLP、标签事务与保存反馈；旧标题编辑未写提醒/优先级就保留，标签合并，空备注不覆盖。目标需显式字段模式，不能把替换/追加/清空都交给旧标题解析。验证未指定字段、空白校验、失败留草稿。 |
| <a id="T2"></a>T2 完成/取消完成、完成反悔、改期、设/取消提醒、设/清优先级、标签增删、新建标签、截止时刻设置/清除 → 任务属性 | [DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：115 `toggleTodo/completeTodo`；[TaskRow+Menus.swift](../AreaChain/Features/Tasks/TaskRow+Menus.swift)：111、140、152、222、240；[DayBoardMutations+Convert.swift](../AreaChain/Features/Tasks/DayBoardMutations+Convert.swift)：6 `setDue` | 明确赋值不能用 toggle 重试。父任务完成会完成活子任务，重开父任务不重开子任务（[SwiftDataTaskRepository.swift](../AreaChain/Services/Repositories/SwiftDataTaskRepository.swift)：114）。截止与提醒独立，截止不进日历同步。验证级联与撤销能力、日期/时刻字段、不重复通知。 |
| <a id="T3"></a>T3 复制整条/标题/备注、回收 → 任务动作 | [TaskRow+Actions.swift](../AreaChain/Features/Tasks/TaskRow+Actions.swift)：64 复制；[TaskRow+Menus.swift](../AreaChain/Features/Tasks/TaskRow+Menus.swift)：70 回收 | 复制仍是页面内 `NSPasteboard` 写法，需共用动作结果；回收走现有确认/软删，不当永久删除。验证内容边界、写剪贴板失败和子项同戳软删。 |
| <a id="T4"></a>T4 子任务新增、完成/重开、标题编辑/取消、标签增删、拖动排序、删除 → 子任务 | [TaskDetailSubtasksView.swift](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift)：82、109、155、250；[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：191 子任务包装；[SwiftDataTaskRepository.swift](../AreaChain/Services/Repositories/SwiftDataTaskRepository.swift)：271、315 `toggleSubtaskTag` | 一层、归属待办，新增从空标签开始且只解析标签，编辑合并标签；不具备自己的日期/提醒/优先级。验证独立选择、父对象存活、排序、不能因命中子任务误改父任务。 |
| <a id="T5"></a>T5 快速/结构化新增重复事项；标题/备注/星期/提醒/优先级/标签；启用/暂停、排序、删除 → 习惯定义 | [ResidentsPage.swift](../AreaChain/Features/Workspace/ResidentsPage.swift)：20、45；[RecurringItemEditor.swift](../AreaChain/Features/Workspace/RecurringItemEditor.swift)：104；[DayBoardMutations+Capture.swift](../AreaChain/Features/Tasks/DayBoardMutations+Capture.swift)：30 `addCapturedRoutine`、47 `addRecurringItem` | 结构化至少一个星期；语法值优先于显式草稿字段，需在新预览解释最终值。启用时补暂停期跳过记录，不能视为只改开关。验证星期/停用区间、定义与执行日分离。 |
| <a id="T6"></a>T6 指定日完成/撤回/跳过、月历选择检查日、当前/最佳连击 → 习惯记录/查询 | [SwiftDataRoutineRepository.swift](../AreaChain/Services/Repositories/SwiftDataRoutineRepository.swift)：220 `toggleRoutine`、235 `markRoutineDone`、247 `skipRoutine`、270 `applyCheck`；[HabitCheckMonthView.swift](../AreaChain/Features/Workspace/HabitCheckMonthView.swift)：27 | `skip` 为 done+skipped；单条 `markRoutineDone` 保留 skip，批量 `applyCheck` 清 skip。单条仓储不负责全部启用/排定限制，不能绕开调用层。先核定操作名称的精确语义，再验证历史/未来/非排定/停用日期及重复调用。月历点击是选日期，不是打卡。 |
| <a id="T7"></a>T7 多选今天/明天、完成/未完成、加/移标签、启用/停用、回收、清选择 → 批量任务/习惯 | [WorkspaceBatchActionBar.swift](../AreaChain/Features/Workspace/WorkspaceBatchActionBar.swift)：36、61 `AgendaProjection.capability`、102 分日；[DayBoardMutations+Batch.swift](../AreaChain/Features/Tasks/DayBoardMutations+Batch.swift)：22、60、97、132 | 现有批量接口只处理 Todo/Routine；习惯按每条真实检查日分组，正向完成检查排定/启用。当前今日/顶部搜索无批量栏，不能当新统一结果批量已存在。验证固定目标、混合适用子集、跨日失败与未完成参数，不静默忽略子任务。 |
| <a id="T8"></a>T8 待办↔重复事项转换 → 对象转换 | [DayBoardMutations+Convert.swift](../AreaChain/Features/Tasks/DayBoardMutations+Convert.swift)：30 `convertTodoToRoutine`、64 `convertRoutineToTodo` | 新建新 ID 并软删原对象，非原 ID 改类型；待办转习惯把活子任务按顺序变成模板（新 ID、不保留完成态）、移交活附件、按原日期取星期，不迁移截止/完成态；反向新建今天待办，模板变成未完成的新子任务。预览字段损失与关联变化，验证旧对象/附件、重试不重复创建。 |
| <a id="T9"></a>T9 今日/昨天/即将展开、昨天全部延至今日；筛选/清筛选；全部事项种类和状态；列表选择/排序 → 查询/批量/排序 | [TasksPage.swift](../AreaChain/Features/Tasks/TasksPage.swift)、[DayBoardList.swift](../AreaChain/Features/Tasks/DayBoardList.swift)；[WorkspacePendingView.swift](../AreaChain/Features/Workspace/WorkspacePendingView.swift)：61；[WorkspaceAllItemsView.swift](../AreaChain/Features/Workspace/WorkspaceAllItemsView.swift)：51；[DayBoardMutations+Convert.swift](../AreaChain/Features/Tasks/DayBoardMutations+Convert.swift)：13 `applyManualOrder` | 复用 `BoardFilter`、`ItemsListing`、`AgendaProjection`、`ManualOrder`；标签、优先级、来源、日期、提醒等适用维度同步查询；完成状态与习惯启用状态不能混为一个状态。验证页内状态与查询往返、混排手动排序、昨天习惯真实检查日；“全部延至今日”只改适用待办。 |
| <a id="T10"></a>T10 剪贴板加今天 → 单次捕获 | [ClipboardCapture.swift](../AreaChain/Services/ClipboardCapture.swift)：39 `ingest`；[Classification.swift](../AreaChain/Domain/Classification.swift) | 有文字只取文字、仅图片才挂图；保留原文，仅解析普通标签，不走任务时间/优先级 NLP；可按偏好附来源 Bundle ID。不同于剪贴板历史和正文粘贴。验证文字+图片优先级、事务/文件失败及重试身份。 |
| <a id="B1"></a>B1 日历月/周切换、上/下月或周、回今天、选日/入日清单、指定日新增、拖拽改期 → 规划导航/任务动作 | [CalendarPage.swift](../AreaChain/Features/Calendar/CalendarPage.swift)：72 页头、288 `addTodo`、294 `selectDayFromGrid`、299 `enterDayList`、314 `dropTodo`；[CalendarWeekBoard.swift](../AreaChain/Features/Calendar/CalendarWeekBoard.swift)：72 | 改期复用 `moveTodo`，只接受待办；选日期导航不改模型。验证六周月历、窄窗、周跨月、保存失败不改选日及原任务草稿。 |
| <a id="B2"></a>B2 四象限按日浏览/翻日、指定象限新增、拖动改优先级、完成、检查器、全文气泡复制 → 规划/优先级/复制 | [QuadrantPage.swift](../AreaChain/Features/Quadrant/QuadrantPage.swift)：100 `copyPreview`、215 `addTodo`、223 `toggle`、251 `apply` | 复用 `addCapturedTodo(fallbackQuadrant:)`、`applyQuadrant`；正文显式优先级胜过所在格子，只展示当日未完成项。验证具体日期、习惯排定、复制与输入优先级。 |
| <a id="B3"></a>B3 安排页翻月/回本月、单选/多选/范围选、同天数平移、完成已选任务、打开检查器 → 安排/批量改期 | [GanttPage.swift](../AreaChain/Features/Gantt/GanttPage.swift)：188 `handle`、213 `completeSelected`、226 `commitDrag`；[GanttRescheduling.swift](../AreaChain/Features/Gantt/GanttRescheduling.swift)：6 `commit` | 单日任务色块，平移保间隔且限当前月，拖动失败整组回滚；已有原日期/完成/删除基线检查。完成选中项仍逐条 toggle，非通用原子批量；习惯点只是排定提示。验证越界、取消/失焦、外部改期与混合目标，不扩成工期/依赖管理。 |
| <a id="J1"></a>J1 手记新建、全文编辑/追加/清空、显式保存、重载/舍弃冲突草稿、标签与快速新增拆分（标题／正文与 #标签）→ 手记正文 | [SwiftDataDiaryRepository.swift](../AreaChain/Services/Repositories/SwiftDataDiaryRepository.swift)：66 新增、86 编辑、201 `writeContent`；[DiaryEditorSession.swift](../AreaChain/Features/Diary/DiaryEditorSession.swift)：109、163 保存/冲突 | 当前新建/全文编辑已存在，追加/清空是新指令字段模式，受正文校验约束；复用会话而非绕过它直写仓储。新建自动分类、编辑追加语法标签。验证空白、长正文、外部冲突、保存失败与锁定封存。 |
| <a id="J2"></a>J2 记录置顶/取消、改今天/昨天/明天/任意日、加/移标签、显示/遮罩、“私密”标记 → 手记组织 | [DiaryOrganizeMenus.swift](../AreaChain/Features/Diary/DiaryOrganizeMenus.swift)：27；[DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)：244、293；[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：465 `moveDiary`、472 `togglePrivateDiary` | `isPinned` 是排序；窗口置顶另见 N4。“私密”标记只切 `isPrivate`，不等于启用/解除加密，真正保护按 P1–P3。验证日期/标签未指定不变、标记/遮罩/加密区分。 |
| <a id="J3"></a>J3 复制整篇/标题/备注、转今天任务、回收 → 手记动作 | [DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)：374 复制；[PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift)：127 `PrivacyAccess.withDiary`；[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：435 `convertDiaryToTodo` | 复制重查活记录并经 `PrivateClipboard`；转任务拒绝敏感/受保护及标签读取失败，首行标题/余文备注、保留原手记、不带标签/附件、不做 NLP。验证保护门禁、失效对象、复制标记、无副作用拒绝及新建重试。 |
| <a id="G1"></a>G1 标签新建/取消、改名、颜色、拖动排序、搜索与全部/常用/最近/未使用/已删除视图 → 标签/查询 | [TagManagementPage.swift](../AreaChain/Features/Workspace/TagManagementPage.swift)：66、91、158、214、254；[SwiftDataCatalogRepository.swift](../AreaChain/Services/Repositories/SwiftDataCatalogRepository.swift)：41、101、132、172、193 | 标签规范化用 `TagSyntax`；预置标签不能改名/改色/合并，已有多选改色。标签页筛选框有意保留（见 §1）；已删除视图映射显式回收范围。验证名称冲突、预置限制、选择/排序与筛选上下文。 |
| <a id="G2"></a>G2 合并、对象解绑、全局解绑能力、软删/恢复/彻底删、清理未使用 → 标签整理 | [TagManagementPage.swift](../AreaChain/Features/Workspace/TagManagementPage.swift)：283、299、440 `commitCleanup`；[SwiftDataCatalogRepository.swift](../AreaChain/Services/Repositories/SwiftDataCatalogRepository.swift)：166 `unlinkTag`、178 `mergeTags`；[Catalog.swift](../AreaChain/Domain/Catalog.swift)：78、252 | 合并同事务替换四类关联并去重/软删来源，含墓碑与编码归一化；软删保关联、彻底删解绑。对象解绑已有入口，全局解绑仅仓储有、未发现独立 UI，不能谎称现有用户功能。清理为未使用标签软删，当前也包含未使用预置标签，选择逻辑仍在页面。验证固定范围、四类关联、合并到私密标签的安全契约，后者未确认不可直接开放。 |
| <a id="A1"></a>A1 选图、粘贴图、截图、原图预览、附件中心分组浏览、回收 → 图片附件 | [AttachmentPicker.swift](../AreaChain/Features/Attachments/AttachmentPicker.swift)：23 `pickDiaryImage`、39 选图、51 粘贴、86 `saveImage`、102 截图、134 `AttachmentActions` 别名；[ScreenCapture.swift](../AreaChain/Services/ScreenCapture.swift)：7、25；[AttachmentBrowserPage.swift](../AreaChain/Features/Attachments/AttachmentBrowserPage.swift)：51、72 | 单选 PNG/JPEG/HEIC/GIF/TIFF/WebP；粘贴/截图转 PNG，截图为鼠标所在整屏静图无光标。任务/习惯行提供截图，手记选图回调重鉴权；唯一活父对象+类型校验，失败清新文件。集中浏览排除敏感手记图，解锁后也不混入；无附件批量/改名/转属/导出 UI。验证权限失败、锁定/删父/重复 UUID、文件/模型回滚和统一搜索相同可见性。 |

需要在业务接入前明确的现状差异：习惯“完成”路径对 skip 的不同处理；标签合并只改关联并未调用保护转换；全局解绑只有仓储入口；清理名称中的 `unusedOrdinary` 实际不排除预置标签。以上按源码保留事实，不根据命名猜规范，也不借统一入口扩大用户授权。

### 8.2 剪贴板历史

| ID / 用户功能 → 指令分类 | 已核实业务入口（文件:行 / 符号） | 差距与验证要求 |
|---|---|---|
| <a id="C1"></a>C1 浏览文字、图片、文件路径、来源 App 与片段；搜索纯文本 → `/clipboard` 查询 | [ClipboardHistoryBrowser.swift](../AreaChain/Features/Clipboard/ClipboardHistoryBrowser.swift)：38 搜索、88 列表、165 预览；[ClipboardHistory.swift](../AreaChain/Domain/ClipboardHistory.swift)：242 `filtered` 相关搜索规则 | 当前独立查询，三种模式只匹配 `plainText`；HTML/RTF 是保留/回写能力，不是富文本渲染搜索。支持混合模糊/精确/正则，接入统一结果时模式必须可见，普通查询不暗中模糊。文件路径不变成任意附件支持。验证三模式、无效正则、命中片段及默认全局排除。 |
| <a id="C2"></a>C2 复制、粘贴、纯文本粘贴 → 剪贴板动作 | [ClipboardHistoryBrowser.swift](../AreaChain/Features/Clipboard/ClipboardHistoryBrowser.swift)：145 行菜单；[ClipboardHistoryPanel.swift](../AreaChain/Features/Clipboard/ClipboardHistoryPanel.swift)：189 `commit`；[ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift) `stage` | 复制先写剪贴板，直接粘贴再请求辅助功能并发按键；没有目标应用接收回执。工作台分支仅清第一响应者，需隔离接收端验证，不能把按键已发送说成粘贴已完成。 |
| <a id="C3"></a>C3 置顶/取消置顶、空查询按置顶字母快捷复制、删除、清空未置顶/全部 → 历史整理 | [ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift)；[ClipboardHistory.swift](../AreaChain/Domain/ClipboardHistory.swift)：274–308 置顶/上限规则；[ClipboardHistoryPage.swift](../AreaChain/Features/Clipboard/ClipboardHistoryPage.swift)：61 页头 | 置顶不占普通上限，a–z 用尽后仍可置顶但无新字母；字母键会复制并在小窗关闭窗口（也适用于工作台历史页），不是只读定位。现有删除/清空没有撤销。新入口须固定集合、明确破坏性确认及结果，不承诺可撤销。验证上限、字母耗尽、部分失败。 |
| <a id="C4"></a>C4 记录暂停/继续、跳过下一次、忽略来源 App → 监听控制 | [ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift)：34、253；[StatusItemController.swift](../AreaChain/Services/StatusItemController.swift)：98、120 Option 点击 | 默认记录开启；跳过下一次只消费下一次通过屏蔽规则的有效复制；强制忽略密码管理器、concealed/transient、自身回写。验证暂停/屏蔽不消耗跳过，不能经指令解除安全过滤。 |
| <a id="C5"></a>C5 所有历史偏好 → 剪贴板设置 | [ClipboardHistoryOptions.swift](../AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift)：33 `options`；[ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift)：108 setters | 完整选项：忽略通用剪贴板；条数 20–999（默认 200）；检查间隔 0.1–2 秒（默认 0.5）；混合/精确/正则搜索；指针旁/居中；点击复制/粘贴；默认纯文本；提示音；移除忽略 App；忽略正则新增/校验/移除；额外剪贴板类型新增/移除。当前逐项立即保存，“取消”只关闭。需共用可校验业务入口，批量设置失败与撤销不能照搬 sheet 标题语义。 |
| <a id="C6"></a>C6 打开/关闭历史小窗、置顶/取消窗口置顶、返回工作台 → 窗口 | [ClipboardHistoryPanel.swift](../AreaChain/Features/Clipboard/ClipboardHistoryPanel.swift)：31 `toggle`、47 `setStaysOnTop`、56 `closeReturning`、136 返回工作台 | 当前与工作台共用 `ClipboardHistorySession`，小窗默认置顶、失焦不关；目标统一查询会话需与历史存储/窗口偏好分离。固定键、前台交还与输入组件优先级需原生验证。 |

现有历史存储是 [ClipboardHistoryStore.swift](../AreaChain/Services/ClipboardHistoryStore.swift)：8，独立 `history.json` 与图片，不进入 SwiftData/JSON 导出/加密备份，也不随手记锁定；`load`（13）失败返回空数组，不能把读取失败当作真实空历史。这是统一结果错误反馈的已知缺口。

### 8.3 设置、通知、日历与快捷键

| ID / 用户功能 → 指令分类 | 已核实业务入口（文件:行 / 符号） | 差距与验证要求 |
|---|---|---|
| <a id="S1"></a>S1 语言、外观、标题省略、捕获来源 → `/setting/…` | [SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift)：15 `GeneralSettingsSection`；[AppPreferences.swift](../AreaChain/Services/AppPreferences.swift)：75 偏好属性 | 语言：系统/简中/英文；外观：系统/浅/深；四象限长标题：尾部/中间；剪贴板捕获附来源开/关。默认系统、系统、尾部、来源关。`didSet` 即写偏好/发通知，无统一事务、失败结果与撤销。验证当前→新值、共同保存及原设置页等价。 |
| <a id="S2"></a>S2 登录启动开/关、打开登录项系统设置 → 系统设置动作 | [SettingsView.swift](../AreaChain/Features/Settings/SettingsView.swift)：91 `updateLoginItem`；[SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift)：73 | `SMAppService` 注册/注销，失败回读真实状态，待批准时引导系统设置；需提取共用动作。验证拒绝/批准/取消及实际状态，不归入普通偏好原子组。 |
| <a id="S3"></a>S3 查看通知权限、请求权限、测试通知、打开通知系统设置 → 通知管理 | [SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift)：108、132；[NotificationScheduler.swift](../AreaChain/Services/NotificationScheduler.swift)：204 `requestAuthorizationAndRefresh`、220 `deliverTestBanner` | 没有应用内通知总开关。已拒绝不重复请求；测试横幅独立 ID，不清既有提醒。验证重复点击、失败、拒绝、发送请求与真实送达区分。 |
| <a id="S4"></a>S4 通知事项完成、延后 10 分钟/1 小时、点横幅打开 → 提醒动作/导航 | [NotificationScheduler.swift](../AreaChain/Services/NotificationScheduler.swift)：78 分类、252 `didReceive`；[ReminderFollowUpStore.swift](../AreaChain/Services/ReminderFollowUpStore.swift) | 完成用 `DayBoardMutations.completeTodo/markRoutineDone`；延后不改持久提醒时刻。需共享安全可调用动作与结果，验证过期对象、具体日期、跨日及重复请求。 |
| <a id="S5"></a>S5 日历同步开/关、状态、重试、系统权限设置、冲突对照/打开本地项 → 日历集成 | [SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift)：159、205 `CalendarConflictList`；[CalendarSync.swift](../AreaChain/Services/CalendarSync.swift)：30 `refreshIfEnabled`；[CalendarSyncCoordinator.swift](../AreaChain/Services/CalendarSyncCoordinator.swift)：19 `request`、40 `stop` | 只同步未完成待办的标题、`dayKey`、提醒，关闭不删已同步事件。当前冲突只对照，不能直接“采用某侧”。复用引擎但补执行结果；验证部分成功、停用/迟到结果与基线重试，不声称跨 EventKit/SwiftData/文件原子回滚。 |
| <a id="S6"></a>S6 查看 iCloud 说明 → 信息 | [SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift)：188 | 只有不同步说明，无开关/账号/同步动作。目录仅提供说明；验证不会写虚假偏好。 |
| <a id="S7"></a>S7 全局/应用内快捷键录制、单项恢复、全部恢复、取消录制 → 快捷键配置 | [ShortcutCatalog.swift](../AreaChain/Domain/ShortcutCatalog.swift)：111、182、227；[ShortcutStore.swift](../AreaChain/Services/ShortcutStore.swift)：35 `assign`、45 `reset`、54 `resetAll`；[HotKeyRecorder.swift](../AreaChain/Features/Settings/HotKeyRecorder.swift)：24、56 | 全局 4 项与应用内 12 项见下文；同作用域最新分配优先，注册失败保留组合但停用。验证冲突、无效组合、输入优先级和所有消费者，不能把快捷键目录当统一执行器。 |

全局四项：浮层开关、剪贴板加今天、显示工作台、剪贴板历史，默认未绑定。应用内十二项：搜索、筛选、工作台、语法帮助、设置、退出、记手记、保存手记小窗、打开手记、复制手记、清单全选、手记移入回收站。固定方向键、Return、Esc、Delete、备注 ⌘Return，以及剪贴板历史的复制/粘贴/置顶组合不在可重录目录内，仍需纳入键盘回归；不能为了通用指令吞掉原生编辑按键。可重录退出只在浮层有显式消费，工作台/手记小窗与原生退出菜单的一致性尚需组合场景验证。

### 8.4 隐私、回收站与数据恢复

本组标注目录不代表获得实施或执行授权；凭据走安全交互，不能进入可回显路径。

| ID / 用户功能 → 指令分类 | 已核实业务入口（文件:行 / 符号） | 差距与验证要求 |
|---|---|---|
| <a id="P1"></a>P1 创建私密锁、选择系统/主密码解锁、选择私密标签、纳入旧敏感手记 → 独立安全流程 | [PrivacySetupSheet.swift](../AreaChain/Features/Settings/PrivacySetupSheet.swift)：37、77、95、125；[DiaryProtection.swift](../AreaChain/Services/Privacy/DiaryProtection.swift)：48 `applyTagsAsync` | 涉及转换时先验证加密备份；已有受保护记录但缺配置不允许重建锁。复用既有认证/转换，不进入普通队列。验证备份过期、取消、锁变化与失败回滚。 |
| <a id="P2"></a>P2 锁定/解锁、启用/关闭系统解锁、设置/修改/移除主密码、闲置时长、管理私密标签 → 隐私管理 | [PrivacySettingsSection.swift](../AreaChain/Features/Settings/PrivacySettingsSection.swift)：130；[PrivacyVaultMethods.swift](../AreaChain/Services/Privacy/PrivacyVaultMethods.swift)：73、94；[PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift)：12 `request` | 闲置 1/5/15 分钟；不能删除最后解锁方式，移除一种须实际验证保留方式；没有关闭整个私密锁或云找回。验证强制新鲜认证、失效/迟到认证、未保存草稿封存与敏感参数排除。 |
| <a id="P3"></a>P3 显式解除单条手记保护 → 独立隐私转换 | [DiaryProtection.swift](../AreaChain/Services/Privacy/DiaryProtection.swift)：80 `unprotect` | 新鲜认证且不再命中私密标签；移除标签不会自动解除保护。验证原规则、暂存图片、失败与备份门禁，不能改成普通布尔字段赋值。 |
| <a id="P4"></a>P4 旧附件清理重试、系统密钥清理重试、退出以完成数据库清理 → 安全维护 | [PrivacySettingsSection.swift](../AreaChain/Features/Settings/PrivacySettingsSection.swift)：90、116；[PrivacyStoreMaintenance.swift](../AreaChain/Services/Privacy/PrivacyStoreMaintenance.swift) | 冷启动清理与日常保存分开；保留失败标记。不将“退出”混入普通队列。验证重试和部分清理状态，真实钥匙串/磁盘操作单独授权。 |
| <a id="D1"></a>D1 浏览回收站、单项恢复、永久删除、清空 → 显式已删除范围/独立删除 | [TrashPage.swift](../AreaChain/Features/Trash/TrashPage.swift)：67、139、173、195、307；[AttachmentCleanup.swift](../AreaChain/Services/AttachmentCleanup.swift) `emptyListed` | 五组为待办/习惯/手记/附件/标签，子任务跟父项恢复规则；父项不活跃时附件不能单独恢复。当前无多选恢复/删除撤销 UI。验证软删戳、关联解绑、隐私投影、清文件失败保留元数据和固定目标，不承诺永久删除可撤销。 |
| <a id="D2"></a>D2 JSON 导出、选文件导入、校验/新增覆盖预览、确认导入 → 独立数据交换 | [DataBackupView.swift](../AreaChain/Features/Settings/DataBackupView.swift)：134、146、155、166；[SyncPort.swift](../AreaChain/Services/SyncPort.swift)：13 `makeSnapshot`；[SnapshotImporter.swift](../AreaChain/Services/SnapshotImporter.swift)：24 `apply` | 普通 JSON 排除敏感手记/相关附件，不含图片二进制，包含软删与普通附件元数据；同 UUID 覆盖，非全库替换。已有编辑先保存，导入失败只回滚导入；无逐项冲突取舍/撤销。验证旧日期兼容、重复标识、父子归属和预览后外部变动。 |
| <a id="D3"></a>D3 加密备份导出、检查、预览确认恢复 → 独立备份恢复 | [DataBackupView.swift](../AreaChain/Features/Settings/DataBackupView.swift)：222、243；[PrivateBackupService.swift](../AreaChain/Services/Privacy/PrivateBackupService.swift)：6 `export`、25 `inspect`、31 `restore`；[PrivateBackupFile.swift](../AreaChain/Services/Privacy/PrivateBackupFile.swift)：45 | 独立口令，图片纳入，恢复是合并且按目标锁处理，暂存/回读验证。底层支持取消，现 UI 忙碌时禁取消且不存句柄；提交后清理失败可抛错，需区分已恢复与清理待重试。验证取消、错误口令、损坏、并发修改、提交后失败。 |
| <a id="D4"></a>D4 内存降级提示、“重置并退出” → 独立异常恢复门禁 | [Persistence.swift](../AreaChain/Services/Persistence.swift)：14 `makeSession`、41 `resetStoreOnDisk`；[DataBackupView.swift](../AreaChain/Features/Settings/DataBackupView.swift)：102、217 | 只在磁盘库失败降级时显示；删除库/shm/wal、日历基线与附件目录，逐项 `try?`，没有完整失败结果/自动备份/回滚。不能把调用返回视为恢复成功，也不能一般化为“清缓存”。后续先单独设计恢复点与失败反馈，真实操作须明确授权。 |

已核实的待确认差异：加密备份服务允许未配置私密锁时导出，但当前 UI 无条件认证，`PrivacyUnlockPresenter` 对未配置锁拒绝；因此未配置状态的 UI 导出可达性需要隔离复现与产品决定，不能为此绕过认证。JSON 文件导出当前不是原子写入，导入失败会清待导入预览；接入新执行结果时需保持数据事实，不能把这些现状宣传成目标失败恢复契约。

### 8.5 导航、窗口、总览、帮助与退出

| ID / 用户功能 → 指令分类 | 已核实业务入口（文件:行 / 符号） | 差距与验证要求 |
|---|---|---|
| <a id="N1"></a>N1 全页面与标签清单导航 → `/go/…` | [WorkspaceNavigation.swift](../AreaChain/Features/Workspace/WorkspaceNavigation.swift)：3 `WorkspaceTab`、257 `revealTab`；[MainSplitWorkspaceView.swift](../AreaChain/Features/Workspace/MainSplitWorkspaceView.swift)：132 视图路由 | 16 页：总览、今日、待处理、全部事项、日历、四象限、安排、手记、附件、剪贴板、标签、隐私、数据备份、回收站、设置、快捷键；标签专属列表另按 `selectedTagID` 路由。当前活动查询优先显示结果，而 `revealTab` 不清查询；需明确“显示目标页面”与“保留独立查询”两种状态，验收搜索中导航。 |
| <a id="N2"></a>N2 工作台显示/前置/关闭、浮层开关及任务/手记切换、重复事项新增/管理面板 → 窗口/面板 | [AppWindows.swift](../AreaChain/Services/AppWindows.swift)：16 `openWorkspace`、28 `revealWorkspace`；[FooterBar.swift](../AreaChain/Features/MenuBar/FooterBar.swift)：238、253；[WorkspaceTodayView.swift](../AreaChain/Features/Workspace/WorkspaceTodayView.swift)：83 | `openWorkspace` 默认总览，`revealWorkspace` 保留当前页；底栏按浮层页开今日/手记。重复事项面板非独立侧栏页。关闭工作台保留其他业务窗口，不等于退出；指令与原按钮共用路由并保护草稿。 |
| <a id="N3"></a>N3 检查器打开/关闭、选择对象/日期，列表全选/取消选择 → 检查/选择 | [WorkspaceNavigation.swift](../AreaChain/Features/Workspace/WorkspaceNavigation.swift)：203、207 `updateInspectorTargets`、277 `inspectTask`、291 `closeInspector`；[WorkspaceHeaderContent.swift](../AreaChain/Features/Workspace/WorkspaceHeaderContent.swift)：62 | 目标必须在当前投影登记，切页/查询使失效目标不可检查；子任务定位父任务但保持子任务身份。验证失效 ID、具体检查日、空选择、选择范围及不重复提交。 |
| <a id="N4"></a>N4 单条手记打开/新草稿转小窗、窗口置顶、保存/关闭 → 手记窗口 | [DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift)：14 `open`、22 `openDraft`、108 置顶、117 关闭确认 | 按记录/draft ID 复用，先窗口持有再清来源；窗口置顶不改记录置顶。可复用所有权思路，但没有通用“在工作台继续”协议。验证目标已有草稿、保存失败、关闭取消和单一提交所有权。 |
| <a id="N5"></a>N5 今日进度、逾期/即将、连击/重复数、手记数、7 日趋势、365 日热力图、活动定位 → 总览查询/导航 | [DashboardSummarySection.swift](../AreaChain/Features/Dashboard/DashboardSummarySection.swift)：50、76；[DashboardNavigation.swift](../AreaChain/Features/Dashboard/DashboardNavigation.swift)：5、18、29；[DashboardView.swift](../AreaChain/Features/Dashboard/DashboardView.swift)：61 | 使用 `DashboardProjection`，活动是派生统计非持久日志；热力日期开日历，活动开检查器/小窗/回收站，失效手记回列表。提供统计结果与导航，不另写统计规则；验证日期和失效记录。 |
| <a id="N6"></a>N6 语法帮助、页面说明、示例预填 → 帮助 | [MenuBarPopoverView.swift](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift)：164、246；[WorkspaceHeaderContent.swift](../AreaChain/Features/Workspace/WorkspaceHeaderContent.swift)：69；[WorkspaceHeaderBar.swift](../AreaChain/Features/Workspace/WorkspaceHeaderBar.swift)：56 | 现有帮助依宿主/搜索状态不同，示例可回填捕获框；目标帮助与完整目录同步，预填不执行。验证脏草稿处理、焦点与双语。 |
| <a id="N7"></a>N7 版本/关于、使用讨论、功能建议、报告问题、仓库、许可证 → 信息/外部链接 | [ProjectSupport.swift](../AreaChain/Domain/ProjectSupport.swift)：5；[ProjectSupportSections.swift](../AreaChain/Features/Settings/ProjectSupportSections.swift)：24、35、74、127 | 反馈只复制版本/构建/macOS/语言并打开表单，不自动提交。复用 URL 与报告构造，分别显示复制/外部打开结果，不能加入用户正文或日志。 |
| <a id="N8"></a>N8 退出与未保存确认 → 独立生命周期动作 | [AreaChainApp.swift](../AreaChain/App/AreaChainApp.swift)：69 `applicationShouldTerminate`；[DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift)：41 `confirmTermination` | 退出防重入、先确认再处理脏手记小窗与共享手记 composer；没有汇总任务捕获、检查器标题/备注、卡片等所有草稿。统一会话必须补入关闭/退出保护，验证部分保存后取消、失败不退出。 |

## 9. 实施依赖、验收与未决项

### 9.1 建议的分阶段边界

阶段是依赖与验收单位，不是每阶段自动获得下一阶段授权。未完成的目录能力持续标记，不把小范围试点算作全体系交付。

| 阶段 | 准确目标与建议修改范围 | 前置与退出条件 |
|---|---|---|
| 0（设计基线） | 已确认决定、功能映射与文档引用 | 已完成。 |
| 1（领域协议） | 指令目录与类型化参数、路径解析与补全、内容查询语法与页面查询状态、操作草稿与编辑保护、待执行计划与执行生命周期、跨入口主动转交 | 已实现。纯领域协议，静态校验不授予业务权限；稳定 ID、参数和能力声明是后续解析、补全、草稿的唯一来源。 |
| 2（只读数据） | 待办、子任务、习惯、手记、图片、标签、剪贴板、回收站各自的只读提供者，同批聚合、排序、摘要与分页，以及 SwiftData／文件只读适配 | 已实现并接入正式版；读取仍在主线程同步进行，性能基线未建立。 |
| 3 | 从现有按钮/菜单/设置提取缺少的共用业务动作，建立校验、预览、执行结果、字段冲突、重试身份与可撤销能力；先处理授权范围内的本地普通操作 | 依赖 1；保留旧入口契约，仓储/`ModelChanges` 注入测试；逐动作检验相同输入产生相同写入与副作用次数。安全、权限和跨系统一致性改造单独审批，不能随普通提取潜入。 |
| 4 | 两宿主共享搜索与指令发现 UI，任务页默认条件与筛选双向同步，统一结果与键盘 | 已完成。旧全局搜索已删除；页内筛选有意保留，不与查询双向同步（见 §1）；受限选择器不冒充普通搜索。 |
| 5 | 可编辑预览与长正文、操作草稿、多字段/多对象/多设置、队列执行、冲突处理、真实撤销、关闭/退出与主动转交 | 依赖 3、4；故障注入验证固定集合、未完成参数、顺序合并、依赖暂停、部分成功重试不重复创建、目标草稿不覆盖和唯一提交所有权。设置事务先有证据再开放多设置提交。 |
| 6 | 通知/日历、剪贴板外部粘贴、权限与隐私、回收站永久动作、导入/备份/恢复等独立流程 | 有意不做。这些流程由原页面完成，指令只打开原页面；某一项确有需要时单独立项，届时依赖相应业务适配与明确授权，区分本地/外部成功，安全/真实系统证据分别报告。 |
| 7 | 最近功能标识、固定指令、用户主动保存的查询/操作模板；全目录验收与文档收口 | 依赖稳定 ID/语法及模板数据边界决定；模板仅预填、相对日期/失效引用可见、无默认敏感历史；第 8 节逐项入口等价并完成原生矩阵，才可称全体系交付。 |

搜索实现与业务动作提取可在契约稳定后按独立范围安排，但生产入口开放必须等待相应执行/失败契约。实施不要求新增框架、包、模型表或磁盘草稿；确有必要时另论证与授权。

### 9.2 领域协议的验收案例

领域协议分三块：目录、参数与能力声明；解析/补全及查询状态转移；草稿、计划和转交契约。它们都**不直接改现有设置绑定、不触碰私密锁/持久化**。目录每项至少包含稳定 ID、规范路径、中文/英文名称与别名、分类、适用范围/目标类型、必需参数、字段模式、预览要素、风险/授权、能否排队、重试/撤销能力声明及现有业务出处。声明“待实现”不得伪装成 handler 已可执行。

最小验收案例：

1. `/`、`/set`、`/setting`、完整语言路径及中文别名补全；普通文本、引号/转义、标签、未知路径保留可编辑诊断，不静默执行。
2. 默认 `/tasks` 不激活结果，主动条件激活；删范围后同页刷新不补回；切页保留关键词；用户范围不覆盖；改范围/退出页面绑定不回写旧筛选；清查询返回原页面。
3. 操作草稿与查询隔离：切页不能改目标/正文；“未指定/清空/多个不同值”可区分；设置组合、正文追加、习惯具体日期和固定多对象集合均可表达。
4. 提交/授权/执行/成功/失败/冲突/未执行状态、依赖与重试身份可表达；成功项不重放，普通赋值合并但顺序动作不丢；转交目标占用/执行中/授权中拒绝，失败源保留，成功单一所有权。
5. 全量目录覆盖第 8 节每一动作；范围不会隐藏全局指令；受限选择器限制显式；凭据不进入可序列化参数/历史模板。

实际修改 Swift 后按[验收技能](../.agents/skills/areachain-verify/SKILL.md)跑相应 Domain 定向测试、必要构建及静态门禁；公共契约/复杂状态实现后交 Claude Code `verifier` 独立只读复核（见[技能路由](../skill-routing.md#指定只读复核入口)），不以静态阅读替代独立复核。

### 9.3 后续回归入口与证据缺口

以下是各领域的既有回归入口。测试存在不能证明新增目标已经被覆盖。

| 领域 | 现有测试入口 | 必须补齐的目标证据 |
|---|---|---|
| 查询/语法/日期 | [Domain 测试](../AreaChainTests/Domain)：`BoardSearchTests`、`UnifiedSearchTests`、`SyntaxAutocompleteTests`、`TagSyntaxTests`、`DayKeyTests` | 完整目录、范围来源/激活、短语与排除、排序案例、全部对象类型与跨字段片段。 |
| 公共 UI/键盘 | [Theme 测试](../AreaChainTests/Theme)：`SyntaxOverlayPlacementTests`、`DaybookTextFieldSearchTests`；[Features 测试](../AreaChainTests/Features)：`InputSyntaxInteractionTests`、`MenuBarSearchShortcutTests`、`WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests` | 上补全下预览并存、附件键盘序列、输入法/撤销、Return 与 ⌘Return、Esc 分层、不抢焦点、页面滚动和所有宿主语言/主题/尺寸矩阵。 |
| 任务/规划/标签/图片 | Services `InputSyntaxPersistenceTests`、`AttachmentOwnerLookupTests`；Domain `ManualOrderConversionTests`、`DiaryMutationsTests`、`TagCatalogTests`；Features `SubtaskTitleEditingTests`、`RecurringItemEditorTests`、`CalendarMonthNavigationTests`、`GanttInteractionTests`、`GanttReschedulingTests`、`QuadrantLayoutTests` | 转换不重复创建、父子完成与恢复、习惯 skip 差异、检查日、日历/安排改期与取消、预置标签清理范围、合并私密标签门禁、截图及文件面板回调鉴权。 |
| 草稿/生命周期 | `DiaryEditorSessionTests`、`DiaryWindowLifecycleTests`、`AppTerminationTests`、`PrivacyInteractionTests`（Features） | 通用操作草稿、非手记草稿保护、转交冲突、目标已占用、部分保存后取消及执行中关闭。 |
| 业务事务 | [Services 测试](../AreaChainTests/Services)：`ModelChangesTests`、`SwiftDataTaskRepositoryTests`、`SwiftDataRoutineRepositoryTests`、`SwiftDataCatalogDiaryRepositoryTests`；Domain `BatchMutationsTests` | 字段冲突、设置组、顺序队列、幂等重试、部分成功、可恢复撤销与原按钮等价。 |
| 剪贴板/设置/导航 | Domain `ClipboardHistoryTests`、`ShortcutCatalogTests`、`ProjectSupportTests`；Services `AppPreferencesTests`、`ShortcutStoreTests`、`AppWindowsRoutingTests`；Features `SettingsSectionPresentationTests`、`ShortcutsPageTests`、`DashboardInteractionTests` | 工作台粘贴接收端、历史读取失败、设置批量失败、搜索中显式导航、快捷键作用域和外部打开失败。 |
| 通知/日历 | Services `NotificationSchedulerTests`、`CalendarSyncEngineTests` | 原 UI/指令等价、局部成功、冲突和过期对象；真实送达、权限与真实日历单独验收。 |
| 隐私/数据/恢复 | Services `PrivacyVaultTests`、`PrivacyPersistenceTests`、`PrivacyStoreMaintenanceTests`、`SnapshotImportValidationTests`、`PrivateBackupTests`、`PrivateBackupCancellationTests`、`AttachmentCleanupTests`；Features `DataBackupInteractionTests`；Domain `SoftDeleteTests` | 安全参数排除、失效认证、未配置备份可达性、取消/提交后清理失败、固定目标恢复和重置失败；真实数据与系统凭据不属于普通自动测试。 |

新查询的端到端延迟、长文编辑、最大候选/目标规模、内存及排序权重尚未测量；沿[性能基线](performance-baselines.json)的方法使用合成数据建立，不能借用旧查询耗时保证新体系性能。

### 9.4 未决问题与单独授权边界

- **已定稿**：内容文法、`/tasks` 范围组成、日期字段与页面访问寿命以查询实现为准；习惯完成与跳过的编码见“仍有效的决定”；`tag.merge` 指令涉及私密或预置标签时整条拒绝，这类合并到原标签页完成。
- **目录仍未定稿**：`tag.cleanup` 清理时预置标签是否计入；`backup.export` 在未配置私密锁时的可达性（见下文“已发现现状差距”）。
- **执行默认策略已确认**：按列表顺序执行；前置失败暂停依赖项，不依赖失败项的独立操作继续；已约定的共同保存设置组保持组内一致性，成功项不重复执行。这是已确认目标，队列执行尚未实现。**执行开放前仍须定稿/验证**：哪些设置确实能共同保存及可观测失败/恢复保证；每动作重试和撤销能力；是否提供其他可选策略。
- **模板持久化前定稿**：主动模板允许保存哪些正文/对象引用、私密模板如何处理、固定/模板排序管理和失效引用修复交互。最近使用只存功能 ID 已确认，不能以待定模板策略放宽默认历史。
- **后续原生验证**：浮层上下空间不足时的具体最大高度与避让布局；工作台粘贴前台目标、活动搜索导航、全应用退出快捷键、所有旧草稿的关闭保护。现有静态证据不能证明原生运行效果。
- **已发现现状差距**：备份未配置锁可达性、取消句柄、恢复提交后清理失败；历史读取失败返回空；重置吞掉删除错误。纳入对应接入的设计与回归，不顺带修复。
- **单独确认**：认证/授权、密钥生命周期、加密/敏感处理、隐私转换、真实迁移/恢复、批量或永久删除、跨系统一致性策略、真实钥匙串/日历/系统权限操作，以及安装/发布。每次先说明具体影响、验证与回滚/恢复思路；本文不替代授权。

### 仍有效的决定（摘要）

以下按主题收录仍约束后续工作的用户决定与结论。新的决定写进 §1～§6 对应规则或本节。

- **普通设置共同保存**：只覆盖语言、外观、标题省略、捕获来源标记四项；用独立版本化聚合文件、同路径协作锁、单次权威替换，组内全成或保持原状态，结果未知整组待核实，提交成功后才发布和处理展示。旧四键保留只读、不双写，坏旧值阻断自动迁移；回退默认使用迁移前四键。该方案只在隔离宿主装配；正式版设置指令仍沿用 `AppPreferences` 旧键与 `LocalSettingCommandAdapter`，不切文件后端、不迁移。
- **普通任务字段**（D1～D3）：结构化 title、notes 分别解析，不拼接重解析，旧捕获框保留单段规则；独立备注与不同的标题派生备注必须消歧，显式设置或取消优先级、提醒与语法冲突时阻止提交；append 任一侧为空取另一侧，否则旧全文＋一个换行＋追加原文，不 trim；clear 只清正文。新普通指令拒绝新增关联私密或手记预设标签；标签缺失、歧义或身份重复时阻止提交，普通标签的创建与恢复须明确预览，无法确认普通资格时整项暂停。
- **习惯状态编码**（D1～D3）：读取时 `false/false` 为未处理、`true/false` 为完成、`true/true` 与 `false/true` 均为跳过；写入时完成 `true/false`、跳过 `true/true`、重开 `false/false`，无记录重开不建空记录。恢复补录用恢复时当前星期，跨度超过 4000 日或完整性不足整项拒绝、保持暂停。
- **锁定清理搜索**（D3）：真正锁定时清除搜索原文、用户条件、补全缓冲、返回快照与排序上下文，只从可信页面重建自动范围；再次解锁不自动恢复。失焦或收起只遮罩敏感展示，不清草稿。
- **长文上限**：唯一来源 `CommandLongTextLimit.maxUTF8Bytes = 65_536`，按已确认正文的 UTF-8 字节计算，组合缓冲不计；超限整次修改不生效，不截断，打开旧超限草稿只引导、草稿原样保留。任务备注、手记小窗等原编辑器不受此限。1MiB 长段性能不作为目标。
- **长文受控借用**（L1～L9）：只开放普通长文，私密与受保护内容拒绝；身份全绑定、缺一即拒，每个 attempt 一次借用，失败与取消归还草稿，结果未知时不再借出，锁定即阻塞。指令遇到备注里解析出的私密或预设标签整条不可执行并说明原因。
- **打开原页面**：系统类、永久删除类与附件系统动作在指令里只打开原页面，由原界面完成。
- **待办与重复事项互转**：两个方向保存成功后都经 `ModelChanges` 的默认发布请求日历刷新；待办转习惯在此之后额外调用一次，是冗余请求而不是反方向漏刷新。保持现状，规则有两处：界面路径 `ItemConversionService.convertTodoToRoutine`，指令路径 `ConvertCommandTransaction.apply`；是否删去冗余调用另行决定。
- **接入正式版**：唯一装配点 `UnifiedSearchProductionAssembly`，测试与正式版同一份代码，差别只在 `UnifiedSearchProductionServices`；写入凭据 `CommandStoreGrant` 只放行签发时的主容器 mainContext，保存成功才发布。
- **原界面手记隐私规则**：恢复 `DiaryPrivacy.isSensitive` 的旧判定，`isPrivate`、关联私密标签、关联“密码”名标签、正文旧 `#密码`／`#password` 标记之一即敏感；手记三分类名不当作待办标签。刻意不恢复 `requiresProtection` 的正文关键字判断，以免新写入的普通手记被判损坏。
- **删除旧全局搜索**：旧全局搜索与“新版搜索与指令”开关一并删除，统一搜索是唯一入口、没有退路；`AppPreferences.unifiedSearchEnabled` 的键留在 UserDefaults，不迁移、不读取。`Domain/BoardSearch.swift` 保留（统一搜索与手记列表在用）。
- **恢复三处旧行为**：正式版检查器标题、子任务、备注失焦即保存（按 `WorkspaceHostContext.isIsolated` 判断，隔离宿主仍只留草稿）；普通文字下出 `#`／`!`／`@` 候选，搜索不创建标签；菜单栏任务筛选派生进自动条件、不回写。裸时刻、结果上空格切换完成、Esc 清空查询保持现状。
- **页内筛选有意保留**：页内筛选只缩小当前页，统一搜索跨全应用查找与执行指令；页内筛选不并进统一搜索，也不与统一查询双向同步。条件是普通词匹配与统一搜索同源。
- **阶段 6 有意不做**：系统、隐私、永久删除、导入备份恢复等流程维持“打开原页面”，不在指令里直接执行；某一项确有需要时单独立项。
- **指令输入时结果区让位**：指令不从搜索结果取对象（没有对象参数的修改、导航、交互，以及不读结果的系统动作）且操作面板已显示时，结果区隐藏，操作面板占满结果区；查询、范围、分组、要挑对象的指令与取焦点结果的 occurrence.inspect 保留结果。唯一判断 `UnifiedSearchController.hidesResultsForCommand`。
- **搜索与指令说明页**：工作台侧栏「系统」里的「搜索与指令」页是指令的使用说明，help.syntax 与语法帮助卡的「查看全部指令」都通向它；完整目录只显示指令名称与路径、不显示 summary，不可用的照样列出并弱化，处理方式只读 `disposition(for:)`，示例只预填不执行。
- **两宿主指令去处**：菜单栏不能执行的指令转交工作台，唯一入口 `UnifiedSearchProductionAssembly.revealWorkspaceThenWrite`；工作台有未完成草稿或待执行列表时不写入，菜单栏原文字保留。锁定后再输入用宿主注入的可信页面重建查询，旧文字与条件不恢复。


## 10. 现状总览

本节只记当前状态、覆盖、缺口和每批必读入口，不记更新时间和过程；过程与证据在 git 历史和提交说明里。每批怎样更新本节见[技能路由的路由维护](../skill-routing.md#路由维护)。
### 目标与阶段

- **目标**：工作台和菜单栏共用一套搜索与指令，覆盖 §8 全部 48 项用户功能；现有按钮、菜单与指令共用业务逻辑（[§1](#1-已确认的产品与查询规则)）。
- **当前形态**：统一搜索已接入正式版，是唯一的全局搜索入口，没有开关、没有退回旧搜索的办法。唯一装配点 `UnifiedSearchProductionAssembly` 构造工作台与菜单栏两个控制器；装配失败时两宿主搜索框显示不阻塞的说明。
- 阶段划分见 [§9.1](#91-建议的分阶段边界)：
  - **阶段 1 领域协议**：已实现（目录、解析、查询会话、草稿、计划、转交）。
  - **阶段 2 只读数据**：注入快照提供者与 SwiftData／文件只读适配已实现，读取仍在主线程同步进行。
  - **阶段 3 业务动作适配**：普通设置、任务、子任务、习惯、批量、转换、标签、手记等指令已实现；系统类、永久删除类与附件系统动作只“打开原页面”；手记写入只对普通手记直接执行，受保护目标打开原页面。逐项见下表。
  - **阶段 4 共享界面**：两宿主每条指令都有去处。目录 247 条指令（不含分组与范围）中，工作台可执行 160、打开原页面 86、目录不可用 1；菜单栏可执行 64、在工作台完成 178、目录不可用 5；两宿主“未接上”均为 0。唯一判断入口是 `UnifiedSearchController.disposition(for:)`。页内筛选有意保留：手记页、手记小窗、标签管理、剪贴板历史、附件中心（见 §1）。
  - **阶段 5、7**（队列执行与撤销、模板与全目录收口）：未开始，属可选增强。
  - **阶段 6**（独立系统流程）：有意不做，系统、隐私、永久删除、导入备份恢复由原页面完成。

### 功能覆盖表

状态只用：**已接正式版 / 已接正式版（部分） / 已接正式版＋打开原页面 / 打开原页面 / 隔离实现 / 未开始 / 待核实**。所有“已接正式版”的行都待用户在日用版逐项验收。“打开原页面”指指令只导航到原页面、由原页面完成操作，不在指令里执行；对照只在 [CommandOriginalPage](../AreaChain/Domain/CommandOriginalPage.swift)。“部分”时在“已覆盖／未覆盖”列写清哪些动作没有完成。“已复核”只指按[指定只读复核入口](../skill-routing.md#指定只读复核入口)通过的部分。功能名称见 §8 对应行（ID 链接）。

| ID | 功能 | 状态 | 已覆盖／未覆盖 |
|---|---|---|---|
| [T1](#T1) | 新建任务、标题、备注 | 已接正式版 | 已：todo.create、todo.title（已复核）、todo.notes（长文受控借用）、todo.cancelTitle（去掉宿主保留的标题草稿）；原界面文字里的私密／预设标签不关联 |
| [T2](#T2) | 完成、改期、提醒、优先级、标签、截止 | 已接正式版 | 已：todo.move／priority／reminder／completion／tags／createTag／due（已复核）、todo.cancelCompletion（复用 0.4 秒反悔窗口）；move／priority／reminder／tags／due 允许带备注对象 |
| [T3](#T3) | 复制、回收 | 已接正式版 | 已：todo.copy、todo.trash；带备注对象可复制、可回收（确认面板说明备注随对象进回收站）；未复核 |
| [T4](#T4) | 子任务 | 已接正式版 | 已：subtask.create／title／completion／tags（已复核）、subtask.delete、subtask.order、subtask.cancelTitle；父待办带备注仍拒绝 |
| [T5](#T5) | 重复事项定义 | 已接正式版 | 已：routine.title／weekdays／reminder／priority／tags、routine.create、routine.enabled（以上已复核）、routine.trash、routine.order、routine.capture／routine.notes（经长文受控借用执行） |
| [T6](#T6) | 指定日完成／撤回／跳过、检查日、连击 | 已接正式版 | 已：occurrence.complete／skip／reopen、inspector.day 定位（以上已复核）、routine.streak（复用 HabitStreakLogic，只读）、occurrence.inspect（沿月历点日期换检查日，不打卡） |
| [T7](#T7) | 批量任务／习惯 | 已接正式版 | 已：batch.move／tags（允许带备注）、batch.completion／enabled（以上已复核）、batch.trash（允许带备注）、selection.clear |
| [T8](#T8) | 待办↔重复事项转换 | 已接正式版 | 已：todo.toRoutine、routine.toTodo；带备注对象可转换（损失清单列出“备注原样搬到新对象”）；未复核 |
| [T9](#T9) | 页面筛选、全部事项、排序、延至今日 | 已接正式版（部分） | 已：tasks.order、tasks.postponeYesterday、tasks.filter／clearFilter（今日／待处理／全部事项，与页面双向同步）、tasks.kind／status、tasks.sections（昨天／即将）、tasks.select（待处理／全部事项）；未：今日区收起（始终展开）、今日页与标签清单的多选指令 |
| [T10](#T10) | 剪贴板加今天 | 已接正式版 | 已：capture.clipboard（无 Run 模式，提交才读剪贴板；已复核）；读到私密／预置标签整条不写并说明，菜单栏入口跳过标签照常保存 |
| [B1](#B1) | 日历导航与改期 | 已接正式版 | 已：calendar.mode／step／today／day／dayList（页面指令，月周与选中日写页面那一份）、calendar.create（转交 todo.create）；拖拽改期沿 todo.move；calendar.step 只留 offset，月周跟随当前视图 |
| [B2](#B2) | 四象限 | 已接正式版 | 已：quadrant.day／step／inspect（页面指令）、create／priority／complete／copy（转交 todo.create／todo.priority 或 routine.priority／todo.completion 或 occurrence.complete／todo.copy 标题段）；copy 不接习惯 |
| [B3](#B3) | 安排页平移与完成 | 已接正式版 | 已：gantt.step／currentMonth／select／inspect（页面指令）、gantt.shift（GanttRescheduleService，一次事务、保留间隔、越出当月拒绝）、gantt.complete（转交 batch.completion） |
| [J1](#J1) | 手记新建与正文 | 已接正式版＋打开原页面 | 已：diary.create（快速新增：拆分标题／正文与 #标签）、diary.body replace／append（长文受控借用；clear 按目录静态拒绝）、diary.save／reload／discard（只作用于已打开的小窗会话）、diary.tags（见 J2）；打开原页面：受保护或保存后会变成受保护、加私密标签、超过 64KiB 的已有正文 → 手记页 |
| [J2](#J2) | 手记组织 | 已接正式版＋打开原页面 | 已：diary.pinned、diary.move、diary.tags（普通标签加减／替换／清空；加私密标签拒绝）；打开原页面：diary.privateMark／reveal／mask 与受保护手记 → 手记页 |
| [J3](#J3) | 手记复制、转任务、回收 | 已接正式版＋打开原页面 | 已：diary.copy（整篇／标题／备注，PrivateClipboard）、diary.toTodo、diary.trash（共用独立确认、只能单项）；打开原页面：受保护手记 → 手记页 |
| [G1](#G1) | 标签新建、改名、颜色、排序、搜索与视图 | 已接正式版（部分） | 已：tag.create／rename／color、tag.order、tag.cancel、tag.search／view／deleted（取法即标签页的 TagListQuery）、go.tagList；未：新建时设为私密（需解锁） |
| [G2](#G2) | 标签合并、解绑、软删／恢复、清理 | 已接正式版＋打开原页面 | 已：tag.merge（涉及私密标签整条拒绝）、tag.unlinkObject（受保护手记拒绝）、tag.trash／tag.restore（共用独立确认、只能单项）；打开原页面：tag.delete、tag.cleanup → 标签页；tag.unlinkGlobal 目录 unavailable（原界面没有该功能，不算缺口） |
| [A1](#A1) | 图片附件 | 已接正式版＋打开原页面 | 已：图片元数据只读查询、普通图片查阅（已复核）、image.browse／image.preview／image.trash；打开原页面：image.pick／paste／capture → 焦点对象的详情（手记打开手记页，习惯定义须先选执行日） |
| [C1](#C1) | 剪贴板浏览与搜索 | 已接正式版 | 已：显式 /clipboard 只读提供者与文件只读适配；clipboard.browse／search（与历史页 visibleItems 同一取法）；默认不进普通搜索 |
| [C2](#C2) | 剪贴板复制／粘贴 | 已接正式版 | 已：clipboard.copy／paste／pastePlain（ClipboardHistoryActions，写入失败不报成功）；粘贴到其他应用需辅助功能权限，只在执行时询问 |
| [C3](#C3) | 剪贴板置顶、删除、清空 | 已接正式版＋打开原页面 | 已：clipboard.pinned、clipboard.copyLetter；打开原页面：delete、prune、empty → 剪贴板页 |
| [C4](#C4) | 记录暂停、跳过、忽略来源 | 打开原页面 | clipboard.recording／skipNext／ignoreApp → 剪贴板页 |
| [C5](#C5) | 剪贴板偏好 | 打开原页面 | 全部 13 条（含 add／removePattern、add／removeType、unignoreApp）→ 剪贴板页的“剪贴板选项”（设置页没有剪贴板分节） |
| [C6](#C6) | 剪贴板小窗 | 已接正式版 | 已：clipboard.openWindow／closeWindow／pinWindow／workspace（沿 ClipboardHistoryPanel 现有窗口管理，只有一个面板） |
| [S1](#S1) | 语言、外观、标题省略、捕获来源 | 已接正式版（部分） | 已：四项设置的单项指令（正式版沿用 AppPreferences 旧键）；未：多项共同提交（聚合文件后端只在隔离宿主装配）；未复核 |
| [S2](#S2) | 登录启动 | 打开原页面 | setting.login、loginSettings → 设置“启动”分节 |
| [S3](#S3) | 通知权限与测试 | 打开原页面 | notification.status／request／test／settings → 设置“通知”分节 |
| [S4](#S4) | 通知完成与延后 | 已接正式版＋打开原页面 | 已：notification.open 沿 inspector.open 打开对象；complete／snooze 只说明并给出改用 todo.completion／occurrence.complete／todo.reminder 的入口，不另写执行 |
| [S5](#S5) | 日历同步 | 打开原页面 | calendarSync.enabled／status／retry／settings／conflicts → 设置“系统日历”分节；openLocal 也打开该分节（搜索里没有冲突对象来源） |
| [S6](#S6) | iCloud 说明 | 打开原页面 | setting.icloud → 设置“iCloud”分节 |
| [S7](#S7) | 快捷键配置 | 打开原页面 | shortcut.record／reset／resetAll／cancel → 快捷键页 |
| [P1](#P1) | 创建私密锁 | 打开原页面 | privacy.create／setupMethod／setupTags／protectExisting → 隐私与解锁页；不新增隐私转换执行路径 |
| [P2](#P2) | 隐私管理 | 已接正式版＋打开原页面 | 已：privacy.lock 直接执行（沿“立即锁定”，锁定撤权）；打开原页面：unlock、systemUnlock、set／change／removePassword、idle、tags → 隐私与解锁页 |
| [P3](#P3) | 解除单条手记保护 | 打开原页面 | privacy.unprotect → 隐私与解锁页 |
| [P4](#P4) | 隐私维护重试 | 打开原页面 | privacy.retryImages／retryKeys／quitForCleanup → 隐私与解锁页 |
| [D1](#D1) | 回收站 | 已接正式版＋打开原页面 | 已：显式回收范围的墓碑只读搜索、trash.restore（与回收站页同一写入 TrashRestoreService，共用独立确认、只能单项，受保护拒绝）；打开原页面：trash.delete、trash.empty → 回收站（定位焦点项）、trash.browse → 回收站页（类别在页面筛选里选） |
| [D2](#D2) | JSON 导出导入 | 打开原页面 | data.export／selectImport／validateImport／previewImport／applyImport → 数据与备份页；不新增导入执行路径 |
| [D3](#D3) | 加密备份与恢复 | 打开原页面 | backup.export／inspect／preview／restore → 数据与备份页；不新增备份恢复执行路径 |
| [D4](#D4) | 重置并退出 | 打开原页面 | recovery.status、recovery.resetQuit → 数据与备份页（降级提示就在该页）；resetQuit 目录仍 unavailable |
| [N1](#N1) | 全页面与标签清单导航 | 已接正式版 | 已：16 个 go 入口、go.tagList（均已复核） |
| [N2](#N2) | 工作台、浮层与面板 | 已接正式版（部分） | 已：workspace.open／reveal／close、overlay.toggle、routine.addPanel／managePanel（沿 AppWindows 与今日页原面板，不新建窗口）；未：overlay.mode（浮层的任务／手记页没有外部切换入口，只说明） |
| [N3](#N3) | 检查器与选择 | 已接正式版 | 已：inspector.open／inspector.day（已复核）、selection.all／clear（沿页面投影）、inspector.close（沿检查器关闭按钮，先失焦保存） |
| [N4](#N4) | 手记小窗 | 已接正式版 | 已：diaryWindow.open（受保护手记拒绝）／draft（不写入，受保护草稿留给原页面）／pinned／close（沿小窗原有确认）、diaryWindow.save（复用小窗会话保存，受保护会话只前置小窗） |
| [N5](#N5) | 总览统计 | 已接正式版 | 已：stats.* 八项只读（DashboardStatsReader，与总览页同一投影，私密手记口径不变）、stats.openDay、活动行打开（沿总览路由；stats.openActivity 指向 stats.activity 的列表） |
| [N6](#N6) | 帮助与示例 | 打开原页面 | help.syntax（打开工作台「搜索与指令」页）、help.page（来时页面的说明）、help.example（只预填示例到搜索框，不执行；不带示例时弹语法帮助卡） |
| [N7](#N7) | 版本、反馈与链接 | 打开原页面 | support.* 七条 → 设置“版本／支持／关于”分节；不在指令里打开外部网址 |
| [N8](#N8) | 退出与未保存确认 | 已接正式版 | 已：app.quit 走 AppDelegate.applicationShouldTerminate 的原有确认（含未保存手记），同意后才调注入的 terminate |

合计 48 项：已接正式版 20（T1～T8、T10、B1～B3、C1、C2、C6、N1、N3、N4、N5、N8）；已接正式版（部分）4（T9、G1、N2、S1）；已接正式版＋打开原页面 9（J1～J3、G2、A1、C3、S4、P2、D1）；打开原页面 15（C4、C5、S2、S3、S5、S6、S7、P1、P3、P4、D2、D3、D4、N6、N7）；隔离实现、未开始、待核实均为 0。

### 未闭合缺口

只记仍未解决的问题；关闭某条时删去对应行。

- **用户验收**：日用版逐域试用由用户进行；真实库、真实附件目录、真实钥匙串与真实系统授权均未在隔离验证中覆盖。
- **人工与平台验收**：真人输入法、VoiceOver、最低支持系统、真实多窗口、原生截图逐类查看均未做；工作台操作面板里的按钮在原生用例中改用 AXPress 验证，真实鼠标点击未验证。
- **正常签名构建**：正常开发描述文件到期后正常构建记为阻塞，不续签、不改个人签名配置；当前到期时间用 `security cms -D -i` 读内嵌描述文件核对。Widget 内嵌描述文件签名后被替换、导致正常构建签名核验失败的问题仍记为阻塞。
- **页内筛选的匹配同源**：附件中心的普通词匹配用 `localizedCaseInsensitiveContains`，区分变音符号（`café` 与 `cafe` 不同），与统一搜索的 `localizedStandardContains` 口径不同，不满足 §1 的同源条件；标签页与统一搜索同口径，手记页、剪贴板页未逐一核对。
- **菜单栏手记筛选**：菜单栏手记页签的标签筛选不作用于搜索结果（菜单栏搜索页面固定为今日任务，筛选胶囊只在任务页签显示）。
- **菜单栏打开结果**：工作台查询的页面上下文不同时可能找不到同一对象，只停在结果页。
- **受保护内容**：受保护手记的写入、复制与转换只打开原页面；受保护内容查阅与敏感执行／转交不开放。原生输入接受与锁定交错的问题未解决：敏感输入不开放，mutable textStorage 只能事后检测。
- **有备注对象资格**：仍未放宽 todo.title／subtask.title（`//` 派生备注另行定界）、完成、建标签、子任务与习惯字段类、删子任务时的父待办。
- **手记小窗指令**：diary.save／reload／discard 只作用于已打开的小窗会话（手记页卡片的编辑会话是页面私有状态，宿主没有入口）；有未保存内容的重载只前置小窗由用户确认。
- **打开原页面的限制**：设置与剪贴板分节只在说明里指明，页面不自动滚动；image.preview 只能打开当前结果里可见的普通图片。
- **隔离宿主共享目录**：隔离宿主中 @附件 关联（会改写共享池索引）、手记卡片“取消保护”、输入联想读共享池仍走共享目录。
- **目录未决项**：tag.cleanup（预置标签范围）、backup.export（无锁可达性）未定稿。来源：[§9.4](#94-未决问题与单独授权边界)。
- **现状差距**：备份未配置锁的可达性、剪贴板历史读取失败返回空、重置吞掉删除错误。来源：[§9.4](#94-未决问题与单独授权边界)。
- **性能**：读取仍在主线程同步进行；新查询延迟、长文编辑、最大候选规模与内存均未建立基线。来源：[§9.3](#93-后续回归入口与证据缺口)。
- **未查明的问题**：标题多目标面板消失的根因未判定；DetailSubtaskCompletionTests 两项按已知问题标注；原生日期格按钮在统一搜索测试宿主里找不到标识（`nativeBooleanWeekdaysDayAndTime` 等）。
- **待批准的低级整改**：任务域指令有 9 条低级整改，待单独批准后修复。

### 既有失败

逐条登记在 [`scripts/known_test_failures.json`](../scripts/known_test_failures.json)（门禁只改变归类，测试照常运行）。共 32 条，每条的首次复现提交与原因见登记表：CalendarSpanConsumerTests（3）、CalendarWeekConsumerTests、CalendarWeekLayoutTests（2）、DashboardScrollTests、DaybookScrollNativeTests、DiaryTitleHoverTests（2）、MenuBarHelpSurfaceTests、MenuBarStatusImageTests、PasswordRetryDiagnosticTests（2，诊断型）、PrivacyAutolockPickerTests（2）、PrivacyButtonConsumerTests、ScrollAssemblyConsumerTests、SearchMultilineDiagnosticTests、UnifiedSearchOperationInteractionTests、UnifiedSearchSettingInteractionTests、WeekdayConsumerBaselineTests、WorkspaceInspectorSizingTests（2）、WorkspaceMenuConsumerTests、WorkspaceRenderingTests、YesterdayCardActionTests（3）、YesterdayCardConsumerTests（3）。

- 各批只跑定向测试；全量回归只在替换日常应用之前或用户明确要求时运行（见[质量门禁](quality-gates.md)）。
- 焦点前置失败（拿不到 key window）在桌面空闲重跑后通过的不登记。

### 补复核待办

- **仍待复核**：阶段 2 只读数据、阶段 4 共享界面、普通设置指令、普通任务新增与标题指令，以及复制与回收、待办与重复事项互转。
- **已复核通过**的部分在上表各行标注“已复核”。

### 每批最少必读

执行一个批次时，按下面顺序读，读够即停。

1. 本节（§10）全文。
2. §8 中本批涉及的行：用行首锚点定位，例如 `grep -n 'id="G1"' docs/unified-search-commands.md`。
3. §1～§6 中与本批相关的规则小节。
4. §9 的“仍有效的决定”中本域条目。
5. 涉及未决项时读 [§9.4](#94-未决问题与单独授权边界)；涉及目录 ID 时，以 `CommandCatalog` 源码和 §8 映射为准。
6. [技能路由](../skill-routing.md)的“指定只读复核入口”与“路由维护”，[组件目录](component-catalog.md)中本域条目；新简单修改指令先看组件目录的“简单指令共用骨架”。

# 统一搜索与指令体系

## 0. 状态、权威范围与基线

**状态：阶段 1A 纯领域目录与参数声明已实现；验证及缺口见第 9.6 节，产品 UI 与执行接入尚未实施。** 设计决定来自阶段 0 与本次已确认需求，源码核对日期为 2026-10-01，基线提交为 `25a7cb3777f52983c26a6e3f938bd1fac0bd441d`，另有下述未提交修改。本段及阶段 0 记录保留当时的静态阅读基线；阶段 1A 的实际 Swift 检查另记于第 9.6 节，不能混用历史证据。

本文是该体系唯一的目标设计来源，后续阶段在本文更新决定、映射及完成证据，不复制计划、不另建自动执行器。当前行为仍见[功能清单](features.md)、[使用说明](usage.md)、[架构](architecture.md)；目标与现状有差异时以本文的“目标”理解未来工作，不能据此宣称当前产品已有能力。实现继续遵循[项目规则](../AGENTS.md)、[技能路由](../skill-routing.md)、[组件目录](component-catalog.md)与[质量门禁](quality-gates.md)。本文件不授予安全边界变更、真实数据写入、系统权限、安装或发布权限。

### 工作区边界

开始时索引无暂存改动，工作区有 7 个已跟踪修改及 2 个未跟踪文件，均保留：

| 已有改动 | 对后续阶段的影响 |
|---|---|
| `AreaChain/Theme/DaybookButtonStyle.swift`、`AreaChain/Resources/Localizable.xcstrings` | 按钮/menu label 共用视觉基座、焦点/减弱动态效果及展示文案；后续指令提交按钮沿修改后的基座核对，不覆盖这些改动。 |
| `AreaChainTests/Theme/DaybookButtonInteractionTests.swift`、`AreaChainTests/Theme/DaybookControlsPreview.swift`（未跟踪） | 按钮原生交互和展示夹具；存在不等于本阶段已验证，也不能因未跟踪而删除。 |
| `docs/component-catalog.md`、`docs/engineering.md`、`skill-routing.md` | 已有按钮契约、展示验收与路由补充；本文引用现有文件，不改写其工作成果。 |
| `scripts/check_workflow.py`、`scripts/tests/test_check_workflow.py` | 检查器已要求上述展示文件和目录条目；必须以当前整套工作区验证，不能只拿 HEAD 检查器代表现状。 |

没有发现上述差异改动搜索领域逻辑；UI 和文案接入有共享文件重叠风险。下一阶段重新检查差异，不假设这些改动已提交或完成原生验收。阶段 0 不修改 Swift，不重置、不提交、不推送、不安装或启动生产应用，不访问 `.cursor/plans`。

核对期间 `docs/engineering.md` 又出现按钮任务的验收记录及示例命令修订；本任务未写该文件，也未把其中的 Swift/原生结果作为阶段 0 的验证证据。其他任务可能仍在更新工作区，后续须重新取基线。

## 1. 已确认的产品与查询规则

### 统一能力与指令发现

- 工作台和菜单栏共用搜索能力、查询语法、指令目录及交互机制，各自拥有会话；普通搜索入口能力完整，特殊对象选择器才能使用明确声明的受限配置，并解释限制。
- 消除功能重复的页内搜索。页面提供可见、可编辑、可删除的默认范围，例如 `/tasks`、`/diaries`。页面筛选控件可保留，但读写同一查询上下文，不能再保留第二套搜索状态。
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

独立查询与页面再次绑定必须是明确的动作，不能因路径文字碰巧相同而自动绑定。跨页后的“原页面”指进入该次结果上下文时保存的返回位置；重新在另一个页面建立上下文时更新返回位置。页面自动范围的完整映射及删除标记跨“离开后再进入”的保留时限，在阶段 1B 用案例定稿，不能削弱当前页内不补回的规则。

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

### 目标与队列

- 支持多个设置、多个对象和多个字段。目标可以是单对象、明确选中的多对象、显式选择的“当前全部结果”；确认后固定对象集合，后续结果增减不能静默扩大目标。
- 对象引用应包含类型和稳定标识；打卡还带明确日期。父子结果可归组但独立选择，不能把父对象和子对象的操作混淆。
- 混合类型只提供共同操作；非共同操作必须说明适用子集，用户明确选择后执行，不静默跳过其他对象。
- 同一对象同一字段的普通赋值合并成最终值；追加正文等顺序敏感操作保留顺序。不能跨有语义依赖的步骤随意合并。
- 默认按列表顺序执行；依赖显式，前置失败暂停依赖项，不依赖失败项的独立操作继续；已约定为共同保存的设置组保持组内一致性，成功项不重复执行。这是用户已确认的目标，阶段 1A 不实现队列执行。参数未完成不能静默跳过，应在统一提交校验中标记并阻止其被当作可执行项。
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
- 默认相关性排序，可切换明确排序方式；具体权重和稳定并列顺序通过合成案例验证后定稿，不能将当前日期倒序当成相关性。
- 结果显示命中片段、命中字段、类型、所属对象；私密投影仍优先于展示丰富度。附件进入同一键盘序列；父子可归组但仍独立选择。
- 最近使用仅持久化功能标识，不默认保存完整输入、正文、对象或路径。支持固定指令和用户主动保存的查询/操作模板。
- 模板只预填，不自动执行；相对日期使用时显示实际日期，失效引用明确提示。主动保存模板时明确展示要保存的字段，敏感凭据始终排除；正文/对象引用的允许范围和私密模板策略需在实施前单独定界。

## 7. 已核实的搜索与公共复用基线

以下行号对应阶段 0 基线，链接定位文件，符号是后续检索的稳定入口。分类为“直接复用”“扩展”“提取”“新建”仅表示建议，不宣称已修改。

| 能力/真实消费者 | 源码依据 | 复用与关键差距 |
|---|---|---|
| 查询解析与任务/习惯/子任务/手记搜索 | [BoardSearch.swift](../AreaChain/Domain/BoardSearch.swift)：52 `BoardSearchQuery`、68 `parseQuery`、138 `hits`、289 `matchesRecord`；消费者是工作台、菜单栏、手记列表 | 扩展。已有多词全部满足、多个标签交集、优先级/提醒；没有范围路径、短语/排除 AST（结构化语义树）、字段命中片段及相关性排序。163 按日期/创建时间倒序，216 排除停用习惯。 |
| 统一结果身份与附件 | [WorkspaceGlobalSearchView.swift](../AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift)：26 `body`、85 `SearchResultKeys`、196 `WorkspaceAttachmentQuery`；[SearchResultKeys.swift](../AreaChain/Features/Search/SearchResultKeys.swift)：5 `SearchResultOrder` | 扩展。工作台额外按文件名匹配图片，附件不进入 `BoardSearchHit`/键盘序列；菜单栏没有同等附件搜索。附件类型/拥有者/重复 UUID 校验不能丢。 |
| 两宿主搜索与打开 | [MenuBarSearchResults.swift](../AreaChain/Features/MenuBar/MenuBarSearchResults.swift)：56 `makeHits`；[SearchResultsView.swift](../AreaChain/Features/Search/SearchResultsView.swift)：35 `open`；[WorkspaceGlobalSearchView.swift](../AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift)：145 `openHit` | 共用 `BoardSearch` 与 `BoardSearchHitGroups`；工作台就地检查，菜单栏转日历检查，手记开小窗。后续共用结果/动作协议，宿主路由差异显式适配。 |
| 页面筛选与搜索会话 | [BoardComposer.swift](../AreaChain/Features/Board/BoardComposer.swift)：29 `BoardFilterSession`、49 `globalSearchFilter`；[WorkspaceNavigation.swift](../AreaChain/Features/Workspace/WorkspaceNavigation.swift)：147–183 页面记忆与搜索；[DiaryPage.swift](../AreaChain/Features/Diary/DiaryPage.swift)：34 `searchQuery`、216 `searchChrome` | 新建带来源的查询会话并接入既有筛选。当前两宿主今日/手记筛选共享，工作台全局搜索取任务筛选；无默认范围来源、用户删除标记、独立查询脱离绑定模型；手记仍有局部搜索。 |
| 结果替换与返回 | [MainSplitWorkspaceView.swift](../AreaChain/Features/Workspace/MainSplitWorkspaceView.swift)：48 搜索分支；[WorkspaceNavigation.swift](../AreaChain/Features/Workspace/WorkspaceNavigation.swift)：117 `selectedTab`、147 `todayDraft`、171 `isSearching` | 当前非空字符串就换结果视图，部分草稿/筛选已外置；不能据此推断所有页面滚动和草稿恢复完整。需结构化激活判定与返回上下文。 |
| 补全、编辑与预览 | [SyntaxAutocomplete.swift](../AreaChain/Domain/SyntaxAutocomplete.swift)：4 `SyntaxTriggerKind`、59 `SyntaxAutocompleteEngine`；[SyntaxAutocompleteView.swift](../AreaChain/Theme/SyntaxAutocompleteView.swift)：6 `SyntaxAutocompleteState`、84 `commit`；[SyntaxOverlay.swift](../AreaChain/Theme/SyntaxOverlay.swift)：8 `resolve`、122 宿主、183 `panel` | 复用原生替换/撤销、标签/时刻/优先级候选和锚点定位。触发仅 `# ! @`；现有候选与捕获预览能在同一面板组合，但不是输入上方补全、下方可编辑预览的双区域机制；属性浮层不是通用可编辑参数模型。 |
| 原生键盘与视觉 | [DaybookTextField.swift](../AreaChain/Theme/DaybookTextField.swift)：324 组合文本守卫、367 补全；[DaybookTextEditor.swift](../AreaChain/Theme/DaybookTextEditor.swift)：132 原生命令；[WorkspaceHeaderSearch.swift](../AreaChain/Features/Workspace/WorkspaceHeaderSearch.swift)：18 输入、74 Escape | 直接复用原生输入、`DaybookInputShell` 和语义令牌，聚焦修改路由。当前顶栏 `onSubmit` 为空，Escape 会清查询；新的操作草稿/结果/多行优先级需要专项覆盖。 |
| 事务、正文会话和日期/标签 | [ModelChanges.swift](../AreaChain/Services/ModelChanges.swift)：33 `commit`、78 `transaction`；[DiaryEditorSession.swift](../AreaChain/Features/Diary/DiaryEditorSession.swift)；[DayKey.swift](../AreaChain/Domain/DayKey.swift)、[TagSyntax.swift](../AreaChain/Domain/TagSyntax.swift)、[InputTagResolver.swift](../AreaChain/Services/Repositories/InputTagResolver.swift) | 直接复用保存与失败回滚、正文基线、民事日期和无副作用解析；补通用字段修改、执行结果、冲突/重试/撤销能力。`ModelChanges` 不是跨偏好/文件/系统的事务。 |

功能级业务入口及测试映射见下一节；阶段 1A 新增的实际目录类型见 9.6；本节尚未实施的查询会话、执行等责任名仍不能误认成现有公共组件。

## 8. 用户功能覆盖映射

表内分类对应**目标产品能力**；阶段 1A 已有完整目录元数据，但尚未接入产品入口或执行适配。已确认的 `/tasks`、`/diaries`、`/clipboard`、`/go/…`、`/setting/language/chinese` 保持不变；其余稳定 ID、叶子路径、中英文名称/别名已在 1A 逐动作登记，见 9.6；参数化尾段的解析属于 1B。同一行中的多个动作必须各有目录条目或明确的参数化动作，不能用该行一个“打开页面”替代。验证列中的业务与原生行为仍待接入验收；1A 目录测试证据见第 9.6 节。

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
| <a id="T8"></a>T8 待办↔重复事项转换 → 对象转换 | [DayBoardMutations+Convert.swift](../AreaChain/Features/Tasks/DayBoardMutations+Convert.swift)：30 `convertTodoToRoutine`、64 `convertRoutineToTodo` | 新建新 ID 并软删原对象，非原 ID 改类型；待办转习惯将活子任务标题折入备注、移交活附件、按原日期取星期，不迁移截止/完成态；反向新建今天待办。预览字段损失与关联变化，验证旧对象/附件、重试不重复创建。 |
| <a id="T9"></a>T9 今日/昨天/即将展开、昨天全部延至今日；筛选/清筛选；全部事项种类和状态；列表选择/排序 → 查询/批量/排序 | [TasksPage.swift](../AreaChain/Features/Tasks/TasksPage.swift)、[DayBoardList.swift](../AreaChain/Features/Tasks/DayBoardList.swift)；[WorkspacePendingView.swift](../AreaChain/Features/Workspace/WorkspacePendingView.swift)：61；[WorkspaceAllItemsView.swift](../AreaChain/Features/Workspace/WorkspaceAllItemsView.swift)：51；[DayBoardMutations+Convert.swift](../AreaChain/Features/Tasks/DayBoardMutations+Convert.swift)：13 `applyManualOrder` | 复用 `BoardFilter`、`ItemsListing`、`AgendaProjection`、`ManualOrder`；标签、优先级、来源、日期、提醒等适用维度同步查询；完成状态与习惯启用状态不能混为一个状态。验证页内状态与查询往返、混排手动排序、昨天习惯真实检查日；“全部延至今日”只改适用待办。 |
| <a id="T10"></a>T10 剪贴板加今天 → 单次捕获 | [ClipboardCapture.swift](../AreaChain/Services/ClipboardCapture.swift)：39 `ingest`；[Classification.swift](../AreaChain/Domain/Classification.swift) | 有文字只取文字、仅图片才挂图；保留原文，仅解析普通标签，不走任务时间/优先级 NLP；可按偏好附来源 Bundle ID。不同于剪贴板历史和正文粘贴。验证文字+图片优先级、事务/文件失败及重试身份。 |
| <a id="B1"></a>B1 日历月/周切换、上/下月或周、回今天、选日/入日清单、指定日新增、拖拽改期 → 规划导航/任务动作 | [CalendarPage.swift](../AreaChain/Features/Calendar/CalendarPage.swift)：72 页头、288 `addTodo`、294 `selectDayFromGrid`、299 `enterDayList`、314 `dropTodo`；[CalendarWeekBoard.swift](../AreaChain/Features/Calendar/CalendarWeekBoard.swift)：72 | 改期复用 `moveTodo`，只接受待办；选日期导航不改模型。验证六周月历、窄窗、周跨月、保存失败不改选日及原任务草稿。 |
| <a id="B2"></a>B2 四象限按日浏览/翻日、指定象限新增、拖动改优先级、完成、检查器、全文气泡复制 → 规划/优先级/复制 | [QuadrantPage.swift](../AreaChain/Features/Quadrant/QuadrantPage.swift)：100 `copyPreview`、215 `addTodo`、223 `toggle`、251 `apply` | 复用 `addCapturedTodo(fallbackQuadrant:)`、`applyQuadrant`；正文显式优先级胜过所在格子，只展示当日未完成项。验证具体日期、习惯排定、复制与输入优先级。 |
| <a id="B3"></a>B3 安排页翻月/回本月、单选/多选/范围选、同天数平移、完成已选任务、打开检查器 → 安排/批量改期 | [GanttPage.swift](../AreaChain/Features/Gantt/GanttPage.swift)：188 `handle`、213 `completeSelected`、226 `commitDrag`；[GanttRescheduling.swift](../AreaChain/Features/Gantt/GanttRescheduling.swift)：6 `commit` | 单日任务色块，平移保间隔且限当前月，拖动失败整组回滚；已有原日期/完成/删除基线检查。完成选中项仍逐条 toggle，非通用原子批量；习惯点只是排定提示。验证越界、取消/失焦、外部改期与混合目标，不扩成工期/依赖管理。 |
| <a id="J1"></a>J1 手记新建、全文编辑/追加/清空、显式保存、重载/舍弃冲突草稿、标签与自动分类 → 手记正文 | [SwiftDataDiaryRepository.swift](../AreaChain/Services/Repositories/SwiftDataDiaryRepository.swift)：66 新增、86 编辑、201 `writeContent`；[DiaryEditorSession.swift](../AreaChain/Features/Diary/DiaryEditorSession.swift)：109、163 保存/冲突 | 当前新建/全文编辑已存在，追加/清空是新指令字段模式，受正文校验约束；复用会话而非绕过它直写仓储。新建自动分类、编辑追加语法标签。验证空白、长正文、外部冲突、保存失败与锁定封存。 |
| <a id="J2"></a>J2 记录置顶/取消、改今天/昨天/明天/任意日、加/移标签、显示/遮罩、“私密”标记 → 手记组织 | [DiaryOrganizeMenus.swift](../AreaChain/Features/Diary/DiaryOrganizeMenus.swift)：27；[DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)：244、293；[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：465 `moveDiary`、472 `togglePrivateDiary` | `isPinned` 是排序；窗口置顶另见 N4。“私密”标记只切 `isPrivate`，不等于启用/解除加密，真正保护按 P1–P3。验证日期/标签未指定不变、标记/遮罩/加密区分。 |
| <a id="J3"></a>J3 复制整篇/标题/备注、转今天任务、回收 → 手记动作 | [DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)：374 复制；[PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift)：127 `PrivacyAccess.withDiary`；[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)：435 `convertDiaryToTodo` | 复制重查活记录并经 `PrivateClipboard`；转任务拒绝敏感/受保护及标签读取失败，首行标题/余文备注、保留原手记、不带标签/附件、不做 NLP。验证保护门禁、失效对象、复制标记、无副作用拒绝及新建重试。 |
| <a id="G1"></a>G1 标签新建/取消、改名、颜色、拖动排序、搜索与全部/常用/最近/未使用/已删除视图 → 标签/查询 | [TagManagementPage.swift](../AreaChain/Features/Workspace/TagManagementPage.swift)：66、91、158、214、254；[SwiftDataCatalogRepository.swift](../AreaChain/Services/Repositories/SwiftDataCatalogRepository.swift)：41、101、132、172、193 | 标签规范化用 `TagSyntax`；预置标签不能改名/改色/合并，已有多选改色。重复页内搜索在统一入口等价后移除；已删除视图映射显式回收范围。验证名称冲突、预置限制、选择/排序与筛选上下文。 |
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

现有历史存储是 [ClipboardHistoryStore.swift](../AreaChain/Services/ClipboardHistoryStore.swift)：8，独立 `history.json` 与图片，不进入 SwiftData/JSON 导出/加密备份，也不随手记锁定；`load`（13）失败返回空数组，不能把读取失败当作真实空历史。这是新统一结果错误反馈的接入缺口，不在阶段 0 修复。

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

全局四项：浮层开关、剪贴板加今天、显示工作台、剪贴板历史，默认未绑定。应用内十二项：搜索、筛选、工作台、语法帮助、设置、退出、记手记、保存手记小窗、打开手记、复制手记、清单全选、手记移入回收站。固定方向键、Return、Esc、Delete、备注 ⌘Return，以及剪贴板历史的复制/粘贴/置顶组合不在可重录目录内，仍需纳入键盘回归；不能为了通用指令吞掉原生编辑按键。可重录退出目前只在浮层找到显式消费，工作台/手记小窗与原生退出菜单的一致性尚需组合场景验证。

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

已核实的待确认差异：加密备份服务允许未配置私密锁时导出，但当前 UI 无条件认证，`PrivacyUnlockPresenter` 对未配置锁拒绝；因此未配置状态的 UI 导出可达性需要隔离复现与产品决定，阶段 0/1A 不修复或绕过认证。JSON 文件导出当前不是原子写入，导入失败会清待导入预览；接入新执行结果时需保持数据事实，不能把这些现状宣传成目标失败恢复契约。

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
| 0（设计基线） | 本文的已确认决定、功能/源码映射、工作区基线及文档引用 | 只改文档；静态/工作流检查和差异核对，明确未实现。 |
| 1A（本次） | 纯领域指令目录、参数类型与操作模式、目标类型、预览与能力声明；覆盖第 8 节全部 48 组及独立动作，补双语资源 | 唯一 ID/路径/父子结构、映射覆盖、参数及安全交互可测试；全部执行未接线；不含解析、补全算法、UI、持久化、系统 IO 或页面会话。证据见 9.6。 |
| 1B | 查询解析、补全、条件来源、页面范围及状态转移；复用 1A 目录和参数，保持既有搜索语法兼容 | 定稿短语/排除/同维度语法、`/tasks` 具体集合、停用习惯呈现、页面自动条件、日期字段及删除标记寿命；纯领域测试覆盖激活/清除/切页/脱离绑定，不接产品 UI 或真实数据提供者。 |
| 1C | 草稿、固定目标、队列与转交契约；复用 1A 描述及 1B 查询状态 | 表达独立草稿、固定类型/日期身份、依赖与部分失败、成功不重放、设置组一致性及单一提交所有权；不实现执行器、转交服务或持久化。 |
| 2 | 扩展搜索查询与结果协议，任务/习惯定义和打卡/子任务/手记/标签/图片，以及显式剪贴板/回收站数据提供者；复用 `BoardSearch`、日期/隐私/附件规则 | 依赖 1；多词/短语/排除/交集、范围、片段、排序、父子/附件身份和私密投影通过合成测试；剪贴板/回收站默认隔离。停用习惯、日期字段等口径须先定稿。 |
| 3 | 从现有按钮/菜单/设置提取缺少的共用业务动作，建立校验、预览、执行结果、字段冲突、重试身份与可撤销能力；先处理授权范围内的本地普通操作 | 依赖 1；保留旧入口契约，仓储/`ModelChanges` 注入测试；逐动作检验相同输入产生相同写入与副作用次数。安全、权限和跨系统一致性改造单独审批，不能随普通提取潜入。 |
| 4 | 两宿主共享搜索与指令发现 UI，页面默认条件与筛选双向同步，统一结果与键盘；删除已被替代的重复页内搜索 | 依赖 1、2；建议改 `Features/Search`、`Workspace`、`MenuBar`、手记/标签/剪贴板宿主及必要 `Theme`。原页面草稿/滚动、显式范围/删除标记、独立查询、菜单栏与最小窗口等价后才移除旧入口；受限选择器不冒充普通搜索。 |
| 5 | 可编辑预览与长正文、操作草稿、多字段/多对象/多设置、队列执行、冲突处理、真实撤销、关闭/退出与主动转交 | 依赖 3、4；故障注入验证固定集合、未完成参数、顺序合并、依赖暂停、部分成功重试不重复创建、目标草稿不覆盖和唯一提交所有权。设置事务先有证据再开放多设置提交。 |
| 6 | 完整接入通知/日历、剪贴板外部粘贴、权限与隐私、回收站永久动作、导入/备份/恢复等独立流程 | 依赖相应业务适配与明确授权；每项现有功能可在入口发起并完成原有流程，不以打开设置页代替。区分本地/外部成功，取消仅底层支持时提供；安全/真实系统证据分别报告。 |
| 7 | 最近功能标识、固定指令、用户主动保存的查询/操作模板；全目录验收与文档收口 | 依赖稳定 ID/语法及模板数据边界决定；模板仅预填、相对日期/失效引用可见、无默认敏感历史；第 8 节逐项入口等价并完成原生矩阵，才可称全体系交付。 |

搜索实现与业务动作提取可在契约稳定后按独立范围安排，但生产入口开放必须等待相应执行/失败契约。实施不要求新增框架、包、模型表或磁盘草稿；确有必要时另论证与授权。

### 9.2 阶段 1 的可检查交接

1A 只建立目录、参数与能力声明；1B 才建立解析/补全及查询状态转移，1C 才建立草稿、队列和转交契约。三个子阶段均**不直接改现有设置绑定、不启动统一产品 UI、不触碰私密锁/持久化**。目录每项至少包含稳定 ID、规范路径、中文/英文名称与别名、分类、适用范围/目标类型、必需参数、字段模式、预览要素、风险/授权、能否排队、重试/撤销能力声明及现有业务出处。声明“待实现”不得伪装成 handler 已可执行。

最小验收案例：

1. `/`、`/set`、`/setting`、完整语言路径及中文别名补全；普通文本、引号/转义、标签、未知路径保留可编辑诊断，不静默执行。
2. 默认 `/tasks` 不激活结果，主动条件激活；删范围后同页刷新不补回；切页保留关键词；用户范围不覆盖；改范围/退出页面绑定不回写旧筛选；清查询返回原页面。
3. 操作草稿与查询隔离：切页不能改目标/正文；“未指定/清空/多个不同值”可区分；设置组合、正文追加、习惯具体日期和固定多对象集合均可表达。
4. 提交/授权/执行/成功/失败/冲突/未执行状态、依赖与重试身份可表达；成功项不重放，普通赋值合并但顺序动作不丢；转交目标占用/执行中/授权中拒绝，失败源保留，成功单一所有权。
5. 全量目录覆盖第 8 节每一动作；范围不会隐藏全局指令；受限选择器限制显式；凭据不进入可序列化参数/历史模板。

实际修改 Swift 后按[验收技能](../.agents/skills/areachain-verify/SKILL.md)跑相应 Domain 定向测试、必要构建及静态门禁；公共契约/复杂状态实现后交 Cursor `verifier` 独立只读复核。阶段 0 没有运行时行为变化；阶段 1A 的实际复核可用性和测试结果见 9.6，不以静态阅读替代独立复核。

### 9.3 后续回归入口与证据缺口

以下测试源码已经定位，部分关键用例已阅读，但本阶段均未执行。测试存在不能证明新增目标已经被覆盖。

| 领域 | 现有测试入口 | 必须补齐的目标证据 |
|---|---|---|
| 查询/语法/日期 | [Domain 测试](../AreaChainTests/Domain)：`BoardSearchTests`、`UnifiedSearchTests`、`SyntaxAutocompleteTests`、`TagSyntaxTests`、`DayKeyTests` | 完整目录、范围来源/激活、短语与排除、排序案例、全部对象类型与跨字段片段。 |
| 公共 UI/键盘 | [Theme 测试](../AreaChainTests/Theme)：`SyntaxOverlayPlacementTests`、`DaybookTextFieldSearchTests`；[Features 测试](../AreaChainTests/Features)：`InputSyntaxInteractionTests`、`MenuBarSearchShortcutTests`、`WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests`、`WorkspaceAttachmentSearchTests` | 上补全下预览并存、附件键盘序列、输入法/撤销、Return 与 ⌘Return、Esc 分层、不抢焦点、页面滚动和所有宿主语言/主题/尺寸矩阵。 |
| 任务/规划/标签/图片 | Services `InputSyntaxPersistenceTests`、`AttachmentOwnerLookupTests`；Domain `ManualOrderConversionTests`、`DiaryMutationsTests`、`TagCatalogTests`；Features `SubtaskTitleEditingTests`、`RecurringItemEditorTests`、`CalendarMonthNavigationTests`、`GanttInteractionTests`、`GanttReschedulingTests`、`QuadrantLayoutTests` | 转换不重复创建、父子完成与恢复、习惯 skip 差异、检查日、日历/安排改期与取消、预置标签清理范围、合并私密标签门禁、截图及文件面板回调鉴权。 |
| 草稿/生命周期 | `DiaryEditorSessionTests`、`DiaryWindowLifecycleTests`、`AppTerminationTests`、`PrivacyInteractionTests`（Features） | 通用操作草稿、非手记草稿保护、转交冲突、目标已占用、部分保存后取消及执行中关闭。 |
| 业务事务 | [Services 测试](../AreaChainTests/Services)：`ModelChangesTests`、`SwiftDataTaskRepositoryTests`、`SwiftDataRoutineRepositoryTests`、`SwiftDataCatalogDiaryRepositoryTests`；Domain `BatchMutationsTests` | 字段冲突、设置组、顺序队列、幂等重试、部分成功、可恢复撤销与原按钮等价。 |
| 剪贴板/设置/导航 | Domain `ClipboardHistoryTests`、`ShortcutCatalogTests`、`ProjectSupportTests`；Services `AppPreferencesTests`、`ShortcutStoreTests`、`AppWindowsRoutingTests`；Features `SettingsSectionPresentationTests`、`ShortcutsPageTests`、`DashboardInteractionTests` | 工作台粘贴接收端、历史读取失败、设置批量失败、搜索中显式导航、快捷键作用域和外部打开失败。 |
| 通知/日历 | Services `NotificationSchedulerTests`、`CalendarSyncEngineTests` | 原 UI/指令等价、局部成功、冲突和过期对象；真实送达、权限与真实日历单独验收。 |
| 隐私/数据/恢复 | Services `PrivacyVaultTests`、`PrivacyPersistenceTests`、`PrivacyStoreMaintenanceTests`、`SnapshotImportValidationTests`、`PrivateBackupTests`、`PrivateBackupCancellationTests`、`AttachmentCleanupTests`；Features `DataBackupInteractionTests`；Domain `SoftDeleteTests` | 安全参数排除、失效认证、未配置备份可达性、取消/提交后清理失败、固定目标恢复和重置失败；真实数据与系统凭据不属于普通自动测试。 |

新查询的端到端延迟、长文编辑、最大候选/目标规模、内存及排序权重尚未测量；沿[性能基线](performance-baselines.json)的方法使用合成数据建立，不能借用旧查询耗时保证新体系性能。

### 9.4 未决问题与单独授权边界

- **1A 命名已登记、1B 前定稿**：完整叶子路径与双语别名见目录和 9.6；短语/排除/同维度任一全部语法；`/tasks` 对习惯定义/某日记录/子任务的具体范围，以及停用习惯的搜索呈现；16 个页面及标签清单的自动条件、日期字段映射、默认范围删除标记离页后寿命。推荐显式类型/日期字段，避免用一个含混“日期”重写多种语义。
- **业务接入前核定**：单条/批量习惯“完成”是否保留 skip 的具体操作语义；普通标签合并进入私密标签时的保护处理。不能借新指令静默改变原有行为或绕过保护，涉及安全边界的处理需另行确认。
- **执行默认策略已确认**：按列表顺序执行；前置失败暂停依赖项，不依赖失败项的独立操作继续；已约定的共同保存设置组保持组内一致性，成功项不重复执行。这是已确认目标，1A 未实现。**执行开放前仍须定稿/验证**：哪些设置确实能共同保存及可观测失败/恢复保证；每动作重试和撤销能力；是否提供其他可选策略。
- **模板持久化前定稿**：主动模板允许保存哪些正文/对象引用、私密模板如何处理、固定/模板排序管理和失效引用修复交互。最近使用只存功能 ID 已确认，不能以待定模板策略放宽默认历史。
- **后续原生验证**：浮层上下空间不足时的具体最大高度与避让布局；工作台粘贴前台目标、活动搜索导航、全应用退出快捷键、所有旧草稿的关闭保护。现有静态证据不能证明原生运行效果。
- **已发现现状差距**：备份未配置锁可达性、取消句柄、恢复提交后清理失败；历史读取失败返回空；重置吞掉删除错误。纳入对应接入阶段的设计/回归，不顺带在阶段 0 修复。
- **单独确认**：认证/授权、密钥生命周期、加密/敏感处理、隐私转换、真实迁移/恢复、批量或永久删除、跨系统一致性策略、真实钥匙串/日历/系统权限操作，以及安装/发布。每次先说明具体影响、验证与回滚/恢复思路；本文不替代授权。

### 9.5 阶段 0 检查记录

本阶段只修改本文、`docs/README.md`、`docs/architecture.md`、`docs/features.md`；其余改动属于开始时已有或并行任务成果。

| 实际检查 | 结果与证据边界 |
|---|---|
| `python3 -B scripts/check_workflow.py` | 通过；文档内联链接、项目工作流、组件入口、技能格式/边界等静态检查。初次发现 `ClipboardPayload` 文件路径错误，已改为实际所在 `Classification.swift` 后重跑。 |
| `python3 -B scripts/quality_gate.py --profile static --format json` | 通过，无 warning/failed/blocked；包含 171 项脚本回归、Shell 语法、静态敏感日志/秘密扫描、注释与性能清单契约。选择 static 是为了避免已有他人 Swift 差异触发本阶段不需要的 Swift/应用测试；性能清单仍有 5 条历史未建立项，不是新查询已测。 |
| `git diff --check` 与新文件空白/引用核对 | 通过；新文档作为未跟踪文件也由质量门禁读取，不只检查 Git 已跟踪差异。 |
| 源码功能映射与文档只读核对 | 三个功能域只读核对，主代理抽查业务/安全/生命周期关键出处；另核对剪贴板/导航/快捷键文档表，修正方法行号、字母复制及纯文本搜索表述。不是运行时或实现后的 Cursor `verifier` 证据。 |
| Swift、构建、原生交互、真实认证/数据、安装、发布 | 本任务未运行；无 Swift 产品代码修改，本阶段不要求这些操作，不能借用其他任务的结果冒充通过。 |

交接结论仅为目标设计与实施基线已固化；新查询、指令、会话、批量执行与模板功能均尚未实现。

### 9.6 阶段 1A 目录决策与证据

本次只新增纯领域声明，未替换任何现有搜索/输入组件，未接仓储、偏好、文件、系统 API 或 handler。全部 `CommandExecutionBinding` 为 `unwired`，`isExecutable` 与实际入队能力均为 false；`eligibleAfterWiring` 仅表示未来普通队列兼容性。风险、认证和确认字段只描述交互要求，不能授予权限或替代业务检查。没有产品 UI、页面会话、草稿状态机、执行器、模板或历史持久化。

公共入口与维护责任：

- [CommandCatalog.swift](../AreaChain/Domain/CommandCatalog.swift)：`CommandCatalog.standard` 唯一聚合；按稳定 ID/规范路径读取、浏览子级、按功能映射读取、精确名称/别名匹配及显式选择器限制。普通 `discover` 不受内容范围影响；不做前缀补全或参数尾段解析。
- [CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift)：稳定身份、类别、目标、批量、范围政策、预览、队列、交互与能力证据。分组只浏览；范围改变查询；导航、修改与独立系统动作分开，取消编辑/保存现有编辑会话等另归 `interaction`。
- [CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift) 与 [CommandArgumentValidation.swift](../AreaChain/Domain/CommandArgumentValidation.swift)：有类型参数、值与操作；不采用任意字符串字典，不提供 Codable 或凭据字段。安全输入只声明交互需求。原生文件值仅为选择句柄 UUID，不含路径；句柄的存在、类型与权限须由后续原生适配重新核验。
- [CommandFeature.swift](../AreaChain/Domain/CommandFeature.swift) 与 [CommandCatalogValidation.swift](../AreaChain/Domain/CommandCatalogValidation.swift)：独立动作槽清单、缺失/重复/未知覆盖、路径与父子、参数/默认值/预览引用及队列边界校验。来源链接回第 8 节，避免复制业务实现规格。
- 定义按 Tasks、Content、Clipboard、Settings、Safety、Planning、Navigation、Support、Structure 分文件，只有上述一个聚合目录；没有按指令建立文件或 handler 类。当前运行消费者仅 [CommandCatalogTests.swift](../AreaChainTests/Domain/CommandCatalogTests.swift) 与 [CommandParameterTests.swift](../AreaChainTests/Domain/CommandParameterTests.swift)，1B/1C 应直接复用。

本次实际文件清单：上列 6 个核心 Domain 文件，加 [CommandCatalogBuilder.swift](../AreaChain/Domain/CommandCatalogBuilder.swift) 和 9 个功能域定义（[Tasks](../AreaChain/Domain/CommandCatalog+Tasks.swift)、[Content](../AreaChain/Domain/CommandCatalog+Content.swift)、[Clipboard](../AreaChain/Domain/CommandCatalog+Clipboard.swift)、[Settings](../AreaChain/Domain/CommandCatalog+Settings.swift)、[Safety](../AreaChain/Domain/CommandCatalog+Safety.swift)、[Planning](../AreaChain/Domain/CommandCatalog+Planning.swift)、[Navigation](../AreaChain/Domain/CommandCatalog+Navigation.swift)、[Support](../AreaChain/Domain/CommandCatalog+Support.swift)、[Structure](../AreaChain/Domain/CommandCatalog+Structure.swift)），共 16 个新增 Domain 文件；新增上述两份 Domain 测试。另增量编辑 [Localizable.xcstrings](../AreaChain/Resources/Localizable.xcstrings)、本文、[文档索引](README.md)、[架构](architecture.md)、[功能说明](features.md)、[组件目录](component-catalog.md)、[技能路由](../skill-routing.md)、[检查器](../scripts/check_workflow.py) 与[检查器测试](../scripts/tests/test_check_workflow.py)。未修改按钮实现、按钮测试、工程手册；它们的并行修改保留。

命名和参数决定：

1. 稳定 ID 采用 `todo.title`、`setting.language` 等不翻译的语义标识，规范路径小写斜杠加短横线。`/tasks`、`/diaries`、`/clipboard` 保持范围含义；`/go/*` 为导航。额外范围为 `/routines`、`/subtasks`、`/tags`、`/images`、`/trash`。`/tasks` 的结果集合仍标记 `unresolvedComposition`，未建立页面范围映射。
2. `/setting` 是分组，`/settings` 是它的精确路径别名；动作名称与双语关键词别名在既有语言资源中。别名允许歧义并返回候选数组；稳定 ID 不随翻译改变。`/setting/language` 只有一项，必填 `value = system / chinese / english`，中文“简体中文/简中/中文”匹配 `chinese`。`/setting/language/chinese` 是 1B 将解析的“指令+参数”示例，不新建叶子或语言执行逻辑。
3. `CommandParameterID` 为有限字段；枚举、布尔、整数/小数、民事日期、墙上时钟分钟、星期掩码、短文本/长正文、单/多类型对象、标签 ID 集合与原生面板均分型。语言/颜色/快捷键优先复用既有文案，颜色和快捷键候选复用既有目录。设置写入值必填，不因当前偏好默认值就静默产生一次修改；复制内容默认 `record`、浏览类型默认 `all`。现有设置初始默认值仍以 S1/C5 及原偏好代码为准。
4. 日期以 `DayKey` 解析后往返校验拒绝回卷；时刻用 `RemindMinutes`，星期用 `WeekdayMask.all` 验证且不把空选择自动收成每天。相对日期解析在 1B；日期参数在各命令中分别指修改日、检查日、导航日或统计基准日，不建立通用时间戳替代。指定日记录身份为习惯 ID + 明确民事日；普通对象不接受附带检查日。
5. `unspecified` 保持原值；`assign/clear`、`replace/append/clear`、`add/remove/replaceAll/clear`、`setReminder/cancelReminder` 有不同合法组合。备注默认替换、标签默认添加；正文可表达清空意图，但静态提交校验继续拒绝空白手记正文。`CommandOriginalValue.mixed` 与无值分开。批量正文要求明确对象、逐篇预览和独立确认，尚无正文编辑器或执行。
6. 待办完成状态与习惯启用状态使用独立参数，复用 `TodoStatusScope` 与 `RoutineStatusScope`；任务、子任务、习惯定义、指定日记录，记录置顶和窗口置顶均分型。清空历史/回收站声明显式目标集合，1C 才建立固定集合语义；附件仅单选 PNG/JPEG/HEIC/GIF/TIFF/WebP，暂无任意文件附件能力。
7. 普通全局内容排除剪贴板和已删除内容；目录发现仍可见这两类指令。只声明范围政策，没有提供者或检索。所有 retry/undo 默认 `unverified`；类型允许未来记录条件性/已核实/未实现证据，本次不因旧业务的局部能力宣称通用重试撤销。

目录规模为 **285 项：247 个动作/查询/导航/交互项，8 个范围、30 个分组；48/48 组映射，282 个独立动作槽各绑定一次**。同一参数化动作可覆盖多个效果槽，例如完成/重开、复制部分、启用/暂停；不同目标、风险和效果需分立的动作均有独立项。

未决/不可用声明：`occurrence.complete`、`batch.completion`、`notification.complete`、`quadrant.complete` 等待习惯 skip 语义；`tag.merge` 等待私密标签合并语义；`tag.cleanup` 等待预置清理范围；`backup.export` 等待无锁状态可达性决定；`diary.tags` 保留保护转换适配前置；`tag.unlinkGlobal` 无既有独立用户入口而 unavailable；`recovery.resetQuit` 因恢复点/失败反馈设计不足而 unavailable。共 8 项 unresolved、2 项 unavailable；其他项只声明目录存在，仍全部未接线。

下表登记全部叶子路径；稳定 ID、参数和双语别名以目录及语言资源为实现来源。本表只追踪第 8 节功能覆盖，不替代业务规则。

| 功能映射 | 1A 目录路径 |
|---|---|
| `T1` | `/tasks/add`、`/tasks/title`、`/tasks/cancel-title`、`/tasks/notes` |
| `T2` | `/tasks/completion`、`/tasks/cancel-completion`、`/tasks/move`、`/tasks/reminder`、`/tasks/priority`、`/tasks/tags`、`/tasks/create-tag`、`/tasks/due` |
| `T3` | `/tasks/copy`、`/tasks/trash` |
| `T4` | `/subtasks/add`、`/subtasks/completion`、`/subtasks/title`、`/subtasks/cancel-title`、`/subtasks/tags`、`/subtasks/order`、`/subtasks/delete` |
| `T5` | `/routines/capture`、`/routines/add`、`/routines/title`、`/routines/notes`、`/routines/weekdays`、`/routines/reminder`、`/routines/priority`、`/routines/tags`、`/routines/enabled`、`/routines/order`、`/routines/trash` |
| `T6` | `/routines/checks/complete`、`/routines/checks/reopen`、`/routines/checks/skip`、`/routines/checks/inspect`、`/routines/streak` |
| `T7` | `/selection/clear`、`/tasks/batch/move`、`/tasks/batch/completion`、`/tasks/batch/tags`、`/tasks/batch/enabled`、`/tasks/batch/trash` |
| `T8` | `/tasks/convert-to-routine`、`/routines/convert-to-task` |
| `T9` | `/tasks/sections`、`/tasks/postpone-yesterday`、`/tasks/filter`、`/tasks/clear-filter`、`/tasks/kind`、`/tasks/status`、`/tasks/select`、`/tasks/order` |
| `T10` | `/capture/clipboard` |
| `B1` | `/calendar/mode`、`/calendar/step`、`/calendar/today`、`/calendar/day`、`/calendar/day-list`、`/calendar/add`、`/tasks/move` |
| `B2` | `/quadrant/day`、`/quadrant/step`、`/quadrant/add`、`/quadrant/priority`、`/quadrant/complete`、`/quadrant/inspect`、`/quadrant/copy` |
| `B3` | `/gantt/step`、`/gantt/current-month`、`/gantt/select`、`/gantt/shift`、`/gantt/complete`、`/gantt/inspect` |
| `J1` | `/diaries/add`、`/diaries/body`、`/diaries/save`、`/diaries/reload`、`/diaries/discard`、`/diaries/tags` |
| `J2` | `/diaries/tags`、`/diaries/pinned`、`/diaries/move`、`/diaries/reveal`、`/diaries/mask`、`/diaries/private-mark` |
| `J3` | `/diaries/copy`、`/diaries/to-task`、`/diaries/trash` |
| `G1` | `/tags/add`、`/tags/cancel`、`/tags/rename`、`/tags/color`、`/tags/order`、`/tags/search`、`/tags/view`、`/trash/tags` |
| `G2` | `/tags/merge`、`/tags/unlink-object`、`/tags/unlink-global`、`/tags/trash`、`/tags/restore`、`/tags/delete`、`/tags/cleanup` |
| `A1` | `/images/add`、`/images/paste`、`/images/capture`、`/images/preview`、`/images/browse`、`/images/trash` |
| `C1` | `/clipboard/browse`、`/clipboard/search` |
| `C2` | `/clipboard/copy`、`/clipboard/paste`、`/clipboard/paste-plain` |
| `C3` | `/clipboard/pinned`、`/clipboard/copy-letter`、`/clipboard/delete`、`/clipboard/prune`、`/clipboard/empty` |
| `C4` | `/clipboard/recording`、`/clipboard/skip-next`、`/clipboard/ignore-app` |
| `C5` | `/setting/clipboard/ignore-universal`、`/setting/clipboard/limit`、`/setting/clipboard/interval`、`/setting/clipboard/search-mode`、`/setting/clipboard/position`、`/setting/clipboard/click-action`、`/setting/clipboard/plain-text`、`/setting/clipboard/sound`、`/setting/clipboard/unignore-app`、`/setting/clipboard/add-pattern`、`/setting/clipboard/remove-pattern`、`/setting/clipboard/add-type`、`/setting/clipboard/remove-type` |
| `C6` | `/window/clipboard/open`、`/window/clipboard/close`、`/window/clipboard/pinned`、`/window/clipboard/workspace` |
| `S1` | `/setting/language`、`/setting/appearance`、`/setting/title-truncation`、`/setting/capture-source` |
| `S2` | `/setting/login`、`/setting/login-settings` |
| `S3` | `/notification/status`、`/notification/request`、`/notification/test`、`/notification/system-settings` |
| `S4` | `/notification/complete`、`/notification/snooze`、`/notification/open` |
| `S5` | `/calendar-sync/enabled`、`/calendar-sync/status`、`/calendar-sync/retry`、`/calendar-sync/system-settings`、`/calendar-sync/conflicts`、`/calendar-sync/open-local` |
| `S6` | `/setting/icloud` |
| `S7` | `/shortcut/record`、`/shortcut/reset`、`/shortcut/reset-all`、`/shortcut/cancel` |
| `P1` | `/privacy/create`、`/privacy/setup-method`、`/privacy/setup-tags`、`/privacy/protect-existing` |
| `P2` | `/privacy/lock`、`/privacy/unlock`、`/privacy/system-unlock`、`/privacy/set-password`、`/privacy/change-password`、`/privacy/remove-password`、`/privacy/idle`、`/privacy/tags` |
| `P3` | `/privacy/unprotect` |
| `P4` | `/privacy/maintenance/images`、`/privacy/maintenance/keys`、`/privacy/maintenance/quit` |
| `D1` | `/trash/browse`、`/trash/restore`、`/trash/delete`、`/trash/empty` |
| `D2` | `/data/export`、`/data/import/select`、`/data/import/validate`、`/data/import/preview`、`/data/import/apply` |
| `D3` | `/backup/export`、`/backup/inspect`、`/backup/preview`、`/backup/restore` |
| `D4` | `/recovery/status`、`/recovery/reset-quit` |
| `N1` | `/go/dashboard`、`/go/today`、`/go/pending`、`/go/all-items`、`/go/calendar`、`/go/quadrant`、`/go/gantt`、`/go/diaries`、`/go/images`、`/go/clipboard`、`/go/tags`、`/go/privacy`、`/go/backup`、`/go/trash`、`/go/settings`、`/go/shortcuts`、`/go/tag` |
| `N2` | `/window/workspace/open`、`/window/workspace/reveal`、`/window/workspace/close`、`/window/overlay/toggle`、`/window/overlay/mode`、`/window/routines/add`、`/window/routines/manage` |
| `N3` | `/inspector/open`、`/inspector/day`、`/inspector/close`、`/selection/all`、`/selection/clear` |
| `N4` | `/window/diary/open`、`/window/diary/draft`、`/window/diary/pinned`、`/window/diary/save`、`/window/diary/close` |
| `N5` | `/stats/today`、`/stats/pending`、`/stats/streaks`、`/stats/routines`、`/stats/diaries`、`/stats/trend`、`/stats/heatmap`、`/stats/activity`、`/stats/open-day`、`/stats/open-activity` |
| `N6` | `/help/syntax`、`/help/page`、`/help/example` |
| `N7` | `/support/version`、`/support/about`、`/support/discussion`、`/support/suggestion`、`/support/issue`、`/support/repository`、`/support/license` |
| `N8` | `/quit` |

验证记录（2026-10-01，macOS 26.6.2 / arm64）：

- 最终 `./scripts/build.sh test --only-testing AreaChainTests/CommandCatalogTests --only-testing AreaChainTests/CommandParameterTests --only-testing AreaChainTests/BoardSearchTests --only-testing AreaChainTests/UnifiedSearchTests --only-testing AreaChainTests/SyntaxAutocompleteTests`：53 项通过、0 失败/跳过，包含 22 项新契约测试与 31 项既有回归。结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_11-46-41-+0800.xcresult`，已用 `xcresulttool` 核对实际测试数。
- 最终 `./scripts/build.sh`：Debug development 构建及静态验签通过；不表示系统解锁或发行验收，未安装/启动生产应用。
- `python3 -B scripts/quality_gate.py --profile swift` 已实际运行：静态与 SwiftLint 通过；全量 Swift 为 1024 项通过、1 项失败、1 项按边界跳过（含参数化运行：1109 次通过、2 次失败、1 次跳过）。失败为既有 `CaptureOverlayLayoutTests/syntaxAndAttributesNeverResizeTheList(workspace:)` 的 key window 断言：`appActive=false`，前台标识 `com.areachain.app`。结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_11-38-38-+0800.xcresult`。这次总门禁为 failed，不能写成全绿；末次目录边界修改以随后 53 项定向结果为准。
- 工作流检查通过；检查器定向测试 52 项、完整脚本回归 172 项通过；本次全部 Command Swift 文件严格 SwiftLint 通过；静态 profile 与差异空白检查通过。原有测试的未使用值和旧 AppKit API 编译警告保留。
- 独立复核未完成：可用工具清单无 Cursor verifier 专用工具；Cursor CLI 已安装但 `agent status` 为未登录。已向 `agent --print --mode ask --workspace …` 提供只读 verifier 范围和证据，退出 1：`Authentication required`，没有进入审阅。未登录、读取凭据、修改配置，也未用其他代理冒充规定复核。按项目验收要求，阶段交付保持 **partial**。
- 失败焦点用例的隔离复测：采用 `build/CommandCatalogQA`、`com.areachain.command-catalog-qa`、local/ad-hoc、`LSUIElement=NO`、清除六个真实钥匙串授权环境变量及串行测试；复测 1 个参数化测试 / 2 次运行全部通过，0 失败/跳过，结果包 `build/CommandCatalogQA/Logs/Test/Test-AreaChain-2026.10.01_11-47-44-+0800.xcresult` 已核对。隔离通过支持宿主/焦点环境相关判断，但不能抹去原全量门禁失败或证明唯一根因。未做新产品 UI 验收，因本次无 UI 接入；没有真实认证、数据转换、安装或发布。

工作区：接手时已有 10 个已跟踪修改、2 个按钮测试/展示未跟踪文件，以及本权威文档未跟踪；暂存区为空。保留全部按钮、工程记录与检查器改动。期间工程手册又追加按钮阶段 B 验收记录，本任务未写该文件。文案只追加目录条目并复用既有键，原有资源值保持；目录、路由与检查器在已有修改上增量补充。未修改 `BoardSearch`、`SyntaxAutocomplete`、自然语言解析或输入组件。

#### 1A-R 独立复核与验收收口（2026-10-01）

**状态：partial。** Cursor 认证仍阻塞规定的独立复核；本轮隔离全量仍有焦点失败，随后定向通过不替代全量门禁。没有发现足以支持修改 1A 代码或公共验证脚本的证据。本轮只更新本节，不开发 1B，不改变 unresolved、unavailable、unwired 或高风险业务语义。

**代码与归属。** 接手时工作树及暂存区均干净，HEAD 为 `533164395cd8c16c317e92a945475bce2612654b`，包含上述 1A 成果和其他任务的按钮成果；相对父提交 `25a7cb3777f52983c26a6e3f938bd1fac0bd441d` 核对差异。`CaptureOverlayLayoutTests.swift`、`InputSyntaxInteractionTests.swift`、`NativeSyntaxUI.swift`、Scheme 和 `scripts/build.sh` 在该提交中均未改变。复用上述目录测试、原生测试和架构文档的 QA 命令，不新增验证入口。运行期间并行修改了 `DiaryCardComponents.swift`、`DiaryWindowView.swift`、`TaskDetailClassificationSection.swift`、组件目录，并新增 `DiaryButtonConsumerTests.swift`；全部保留，不计作 1A-R 成果。

**Cursor 复核阻塞。** 本会话没有 Cursor verifier 专用工具。实际 CLI 入口为 `/Users/as/.local/bin/agent`（另有 `cursor-agent`），版本 `2026.01.23-916f423`；`agent --help` 声明 `--print --mode ask --workspace` 为只读问答入口。本次 `agent status` 输出 `Not logged in`，退出码 0 仅表示状态查询成功。仓库与个人常规 `.cursor/agents/verifier.md` 路径均不存在；未核实其他命名 verifier 路由可调用。因认证前置条件不满足，本轮未发送审阅任务、未再次请求生成；上文 `Authentication required` 是历史调用证据。未读取凭据、调用 login 或修改个人配置，也没有用普通代理或主代理自查替代 Cursor 复核。

用户最小后续操作：自行运行 `agent login` 完成 Cursor CLI 认证；之后在最终 1A 差异上恢复 Cursor 只读 verifier 审阅并核实其入口。审阅范围是本节列出的 16 个 Domain 文件、两份目录测试、增量语言资源及相应文档/检查器差异，排除按钮并行成果。应向审阅者提供第 8 节原目标、1A 纯声明边界、该实际差异和下列新旧证据，要求逐项检查 48 组/282 动作槽的真实覆盖、参数/效果/对象对应、类别、双语名称/别名、风险/队列/未知能力/unwired、凭据交互与校验反例，并返回问题、`file:line`、行为影响及未覆盖项。若审阅后修改影响结论，需补充复核。现阶段这些业务语义问题仍未获得规定的独立结论；机械计数和测试通过不是语义完整性证明。

**历史焦点证据重新核对。** 本轮首先成功读取三个历史结果包的 `test-results summary`，核实原全量 1024 passed / 1 failed / 1 skipped、最终定向 53 passed、隔离定向 1 项 / 2 次 passed，计数与上文一致。进一步读取时，原 `11-38-38` 失败结果包已不存在；原因未知，本任务未删除它。因此该包目前只有本轮已读摘要和原记录可引用，不能承诺完整日志仍可复查。最终 53 项与旧 QA 包仍存在。

- 原失败摘要明确记录 `appActive=false, foreground=com.areachain.app`。当前调用链中，该错误来自 `CaptureOverlayHost.requireKeyWindow`（[测试源码](../AreaChainTests/Features/CaptureOverlayLayoutTests.swift)，432 行），经 `pressEscape` 在初始 `prepareFocus` 之后触发；这只是源码定位，原失败的具体迭代、PID、窗口事件和竞争来源未取得。
- 原 development 产物已被后续构建覆盖，不能用当前包的签名/Info.plist 代替失败时快照。原命令按脚本采用 development 测试宿主、测试专用 entitlement 和串行参数；失败时 Bundle ID、签名与应用激活配置的不可变产物证据不足。旧测试在当前 HEAD 形成前执行，未取得其完整源码指纹，不能仅凭现有文件宣称与当前代码完全相同。
- 旧 `CommandCatalogQA` 包的 Info.plist 为 `com.areachain.command-catalog-qa`、`LSUIElement=false`，当前签名为 ad-hoc；旧结果包的构建日志也记录 `Sign to Run Locally`，action 日志存在 XCTest 注入，参数运行确为 `workspace=false/true`。成功证明这两个隔离场景当时通过，不证明原全量通过或唯一根因。
- 另读 `build/ButtonStageB.xcresult` 核对展示测试于北京时间 11:37:16 结束；原全量于 11:38:38 开始，两份记录没有运行时间重叠。没有原失败时完整窗口/进程轨迹，仍不能排除其他窗口、测试状态残留或系统激活时序。

**可检验假设与本轮执行。** 假设一是宿主身份/激活配置与外部前台竞争；假设二是全套执行顺序或窗口状态残留。先沿[隔离验收命令](architecture.md#隔离验收与真实启用门禁)执行一次全量，以区分“仅定向通过”与全套条件；发现新的焦点失败后，只对原 53 项加三个焦点用例进行一次定向复测，没有再次循环全量。

两次均使用 `xcodebuild -quiet -project AreaChain.xcodeproj -scheme AreaChain -configuration Debug -destination 'platform=macOS,arch=arm64'`，并保留以下隔离设置：

```text
-derivedDataPath build/CommandCatalogReviewQA
AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=-
CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements
PRODUCT_BUNDLE_IDENTIFIER=com.areachain.command-catalog-review-qa
INFOPLIST_KEY_LSUIElement=NO -parallel-testing-enabled NO
```

调用前清除 `AREACHAIN_SYSTEM_KEYCHAIN_QA/RUN_ID/PHASE` 及三个 `TEST_RUNNER_` 对应变量，并持有现有 `build/.build.lock`，不启用真实钥匙串。测试宿主沿 `Persistence.makeSession` 的 XCTest 内存分支；原生夹具使用内存/临时合成数据。未安装、操纵或退出日用应用，也未使用 UI 工具抢占窗口。新 QA 包 Info.plist、ad-hoc 签名及 `codesign --verify --deep --strict` 已核对。环境为 macOS 26.6.2（25G83）/ arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6。

| 本轮检查 | 实际结果与边界 |
|---|---|
| 隔离全量，12:14:38–12:23:29 | `build/CommandCatalogReviewQA-Full.xcresult`：1023 passed、2 failed、1 skipped；含参数化运行为 1109 passed、2 failed、1 skipped，退出 65。原 CaptureOverlay 参数化用例两次均通过。真实钥匙串入口按原授权边界跳过。 |
| 全量新增失败 | `InputSyntaxInteractionTests/mouseCompletionInTheMiddleOfATagKeepsTheCaretAndUndo(multiline:)` 的 `true` 分支，以及 `notesRetainTheDraftUntilCommitInsteadOfCreatingPartialTags()`；均在 `NativeSyntaxUI.prepareFocus` 的原断言失败，`policy=0, visible=true, key=false, active=false`，前台分别为 `com.openai.codex` 和 `com.areachain.app`。结果包 `test-details` 已核对；这些标识不单独证明触发原因。 |
| 最终隔离定向，12:25:26–12:25:48 | `build/CommandCatalogReviewQA-Targeted.xcresult`：56 项 / 58 次运行全部通过，0 failed/skipped，退出 0。包括 CommandCatalog 11、CommandParameter 11、BoardSearch 15、UnifiedSearch 6、SyntaxAutocomplete 10 项，以及原 CaptureOverlay 用例和上述两个新失败用例；测试树已核实实际执行。没有跳过失败用例或放松断言。 |
| 目录静态核对 | 动作清单机械计数 48 组 / 282 槽；18 个 Command 源码及测试文件的 `swiftlint lint --strict --quiet` 通过。目录测试实际覆盖缺失/重复/未知动作、错误父子/路径/预览、参数类型与危险队列反例；完整业务映射仍待 Cursor 审阅。 |
| Debug 构建与验签 | `./scripts/build.sh --no-wait` 退出 0，Debug development 构建及脚本静态验签通过，日志 `build/CommandCatalogReviewQA/debug-build.log`；未安装或启动生产应用，不表示系统认证或发行通过。 |
| 最终静态门禁 | `python3 -B scripts/quality_gate.py --profile static --format json` 通过，包含工作流检查、172 项脚本测试、Shell 语法、敏感日志/安全静态、注释、性能契约及差异空白检查；结果 `build/CommandCatalogReviewQA/static-gate.json`。显式 static 避免因并行 Swift 差异调用非隔离的全量测试；未运行本轮 `--profile swift`，不能把静态通过合并成全量通过。 |

**输入可追溯性。** 完整命令、六项环境变量清除、起止时间与源码 SHA-256 保存在忽略的测试产物 `build/CommandCatalogReviewQA/evidence.json`、`targeted-evidence.json`，对应日志为 `xcodebuild.log`、`targeted-xcodebuild.log`。全量开始时清单指纹为 `f42e560578d57f15d2f4aa064df095c3232eb83454ef03ab2926da52ab5325c1`；上述三个按钮宿主文件在编译期间被并行修改，后来又新增按钮测试，故全量输入不是稳定快照，不能宣称当前整个工作树已通过全量。最终定向重新记录已跟踪和未跟踪的源码/工程/脚本输入，前后完全一致，指纹为 `d3ea754d2cd2fe07a92bec9596bf2af68a38f83c853fc5d8b02da54e2474784f`。这些并行文件的产品验收仍归其所属任务。

定向结束后，并行的 `DiaryButtonConsumerTests.swift` 再次修改；收尾按指纹确认，所选定向测试、其生产源码、工程和公共脚本未再变化。未对这份未被选择的并行按钮测试重跑本轮定向，也不声称其最新版本已验收。构建保留既有未使用返回值与旧 AppKit API 警告。

独立 QA 身份下仍出现其他焦点失败、随后短程复测通过，支持环境/时序相关假设，但尚未分离宿主配置、全套顺序和外部竞争的贡献，也没有证据认定是 1A 引入的产品回归。未修改公共验证脚本、生产行为或测试断言。恢复验收需要先补 Cursor 认证与独立结论，并在可保持焦点及稳定源码的条件下重新评估全量门禁；不以本记录自行豁免失败。**尚不具备把 1A 视为已验收并进入 1B 的依据，本轮在此停止。**

阶段 1B 建议范围：只做查询结构、斜杠/关键词/参数解析、补全候选、条件来源、页面范围与状态转移。必须复用 `CommandCatalog.standard`、稳定 ID、`CommandChoice`、参数/操作校验及范围政策；先定稿 9.4 的语法、`/tasks` 集合和页面规则。验收至少覆盖 `/`、`/set`、中文别名与语言参数尾段；未知路径/引号/转义保留诊断；普通内容范围不隐藏指令；默认条件不激活结果；删除范围同页不补回；切页保留用户条件；脱离绑定不回写；清查询返回原页。1C 的草稿/队列/转交继续隔离，不自动推进。

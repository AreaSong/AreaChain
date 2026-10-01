# 统一搜索与指令体系

## 0. 状态、权威范围与基线

**状态：1A 目录和 1B-1 纯领域路径解析/补全已实现，阶段仍 partial；历史证据见 9.6，本轮接口与检查见 9.7。产品 UI 与执行接入尚未实施。** 设计决定来自阶段 0 与本次已确认需求，源码核对日期为 2026-10-01，基线提交为 `25a7cb3777f52983c26a6e3f938bd1fac0bd441d`，另有下述未提交修改。本段及阶段 0 记录保留当时的静态阅读基线；阶段 1A 的实际 Swift 检查另记于第 9.6 节，不能混用历史证据。

本文是该体系唯一的目标设计来源，后续阶段在本文更新决定、映射及完成证据，不复制计划、不另建自动执行器。当前行为仍见[功能清单](features.md)、[使用说明](usage.md)、[架构](architecture.md)；目标与现状有差异时以本文的“目标”理解未来工作，不能据此宣称当前产品已有能力。实现继续遵循[项目规则](../AGENTS.md)、[技能路由](../skill-routing.md)、[组件目录](component-catalog.md)与[质量门禁](quality-gates.md)。本文件不授予安全边界变更、真实数据写入、系统权限、安装或发布权限。

2026-10-01 阶段 1B-2B 增量实施与证据见第 9.9 节。第 9.8 节“仅登记/未实现/不进入 1B-2B”保留为前阶段交接时点，不表示此次没有实施；前阶段指定复核及整树验收缺口未因此关闭。

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
| 1B-1 | 纯领域指令路径解析与补全 | 本轮限定授权；独立指令、双语匹配、简单参数尾段、UTF-16 候选及诊断。不涉及内容集合或页面决策；证据见 9.7，1A 仍 partial。 |
| 1B-2 | 内容查询契约、条件来源与页面状态转移 | 另行定稿短语/排除/AND/OR、tasks 集合、停用记录、16 页自动条件、日期字段及删除标记寿命；须另行授权。 |
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

更新：内容文法、范围组成、日期与页面访问寿命已由第 9.8 节的 1B-2A 授权增量确认；下方及 9.6/9.7 的旧未决记录保留其历史阶段含义，以 9.8 的确认目标和实际实现边界为当前交接。

- **1A 命名已登记、1B-2 前定稿**：完整叶子路径与双语别名见目录和 9.6；短语/排除/同维度任一全部语法；`/tasks` 对习惯定义/某日记录/子任务的具体范围，以及停用习惯的搜索呈现；16 个页面及标签清单的自动条件、日期字段映射、默认范围删除标记离页后寿命。推荐显式类型/日期字段，避免用一个含混“日期”重写多种语义。
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

独立 QA 身份下仍出现其他焦点失败、随后短程复测通过，支持环境/时序相关假设，但尚未分离宿主配置、全套顺序和外部竞争的贡献，也没有证据认定是 1A 引入的产品回归。未修改公共验证脚本、生产行为或测试断言。1A 完整验收仍缺 Cursor 独立结论，整树全量门禁仍需单独收口；不以本记录自行豁免失败。上一轮未进入 1B；对后续纯领域开发的限制范围，以下方续核的规则判读为准。

#### 1A-R 续核：分层状态与门禁适用范围（2026-10-01）

本轮只继续复核可用性与验收结论，未开发 1B、修改 Swift 或公共验证脚本。接手时 HEAD 为 `6657ba09ce54ba7d5e60176b86cc9105ed66b1d5`，工作树和暂存区均干净；此前按钮修改与上一轮收口文档已包含在该提交中，不是本轮提交的成果。

**认证只检查一次。** 用户表示已自行处理登录后，本轮执行 `/Users/as/.local/bin/agent --version` 与 `agent status`，版本仍为 `2026.01.23-916f423`，状态仍输出 `Not logged in`，退出码 0。CLI 没有返回更具体的认证错误；它只说明本轮该 CLI 未取得可用登录态，不能据此判断用户此前在什么入口或环境完成登录。遵照本轮要求，没有重试状态、调用审阅生成、登录或读取/修改认证配置。Cursor verifier 没有实际开始审阅，也没有新的独立发现或通过结论；上述待审范围和证据要求保留。需要用户在相同用户/运行环境下确认该绝对路径的 CLI 登录状态可用，再恢复指定复核，无需提供凭据。

**版本对应重新核对。** 本轮重新读取 `CommandCatalogReviewQA-Full.xcresult` 与 `CommandCatalogReviewQA-Targeted.xcresult` 摘要，原失败及 56 项/58 次通过均保留，没有重新执行 Swift 测试。比较 `targeted-evidence.json` 的全部 498 个源码/工程/脚本输入，当前仅 `AreaChainTests/Features/DiaryButtonConsumerTests.swift` 内容不同，没有新增或删除的输入；该文件不在当时定向选择中。1A 的 16 个 Domain 文件、两份目录测试、语言资源、所选搜索/焦点测试及其生产源码、工程和脚本均匹配；原第 8 节映射没有改变。因此既有定向证据仍适用于这些未变内容，不能扩展成当前 HEAD 的整树通过。当前清单 SHA-256 为 `94de27a2ff746e8f681c0fb2c90049bf7f72bb10f6b7b2ea6344340495463695`；本轮结束前再次核对源码稳定性。原全量编译期间的输入重叠是历史证据缺口，不能因现在工作树干净而消除。

| 验收层级 | 本次判定 | 规则依据与边界 |
|---|---|---|
| 1A 实现与定向验证 | 已实现；未变的目录/参数与搜索回归已有相应通过证据，阶段整体仍 partial | 本节原始 1A 清单及最终定向结果支持结构、动作槽绑定、参数校验、双语资源和未接线声明；真实业务覆盖、语义冲突与风险判断仍缺指定独立复核。按[验证技能“输出与边界”](../.agents/skills/areachain-verify/SKILL.md#输出与边界)，只在相关编辑使证据失效时补测，不把旧结果冒充本轮执行。 |
| Cursor 独立复核 | blocked，未执行 | [项目规则“新任务闭环”](../AGENTS.md#新任务闭环)及[路由“验证与交接”](../skill-routing.md#7-验证与交接)指定公共契约只由 Cursor verifier 复核；主代理分析、测试和构建均不能替代。 |
| 整树门禁 | 历史全量 failed；当前整树尚无稳定输入下的全量通过证据 | [质量门禁“状态语义”](quality-gates.md#状态语义)要求 failed 修复或明确授权暂缓，且“总结果只在没有 failed 或 blocked 时允许继续交付”。本轮没有暂缓授权，也不将历史失败改写为 passed。当前其他任务的按钮验收记录归其自身范围。 |
| 后续纯领域开发 | 历史 UI 全量失败不构成所有纯领域开发的一律禁令；本轮仍不进入 1B | [项目规则“按影响选择验证”](../AGENTS.md#按影响选择验证)要求按真实影响选测试，[质量门禁“使用方式”](quality-gates.md#使用方式)按差异选最小适用范围；前述 failed/blocked 限制的是验收完成及交付。规则没有“任何历史全量失败清零前禁止所有后续代码实施”的条款。 |

**1B 的具体结论。** 本轮授权明确止于 1A-R，故不允许本轮执行 1B。若之后另行明确授权，且先完成第 9.1/9.4 节要求的语法、`/tasks` 集合、停用习惯呈现、页面自动条件、日期字段与删除标记寿命等定稿，现行规则不单因历史 UI 焦点失败禁止边界明确的纯领域实施。此判读不表示 1A 已完整验收、不表示目录公共契约已获独立认可，也不豁免后续阶段的验证/复核：依赖未决契约的部分不能擅自定案；公共契约仍须 Cursor 复核，Swift 改动仍须遵守[路由“质量门禁”](../skill-routing.md#5-质量门禁)的 `--profile swift` 要求。不能将局部开发许可表述为“1A 已通过、1B 可无条件交付”。

**是否现在需要全量。** 本次只改验收文档，按[项目规则文档验证边界](../AGENTS.md#按影响选择验证)，不因此运行整套应用测试；本轮不需要以再次全量来证明上述规则判读。若后续目标是关闭整树全量门禁，则应先满足：相关并行源码工作结束；建立可复查的提交/差异与输入指纹并在执行后核对一致；没有竞争的构建/原生测试；按架构文档的独立 QA 标识、隔离目录、合成数据、六项授权清除及串行配置运行；留出不操作其他窗口的焦点时段，不退出或操纵日用应用。条件满足后，才执行一次目的明确的全量以检验稳定整树和既有焦点失败；仍失败则保留结果并缩小原因，不循环至偶然通过。本轮没有停止其他任务、覆盖并行修改或重跑全量。

本轮新执行 `python3 -B scripts/quality_gate.py --format json`，默认按唯一文档差异选择 `docs` profile，通过工作流（内含 `check_workflow.py`）、差异空白、性能契约及注释检查。收尾源码指纹与上述当前清单一致，工作区仅本权威文档有差异，没有观察到本轮核验期间的源码修改。未重跑 Swift、SwiftLint、172 项脚本回归或构建；这些上一轮结果均维持其原证据范围，不能归为本轮新通过。**本轮交接：1A 实现/定向证据保留，Cursor 复核 blocked，整树验收未通过，阶段整体 partial；本轮不进入 1B。**

此前 1B 建议范围（现按本轮授权拆为 1B-1 / 1B-2）：查询结构、斜杠/关键词/参数解析、补全候选、条件来源、页面范围与状态转移。必须复用 `CommandCatalog.standard`、稳定 ID、`CommandChoice`、参数/操作校验及范围政策；先定稿 9.4 的语法、`/tasks` 集合和页面规则。验收至少覆盖 `/`、`/set`、中文别名与语言参数尾段；未知路径/引号/转义保留诊断；普通内容范围不隐藏指令；默认条件不激活结果；删除范围同页不补回；切页保留用户条件；脱离绑定不回写；清查询返回原页。1C 的草稿/队列/转交继续隔离，不自动推进。

### 9.7 阶段 1B-1 指令路径解析与补全

**授权与状态：已实现，阶段仍 partial。** 本轮只实施明确授权的 1B-1，不代表 1A 已验收；1A 的 Cursor 指定复核与整树历史焦点失败均保留。不启动另一轮 1A-R，不重复检查认证，不修改认证配置。完成本阶段后停止，不进入 1B-2 / 1C。

接手已有三份隐私按钮源码修改和本文的 1A-R 续核记录；期间又出现隐私按钮测试及相关文档修改，全部保留。本轮仅新增 Domain、Domain 测试，并增量维护本文、组件目录、架构和技能路由。不改目录声明、语言资源、生产 UI、旧搜索/补全、仓储、设置、文件、系统服务或持久化。验证脚本接口未变化，且本轮范围限定 Domain/测试/文档，沿现有守卫验证，不扩展检查器。

#### 真实接口与消费者

| 文件/接口 | 输入输出及复用边界 |
|---|---|
| [CommandPathParser.swift](../AreaChain/Domain/CommandPathParser.swift) — `CommandPathParser.parse` | 可注入目录，默认 `CommandCatalog.standard`；接收请求，返回原始文本、编辑状态、原描述符、有类型参数、原参数校验结果、诊断与候选。当前消费者仅新 Domain 测试。 |
| [CommandPathResult.swift](../AreaChain/Domain/CommandPathResult.swift) — `CommandPathRequest` / `CommandPathResult` / `CommandPathCandidate` | 请求携带显示语言、UTF-16 光标、显式选择器、内容范围和组合输入状态；结果区分普通文字、分组、范围、指令、未完成路径、参数不完整、无效输入。候选携带稳定身份、原描述符/类别、显示文本、替换范围、插入文字、匹配类别和下一步意图。 |
| 同文件 — `CommandPathResult.accepting` / `CommandPathText` | 仅接受结果中的候选；要求原始 UTF-16 缓冲一致、无组合文本且范围在完整字符边界。返回文本、光标与编辑意图；无提交或执行接口。复用 Foundation `NSString` / `NSRange` / `Range(_:in:)`，拒绝 surrogate、组合字符和 emoji 序列内部边界，不钳制非法偏移。 |
| [CommandPathResolver.swift](../AreaChain/Domain/CommandPathResolver.swift) | 复用目录父子、路径、路径别名、中英文名称/关键词别名；多匹配返回数组，不使用 first-wins 便捷查询裁决歧义。 |
| [CommandPathArguments.swift](../AreaChain/Domain/CommandPathArguments.swift) | 复用 `CommandParameter`、`CommandChoice.matches`、`CommandArgumentValidation`；只解释唯一简单参数，不建立第二份指令表。 |
| [CommandPathCompletion.swift](../AreaChain/Domain/CommandPathCompletion.swift) | 按光标生成局部路径/参数候选，复用 `discover`；默认内容范围不影响发现，特殊选择器才限制可见目录。 |

分组候选只产生 `expand`；其他目录候选产生 `complete` 或 `chooseParameter`；参数候选产生 `setArgument`。没有 execute/submit 分支。`unwired`、`unresolved`、`unavailable` 和不可执行状态原样保留，静态参数校验不授予权限。诊断为结构化代码、ID、NSRange，本阶段未新增用户诊断文案或 UI。组词期间可计算结果但不能接受；组词结束须重新计算，领域不强制提交组词。

#### 本阶段语法决定

- 独立输入仅在位置 0 的 ASCII `/` 触发，不跳过前导空白，不扫描正文中间斜杠。单段未知 `/unknown` 为可编辑未知指令；多段输入只有首段能精确解析为目录路径/名称/别名才进入指令文法，否则作为普通路径文字。目录根词是保留命名空间，如 `/setting/unknown` 会报未知路径。
- `//server/share`、相对路径、URL、前导代码/Markdown 链接/转义不触发。保护区间复用 `TagSyntax.protectedRanges`，其中候选片段不替换。普通路径与未知指令不自动删除任何文字。
- `/` 是分组，`/set` 是前缀；`/setting` 与 `/setting/` 是分组；`/settings` 是已有路径别名，可继续 `/settings/language`。`/application settings`、`/应用设置`、`/change language`、`/语言` 沿已有名称和别名匹配，完整空格别名可用，不将任意空格文本解释成混合查询。
- `/setting/language`、`/setting/language/` 为参数不完整；`/setting/language/chinese`、`/应用设置/语言/简中`、`/settings/language/中文` 解析成同一个 `setting.language` 的 `.value = .choice("chinese")`，不增加语言叶子指令。两种语言匹配与显示语言无关；沿已有不区分大小写/音调的匹配方式，不做模糊纠错。
- 允许一个结尾分隔斜杠，不归一化连续空片段。引号、反斜杠、换行、查询符号不属于本阶段连续路径语法，保留输入并给诊断。未知参数保留为可编辑的不完整/无效结果。
- 只有目录恰好声明一个 choice / boolean / number / day / time 参数、默认操作需要值且不要求 secureInput，才解释一个尾段。choice 使用既有双语别名；boolean 只用 `true/false`；number 沿既有范围/整数规则；day 仅 `yyyy-MM-dd` 规范民事日；time 仅 ASCII `HH:mm`。不读真实时钟，不生成当前日或相对日期候选。
- 多参数、对象、长/短正文、标签、星期集合、安全输入、原生文件/快捷键不强行编码为连续路径，返回 `chooseParameter` 和参数 ID；没有可选参数却附加尾段时返回 unsupportedTail。声明中的复杂参数可发现，不代表已解析完成。
- 全文精确规范路径优先于别名及参数解释。别名与有效尾段冲突、多个别名或参数别名匹配均报 ambiguous 并保留候选，不选择第一个。显式选择器先确定真实身份再检查限制，不能退回允许的别名/参数解释绕过限制。参数候选也排除与精确目录路径冲突或指向受限目录的插入结果。

#### 候选排序与替换

1. 精确规范路径、规范路径前缀、精确名称/别名、名称/别名前缀、精确参数值/别名、参数前缀，依次排序。同档按规范路径、稳定候选 ID 排序，不依赖目录数组顺序、显示语言、历史或任意权重。
2. `/`、`/set`、`/setting`、`/setting/la`、中文关键词均可补全；完整单参数命令无尾斜杠也可追加参数。根部名称可定位全目录；明确父级下匹配其下路径/直接子项名称及父级参数。
3. 查询取片段起点到光标的前缀；替换覆盖当前片段的剩余拼写，保留下一斜杠及后续正文。例如 `/setting/lanWRONG/chinese 后续` 在 `lan` 后接受候选，得到 `/setting/language/chinese 后续`；全文仍不作为混合查询解析。参数候选也仅修改对应片段。已知的多词名称/别名作为完整片段替换；跨分组路径别名会将截至当前片段的路径改为目标规范路径，仍保留后续文字。
4. 默认发现保留不可用/未解决项，内容范围不隐藏设置等功能；显式选择器仅发现允许 ID 和祖先路径。祖先帮助展开，不允许借参数或别名获取额外能力。限制是发现/解析配置，不是业务权限判断的替代品。

#### 验证与未完成项

新增 [CommandPathTests.swift](../AreaChainTests/Domain/CommandPathTests.swift) 与 [CommandPathConflictTests.swift](../AreaChainTests/Domain/CommandPathConflictTests.swift)，覆盖指定路径、双语别名、目录与参数冲突、多匹配、排序、复杂参数、限制绕过反例、中间替换、Unicode、组词/过期缓冲、普通路径/URL/保护区间及全目录能力不升级。使用合成目录和文本，无真实数据、时钟、文件或系统操作依赖。

实际验证（2026-10-01，macOS 26.6.2 / arm64，Xcode 26.6 / Swift 6.3.3 / Python 3.9.6）：

| 检查 | 实际结果与边界 |
|---|---|
| 最终定向 `./scripts/build.sh test`，选择 `CommandPathTests`、`CommandPathConflictTests`、`CommandCatalogTests`、`CommandParameterTests`、`BoardSearchTests`、`UnifiedSearchTests`、`SyntaxAutocompleteTests`、`TagSyntaxTests`、`SyntaxHotPathTests`（各使用 `--only-testing AreaChainTests/类名`） | 83 项 / 86 次运行通过，0 失败/跳过；其中新增 17 项。结果已由 xcresulttool 核对并保存在 `build/CommandPathQA/Targeted.xcresult`，摘要 `targeted-summary.json`，日志 `targeted.log`。这是最终解析器版本的定向证据。 |
| `python3 -B scripts/quality_gate.py --profile swift --format json` | 实际运行一次，返回 passed；静态与 SwiftLint、172 项脚本回归通过，全量 1049 项通过、0 失败、1 跳过（含参数化为 1151 次通过）。摘要 `build/CommandPathQA/full-summary.json`，门禁输出 `swift-gate.json`。运行期间有并行 UI 修改和本阶段候选边界收尾修改，不代表最终整树的稳定快照；最终领域版本以上述定向结果为准，不据此关闭 1A 历史焦点失败。 |
| 全量结果保留边界 | 原包 `Test-AreaChain-2026.10.01_13-04-32-+0800.xcresult` 的摘要已提取；后续再次查询原路径时已不存在，未取得跳过项的详细清单，不猜测其身份。没有为取得另一次通过而重跑全量，摘要及门禁记录仍保留。 |
| `./scripts/build.sh` | 最终 Debug development 构建、静态验签通过；日志 `build/CommandPathQA/build.log`。没有安装或启动生产应用，不证明系统解锁或发行通过。 |
| 工作流、静态与源码差异 | `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、新增 7 份 Swift 文件的 `swiftlint lint --strict --quiet` 和 `git diff --check` 通过；静态结果保存在 `build/CommandPathQA/static-gate.json`。旧 AppKit API 和既有未使用值编译警告保留。 |
| 指纹与归属 | 最终定向前后 29 份 Command 源码/测试及 BoardSearch、SyntaxAutocomplete、TagSyntax、L10n 文件 SHA-256 一致，清单见 `source-before.json` / `source-after.json`；清单指纹 `7db291fee1414df8b42d0d42a1bf25260e314128ef6b8dcbeb571382ce82a429`。其他按钮/设置任务差异保留，本轮不认领其验收。 |

开发中曾发现两个失败：首轮测试使用了目录未声明的 appearance 别名，改成既有 change appearance；随后冲突测试发现精确参数候选可能排在精确子路径之前，已修正排序，并进一步禁止参数候选覆盖规范目录路径或绕过选择器。补充了跨分组别名、多词别名中间替换、原始 UTF-16 过期缓冲与直接补全入口非法偏移保护；最终定向全部通过。1A 接口没有因此改变。

Cursor 指定只读复核仍 blocked / 未执行；本轮不重复检查认证，不以其他代理或主代理自查替代。没有新产品 UI、真实系统、安装、发布或远端 CI 验收。**1B-1 保持 partial，1A 历史结果不改写，本轮到此停止。**

**1A 必要修正：无。** 原目录、参数声明/校验与旧搜索/补全生产行为不变。

**1B-2 待定稿：** 短语/排除/AND/OR 与引号/转义的内容查询文法；独立指令和混合条件的组合；`/tasks` 是否包含习惯定义、某日记录、子任务与停用记录；16 页及标签页默认条件、日期字段；来源/绑定/脱离/清除/返回规则；默认范围删除标记离页保留期限。草稿、固定目标、队列、转交留在 1C，本阶段不替用户决定。

### 9.8 阶段 1B-2A：内容查询语法、范围与日期契约

#### 2026-10-01 增量确认目标（不等同实现或验收）

本次明确授权纯 Domain 实现及测试；不接 UI、数据提供者、匹配排序、真实执行或页面状态。1A、1B-1 仍 partial，指定 Cursor 复核 blocked 与历史整树验证缺口保留；不重查认证、不改认证配置、不用其他复核替代。

- **范围**：`/tasks` 包含一次性任务、子任务、启用习惯定义及已完成任务，默认排除停用习惯，可显式包含；`/subtasks` 只查子任务；`/routines` 包含启用与停用定义，未来展示必须明确状态。某日执行记录只通过显式记录范围或对应查询操作访问，不混入普通结果。软删除仅回收站；剪贴板历史仅显式 `/clipboard`。内容范围不限制全局指令发现。
- **语法**：空白分隔文字取交集，允许分别命中适用字段；双引号为连续短语；`-文字`、`-"短语"` 排除文字；多个 `#标签` 取交集，`-#标签` 排除；`(原子 | 原子)` 为同维度任一，不支持跨维度或任意嵌套。不同条件取交集，重复保留，矛盾诊断，不最后值覆盖。`!p1` 和 `@15:30` 保持既有优先级/提醒语义。`status:open/done`、`date:today/2026-10-01/2026-10-01..2026-10-07`、同格式 `created:`、`has:image`。机器词稳定，中文别名映射同一语义。引号、转义、代码保护沿 TagSyntax 协调；不完整输入保留并诊断；不适用字段明确说明，不静默放宽、模糊匹配或执行。
- **日期**：任务安排日；子任务父项安排日；手记归属日；习惯记录执行日；习惯定义区间内应执行日；图片所属记录业务日；剪贴板采集日；标签 date 不适用。created 仅真实拥有创建字段的类型。习惯定义区间内存在应执行日即可匹配，每个定义只返回一次，具体日期另选。逾期复用现有判断，不能以星期匹配代替。today 必须支持，当前日与日历显式注入，预览返回具体民事日期；不以 UTC 时间戳替代。其他相对词不自行扩展。

#### 1B-2B 已确认页面状态（仅登记，本次不实现）

| 页面 | 默认条件 |
|---|---|
| 总览、设置、快捷键、隐私、备份 | 全局 |
| 今日 | 任务＋今天 |
| 待处理 | 任务＋当前逾期/即将筛选 |
| 全部事项 | 任务＋当前显式筛选 |
| 手记 | 手记＋当前标签 |
| 图片 | 图片范围＋实际存在的筛选 |
| 剪贴板 | 剪贴板范围 |
| 标签管理 | 标签范围 |
| 标签内容列表 | 标签条件及该列表支持的内容类型 |
| 回收站 | 回收站＋类型筛选 |
| 日历 | 任务＋当前日/周/月区间 |
| 安排 | 任务＋展示期间 |
| 四象限 | 任务＋查看日期；仅明确选中象限时增加优先级 |

自动条件本身不激活结果；删除自动范围的意图在当前页面访问期间保留，刷新、重聚焦、打开详情或系统面板不重置；真正离页再进入重新提供默认条件。用户显式范围不被切页覆盖；独立查询需明确操作才能重新绑定。各入口分别维护状态，操作草稿不受页面自动条件改写。

以下实际接口与验证记录在最终检查后补充；上述确认不表示提供者日期命中、页面状态或旧阶段验收已完成。

#### 1B-2A 实际实现与接口

| 文件与核心接口 | 已实现的边界 |
|---|---|
| [ContentQuery.swift](../AreaChain/Domain/ContentQuery.swift) — `ContentQueryInput` / `ContentQuery` / `ContentQueryClause` / `ContentQueryTerm` | content / command 分流；保留 source、每个范围/原子/组的 UTF-16 NSRange；clauses 取 AND、alternatives 取 OR。结构化诊断及相关条件位置；`isReady` 仅代表语法和静态条件检查可用，不代表有结果、激活或可执行。 |
| [ContentQueryParser.swift](../AreaChain/Domain/ContentQueryParser.swift) — `parse(_:context:)` | 默认现有目录，可注入合成目录。复用 CommandPathParser，不维护第二份目录；真实指令及其参数正文整段返回原 CommandPathResult。 |
| [ContentQueryLexer.swift](../AreaChain/Domain/ContentQueryLexer.swift) / [ContentQueryAtomParser.swift](../AreaChain/Domain/ContentQueryAtomParser.swift) | Character 扫描、UTF-16 定位；TagSyntax 保护区、引号标签与规范标签名；PriorityToken、NaturalLanguageParser 提醒解析。只解析确认字段，未知字段诊断。 |
| [ContentQueryValidation.swift](../AreaChain/Domain/ContentQueryValidation.swift) | 重复保留并提示；同维度标量交集、日期闭区间交集与文字/标签布尔条件的静态矛盾诊断。分析超限明确返回 analysisLimit，不忽略条件。 |
| [ContentQueryDates.swift](../AreaChain/Domain/ContentQueryDates.swift) — `ContentQueryDateContext` / `ContentQueryDateInterval` / `ContentQueryDates.parse` | 显式 todayKey 与 Calendar，复用 CommandArgumentValidation 严格日校验及 DayKey，闭区间及 intersection。不读取系统当前日、不扫描排程。 |
| [ContentQueryScope.swift](../AreaChain/Domain/ContentQueryScope.swift) — `ContentQueryScopeSelection` / `ContentQueryScopeContract.composition` | 全局、原目录范围、显式 routineOccurrences；停用习惯选项 includeInactiveRoutines。返回类型、liveOnly/deletedOnly、习惯启停范围与展示状态要求，不查询实际记录。 |
| 同文件 — `ContentQueryApplicability.binding` / `requirements` | 按类型返回真实字段或提供者投影要求；保留条件位置。notApplicable / requiresOccurrenceDay 不可忽略；isApplicable 仅判断字段具备，不证明实际命中。 |

**最小影响/复用表：** 新接口当前仅由 [ContentQueryTests](../AreaChainTests/Domain/ContentQueryTests.swift) 与 [ContentQueryContractTests](../AreaChainTests/Domain/ContentQueryContractTests.swift) 消费；生产 BoardSearch、旧补全、UI、Services、仓储均未接线。1A 仅将 [CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift) 中 `/tasks.inclusion` 从 unresolvedComposition 更新为 ordinaryContent，并更新原目录测试断言；详细集合由新范围契约维护，原枚举的 unresolvedComposition case 为兼容保留。1B-1 源码和目录参数没有修改。组件目录、架构与技能路由增量登记接口，检查脚本接口未改变，继续沿既有守卫验证，无新脚本或另一套流程。

#### 精确文法与诊断规则

- 内容范围可在开头与后续空白边界作为完整范围 token 出现；开头支持现有路径与多词/中文别名。最长完整目录头优先，真实指令、分组、参数路径与歧义不会降格为内容查询；正文中的真实指令报 unsupportedStructure，不执行或混入内容。多个相同范围保留并提示重复，不同范围报 incompatibleScopes，不擅自并集或让回收站扩大可见性。`/tasks 汇报 #工作` 为内容；`/setting/language/chinese` 为指令。未知独立路径按 1B-1 状态返回。
- 空白词是独立 AND 条件，允许不同适用字段分别满足；短语必须在同一个适用字段连续出现。排除文字要求各适用字段均不包含该文字/短语。标签沿 TagSyntax 规范名精确关联，不创建标签、不访问名称库。当前只输出语义，不实现匹配、大小写策略或模糊检索。
- 双引号字符串沿 TagSyntax 的 JSON 解码契约，包括引号/反斜杠转义；标签拼写沿 TagSyntax。引号外反斜杠可保护 `\\`、`"`、`#`、`@`、`!`、`-`、括号、`|`、冒号、斜杠和空格；未知转义明确诊断。代码与 Markdown 链接保护区整段作为原样文字（含定界符），内部符号不成为条件；未闭合代码按 TagSyntax 保护至其现有终点，不额外解释内部语法。
- 任一组必须至少两个原子，以 ASCII `|` 分隔，组内不隐式 AND；可用文字/短语、标签、优先级、提醒、状态、date、created、has:image 原子，同组只能同维度。排除仅文字与标签，组内同样适用。跨维度、嵌套、组外 `|`、范围组、不支持的括号结构都诊断，整条查询不可 ready。
- 标量重复取交集，如 `!p1 !p2`、不同提醒、open AND done 不可满足。日期各组为区间并集，各组之间交集为同一个业务日期窗口（created 独立窗口）；边界相交一天仍有效。未来习惯定义在这个窗口内存在应执行日返回一个定义，不把多条 date 当成多次打卡要求。
- 文字/标签的静态矛盾检查处理相同原子正反条件及 OR 组合；同文单词与单词短语可识别冲突。词语子串关系、真实字段内容、动态标签存在性及排程/状态联合命中留给提供者，不把“没有检测到矛盾”写成“必有结果”。为避免任意组合耗尽分析，单维度文字/标签最多 128 个原子及 4096 次分支步骤，超过时保留全部条件并报 analysisLimit。
- `!p1`–`!p4` 及现有中文优先级别名沿原规则；提醒明确使用 ASCII `@HH:mm`（00:00–23:59），不会作为日期。`status:open/done` 别名为 `状态:未完成/已完成`；`date:` / `日期:`、`created:` / `创建日期:`；`has:image` / `包含:图片`；today / 今天。机器字段与枚举不翻译。无候选 UI，本阶段不新增显示文案。
- 日期支持 today、规范 yyyy-MM-dd 和闭区间，两端可用 today；只接受显式公历 Calendar（其他历法返回诊断），使用调用方时区做 DayKey 往返校验，不将时区偏移转成业务日。闰日、非法日期、非规范日键与反向区间都检查。未闭合引号、尾部转义、缺值、未完成组、可识别的日期/状态/提醒前缀返回待补全诊断；原文始终保留。不实现其他自然语言相对词、逾期新语法或自动纠错。
- **不提供规范化文本输出**，因此没有“输出文本覆盖原始编辑缓冲”的路径；规范语义是结构化原子/组、范围、具体民事日期与诊断。重复条件不删除，不提供真实查询、排序、高亮、执行或页面激活。

#### 后续提供者必须处理的边界

任务/子任务完成用自身完成字段；习惯定义没有 done 字段，status 必须显式选择一个规范记录日后才得到 routineCompletionOnDay，date:today 不自动等同这个选择。执行记录用自身记录完成态，skip 的写入和显示口径仍按旧未决事项另行处理，不在这里定案。

日期映射按上方确认表实现。习惯排程必须综合创建日、暂停/启用历史与现有排程规则，先判断查询日期窗口内存在应执行日，再按定义 ID 去重；同一习惯的具体执行日另选。图片先解析真实拥有者再取其业务日期；子任务取父安排日；剪贴板由 copiedAt 按注入日历得采集日。逾期复用 AgendaProjection.overdueRoutines / Classification 既有判断，不用星期命中冒充逾期。这些均未接提供者、没有运行命中证据。

created 仅 todo/subtask/routine/diary/image 有真实 createdAt；tag、routineOccurrence、clipboardEntry 不适用，copiedAt 不伪装 createdAt。priority/reminder 仅 todo/routine；tags 仅 todo/subtask/routine/diary；has:image 对 todo/routine/diary 为关联图片，对 clipboardEntry 为 imageFile，对子任务/标签/图片本身/执行记录不伪造附件字段。文字字段只声明真实内容对象（执行记录无自身正文）；未来是否提供拥有者文字投影须明确适配，不能自动继承。对不适用类型不得忽略条件而保留该类型结果，未来 UI 需说明字段不适用或需要执行日期。

1B-2B 可复用结构化查询、原文范围、诊断、范围组成、字段需求与日期区间；条件来源/页面绑定/访问寿命/删除标记/返回位置仍全部未实现。不得用这些纯值接口推导页面状态已完成。

#### 1B-2A 验证与交接（2026-10-01）

**已实现并通过最终领域定向验证，阶段整体 partial。** 指定 Cursor verifier 仍 blocked / 未执行，本轮未检查登录、未改认证，也未用其他代理或主代理自查冒充指定复核。1A、1B-1 原验收状态和历史全量问题不改写；本次不进入 1B-2B。

| 检查 | 实际结果与可支持的结论 |
|---|---|
| 最终 `./scripts/build.sh test`，分别以 `--only-testing AreaChainTests/类名` 选择 ContentQueryTests、ContentQueryContractTests、CommandCatalogTests、CommandParameterTests、CommandPathTests、CommandPathConflictTests、BoardSearchTests、TagSyntaxTests、DayKeyTests、UnifiedSearchTests、SyntaxAutocompleteTests | **108 项 / 111 次运行 passed，0 failed / skipped**。包含新增 19 项；最终定向结果包已独立保存为 `build/ContentQueryQA/Targeted.xcresult`，摘要 `verified-targeted-summary.json`，日志 `verified-targeted.log`。只证明所选领域与旧搜索回归，不证明真实检索/UI。 |
| 最终 `./scripts/build.sh` | **Debug development 构建及静态验签 passed**，日志 `build/ContentQueryQA/build.log`。未安装、未启动生产应用，不代表系统认证/发行通过。 |
| `python3 -B scripts/quality_gate.py --profile swift --format json` | **failed**。静态、SwiftLint、172 项脚本回归通过；全量 1080 项中 1073 passed、6 failed、1 skipped（参数化运行 1201 passed、10 failed、1 skipped）。原输出 `swift-gate.json`，结果摘要 `full-summary.json`。四个领域失败对应下面已修正的 today 回归，另外两个为并行 PrivacyButtonConsumerTests 的布局/控件查找失败。本轮不修改那些 UI/测试。 |
| 本阶段失败修正 | 日期待补全扩展一度将完整 today/今天识别为前缀，影响四个新测试；已排除完整词，并由最终定向覆盖。新增适用性测试中 `#expect(allSatisfy(键路径))` 的宏展开曾导致编译失败，改成等价闭包，最终定向编译和运行均通过。保留 `final-targeted.log` 的编译失败记录，没有削弱断言。 |
| 严格局部 SwiftLint | 最终 7 份 ContentQuery Domain 文件与 2 份新测试的 `swiftlint lint --strict --quiet` passed，日志 `lint.log`。 |
| 输入追溯 | 最终定向前后 159 份 Domain/DomainTests/工程/脚本 SHA-256 全部一致：`source-before.json` / `source-after.json`，清单指纹 `5f897ba712a5a169441cee8f9f40fd505f1619f3f9dd8d6c554da6541165174d`。该清单不是整个 UI 工作树的稳定快照。 |

全量两个并行失败为 `PrivacyButtonConsumerTests.backupButtonsAndPasswordCancelStayIsolated(locale:scheme:)`（控件矩形越界）及 `homeUnconfiguredUnavailableAndCleanupLayout(locale:scheme:)`（找不到 privacy.system.cleanup.retry）。不能由本轮结果推断其最终并行修订已通过或失败。全量原 xcresult 在后续测试后已不在原路径，保留了完整摘要和失败清单，但未取得跳过项详情，不猜测其身份。没有反复重跑整树以取得偶然通过；本次修正后重跑真正受影响的领域定向，并单独构建。整树门禁仍 failed / 未收口。

中间一次 static profile 的 workflow-contract 返回 failed，其压缩输出未保留具体子项；立即单独重跑 check_workflow 全部通过，原因未确定，不归因于并行任务。首次 static 输出保留在 `static-first-run.json`；最终静态和文档检查以下方收尾记录为准。

接手时已有 1B-1、设置/隐私 UI、测试与文档改动；工作期间发生外部提交，HEAD 出现 `3fb7277`，含本阶段先写入的部分文件。本代理未暂存、提交、推送或回退该提交；最终差异不能单独代表本次全部成果，以本节列出的 7 份新 Domain 文件、2 份新测试、1A 两处最小调整与四份增量文档为范围。并行设置/隐私和工程手册改动保留，不认领其实现或验收。没有改生产 BoardSearch、TagSyntax、DayKey、CommandPath、数据提供者、UI 或任何真实执行入口。

**最终收尾静态记录：** `python3 -B scripts/quality_gate.py --profile static --format json` passed（工作流、差异空白、性能契约、172 项脚本回归、Shell 语法、安全与注释守卫）；输出 `build/ContentQueryQA/static-gate.json`。Debug 构建后再次核对上述 159 份输入仍一致。追加本记录后重跑 `python3 -B scripts/check_workflow.py` 与 `git diff --check`；本阶段不再更改 Swift。本阶段结论仍为领域实现/定向/构建已验证，完整验收 partial，指定复核 blocked，整树门禁未收口；不安装、发布或进入 1B-2B。

### 9.9 阶段 1B-2B：页面查询上下文与纯状态转移

#### 范围与实际接口（2026-10-01）

本次获准实施 Domain 契约、纯映射、状态转移和测试。开始时 HEAD 为 `3fb727743759ebbe2d631b0fcb95dcfd3ef61f5e`；已有 1B-2A、设置/隐私、测试及文档差异，实施期间另出现手记/日期菜单修改，全部保留。生产页面、旧搜索、共享筛选会话、操作草稿、执行器、权限与系统 IO 均未接线。本节不关闭 1A、1B-1、1B-2A 的指定复核及整树缺口。

| 文件 / 核心接口 | 责任与复用 |
|---|---|
| [ContentQueryCondition.swift](../AreaChain/Domain/ContentQueryCondition.swift) — `ContentQuerySemanticTerm`、`ContentQueryConditionValue`、`ContentQueryCondition` | 复用 ContentQueryAtom、范围、日期和 BoardFilter 枚举；包装无位置语义、稳定条件 ID、来源及最小页面谓词。 |
| [ContentQueryPageContext.swift](../AreaChain/Domain/ContentQueryPageContext.swift) — `ContentQueryPageLocation`、`ContentQueryPageContext`、`ContentQueryPageMapping.defaults` | 调用方显式提供宿主、访问、返回引用、页面、todayKey 和 Calendar；纯默认映射，不读取 WorkspaceNavigation、BoardFilterSession、偏好或数据库。 |
| [ContentQuerySession.swift](../AreaChain/Domain/ContentQuerySession.swift) — `ContentQuerySession`、`ContentQueryEvent`、`ContentQueryIntent` | 每宿主值状态；持有解析结果、有效条件、绑定、删除维度和返回引用。只输出页面同步、返回、需要查询编辑或拒绝事件。 |
| [ContentQueryReducer.swift](../AreaChain/Domain/ContentQueryReducer.swift) — `reduce(_:_:)` | 输入事件，输出新值及意图；使用 ContentQueryParser，不直接调用页面、服务或执行任何操作。 |
| [ContentQueryPageProjection.swift](../AreaChain/Domain/ContentQueryPageProjection.swift) — `make` / `accepts` | 只派生可表达字段、BoardFilter 及 extended 条件身份；不是完整查询序列化，也不是新的筛选真值。 |
| [ContentQueryConditionValidation.swift](../AreaChain/Domain/ContentQueryConditionValidation.swift) | 语义条件按 ID 诊断，检查类型化日期、范围、组结构、无标签/有标签、无提醒/具体时刻等可证明冲突。 |
| [ContentQueryValidation.swift](../AreaChain/Domain/ContentQueryValidation.swift) — `satisfiable(_:dimension:)` | 1B-2A 唯一必要接口扩展：把既有布尔/标量/日期可满足性算法接到无位置语义项；原文本 diagnostics API 和 NSRange 不变。没有新增文本语法或修改目录/路径解析。 |

当前新接口消费者仅 [ContentQuerySessionTests](../AreaChainTests/Domain/ContentQuerySessionTests.swift)、[ContentQueryProjectionTests](../AreaChainTests/Domain/ContentQueryProjectionTests.swift)、[ContentQueryPageMappingTests](../AreaChainTests/Domain/ContentQueryPageMappingTests.swift) 及其 [合成夹具](../AreaChainTests/Domain/ContentQuerySessionTestSupport.swift)。原 ContentQuery 测试继续覆盖共享验证算法。新类型分文件只为划分映射、状态、投影和验证责任，未建设通用事件总线或持久化协议。

#### 身份、来源与唯一真值

- `hostID` 与 `visitID` 是宿主提供的不透明运行内标识；返回 `reference` 只引用宿主位置。菜单栏和工作台各自创建值状态，不调用当前生产 `BoardFilterSession.shared`。条件 ID 由本会话递增生成，只在该会话内有意义；不得跨宿主按裸 ID 关联。
- `page(visitID:)`、`input(range:)`、`user` 区分页面自动、用户原文与用户结构化条件。相同语义/相同文本不会推断相同来源。自动条件同一访问同一维度更新保留 ID；原文编辑按语义及重复出现次序复用未变条件 ID，同时更新真实 UTF-16 范围。条件编辑保留该条件 ID，转为 user。
- 自动条件没有 source/NSRange。原始 `ContentQueryInput` 和 ContentQuery diagnostics 始终保持解析器返回；语义诊断只引用条件 ID，不伪造用户文本位置。修改来自输入的条件时，明确删除其真实原文区间并重新解析剩余原文；新的结构化值由 user 条件承担，不伪造规范化文本。剩余诊断范围随这一真实编辑重算。
- `page` 保存宿主最近提供的默认候选快照，不能当作第二份编辑真值。有效条件由会话持有；页面读取派生投影，用户修改以明确的单维度事件进入 reducer，不能把投影出的整个 BoardFilter 再灌回完整查询。ItemsListingQuery 仅复用类型/状态/筛选输入，日期基准统一使用外层 PageContext.todayKey/Calendar，宿主适配时应传同一基准。
- 默认条件提供候选；活跃用户条件优先拥有该维度，其次是本次访问的删除标记，最后才是页面自动条件。新页面自动条件不能覆盖用户日期、标签或优先级，也不能把旧自动条件作为用户条件叠加。多个用户条件仍取原 AND/OR 语义，冲突保留诊断。

#### 状态转移与访问寿命

| 事件 | 已实现规则 |
|---|---|
| 初始化 / enterPage | 自动条件可枚举、可编辑、可移除；单独存在不激活结果。新 visitID 才建立新访问；相同 visitID 走刷新。宿主间 enterPage 拒绝。 |
| setInput / addCondition | 非空内容输入（包括无效/待补全输入）或主动语义条件激活结果；不以 source 是否为空作为唯一依据。command 保留 CommandPathResult，并不激活内容结果；不会执行，也不把参数正文当关键词。 |
| editCondition | 自动条件即使改成相同值也转 user；之后页面刷新不能覆盖该维度。真实文本条件编辑会删除相应原文范围并保留其余诊断关系。 |
| removeCondition | 删除的维度在本次访问中不补回。删除范围使查询转全局独立上下文，并移除其他页面自动条件；用户条件保留。 |
| refreshPage | 仅接受当前 location；只更新仍属页面的维度。刷新、重绘、重新聚焦、候选收起、详情或原生面板开合均沿用 visitID，不清删除标记、不重新解析用户相对日期、不重建返回位置。 |
| 切到新 visitID | 绑定查询替换自动条件，保留用户词和条件。删除自动范围造成的独立状态只活在原访问，新访问重新提供默认；显式脱离、或仍持有不兼容用户范围的独立查询不会叠加新页面条件。 |
| 用户改到其他范围 | independent(userScope)，不回写旧页；路径后来恰好相同也不自动重绑。清除原文范围但未清整个结果上下文也不靠匹配路径重绑。 |
| detach | 将当前自动条件转为 user 并保留 ID/语义，再独立；不把明确脱离解释成丢掉当前条件。 |
| rebind | 明确动作恢复当前页面联动、取消范围删除标记；其他维度删除标记保留。不兼容的用户范围要求先回查询编辑，不默默丢弃它。 |
| pageFilterChanged | 只有仍绑定且 location 匹配时接受；修改一个可表达维度。扩展用户条件拒绝有损覆盖，返回 requiresQueryEditing；页筛选主动编辑视为用户意图。 |
| projectionApplied | 同步回声为严格 no-op；迟到回声也不写查询，不发第二次同步。用户输入与刷新结果只在投影真的变化时发同步意图。 |
| clearUserQuery / 最后内容输入清空 | 清用户内容后退出结果，回到首次进入本次结果时的 location。返回点保留该访问的删除标记；以后输入、翻页不重建它。返回是恢复被记录的访问，不是普通新 visit。没有返回点时不虚构导航。 |

返回位置不保存滚动坐标、视图、窗口或几何对象。首次激活前的页面快照与访问引用作为恢复基线，活动访问中明确删除的维度持续更新到返回点；宿主后续必须按 reference 保存/恢复滚动。返回命令不得被宿主当成丢弃操作草稿。

#### 页面映射与现状差异

| 页面 | 本阶段映射 / 已核实边界 |
|---|---|
| 总览、设置、快捷键、隐私、备份 | 全局，无自动条件；全局组成仍排除剪贴板与软删除。 |
| 今日（含菜单栏 tasks） | tasks＋todayKey 单日＋实际 BoardFilter。已有明确 dateScope 时由该页筛选取代 today 默认，避免两个自动日期相冲突。任务标签/无标签、来源、优先级、提醒有无均可保留。 |
| 待处理 | tasks＋明确 PendingLane（overdue/upcoming）＋标签/无标签、来源、优先级；不虚构 kind/status/reminder 控件。 |
| 全部事项 | tasks＋ItemsListingQuery 实际类型、一次性完成态、习惯启停态、BoardFilter 标签/来源/优先级/日期；不把 routine disabled 转成 status:done，不导入未使用的 reminderScope。显式 disabled 使范围允许停用定义，再由类型谓词筛选。 |
| 手记（含菜单栏 diary） | diaries＋真实标签 UUID。当前手记页没有无标签选项，不能把 noneID 映射成合法手记无标签筛选。 |
| 图片、剪贴板、标签管理、回收站 | 分别 images/clipboard/tags/trash。附件与回收站现状只有分组，**没有类型筛选状态**，本阶段不虚构字段；剪贴板 mixed/exact/regex 不暗中迁入统一内容查询。标签管理的使用度/名称搜索与排序不属于本次默认映射。 |
| 标签内容 | global＋稳定标签 UUID＋显式允许类型集合（现有 todo/routine/subtask）；集合只收窄范围，不能纳入 diary/image/clipboard 或软删除。完成区折叠不转成统一 status:open。 |
| 日历 | 调用方给定 selectedDay/week/month 的闭区间；现有主视图只有 week/month，selectedDay 对应选中日列表。日期由宿主按注入 Calendar 计算；没有新增 UI 模式。 |
| 安排 | tasks＋调用方展示期间；反向日期投影只接受整月。当前 Gantt 一次性项未完成、routine 不检查当日完成等页面呈现规则，不冒充为统一查询 status。 |
| 四象限 | tasks＋查看日；只有调用方明确 selection 时增加优先级。当前 dropSlot 只是拖放目标，不能拿它当筛选选中态。反向日期只接受单日。 |

源码依据包括 Classification / ItemsListing / AgendaProjection、WorkspacePageModels、WorkspacePendingView / WorkspaceAllItemsView、DiaryPage / DiaryPageListModel、AttachmentBrowserPage、TrashPage、CalendarPage、GanttPage、QuadrantPage 和 MenuBarFilterFlyout。上述页面保持未修改；本阶段映射的是统一查询默认条件，不声称复制了每个旧页面的候选行、折叠、排序或可见性算法。比如标签列表和全部事项当前可呈现停用习惯，而统一 global/tasks 默认仍沿 1B-2A 排除停用；只有显式 disabled 条件才扩入，后续提供者/接线必须显示该范围差异，不擅自把整个旧列表当作统一结果。

#### 同步投影与后续提供者要求

- `ContentQueryPagePredicate` 保留 stable tag UUID、noTags、sourceApplication 精确 Bundle ID、reminderPresence、带评估方式的 boardDate、itemKind、todoStatus、routineStatus、contentTypes；这些不是新的文本语法。标签页及今日按 own 关联；待处理/全部事项通过 `taskOrSubtask` 保留父项因子任务标签入围的旧契约，不能转成 ownTags。
- boardDate 携带 `listedDay / agenda / items` 与注入日期/日历。提供者须复用相应 Classification / Agenda / ItemsListing 口径；逾期/即将包含未闭合/下一排定规则，recent 是 today…today+7 闭区间，不能降成单日、无界文字或星期匹配。看板 first-wins 与 Agenda 任一完成/跳过闭合的差异仍由原规则负责。
- 旧 BoardFilter 无法无损承载 OR、排除、多标签/多日期条件、精确提醒、created、has:image、未解析到稳定 ID 的文本标签和部分绝对日期。投影返回 `extendedConditionIDs / extendedDimensions`，查询保留全部原文、条件和诊断；控件只能显示可表达部分，尝试覆盖扩展维度会返回查询编辑意图。
- P1/P2/P3 的原 highPriorityOnly 特例可无损表达；任意其他 OR 不压缩。整周以注入 Calendar.firstWeekday 校验，整月用原 DayKey；不把跨月区间硬塞进安排，也不把区间硬塞进四象限单日。自动日期允许被页面明确选择替换，扩展的用户日期不允许被旧控件覆盖。
- 组合层复用 `ContentQueryScopeContract`；类型条件只能交集收窄，范围冲突返回 nil scope 并诊断。字段适用性仍由 `ContentQueryApplicability` 及后续类型化谓词适配共同检查；isReady 不证明真实记录命中、页面同步成功或可执行。

#### 验证与停止点

首轮 50 项定向：49 passed、1 failed；失败为新测试误把语言参数路径当成稳定 CommandID，已依据 CommandCatalog+Settings 修为 `setting.language`，未修改解析器。实际最终回归、静态、构建与复核状态在本节收尾更新。

指定独立复核仍 **blocked / 未执行**：当前工具清单没有 Cursor verifier 专用入口，沿用前阶段已登记阻塞；本轮未执行 agent status/login、未修改认证配置，也不以只读页面探索、主代理检查或测试代替指定复核。阶段整体保持 **partial**。

**1C 边界：** 本阶段没有操作草稿的标识、固定目标、正文、参数、待执行列表、转交或执行分支，也没有清空操作草稿意图。`input.command` 仅保留 1B-1 的语法解析结果，不能作为操作正文、参数或目标的权威草稿；清输入不授予清草稿的权限。1C 需另行授权后定义独立操作草稿所有者与查询并列，消费查询返回/同步意图时明确保护草稿；对完整草稿保护、转交所有权及失败恢复做专项测试。生产页面同步、滚动恢复、焦点、真实提供者、草稿保护与原生运行尚未接线验证；本阶段停止，不安装、不启动生产应用，不提交、不推送，不进入 1C。

#### 最终检查记录（2026-10-01）

**纯映射与纯状态转移已验证；阶段整体 partial，指定 Cursor 复核仍 blocked。** 检查产物集中在忽略目录 `build/ContentQueryContextQA/`，不是发行物，也没有替换前阶段记录。

| 检查 | 实际结果及证据边界 |
|---|---|
| 最终领域/兼容定向 | `./scripts/build.sh test` 配合重复 `--only-testing AreaChainTests/类名`，选择 ContentQuerySessionTests、ContentQueryProjectionTests、ContentQueryPageMappingTests、ContentQueryTests、ContentQueryContractTests、CommandCatalogTests、CommandParameterTests、CommandPathTests、CommandPathConflictTests、BoardSearchTests、TagSyntaxTests、DayKeyTests、UnifiedSearchTests、ClassificationTests、ItemsListingTests、AgendaProjectionTests、BoardPageTests、SyntaxAutocompleteTests。**177 项 passed，0 failed / skipped**；新增状态 15、投影 12、映射 10，共 37 项。结果包 `FinalTargeted.xcresult`，摘要 `final-targeted-summary.json`，完整测试树 `final-targeted-tests.json`，日志 `final-targeted.log`。 |
| Swift 质量门禁（本轮只执行一次） | `python3 -B scripts/quality_gate.py --profile swift --format json` **passed**。当次整树 1125 项：**1124 passed、0 failed、1 skipped**；唯一跳过为 `SystemVaultIntegrationTests/testAuthorizedPhase()`，保持真实钥匙串默认禁用。SwiftLint、静态守卫和 172 项脚本测试 passed，Shell 语法 skipped（无适用脚本）。原输出 `swift-gate.json`、`Full.xcresult`、`full-summary.json`、`full-tests.json`。这证明该次编译快照，不是历史阶段补验。 |
| 最后补正与整树证据边界 | 整树测试编译后，主代理自查补上“内容结果 → 指令输入暂时隐藏 → 清空仍应返回”的案例，返回判断从上一帧 showsResults 改为已存 returnPoint；页面补充矛盾检查同时避免两两扫描纯文字项。只涉及 ContentQueryReducer、ContentQueryConditionValidation 和 ContentQuerySessionTests。这三份后续变化已在上述最终 177 项定向中重跑；未反复运行整树，**最终树没有新增整树重跑证据**。 |
| 最终 Debug 构建 | `./scripts/build.sh` **passed**，development / Debug，`staticSignatureVerified: true`，`distributionReady: false`；日志 `build.log`。仅构建验签，未安装或启动生产应用，未修改个人签名或认证配置。 |
| 严格局部 SwiftLint | 7 份相关 Domain 文件（含旧 ContentQueryValidation）及 4 份测试/夹具的 `swiftlint lint --strict --quiet` **passed**，`lint.log`。编译输出另有既有 AppKit 弃用与未用变量 warning，未扩范围修复。 |
| 最终静态 | `python3 -B scripts/quality_gate.py --profile static --format json` **passed**，包括工作流、空白、安全/注释、性能契约及 172 项脚本回归；`final-static-gate.json`。最终增量记录后另跑 `python3 -B scripts/check_workflow.py` 与 `git diff --check`。 |
| 输入追溯 | 定向前后记录 151 份 Domain、DomainTests、工程与构建/检查脚本 SHA-256，`source-final-before.json` / `source-final-after.json` 完全一致；之前 166 项定向的指纹另保留在 `source-before.json` / `source-after.json`。前后只发生上行列出的 3 份本阶段补正；该清单不是整个 UI 工作树的稳定快照。 |
| 指定独立复核 | **blocked / 未执行**。未检查登录、未改认证；页面事实的只读子代理定位及主代理抽查不作为 Cursor verifier 证据。 |

整树运行较长时对本次测试宿主做过一次只读采样，命中 `PrivateBackupService.export → VaultCrypto.pbkdf2HMACSHA256` 的既有测试路径，记录 `full-test-sample.txt`；没有改动加密、降低测试强度或触发真实系统操作。完整整树正常结束后才运行最终定向与构建，未并行操纵焦点敏感窗口。

最终 HEAD 仍为 `3fb727743759ebbe2d631b0fcb95dcfd3ef61f5e`。原有设置/隐私与新增并行手记、日期菜单及其消费者测试修改全部保留；它们不属于本阶段交付。未提交、推送、安装、发布或进入 1C。后续仍需指定复核及独立授权的页面/提供者/草稿接线验收，不能把本次 Domain 通过写成生产页面同步、滚动恢复、焦点或草稿保护通过。

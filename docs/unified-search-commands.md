# 统一搜索与指令体系

2026-10-02 最新增量：2K-5 剪贴板历史文件只读适配与受门禁发布见 §9.41；仅显式临时目录与合成文件验证，指定 Cursor 复核和历史验收缺口保持 partial，无生产来源选择或监听。

2026-10-02 最新增量：2K-4D 受生命周期门禁约束的正文读取见 §9.40，指定复核仍缺失；仅实施与隔离验证授权，无生产接线。历史增量：2K-4C 搜索生命周期、查询清理与发布门禁见 §9.39；仅隔离接线，不含敏感草稿封存或生产入口。历史记录：2K-4B 的 metadataOnly 手记只读适配、同批标签和隔离回归见 §9.38；D1～D3 已确认，D3 仅登记，未实施失效接线。2K-4A 的历史核验及更新后的决策见 §9.37。2K-3 标签目录及任务类同批装配见 §9.36；指定 Cursor 复核与历史缺口保留。

## 0. 状态、权威范围与基线

2026-10-02 最新增量：2J-3C 的冻结值来源、预算续读、同快照全批重算及结果发布协调见第 9.33 节；2J-3A/B 的展示、浏览与分页见第 9.31～9.32 节。以下阶段状态和“不进入后续”保留为历史交接时点。本轮不关闭指定 Cursor verifier 或历史验收缺口，整体 partial；真实仓储、异步调度、合作式取消、隐私失效接线与生产 UI 仍未实现。

2026-10-02 增量：2J-1 注入快照的同步批次、跨提供者类型化聚合与完整性汇总见第 9.28 节。只保证同一调用的值输入一致；指定 Cursor verifier 与旧阶段缺口保留，整体仍 partial。真实仓储、生产 UI、排序/片段/分页、缓存、异步失效和执行未接线。

2026-10-02 当前状态：**1A～1C-3 领域协议已实现；1D 领域链路集成见第 9.13 节；2A / 2B 的 todo 与子任务提供者、2B-R 类型修正、2C 习惯证据与定义提供者见第 9.14～9.18 节；2D 手记只读快照提供者见第 9.19 节；2E-1 图片关联只读基础见第 9.20 节；2E-2A 公开图片元数据查询见第 9.21 节；2E-2B 三类记录 has:image 接入见第 9.22 节；2F 活标签只读快照提供者见第 9.23 节，整体仍 partial。** 指定 Cursor verifier 复核缺失，真实数据库、产品 UI、handler 与系统服务均未接线；todo/routine/diary 已接入注入资料的 has:image；受保护能力与真实接线仍未开放。各阶段原始检查仍保留；本阶段定向证据不关闭历史整树、原生或指定复核缺口。

设计决定来自阶段 0 与后续各次已确认需求。阶段 0 的源码核对日期为 2026-10-01，基线提交为 `25a7cb3777f52983c26a6e3f938bd1fac0bd441d`，另有下述未提交修改；这是当时的静态阅读基线，不能混用为本阶段运行证据。

本文是该体系唯一的目标设计来源，后续阶段在本文更新决定、映射及完成证据，不复制计划、不另建自动执行器。当前行为仍见[功能清单](features.md)、[使用说明](usage.md)、[架构](architecture.md)；目标与现状有差异时以本文的“目标”理解未来工作，不能据此宣称当前产品已有能力。实现继续遵循[项目规则](../AGENTS.md)、[技能路由](../skill-routing.md)、[组件目录](component-catalog.md)与[质量门禁](quality-gates.md)。本文件不授予安全边界变更、真实数据写入、系统权限、安装或发布权限。

2026-10-02 增量：2H-2 显式墓碑只读搜索与命中归组见第 9.26 节；历史阶段和指定复核缺口保留。

2026-10-02 增量：2G 显式剪贴板只读提供者见第 9.24 节；2H-1 墓碑读取、删除关联与恢复条件见第 9.25 节。2H-1 没有查询提供者或业务执行接线，指定复核缺失继续 partial；前文阶段状态保留为历史记录。

2026-10-01 阶段 1C-1 增量实施与证据见第 9.10 节，前文“不进入 1C”保留为历史交接时点。阶段 1B-2B 增量实施与证据见第 9.9 节。第 9.8 节“仅登记/未实现/不进入 1B-2B”保留为前阶段交接时点，不表示此次没有实施；前阶段指定复核及整树验收缺口未因此关闭。

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

### 手记不可读正文与搜索投影（阶段 2D 已确认，2026-10-01）

- 正文不可读不等于空正文；标签、归属日、创建时间等允许读取的元数据仍可判断。可读字段足以证明匹配或不匹配时正常判断；依赖不可读正文才可决定的对象为未知，不进入确定命中，也不伪装完整零结果。
- 正向文字可由正文或任一关联标签名证明；排除文字不能因正文不可读自动成立。AND 有确定不匹配则不匹配，否则有未知则未知；OR 有确定匹配则匹配，否则有未知则未知。所有分支先求值并保留身份/安全诊断，不以短路隐藏问题。
- 搜索不自动触发解锁。私密及无法确认公开的结果始终用现有隐藏标题；即使注入快照正文可读且参与匹配，结果也不携带正文、片段、正文长度、正文命中范围或其他正文派生展示。正文命中理由至多为无内容的通用说明。
- 标签名字、私密标签集合是调用方提供的事实，缺失不等于已提供空集合；不能可靠判定敏感性时不得默认公开。`DiarySnapshot.isContentAvailable` 决定正文能否参与匹配，占位文字不作为真实正文。
- 2D 仅消费注入快照和完整查询，实现纯读取与投影；不修改认证、加密、锁定或正文生产入口，不调用真实 vault，不接真实库、生产 UI、附件提供者、缓存失效或指令执行。历史指定复核和真实隐私接线验收缺口保留。

### 图片查询语义（2E-1 关联、2E-2A 元数据匹配与 2E-2B 记录存在性）

- 普通文字、短语和排除文字只匹配图片文件名；不读取图片内容，不做 OCR。
- `date` 使用所属记录业务日期，`created` 使用图片附件自身创建时间；`#标签` 使用所属记录标签。
- 优先级、提醒、完成状态只使用所属类型真实存在的字段；条件与命中依据须标明“所属记录属性”，并保留类型化所属身份。手记没有任务完成态、优先级或提醒；习惯状态必须有明确执行日并复用既定记录与历史证据规则。
- `has:image` 查询带图片的记录，不是图片自身属性。是否允许已授权私密记录使用该条件，留待真实隐私适配，不在此阶段开放。
- 2E-1 仅建立类型化关联、完整性与只读可浏览投影；2E-2A 按上述规则接入图片字段适用性与完整 Session 匹配，详见第 9.21 节。2E-2B 接入 todo/routine/diary 的 has:image，详见第 9.22 节；第 9.8 节的适用性说明是历史阶段基线。

### 回收站分组与恢复描述（阶段 2H-1 已确认，2026-10-02）

- 随父任务删除的子任务和图片默认归在父项下，可展开，不重复计入顶层结果；子项保持独立身份。搜索只命中子项时须显示具体命中及父关系，不能因折叠隐藏命中。
- 父任务删除前已独立删除的子任务不属于本次级联，不暗示恢复父项会恢复它。先核实真实父子/类型化拥有者关系，再用既有精确删除戳判断，不引入容差或按天近似。
- 图片拥有者仍被删除时说明需先恢复拥有者；可搜索不等于已有独立恢复入口。缺少既有能力时声明不可直接恢复，不新增业务操作。
- 缺失、未提供、部分覆盖和歧义分别保留；关系不确定时不猜测。父已恢复后仍有墓碑的子项不继续归入当前级联组。
- 私密手记沿隐藏标题；私密/保护资料不足的图片不发布文件名、内容、访问能力，也不从分组成员、计数或诊断位置泄露。新增披露须另行定界。
- 恢复条件仅是读取说明，提交前仍须重新检查身份、删除状态、权限、数据及业务规则，不是授权或成功保证。
- 2H-1 仅建立纯值墓碑输入、关系判断、分组依据与测试；实际查询、子项命中提升留给 2H-2。无完整提供者、恢复/删除 handler 或文件操作。

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

本节描述产品目标。1C-2 只实现第 9.11 节的内存计划、静态校验和纯结果协议；真实业务执行、事务、重试、取消及撤销的能力仍需后续适配验证，不能由本节或协议状态推导已经接线。

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
- 默认相关性排序，可切换最近排序；四档、时间精度与稳定并列规则见第 9.29 节。纯领域排序不表示已接入生产界面，不能将当前日期倒序当成相关性。
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

功能级业务入口及测试映射见下一节；本表保留阶段 0 的生产基线。后续已实现的目录、查询会话、草稿、计划与转交领域协议以第 9.6～9.13 节为准，不能把领域接口误认成已接入的产品能力。

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
| 1A | 指令目录、类型化参数、能力与双语声明已实现 | 第 9.6 节；静态校验不授予权限，全部 execution 保持 unwired；指定复核缺失，partial。 |
| 1B-1 | 指令路径解析与补全已实现 | 第 9.7 节；独立指令、双语、简单参数尾段及 UTF-16 编辑意图，未接 UI；partial。 |
| 1B-2A | 内容查询语法、范围、字段与日期契约已实现 | 第 9.8 节；AND/OR、排除、tasks 组成和日期语义已明确，不产生真实命中；partial。 |
| 1B-2B | 条件来源、页面投影与访问寿命已实现 | 第 9.9 节；用户接管、独立查询、删除标记与返回位置是纯状态协议，页面未接线；partial。 |
| 1C-1 | 操作草稿、固定目标、基线与编辑保护已实现 | 第 9.10 节；唯一可编辑参数、active / retained 及版本保护，未持久化；partial。 |
| 1C-2 | 待执行计划、依赖、合并与纯执行生命周期已实现 | 第 9.11 节；协议封存、合成回执与真实执行资格分层，无真实事务/重试/撤销；partial。 |
| 1C-3 | 跨入口主动转交与唯一所有权领域协议已实现 | 第 9.12 节；同一协调者核验 lease、原子接管和失败保留；真实窗口/文件/私密接续未实现，partial。 |
| 1D | 四条跨模块领域集成链路与必要最小修正 | 第 9.13 节；通过公共接口与合成输入验证，保留指定复核缺口；到本阶段停止，产品未接线。 |
| 2A | 一次性 todo 的注入快照只读提供者与最小类型化结果 | 第 9.14 节；实际匹配有效条件，报告类型覆盖、未知数据与歧义；不读真实库、不接 UI/执行，指定复核缺失仍 partial，到此停止。 |
| 2B | 活子任务独立结果的注入快照只读提供者 | 第 9.15 节；自身字段与父级页面约束分开，类型覆盖与完整性显式报告；指定复核缺失仍 partial，停在本阶段。 |
| 2C～2E-2B | 习惯历史/单日证据与定义、手记、公开图片提供者及三类记录 has:image 已实现 | 第 9.17～9.22 节；仅注入快照，指定复核与历史缺口保留，整体 partial。 |
| 2F～2H-2 | 标签、显式剪贴板、回收站墓碑读取与搜索提供者已实现 | 第 9.23～9.26 节；只读注入数据，指定复核与历史缺口保留，整体 partial。 |
| 2I | 显式日期窗口内的习惯执行情况独立只读提供者 | 第 9.27 节；确定记录/可靠派生与未知/冲突/异常/截断分开；指定复核缺失仍 partial。 |
| 2J-1 | 同步注入批次、类型化结果与完整性汇总 | 第 9.28 节；复用九个只读提供者，保留类型限制、缺源、未知、保护及记录剩余；指定复核缺失仍 partial。 |
| 2J-2A | 已知安全聚合结果的相关性与最近排序 | 第 9.29 节；原匹配集合与覆盖保持，指定复核缺失仍 partial。 |
| 2J-2B | 安全摘要、已知命中窗口与字素高亮映射 | 第 9.30 节；纯展示数据，指定复核缺失仍 partial；未验收原生两行布局。 |
| 2J-3A～2J-3C | 纯领域展示/浏览、展示分页、同快照预算重算及发布协调 | 第 9.31～9.33 节；指定复核缺失仍 partial，只输出身份锚点和意图。 |
| 2 后续（未实施） | 真实数据与产品读取适配 | 数据库读取一致性、原生宿主接线、真实异步调度、合作式取消与隐私失效清理仍须独立定稿、实施和验证。 |
| 3 | 从现有按钮/菜单/设置提取缺少的共用业务动作，建立校验、预览、执行结果、字段冲突、重试身份与可撤销能力；先处理授权范围内的本地普通操作 | 依赖 1；保留旧入口契约，仓储/`ModelChanges` 注入测试；逐动作检验相同输入产生相同写入与副作用次数。安全、权限和跨系统一致性改造单独审批，不能随普通提取潜入。 |
| 4 | 两宿主共享搜索与指令发现 UI，页面默认条件与筛选双向同步，统一结果与键盘；删除已被替代的重复页内搜索 | 依赖 1、2；建议改 `Features/Search`、`Workspace`、`MenuBar`、手记/标签/剪贴板宿主及必要 `Theme`。原页面草稿/滚动、显式范围/删除标记、独立查询、菜单栏与最小窗口等价后才移除旧入口；受限选择器不冒充普通搜索。 |
| 5 | 可编辑预览与长正文、操作草稿、多字段/多对象/多设置、队列执行、冲突处理、真实撤销、关闭/退出与主动转交 | 依赖 3、4；故障注入验证固定集合、未完成参数、顺序合并、依赖暂停、部分成功重试不重复创建、目标草稿不覆盖和唯一提交所有权。设置事务先有证据再开放多设置提交。 |
| 6 | 完整接入通知/日历、剪贴板外部粘贴、权限与隐私、回收站永久动作、导入/备份/恢复等独立流程 | 依赖相应业务适配与明确授权；每项现有功能可在入口发起并完成原有流程，不以打开设置页代替。区分本地/外部成功，取消仅底层支持时提供；安全/真实系统证据分别报告。 |
| 7 | 最近功能标识、固定指令、用户主动保存的查询/操作模板；全目录验收与文档收口 | 依赖稳定 ID/语法及模板数据边界决定；模板仅预填、相对日期/失效引用可见、无默认敏感历史；第 8 节逐项入口等价并完成原生矩阵，才可称全体系交付。 |

搜索实现与业务动作提取可在契约稳定后按独立范围安排，但生产入口开放必须等待相应执行/失败契约。实施不要求新增框架、包、模型表或磁盘草稿；确有必要时另论证与授权。

### 9.2 阶段 1 的可检查交接

1A 负责目录、参数与能力声明；1B 负责解析/补全及查询状态转移，1C 负责草稿、计划和转交契约。三个子阶段均**不直接改现有设置绑定、不启动统一产品 UI、不触碰私密锁/持久化**。目录每项至少包含稳定 ID、规范路径、中文/英文名称与别名、分类、适用范围/目标类型、必需参数、字段模式、预览要素、风险/授权、能否排队、重试/撤销能力声明及现有业务出处。声明“待实现”不得伪装成 handler 已可执行。

最小验收案例：

1. `/`、`/set`、`/setting`、完整语言路径及中文别名补全；普通文本、引号/转义、标签、未知路径保留可编辑诊断，不静默执行。
2. 默认 `/tasks` 不激活结果，主动条件激活；删范围后同页刷新不补回；切页保留关键词；用户范围不覆盖；改范围/退出页面绑定不回写旧筛选；清查询返回原页面。
3. 操作草稿与查询隔离：切页不能改目标/正文；“未指定/清空/多个不同值”可区分；设置组合、正文追加、习惯具体日期和固定多对象集合均可表达。
4. 提交/授权/执行/成功/失败/冲突/未执行状态、依赖与重试身份可表达；成功项不重放，普通赋值合并但顺序动作不丢；转交目标占用/执行中/授权中拒绝，失败源保留，成功单一所有权。
5. 全量目录覆盖第 8 节每一动作；范围不会隐藏全局指令；受限选择器限制显式；凭据不进入可序列化参数/历史模板。

实际修改 Swift 后按[验收技能](../.agents/skills/areachain-verify/SKILL.md)跑相应 Domain 定向测试、必要构建及静态门禁；公共契约/复杂状态实现后交 Cursor `verifier` 独立只读复核。阶段 0 没有运行时行为变化；阶段 1A 的实际复核可用性和测试结果见 9.6，不以静态阅读替代独立复核。

### 9.3 后续回归入口与证据缺口

以下是阶段 0 定位的既有回归入口，当时未执行；后续各阶段实际运行范围见各节证据。测试存在不能证明新增目标已经被覆盖。

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

### 9.10 阶段 1C-1：操作草稿、固定目标与编辑保护

#### 范围与来源（2026-10-01）

本次仅获准实现纯 Domain 模型、转移和合成测试。开始时 HEAD 为 `3fb727743759ebbe2d631b0fcb95dcfd3ef61f5e`、索引为空，已有查询阶段、按钮及文档差异全部保留。期间并行任务暂存了部分工作区文件（包括初版 CommandDraft / CommandDraftTargets）并继续修改按钮消费者；本任务没有暂存、提交、推送或回退这些变更。交付按工作区最终文件理解，索引不代表完整的本阶段快照。

复用 `CommandCatalog.standard`、`CommandDescriptor` / `CommandID`、`CommandParameter` / `CommandArgument` / `CommandValue`、`CommandArgumentValidation`、`CommandObjectReference` / `CommandOriginalValue`、`ContentQuerySession` / `ContentQueryReducer`。只读参考 `DiaryEditorSession` 的基线、修改判断、显式重载及保存失败保留约束；未引入其仓储、观察者、正文读取或隐私代码。前阶段指定复核缺口保持不变。

| 文件 / 核心接口 | 当前责任和真实消费者 |
|---|---|
| [CommandDraftTargets.swift](../AreaChain/Domain/CommandDraftTargets.swift) — `CommandDraftTargets`、`CommandDraftBaseline` | 固定集合、目标诊断、派生 target 参数及原值索引；由 CommandDraft 与其领域测试消费。 |
| [CommandDraft.swift](../AreaChain/Domain/CommandDraft.swift) — `CommandDraft`、`CommandDraftStamp`、`CommandDraftCheck` | 指令身份、版本、目标、参数、原值和修改判断；静态检查不授予执行资格。 |
| [CommandDraftSession.swift](../AreaChain/Domain/CommandDraftSession.swift) — `CommandDraftSession`、`CommandDraftReducer.reduce`、`CommandDraftEvent` / `Decision` / `Intent` | 当前草稿、可枚举保留集合、版本确认与纯保护转移；唯一实际消费者是宿主组合与 Domain 测试。 |
| [CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift) — `queryEvent` / `operationEvent` / `presentationEvent` | 每宿主独立组合；查询委托旧 reducer，展示信号严格不改草稿，不保存原生焦点。 |
| [CommandDraftTests.swift](../AreaChainTests/Domain/CommandDraftTests.swift)、[CommandDraftProtectionTests.swift](../AreaChainTests/Domain/CommandDraftProtectionTests.swift)、[CommandHostSessionTests.swift](../AreaChainTests/Domain/CommandHostSessionTests.swift) | 合成参数/基线、身份/保护状态序列及查询组合；没有生产 UI、保存、删除、认证或关闭调用。 |

#### 权威状态、身份与基线

- 调用方为每个宿主创建 `CommandDraftSession(hostID:)`；草稿由调用方提供运行内 UUID，`commandID` 不在原草稿上切换。新独立指令创建新草稿，草稿 UUID 不代表持久化对象 ID。无目标设置和新建指令均用 `.none`，不伪造创建结果；新建子任务的 parent 仍是普通类型化参数。
- `CommandDraftStamp` 为 hostID＋draftID＋version。每次接受参数/目标编辑、显式重载和激活/恢复推进版本；即使文字相同，也使旧回调失效。宿主 revision 保护切换请求；已使用 ID 在运行内保留用于拒绝重复创建，不保存正文历史。
- `arguments` 是唯一可编辑参数/正文值。候选和预览必须派生读取并发送带 stamp 的 edit，不能各建正文真值；`input.command` 仍只是查询解析结果。target 参数不能通过 edit 或初始参数写入，只在静态校验时从固定集合派生。重复参数初始化/重载被拒绝，未知参数、空值、无效 operation 等可在编辑时保留并产生静态诊断。
- baseline 使用 `Subject.ambient`（无对象设置等）或 `.object(reference)`＋parameter 索引。缺项表示调用方未提供，区别于已知 `.absent`；按全部固定对象派生原值，相同为 uniform/absent，不同或已有 mixed 为 mixed，任一缺项返回未提供。不会加载数据库、设置或真实正文。原始基线内容与当前正文分离，是比较证据，不是第二份可编辑正文。
- modification 与参数完整、静态有效、可执行分开。赋值/替换/设置提醒与 uniform 原值比较；清空/取消提醒与 absent 比较；未指定保持原值；追加、标签增删等保守视为修改，是否业务无效果留给后续规则。目标与初始选择不同也算修改。新建正文无原值时，包括空正文在内的显式编辑受保护。没有参数且没有修改的空草稿不触发未保存处理。
- 外部值通知只返回 `externalValuesRequireExplicitReload`，不保存外部正文、不更新基线、不覆盖当前参数。`reloadDiscardingChanges` 必须显式提供当前 stamp、新基线与参数；过期重载被拒绝。这不是三方冲突解决、读库或保存成功接口。完整冲突、对象存活、权限及业务检查留给执行接线阶段。
- 新模型没有 Codable、数据库模型、文件写入或日志调用；草稿、基线、会话和事件的默认描述隐藏参数正文。此处只是运行内明文合成契约，没有“已加密/已保护”状态或安全保存承诺。

#### 固定目标与编辑保护

固定选择来源为 none、single、selected、allResults；allResults 只接收用户显式接受后由调用方传入的具体对象数组，没有查询表达式。按完整 `CommandObjectReference` 稳定 first-wins 去重，类型＋UUID＋习惯日期共同区分身份；非法日期、缺少习惯日期、非习惯多带日期均保留并诊断。混合不适用目标返回 `requiresExplicitSelection`，单类型不适用返回 `notApplicable`；不静默筛成子集。空选择、错误单选数量、单对象指令接多个对象分别诊断。

| 转移 / 判断 | 行为 |
|---|---|
| start / restore | 无修改时切换；有修改时只建立包含当前 stamp 和目标的决策，不撤走当前草稿。待决期间不接受第二个切换请求。 |
| resolve retain | 当前草稿进入 retained，目标成为 active；保留集合有完整可读身份/参数/基线，可枚举恢复。 |
| resolve discard / cancel | 放弃只针对决策中的当前身份/版本；取消保留当前和原 retained，撤销待决请求。 |
| 编辑发生于待决期间 | 保留最新编辑并撤销旧 pending；旧确认拒绝，调用方需基于新状态重新发起切换。已受理的新草稿 ID 不复用。 |
| 恢复保留草稿 | 同样先保护当前修改，恢复后推进草稿版本；旧激活期间的候选回调不能复活。 |
| discardRetained | 必须匹配保留项完整 stamp；旧版本不能删除恢复后再编辑/保留的内容。 |
| 重复 start / restore / resolve / edit | revision、stamp、pending 和运行内已用 ID 拒绝重复请求；状态不变，不复制保留项。 |
| externalValuesArrived | 只输出显式重载提示；重复通知不改状态。 |
| unsavedDrafts / requiresUnsavedContentHandling | 包含 active 和 retained 中所有有修改项；不以参数有效性筛掉长文。仅纯判断，不执行关闭窗口、退出或保存。 |
| 查询变化、清查询、切页、收起面板、外部点击、重新聚焦 | 不产生操作事件；保持目标、参数、正文、基线和版本。查询返回/同步意图也无权清稿。 |

retained 是**编辑保留集合**，没有待执行标记、排序依赖、运行结果或提交动作；保留不会获得执行资格。`CommandDraftCheck` 复用静态参数校验，所有执行 binding 仍为 `.unwired`，`isExecutable` 始终 false。目标和参数完整不代表真实业务、权限或存活已检查。

#### 后续接线边界

1C-1 当时的后续要求（现行 1C-2 领域协议见第 9.11 节）：复用上述草稿身份、版本、类型化参数、固定对象与基线，另行设计队列项身份、依赖/前步结果引用、执行状态、失败保留与成功不重放；不要给 retained 加一个提交按钮就当队列，也不以领域授权执行真实业务。真实重试和撤销仍未实现。

1C-1 当时的转交要求（现行 1C-3 领域协议见第 9.12 节）：复用 hostID 和草稿 stamp，再定义跨入口所有权转交及失败协议。当时两宿主分别实例化，尚无接管协议；现已增加协调者。生产 UI、原生关闭确认、正文持久化、系统设置写入、模板/历史与执行锁均未接线。私密编辑器后续必须复用既有 DiaryContent / PrivacyAccess / PrivacyVault 保护机制及高风险授权，不通过普通 CommandValue 存密码、密钥或认证结果。

#### 验证与缺口

指定 Cursor verifier 在当前工具清单没有可调用入口，仍 **blocked / 未执行**；没有重新检查登录或修改认证配置，也没有安排其他代理冒充指定复核。阶段整体 **partial**。最终本地检查结果在本节下方登记，不能关闭前阶段缺口或证明生产 UI/真实系统接线通过。

本轮最终检查（2026-10-01），产物在忽略目录 `build/CommandDraftQA/`：

| 检查 | 实际结果与边界 |
|---|---|
| 领域定向 | 最终 `./scripts/build.sh test` 配合重复 `--only-testing AreaChainTests/类名`：CommandDraftTests、CommandDraftProtectionTests、CommandHostSessionTests、CommandCatalogTests、CommandParameterTests、ContentQuerySessionTests、ContentQueryProjectionTests、ContentQueryPageMappingTests、ContentQueryTests、ContentQueryContractTests、CommandPathTests、CommandPathConflictTests，**110 passed / 0 failed / 0 skipped**，其中本阶段新增 15 项。`final-targeted.log` / `final-targeted-summary.json`；结果包为 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_15-37-46-+0800.xcresult`。 |
| 状态序列覆盖 | 无目标设置、已有记录、新建无持久化 ID；空正文/缺参仍保留；正文/标签/提醒操作；固定集合、类型/日期身份、混合诊断；原值/修改分离、外部通知不覆盖及显式重载；切换三选、恢复、保留项删除；过期确认/编辑/目标回调和重复事件；查询/页面/面板保护、两宿主隔离及关闭纯判断。 |
| Debug 构建 | `./scripts/build.sh` **passed**；`staticSignatureVerified: true`、`distributionReady: false`。仅构建和静态验签，`build.log`；未安装或启动生产应用。 |
| 严格局部 lint | 4 份新增 Domain 与 3 份新增测试执行 `swiftlint lint --strict --quiet`，**passed**，`lint.log`。 |
| Swift 质量门禁 | `python3 -B scripts/quality_gate.py --profile swift --format json` 只执行一次，**failed**：并行新增 `BatchMenuConsumerTests.swift:22` 当时引用不存在的 `NativeSyntaxNative`，导致整树测试编译失败、测试取消；不能记为整树通过。原结果 `swift-gate.json`。该引用随后由并行任务改成 `NativeSyntaxUI`，上述最终定向编译通过，但本任务没有重跑整树碰运气。 |
| 最终静态/工作流 | `python3 -B scripts/quality_gate.py --profile static --format json` 与 `python3 -B scripts/check_workflow.py` **failed**：并行的组件目录第二阶段 F 链接指向尚不存在的 `engineering.md#第二阶段-f菜单入口与标签合并取消2026-10-01`。本阶段 9.10 引用通过；未替其他任务生成虚假验收章节。静态门禁其余检查通过，包括安全/注释、空白与 172 项脚本测试；见 `static-gate.json` / `workflow.log`。 |
| 修正与证据追溯 | 首轮新增测试 12 passed / 1 failed：测试的 `.none` 被 Swift 推断为 Optional.nil，已显式写为 CommandDraftTargets.none。主代理自查另使单对象指令收到多目标时不派生首项，补断言后纳入上述最终 110 项。最终测试前后本轮 7 份 Swift SHA-256 一致，`source-before.json` / `source-after.json`；不代表所有并行文件已冻结。 |
| 独立复核及未执行项 | 指定 Cursor verifier **blocked / 未执行**；主代理自查和测试不是指定复核。没有认证检查、真实数据/设置写入、执行器、生产 UI/原生关闭、私密封存、跨入口转交或 1C-2 实施。本阶段整体 **partial**，旧阶段验收缺口未关闭。 |

1C-1 历史停止点：当时后续阶段仍需独立授权。后续领域实施现见第 9.11、9.12 节，不能因此把本次纯领域实现当作已接线、已安装或已发布，也不自动关闭上述缺口。

### 9.11 阶段 1C-2：待执行计划、依赖与纯生命周期协议

#### 范围、复用与工作区（2026-10-01）

本次独立授权仅覆盖 Domain 内存契约、纯状态转移与合成测试。复用第 9.10 节的 CommandDraft / Stamp、Targets / Baseline、DraftSession / Reducer 和 HostSession，以及目录、参数、CommandValue、CommandObjectReference、查询会话。没有第二套参数值、对象身份或可编辑正文。实际消费者只有领域宿主组合和测试，没有 handler、仓储、系统服务、持久化、产品 UI 或真实关闭事件。

开始时已存在查询、草稿、按钮消费者及文档的 staged / unstaged / untracked 并行修改；本次保留原修改、不暂存/提交/推送。起始 `check_workflow.py` 确认组件目录的 `engineering.md#第二阶段-f菜单入口与标签合并取消2026-10-01` 仍缺失。实施期间该章节由并行任务补齐，随后静态检查通过；本任务没有替其补写章节，最终检查另列。历史指定复核和整树缺口继续作为历史事实保留，不用本阶段授权冒充前阶段验收。

| 文件 / 核心接口 | 职责 |
|---|---|
| [CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift) — `CommandPlan`、`CommandPlanStamp`、`CommandPlanItemStamp`、`CommandPlanEvent`、`CommandPlanSnapshot` | 计划身份/修订版、稳定项顺序、唯一草稿所有权、编辑/移除/组与封存。快照只能从计划封存产生。 |
| [CommandPlanValidation.swift](../AreaChain/Domain/CommandPlanValidation.swift) — `CommandPlanCheck`、`CommandPlanValidation` | 参数/目标检查、依赖图、结果引用及设置组结构诊断；`canSealProtocol` 不是执行许可。 |
| [CommandPlanSemantics.swift](../AreaChain/Domain/CommandPlanSemantics.swift) — `CommandPlanSemantics`、`CommandMergeConflict` | 已核实的窄赋值白名单及保守合并冲突原因。 |
| [CommandExecutionContract.swift](../AreaChain/Domain/CommandExecutionContract.swift) — `CommandExecutionStamp`、`CommandAttemptStamp`、`CommandOperationIdentity`、`CommandExecutionReceipt` / `Result` | 版本化运行/尝试/结果、提交确定性、外部效果、重试/取消/校验的适配协议；没有执行闭包或认证票据。 |
| [CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift) — `beginNext` / `receive` / `retryAssessment` / `retry` / `resolveValidation` | 不可编辑快照、按顺序的纯状态转移、一次性结果绑定、组结果一致性及成功不重放。 |
| [CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift) — `enqueue` / `planEvent` / `removeFromPlan` / `sealPlanForProtocol` / `receiveProtocolResult` | 草稿与计划间原子值转移、查询隔离、未保存保护与生命周期组合。 |
| [CommandDraftSession.swift](../AreaChain/Domain/CommandDraftSession.swift) — `takeForPlan` / `retainFromPlan` | 原会话的窄所有权入口，复用运行内 usedIDs 和 stamp；不改变 retained 的原有用途。 |
| [CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift) — `createdObjectType` | 仅增加 `todo.create → todo` 输出形状声明；execution / isExecutable / canEnterOrdinaryQueue 保持原值。 |

#### 权威所有权与编辑保护

- `enqueue(draftStamp, itemID, expecting: planStamp)` 必须显式给出宿主/草稿 UUID/版本、计划修订版及新的计划项 UUID。宿主在同一值事务中从 active 或 retained 移出草稿，再加入计划；任何失败保持双方原样。待决草稿切换先解决，不能清掉 pending 内的内容。仅 retain 不加入计划。
- 参数、正文、固定目标和原始基线直接由计划项内原 CommandDraft 持有，原草稿 UUID 保留。计划 UUID＋hostID＋revision 拒绝旧计划回调；项 UUID＋version 拒绝旧编辑/引用；草稿自己的版本继续推进。运行内已用项/组/草稿/运行 ID 防止身份重用，没有持久化 ID 登记。
- `beginEditing` 指定项，编辑直接修改该项，不搬回 active、不建立可提交编辑副本。`finish` 结束编辑；`cancelKeepingChanges` 明确表示结束编辑并保留最新内容，不承诺回滚。结束前不允许封存或移除此项。直接参数与结果引用不可同时成为同一参数的权威值。
- `removeFromPlan` 只在无依赖者、非组成员、未编辑且版本吻合时退回 retained，并推进草稿版本。丢弃仍须走原有显式草稿操作；移除不是删除正文。组须显式 dissolve 后再移除。移除被依赖项返回依赖者 ID，既不级联删除也不自动解绑。
- 所有尚未封存的计划项（含未完成参数、无可证明修改的项）都参加宿主 `requiresUnsavedContentHandling`；失败、受阻、未知结果和待处理外部效果也保留保护。查询、切页、清查询、收起、外部点击和重新聚焦都不改计划/运行。没有窗口关闭接线。
- 封存要求明确计划修订版，参数/目标与整个依赖图均有效，且没有正在编辑的项。内容所有权整体移入执行快照，当前计划清空并推进修订版；之后可以准备新计划，但已有 execution 未显式释放前不能封存第二个运行。新计划编辑不能覆盖旧快照。仅全部结果确认成功时 `releaseSuccessfulExecution` 才释放其运行内正文；失败/未知不退回成可重放创建。

#### 计划资格、顺序、合并与结果引用

普通计划只接受目录 `.modification + .declared + .eligibleAfterWiring`；unresolved / unavailable 和排除类指令直接拒绝，原草稿保留。导航、退出、隐私转换、永久删除、备份恢复等不能混入。参数未完成可以加入，`CommandPlanCheck` 显示 needsInput / blocked / needsValidation；统一封存不会静默跳过。`.eligibleAfterWiring` 仅是未来普通队列兼容性，所有实际 `isExecutable` 和 `canEnterOrdinaryQueue` 仍为 false。

默认按列表顺序；显式重排必须保持前置在前、组连续，且不丢项或重复项。依赖边检查未知、自依赖、环、逆序和失效输出版本。原子组仅限 language / appearance / truncation / captureSource 四项本地偏好声明，不允许组内依赖；整组是一个生命周期单元。原子结果覆盖全部成员，没有逐成员半成功入口；这只约束后续适配必须报告什么，不证明 UserDefaults 事务已实现。

合并须显式请求，仅合并相邻项。相同命令（业务字段相同）、相同固定选择/目标、完全相同且有已知非 mixed、字段类型有效原值的基线、单个 `.assign` 参数、静态有效、双方无前置/被依赖/结果引用且不在原子组时，保留最早项/草稿/基线并采用最后赋值，记录被合并草稿 stamp。白名单为四项偏好、todo.move、todo.priority、routine.priority。依据是现有偏好赋值、`SwiftDataTaskRepository.moveTodo` / `setPriority` 与 routine `setPriority` 的字段语义；这里只合并尚未执行的意图，不证明通知或业务副作用的事务/幂等。标题入口可能联动 NLP/标签解析，暂不自动合并。追加、替换正文、标签增删、跨命令同名参数、部分重叠批量目标、未知/不兼容基线、有依赖以及非相邻项保留两项并返回具体冲突。已经封存的步骤不属于可合并计划。

`CommandCreationReference(producer: itemStamp, outputType:)` 可以绑定声明为 object / objects 的参数（包括 target、子任务 parent），自动计入依赖。先前没有对象 UUID，不把任意字符串解释成表达式。这里只声明 todo.create 的单 todo 输出：现有 [SwiftDataTaskRepository.addTodo](../AreaChain/Services/Repositories/SwiftDataTaskRepository.swift) 在 `saveAndNotify` 成功后返回 TodoItem；没有调用它，也未核实其他创建动作具备单对象输出，因此不扩展其声明。

生产者版本变动使引用失效，必须显式刷新。生产者尚未成功、类型不符或没有输出时不能解析；前置失败/冲突/未知或外部效果未完成会阻塞依赖者，独立项继续。合成成功输出先检查成员和声明类型，再登记一次；消费者第一次进入 local 尝试时把对象引用固定在 bindings，只派生参数/目标视图，草稿不写占位对象。重试消费者复用固定 bindings；成功生产者不允许 local 重试或换绑另一对象。缺失输出保留 missingOutput 阻塞。

#### 纯生命周期与未来适配边界

- `CommandOperationState` 区分待补充、待校验、受阻、待执行、执行中、等待授权、冲突、成功、失败、未执行和结果待核实。ready / running / succeeded 是生命周期协议状态，不能当作真实接线证明；本阶段测试用合成事件推进，标准目录没有 wired 分支或 testOnly 开关。
- 运行身份包含 runID 和封存 planStamp；操作身份保留 itemStamp、operationID（稳定项 UUID）；每个普通项/原子组有单调尝试号和 local / external 阶段。只接受当前运行/尝试的结果；完全相同的当前 receipt 幂等接受且不再改变状态，冲突回调、旧修订版、旧尝试、未来尝试均拒绝。重试授权后、下次开始前也拒绝上一 receipt。
- local 提交确定性分为 notSubmitted / committed / unknown；external 分 notification / calendar 的 pending / running / succeeded / failed / unknown。local committed 后永不倒退成 notSubmitted。外部失败只能针对已确认可安全重复的失败效果重试，已经成功的效果不重放，local 创建和已登记输出也不重放。
- failedWithoutCommit / notExecuted 还须由后续适配确认 safeLocalReplay 才进入 local 重试；已提交部分只接受 idempotentExternal 指定的失败子集。未知提交或任何未知外部结果返回 requiresVerification；能力未核实返回 requiresAdapterConfirmation。这里的 assurance 只验证协议一致性，本阶段没有验证任何真实重试能力、幂等存储、补偿或业务撤销。
- 取消只对尝试号为 0 的 ready / blocked 单元标记 notExecuted；已开始返回需要适配确认，本地已提交返回不能取消已提交内容。没有真实取消句柄；收起面板不调用取消，取消不等于撤销。
- waitingAuthorization 保持忙碌；冲突保留指向快照基线的字段诊断，并检查所属项、字段、目标与 valueChanged 所需的基线，不读取当前真实值、复制当前正文或实现冲突 UI。后续适配可用 `resolveValidation` 提供 readyForProtocol / notExecuted 纯结果，重新开始时推进尝试号；对象不可用诊断不能直接恢复 ready。这个结果不是认证票据，也没有解锁或权限变化。
- 设置组统一成功/失败/冲突/未知结果来自后续真实适配确认。生产侧仍须验证事务能力、业务校验、目标存活、权限和接线；不得直接把 `beginNext` 或 `canSealProtocol` 接到真实 handler。
- 新类型没有 IO、Codable 或数据库模型。宿主、计划、快照、草稿、基线、事件、结果和派生参数的默认 description/debugDescription 隐藏正文；失败类别只含类型化标识，不接原始错误字符串、私密名称、文件路径或凭据。

#### 验证与交接

新增测试入口：[CommandPlanOwnershipTests](../AreaChainTests/Domain/CommandPlanOwnershipTests.swift)、[CommandPlanDependencyTests](../AreaChainTests/Domain/CommandPlanDependencyTests.swift)、[CommandPlanMergeTests](../AreaChainTests/Domain/CommandPlanMergeTests.swift)、[CommandExecutionTests](../AreaChainTests/Domain/CommandExecutionTests.swift)、[CommandAtomicPlanTests](../AreaChainTests/Domain/CommandAtomicPlanTests.swift)，合成夹具仅在 [CommandPlanTestSupport](../AreaChainTests/Domain/CommandPlanTestSupport.swift)。它们通过宿主真实纯转移序列验证所有权、缺参/排除、顺序/环/移除、保守合并、类型化输出/固定绑定、失败隔离、组协议、重复/旧结果、本地与外部区分、未知结果/重试门槛、取消/校验、查询/面板保护和描述脱敏；不调用业务或系统 API。

指定 Cursor verifier 当前无可调用入口，**blocked / 未执行**；没有再次检查登录、改认证或以其他代理复核替代。阶段整体仍为 **partial**。最终源码对应的本地证据在下表登记；本阶段不安装、不发布、不启动生产应用，不关闭前阶段缺口。

| 检查 | 最终结果 |
|---|---|
| 最终领域及既有草稿/宿主/目录/参数/查询/路径回归 | `./scripts/build.sh test` 配合 17 个重复 `--only-testing AreaChainTests/类名`：本节五套新测试，以及 CommandDraftTests / CommandDraftProtectionTests / CommandHostSessionTests / CommandCatalogTests / CommandParameterTests / ContentQuerySessionTests / ContentQueryProjectionTests / ContentQueryPageMappingTests / ContentQueryTests / ContentQueryContractTests / CommandPathTests / CommandPathConflictTests。**135 passed / 0 failed / 0 skipped**，含本阶段 25 项；`final-targeted.log`、`final-targeted-summary.json`、保存副本 `DomainRegression.xcresult`，原包时间为 `2026.10.01_16-19-32-+0800`。 |
| Debug 构建及静态验签 | 最终源码运行 `./scripts/build.sh` **passed**，`staticSignatureVerified: true`、`distributionReady: false`；`build.log`。没有安装或启动生产应用，不证明真实业务运行。 |
| Swift 质量门禁 | `python3 -B scripts/quality_gate.py --profile swift --format json` **passed**；整树摘要 **1170 passed / 0 failed / 1 skipped**（参数化运行计数为 1321 passed），`swift-gate.json`、`whole-tree-summary.json`。这是最终基线类型校验、冲突字段校验和宿主描述补强之前的编译版本；补强后重跑上述 135 项和 Debug 构建，没有重跑整树，不宣称最终整树全部通过。整树原结果包在后续提取明细时已不存在，保留的摘要未列出跳过项身份，1 项不计为通过。 |
| 严格局部 lint、静态与工作流 | 14 份本轮 Swift 执行 `swiftlint lint --strict --quiet` **passed**；最终 `python3 -B scripts/quality_gate.py --profile static --format json` 与 `python3 -B scripts/check_workflow.py` 均 **passed**，见 `static-gate.json` / `workflow.log`。静态门禁含 **172 项脚本回归**；检查器接口/规则没有修改。 |
| 源码与产物追溯 | 忽略目录 `build/CommandPlanQA/` 保存日志、摘要、领域结果包及 14 份 Swift 的 SHA-256。`source-before-final.json` 与 `source-after-final.json` 相同，关联最终测试/构建；`source-before.json` 对应收尾补强之前。环境为 macOS 26.6.2 arm64、Xcode 26.6 (17F113)、Swift 6.3.3、Python 3.9.6。并行 UI/Theme 仍在变化，没有冻结整树，HEAD/索引不能替代源码清单。 |

首轮新增测试编译曾因 Testing 宏对嵌套 Optional 描述表达式的展开报错；改成局部描述变量后 22 项通过。随后新增/收紧合并、依赖恢复、描述与诊断反例，最终 25 项纳入上述 135 项回归。构建仍有既有未用变量、旧可访问性 API 和多目标选择警告；没有借本阶段改动清理这些历史项。主代理沿所有权、基线、目标引用和结果转换自查；这不替代指定 Cursor verifier。

1C-2 当时的转交接续要求（现行实现见第 9.12 节）：必须同时处理 hostID、planID/revision、draftID/version、itemID/version、运行/操作/尝试身份，以及 active / retained / plan / execution 的唯一所有权。不能只转交 active；运行快照不得复制为可提交草稿。`isBusy` 表示 running / waitingAuthorization，非忙碌不代表 execution 已解决；还须检查未保存保护、未释放运行、冲突/未知结果和单次 receipt。后续已实现纯转交确认、失败保留和迟到回调拒绝；没有持久化明文状态或实现隐私锁定封存。这里保留 1C-2 的历史停止点。

### 9.12 阶段 1C-3：跨入口主动转交与唯一所有权

#### 范围与复用（2026-10-01）

本次独立授权仅覆盖纯 Domain 协议、合成普通内容测试及文档。开始时索引为空，已有 1C-1/1C-2 领域文件和并行按钮/开关、文案、工程文档、检查器差异全部保留。没有提交、推送、安装、生产应用启动、真实窗口操作、业务执行或磁盘数据迁移；第 9.6–9.11 节的历史验收与指定复核缺口不变。

| 核心接口 | 责任与实际消费者 |
|---|---|
| [CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift) — `host` / `validate` / `send` / `prepare` / `confirm` / `commit` / `cancel` / `fail` | 注入的运行内引用对象，MainActor 串行登记宿主与唯一有效代次；没有全局单例、窗口、资源对象或持久化。当前只由 Domain 测试消费。 |
| [CommandHandoffContract.swift](../AreaChain/Domain/CommandHandoffContract.swift) — `CommandHostOwnership` / `Lease` / `OwnedHost`、`CommandHandoffTicket` / `Requirements` / `Readiness` / `Status` | 版本化事件、接收条件和票据生命周期；`CommandHostEvent` 委托原宿主方法，不建立第二份草稿/计划/执行协议。 |
| [CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift) — `handoffStates` / `handoffNativeSelections` | 生成候选双方状态，复用现有查询、草稿、计划和 usedRunIDs。候选值不授予提交所有权。 |
| [CommandDraft.swift](../AreaChain/Domain/CommandDraft.swift)、[CommandDraftSession.swift](../AreaChain/Domain/CommandDraftSession.swift)、[CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift) — `handedOff` / `emptiedAfterHandoff` | 保留固定目标、参数/正文、基线、初始选择、稳定身份及防重放记录；计划图一次校验与迁移。 |
| [ContentQuerySession.swift](../AreaChain/Domain/ContentQuerySession.swift)、[ContentQueryCondition.swift](../AreaChain/Domain/ContentQueryCondition.swift)、[ContentQueryReducer.swift](../AreaChain/Domain/ContentQueryReducer.swift) | 最小增加冻结来源、日期上下文、独立转交原因与查询替换判断；保留旧 reducer 与页面映射。 |

`CommandExecutionRun`、Execution/Attempt/Operation 身份和状态直接复用，只用于资格判断与原有纯事件入口，**不迁移运行**。没有新增业务对象、参数解析器、真实 handler 或认证凭据；全部目录仍 `.unwired`，计划/草稿/运行的 `isExecutable` 仍为 false。

#### 资格与接收需求

- source 与 target 必须是协调者登记的不同宿主，lease 包含当前协调者 UUID、hostID、所有权 generation 和宿主 revision。旧身份、旧修订、重复转交 ID 或任一端已有进行中票据均拒绝。
- 任一端 `execution != nil` 一律拒绝，包括 ready、running、waitingAuthorization、failed、conflict、notExecuted、部分提交、未知本地/外部结果和全部成功。不能通过 `isBusy == false` 或未保存判断绕过。只有全部成功先经原 `releaseSuccessfulExecution` 显式释放，才重新检查普通资格；失败/未知不能变回可重放草稿。
- 任一端有草稿切换 pending 时拒绝。目标有任何 active、retained、计划项或计划编辑意图时拒绝，包含参数为空或 `modification == unchanged` 的草稿。源计划可以带未完成参数或正在编辑的项，但已有失效依赖/创建引用必须先显式修正，转交不暗中修复旧引用。
- 目标仅有查询时，`requiresHandoffReplacement` 检查非空原始输入（含空白和指令候选）、用户条件、抑制维度、独立绑定和未结束返回上下文。需要替换时票据输出 `replacesQuery`，宿主必须显式接受；普通页面自动条件本身不要求替换。确认绑定目标当前 lease，新输入使其过期。
- active、retained、plan 的参数和基线中出现 `nativeSelection` 时收集去重句柄，票据输出 `nativeSelections`。`confirm` 要求适配报告完全一致的已接续集合；漏项、多项或未确认均不提交。UUID 复制、纯协议确认不等于文件访问能力或安全验收。

#### 原子接管、失败与旧事件

1. `prepare` 只登记票据及双方修订，不移动内容、不冻结普通编辑。每次由 `send` 受理的事件都推进宿主 revision，包含同值输入和仅产生意图的事件；底层明确拒绝的事件也保守使准备过期，抛出错误则不发布状态。
2. `confirm` 接收明确的宿主准备成功事件。相同确认在双方 lease 仍有效时幂等；替换接受及原生资源确认都绑定该票据。它不负责创建窗口、焦点或执行命令。
3. `commit` 重新核对票据、双端 lease、资格和计划图，在局部候选中迁移双方，全部成功后以一次 `hosts = next` 发布；同步 MainActor 方法没有 await、外部回调或可失败的中间发布。目标接管和源撤权不可拆成两个公开提交动作。
4. 成功后两端 generation 与 revision 都推进，源恢复自己的当前页空查询/默认条件，清空其 active、retained 和 plan 内容，但保留防重放记录。源可用新 lease 创建新的独立意图，不能重新获得已转交内容。
5. `cancel` / `fail` 只终结票据，不改变任一端原状态/所有权。适配失败原因仅为 receiverUnavailable / windowPreparationFailed / resourceUnavailable / commitFailed，不接收原始错误正文。过期票据仍可显式取消；失败的提交不丢最新编辑。completed / cancelled / failed 身份留作运行内墓碑，不能重复确认、提交或用相同 ID 再准备。

Swift 值副本不具备所有权证明。协调者只从页面创建空宿主，没有导入旧 `CommandHostSession` 快照的入口；快照可供渲染/纯计算，不能独立成为执行入口。后续生产装配须让两个入口共享**同一个注入的协调者实例**，保留事件产生时的 lease，所有编辑、计划提交、确认与迟到回调走它核验。不得用新 lease 给旧事件补身份，也不得先 `validate` 后跨 await 再无检查调用 handler。旧宿主字段清空只是状态结果，真正撤权来自权威登记的代次切换。令牌不提供安全认证能力，不能替代权限、对象存活、业务校验与隐私锁代次核对。

#### 身份迁移与唯一参数所有者

- draftID、planID、itemID、固定对象 type/UUID/习惯记录 dayKey、参数/正文、基线和 initialTargets 保持；草稿 hostID 改为目标，version 推进。没有重新搜索、翻译、解析或读取真实对象。
- plan revision 推进至双方较大修订加一；每个项 version 推进。先校验旧结构，再按完整旧 itemStamp 映射新 stamp，一次更新全部创建结果引用并重新校验。顺序、前置 ID、编辑中项、原子组 ID 均保留；mergedOrigins 作为历史出处保留原 stamp，不伪装成新宿主编辑身份。
- 草稿 usedIDs、计划 usedIDs（项与组）和 usedRunIDs 在接收方取双方并集；源清空内容时仍保留自己的历史。转交往返不允许重建旧草稿、计划项/组或运行身份。
- active、retained、plan 分区与原值一并接续，不给任何一项创建另一份可编辑参数真值。接收后仍走原入计划、就地编辑、移除退回 retained 和封存协议。已执行步骤与已成功创建输出从不复活，因为任何未释放运行都不能转交。

#### 查询与页面接续

源 `input`（含诊断 UTF-16 范围）、条件 ID/值、显式范围、用户条件与实际 composition 原样接续。原 `.page` 条件冻结为 `.handoffPage(sourceLocation)`；缺少 scope 时显式冻结实际 global，避免目标页补默认范围。`handoffContext` 保留原来源/日期解释上下文，接收 `page` 与 `returnPoint` 使用目标当前可用位置及其 suppressed 状态；反复转交继续保留最初来源。

接收后 `.independent(.handoff)`，源页刷新、目标刷新及切页不再更新冻结条件。冻结条件不计为用户主动搜索；只有原输入/用户条件或后续显式编辑激活结果。后续显式输入优先替换同维冻结条件；移除范围后切页仍保持独立。重新绑定必须发送 `.rebind`，只释放冻结自动条件、恢复目标默认条件；与目标不兼容的用户显式范围仍返回 requiresQueryEditing，不能覆盖。

`.clearUserQuery` 或用户将查询清空触发返回时，移除冻结上下文，使用目标返回位置，不发送源宿主导航。保留源查询实际语义和保留源导航是不同责任；焦点、窗口几何、滚动视图对象均不进入 Domain。

#### 原生与隐私适配前置

未来适配负责真实目标准备、窗口创建/焦点、文件能力接续及失败回报，成功准备后才调用 `confirm`。认证不随转交继承，waitingAuthorization 运行被拒绝。私密正文封存/解封、锁定代次及访问校验必须接既有 DiaryContent / PrivacyAccess / PrivacyVault，不把密码、路径、权限票据或密钥塞进 CommandValue。本阶段只验证合成普通内容，未改变敏感内容或授权边界，不能宣称私密转交安全通过。

#### 验证、缺口与停止点

新增合成测试：[CommandHandoffTests](../AreaChainTests/Domain/CommandHandoffTests.swift)、[CommandHandoffIdentityTests](../AreaChainTests/Domain/CommandHandoffIdentityTests.swift)、[CommandHandoffBoundaryTests](../AreaChainTests/Domain/CommandHandoffBoundaryTests.swift)、[ContentQueryHandoffTests](../AreaChainTests/Domain/ContentQueryHandoffTests.swift)，共用 [CommandHandoffTestSupport](../AreaChainTests/Domain/CommandHandoffTestSupport.swift)。覆盖双端资格、查询替换/过期、编辑/取消/失败/重复、值副本与旧事件、稳定对象/基线/引用/组/防重放、原生句柄、全部运行状态、冻结查询/明确重绑/目标返回及描述脱敏；没有 handler、系统认证或原生交互测试。

指定 Cursor `verifier` 仍无可调用入口，**blocked / 未执行**。仅核对本次工具能力清单，未重复登录检查、修改认证或用其他代理/检查冒充指定复核；整体状态 **partial**。首轮两套测试为 13 tests / 22 参数化运行通过；扩展测试曾因测试比较非 Equatable 日期上下文而编译失败，修为字段断言。随后并行 DaybookToggleStyleTests 未定义 acceptsKeyboard 又阻断整个测试 target；保留这些事实，最终证据另记于下表。

`quality_gate.py --profile swift` 无条件调用全量 `build.sh test`，会运行真实原生窗口交互。根据本阶段明确边界未执行该 profile，也未运行会自动选择它的默认 auto；选用原静态/工作流入口、严格局部 SwiftLint、领域定向回归与 Debug 构建，不把这组证据称为整树 Swift 门禁通过。检查器接口/规则未改动，不新增专项脚本。

最终检查（2026-10-01），日志、源码摘要与结果包保存在忽略目录 `build/CommandHandoffQA/`：

| 检查 | 实际结果与边界 |
|---|---|
| 最终正常领域回归 | `./scripts/build.sh test` 配合 21 个 `--only-testing AreaChainTests/类名`：本节四套新增测试，以及 CommandPlanOwnershipTests / CommandPlanDependencyTests / CommandPlanMergeTests / CommandExecutionTests / CommandAtomicPlanTests / CommandDraftTests / CommandDraftProtectionTests / CommandHostSessionTests / CommandCatalogTests / CommandParameterTests / ContentQuerySessionTests / ContentQueryProjectionTests / ContentQueryPageMappingTests / ContentQueryTests / ContentQueryContractTests / CommandPathTests / CommandPathConflictTests。**165 passed / 0 failed / 0 skipped**，参数化运行计数 **203 passed**，其中新增 30 项。`host-regression-command.json`、`host-regression.log`、`host-regression-summary.json` 与 `HostDomainRegression.xcresult`。最终正常入口没有排除任何源码；并行 UI 文件已由其任务修正。 |
| 临时隔离回归 | 并行测试编译阻断期间，直接 xcodebuild 使用独立 `com.areachain.command-handoff-qa`、ad-hoc 签名、独立 DerivedData、串行和清除真实钥匙串授权；仅该次以 `EXCLUDED_SOURCE_FILE_NAMES=DaybookToggleStyleTests.swift` 排除无关 UI 测试源文件，不修改它。**163 tests / 200 参数化运行 passed，0 failed / 0 skipped**，后续补两项测试后由上行正常入口重新覆盖。`regression-command.json` / `regression-summary.json` / `DomainRegression.xcresult`；不作为整树通过证据。 |
| Debug 构建与静态验签 | `./scripts/build.sh` **passed**，`staticSignatureVerified: true`、`distributionReady: false`；`build.log`。没有安装、生产启动或真实系统认证；测试结束后重建正常 Debug 产物。 |
| 严格局部 lint、静态与工作流 | 本轮 9 份 Domain 与 5 份测试执行 `swiftlint lint --strict --quiet` **passed**；`python3 -B scripts/quality_gate.py --profile static --format json` 与 `python3 -B scripts/check_workflow.py` **passed**。静态入口含 **173 项脚本回归**；`lint.log` / `static-gate.json` / `workflow.log`。检查器差异属于既有并行工作，本阶段未新增检查规则。 |
| 源码追溯 | 最终正常回归前后 14 份 Swift 的 SHA-256 一致，见 `source-before-host-regression.json` / `source-after-host-regression.json`；隔离回归到最终回归只有两份测试文件新增覆盖，9 份 Domain 实现未改变。macOS 26.6.2 arm64、Xcode 26.6 (17F113)、Swift 6.3.3。整树仍有并行改动，没有用 HEAD/索引假定冻结。 |
| 指定复核与未运行项 | Cursor verifier **blocked / 未执行**；测试和主代理自查不替代指定复核。全量 auto / swift 门禁未运行；已有未用变量、旧可访问性 API 和多目标警告未在此阶段清理。没有真实窗口接收/焦点、文件访问能力、私密封存/解封、系统认证、磁盘迁移或业务执行证据。整体 **partial**，不关闭历史缺口。 |

1C-3 历史停止点：纯协议通过不等于真实窗口、权限资源或私密转交通过。后续获独立限定授权的 1D 仅补下节领域集成验证。

### 9.13 阶段 1D：领域链路集成验证与最小修正

#### 范围与工作区（2026-10-01）

本阶段仅串联 1A～1C-3 公共领域接口、合成普通内容和纯回执，不新增门面、状态机、参数模型、提供者、匹配/排序、UI 或真实执行。状态为**领域协议已实现、本地定向验证已通过、指定复核缺失、产品未接线，整体 partial**。当前总表以第 9.1 节为准，前节的失败/跳过/停止点保留为历史证据。

开始 HEAD 为 `c9244deb14e7a96cb8c5c78edd0a1a3810778cbc`，52 个已有文件暂存、未暂存区为空。过程中外部操作将这些成果提交为 `34500ebdde39027405bc4ebc563a1e2e01fae910`；本任务未暂存、提交或推送。并行变化涉及 Settings/PrivacySetupSheet、Theme 开关/度量、语言资源、隐私与控件测试、架构/工程/组件文档及工作流检查器，全部保留。当前任务的 Domain 修改仅为下述两份文件。

测试直接复用 `HandoffFixture`、`PlanFixture`、`QuerySessionFixture`；新增的 [CommandIntegrationTestSupport.swift](../AreaChainTests/Domain/CommandIntegrationTestSupport.swift) 只提供普通合成长文、已有创建参数和通过协调者发送事件的测试便捷方法，没有第二个宿主状态所有者。双宿主场景共用同一个 `CommandHandoffCoordinator`，正常事件使用当前 lease，迟到事件保留原 lease，不用宿主值副本冒充接线。面板信号单独用现有 `HostSession.presentationEvent` 验证严格不改草稿，未声称发生真实面板操作。

#### 四条链路与实际发现

| 链路 / 测试文件 | 本阶段验证结果 |
|---|---|
| [CommandLanguageIntegrationTests.swift](../AreaChainTests/Domain/CommandLanguageIntegrationTests.swift) | 中英文显示语言下，从 `/set` 逐步接受分组、语言指令和 chinese 参数候选，得到 `/setting/language/chinese`、同一 `setting.language` 和 `.value = .choice("chinese")`。查询解析不创建草稿；测试显式模拟用户接受后组装原 CommandDraft。编辑只改草稿参数，查询保留只读解析快照；显式入计划撤去 active/retained 副本，旧 stamp 重复入计划拒绝；查询/切页/清查询不动计划。参数完整及 `canSealProtocol` 始终不等于真实可执行。 |
| [ContentQueryIntegrationTests.swift](../AreaChainTests/Domain/ContentQueryIntegrationTests.swift) | `/tasks 汇报 (#工作 \| #学习) -#归档 status:open` 从 parser 到条件来源和页面投影连续通过；自动条件不激活，输入激活。OR/排除留在原条件及 extended 身份，旧 BoardFilter 覆盖被拒绝；detach 后页面事件不覆盖，清查询返回最初页面。另验证默认日期由用户 `date:today` 接管后不随刷新改变、删除范围跨刷新/返回保留但新访问恢复、emoji/组合字符后的非法日期诊断精确对应原始 UTF-16，删除真实条件后重新定位。没有提供记录或产生真实命中，`showsResults` 是结果上下文激活，`isReady` 是静态有效性。 |
| [CommandHandoffIntegrationTests.swift](../AreaChainTests/Domain/CommandHandoffIntegrationTests.swift) | 120 段普通合成备注经编辑、查询/切页/清查询/面板信号、retain/切换/restore、入计划就地修改和移除退回 retained；正文、固定对象、基线保持。源同时携带 todo 创建及子任务结果依赖，从 menubar 转给 workspace；占用目标拒绝，接收失败源完整，成功后旧 lease/候选事件/旧确认/封存事件不能改接收方。目标手记页默认条件及后续切页不覆盖转交查询；草稿/计划身份、依赖和基线保持，版本按原协议推进。描述测试发现并修正下述值展开问题。 |
| [CommandExecutionIntegrationTests.swift](../AreaChainTests/Domain/CommandExecutionIntegrationTests.swift) | 使用目录真实声明的 `todo.create → todo`，引用、合法重排/窄合并、非法重排/合并/移除的原子拒绝和转交后封存连通。前置合成失败阻塞依赖者，独立项继续；显式合成重试确认后创建输出固定，消费者重试不换绑。已提交创建的外部失败仅重试确认的失败效果，不重建本地对象；未知 local/external 结果要求核验，保留快照且不能重试、释放或转交。旧计划版本、旧尝试及重复回执不重放；即使全部成功也须原显式释放接口后才允许转交。多消费者引用修复的失败案例见下文。 |

实际装配判断：解析快照、不可编辑基线及执行快照有各自用途，测试没有发现 active / retained / plan 同时持有可重复提交正文；可编辑参数始终由原草稿承载。解析结果到草稿是用户接受动作的宿主装配，测试内即可表达，因此未抽取生产门面。正常链路中的 host/draft/plan/item/run/attempt 身份及 lease 通过现有入口传递，静态检查没有升级成权限或执行资格。

#### 两处最小修正

1. [CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift)：编辑生产者后，两个消费者同时产生 staleReference。旧 `.link` 每次要求整图无诊断，因此修复任一个都会被另一个旧引用拒绝，公共接口无法逐个完成文档要求的显式刷新。现在只允许**其他项原已存在的 staleReference** 暂留；当前项的旧引用、错误输出类型及新结构错误仍拒绝，失败不发布状态。封存与转交仍要求完整有效图，不自动换绑、不跳过依赖。测试证明可逐项恢复并继续转交，也保留错误链接反例。
2. [CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift)：宿主/草稿已有描述脱敏，但直接描述 `arguments` 或 `baseline.values` 会递归展开 CommandValue 中的正文。新增原值类型的 description/debugDescription 脱敏，数组/原值容器随之隐藏载荷；参数值、Equatable、静态校验和执行资格不变。没有日志、IO、加密或敏感存储变更。原始查询 `source/input` 和显式读取出的正文仍是业务数据，不构成可随意记录日志的安全接口；未来适配不得记录原始查询/正文。

#### 当前验证证据与保留缺口

证据保存在忽略目录 `build/CommandIntegrationQA/`；命令和源码摘要与结果包一起保存，不提交产物。

| 检查 | 结果与适用范围 |
|---|---|
| 最终领域集成及回归 | `./scripts/build.sh test` 加 `regression-command.json` 所列 25 个 `--only-testing AreaChainTests/类名`：本节四套测试以及第 9.12 节的 21 套领域回归。**177 passed / 0 failed / 0 skipped；参数化计数 217 passed**。本阶段新增 **12 项 / 14 次参数化运行**，覆盖两处修正。`regression.log`、`regression-summary.json`、`regression-tests.json`、`DomainRegression.xcresult`。未排除源文件或断言。 |
| Debug 构建 | `./scripts/build.sh` **passed**，`staticSignatureVerified: true`、`distributionReady: false`，见 `build.log`。只构建/静态验签，不安装或启动生产应用，不表示真实系统解锁已验收。 |
| 静态/工作流/局部 lint | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py` 及 2 份 Domain / 5 份测试的 `swiftlint lint --strict --quiet` 均 **passed**；静态门禁含 **174 项脚本回归**，见 `static-gate.json`、`workflow.log`、`lint.log`。检查器的变化属于并行成果，本阶段未修改它。文档收尾后重跑受影响静态/引用检查。 |
| 源码适用性 | `source-before-regression.json` / `source-after-regression.json` 覆盖整个跟踪树与非忽略新文件。回归前后 Swift 和资源摘要一致；仅本权威文档与并行 `docs/engineering.md` 改变。构建后摘要 `source-after-build.json` 中 Swift/资源仍一致，另有本次组件目录/技能路由的引用补充。环境 macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3。HEAD/索引变化不替代文件摘要。 |
| 原失败与检查选择记录 | 首轮 4 passed / 1 failed（参数化 5 passed），多消费者修复失败保存在 `InitialIntegration.xcresult` / `initial-targeted.log` / `initial-summary.json`。扩展测试一次遗漏 `try` 的编译失败保留在 `integration.log`，修正后 11 项通过。描述反例为 3 passed / 1 failed，保留 `ValueDescriptionFailure.xcresult` / `value-description-suite.log`；修正后纳入最终回归。此前一次方法过滤未匹配用例，摘要为 0 tests / unknown（`value-description-selection-summary.json`），未计为通过，改用完整测试类复现。 |
| 指定复核 | Cursor `verifier` 无当前可调用入口，**blocked / 未执行，整体 partial**。没有登录检查、认证配置修改，也没有用集成测试或其他代理冒充指定复核；历史缺口不自动关闭。 |
| 未运行 | 全量 auto / swift profile 会启动无关原生交互，本阶段不执行，不宣称最终整树 Swift 门禁通过。没有产品 UI/焦点/真实窗口、真实 handler/仓储/事务、UserDefaults/文件/系统服务、真实外部重试/撤销、私密封存、真实认证、安装或发布验证。 |

构建/测试日志仍有多架构目标选择、既有原生可访问性 API 过时及并行测试的 Swift 6 actor 隔离警告；本阶段未扩展到这些无关文件修复。主代理已检查实际差异、失败原子性、参数所有者、来源范围和返回/迁移边界，这不是指定独立复核。

纯协议已接受的是**合成回执和合成能力确认**，不是“真实执行成功”。未知结果当前保留在 verificationRequired，现有 resolveValidation 仅处理 waitingAuthorization/conflict，尚无未知结果核对后回填事实的真实适配/协议；这延续第 9.11 节边界，本阶段没有将它降格为安全重试或自行设计恢复语义。真实窗口准备、关闭保护和原生能力接续也仍须后续宿主负责。没有发现本阶段需要改变已确认产品语义的其他选择。

#### 阶段 2 的有界交接（本阶段不实施）

- **直接复用**：`ContentQueryParser` 的原文/条件/诊断、`ContentQuerySession.conditions` 的有效条件与来源（不能只读取 `input` 漏掉结构化或页面条件）、scope/composition、`ContentQueryApplicability`、注入的日期上下文。结果身份沿 `CommandObjectReference` 的 type＋UUID，习惯执行记录另含 dayKey；子任务保留 parent ID，图片保留 owner kind＋ID。条件 ID 只在会话内有效；跨入口继续保留来源上下文和 lease，不按裸整数 ID 合并状态。
- **真实快照输入**：沿 [DayBoardLogic.swift](../AreaChain/Domain/DayBoardLogic.swift) 的 TodoSnapshot / SubtaskSnapshot / RoutineSnapshot / CheckSnapshot / DiarySnapshot 提供真实 ID、类型、存活/删除状态、标题/允许读取的备注或正文、完成态、标签关联、真实 createdAt、业务日、优先级/提醒及来源。子任务日期取父任务且保留父存活状态；习惯还需创建日、启停/暂停日、星期掩码及按日 checks；标签需 UUID/规范名称/删除和私密标签标记；图片需元数据、拥有者和可浏览性；剪贴板需 copiedAt 与载荷类别。不得用快照默认零时间或虚构字段满足 created/status；缺少提供者数据与空结果须分别报告。结果快照版本/查询请求关联、失效反馈及片段协议尚未定义，留给阶段 2 的最小具体消费者决定。
- **依赖既有投影的条件**：`boardDate` 的 listedDay / agenda / items 分别复用 Classification / AgendaProjection / ItemsListing；逾期、即将、排程存在性不能改成星期匹配。`taskOrSubtask` 标签谓词需子任务关联快照，不等同 ownTags。routine 的 status 必须显式给记录日，`date:today` 不替代选择；created、has:image 和其他不适用字段必须遵守 applicability。OR/排除及扩展条件不能丢进旧 BoardFilter 往返；旧 BoardSearch 的匹配、归一化及投影仅在语义等价时复用。
- **隐私与拥有者入口**：手记沿 [DiaryPrivacy](../AreaChain/Domain/DiaryPrivacy.swift)、[BoardSearchPrivacy](../AreaChain/Domain/BoardSearch.swift) 投影，真实正文访问继续经过既有 DiaryContent / PrivacyAccess / PrivacyVault；普通提供者不触发解锁。附件经 `AttachmentAccess.canBrowse`、`AttachmentOwnerIndex` / ownerKey、`isSingleLive`，重复 UUID、未知/已删拥有者和私密手记不能被“活 ID 集合”放宽。图片元数据命中不等于具备文件读取能力。剪贴板和回收站维持显式范围，默认全局不纳入。
- **建议首个子阶段 2A**：只做**一次性任务 todo 的只读快照提供者及最小类型化结果**，以调用方注入的真实形状合成快照和现有有效条件验证 AND/OR/排除、静态适用性、完成/业务日/created、标签及稳定身份；`taskOrSubtask` 或 has:image 若纳入，必须一并给出所需的子任务/拥有者快照，否则明确报告尚不支持。仅实现 tasks/global 中的 todo 子集并报告覆盖范围，不宣称完整 `/tasks` 已提供；暂不做习惯、子任务独立结果、手记/附件/剪贴板/回收站提供者、全局排名、真实仓储接入、UI 或指令执行。未知结果恢复及真实操作适配属于后续执行阶段，不能塞入只读提供者。

阶段 1D 到此停止；阶段 2 仅交接，不因本阶段定向通过而自动启动。

### 9.14 阶段 2A：todo 只读快照提供者与类型化结果

#### 范围、输入与接口（2026-10-01）

本次明确授权实现阶段 2A。开始 HEAD 为 `fef34089ad1d3eb5cbfcf061c830d0f91aec2784`，索引无差异，已有未跟踪 `ClipboardOptionsConsumerTests.swift`；过程中剪贴板选项及组件目录有并行修改，全部保留。前阶段“未实施提供者”是历史时点，本次没有关闭其验收缺口。

- [TodoQueryRead.swift](../AreaChain/Domain/TodoQueryRead.swift)：`TodoQueryRequest`、`TodoQueryResponse`、`TodoQueryMatch`、覆盖/诊断与 `ContentQueryMatchEvidence`；[TodoQueryProvider.swift](../AreaChain/Domain/TodoQueryProvider.swift) 的 `read(_:)` 是入口；[TodoQueryMatching.swift](../AreaChain/Domain/TodoQueryMatching.swift) 只承担该提供者内部的实际匹配。
- 输入为调用方的 requestID、ContentQuerySession、原形 TodoSnapshot 数组、可选 UUID→名称表及 TodoQuerySubtaskData。不接受预判匹配 UUID 集合，不查 ModelContext、单例、偏好、文件或系统时间，不修改快照。真实 createdAt/业务字段须由调用方正确提供；合法的 epoch 时间不能与旧快照默认值自动区分，本实现不虚构创建时间。
- 完整查询仅取 Session 的有效 conditions、scope/composition、queryDates 和原诊断；不重新解析 source，不经旧 BoardFilter 有损往返。页面默认、用户结构化及转交冻结条件均参与。即使 showsResults 为 false，显式读取仍评估默认条件，呈现由未来宿主决定。
- 日期由会话/页面注入，转交沿原 handoffContext 冻结；boardDate 自带的日期/Calendar 保留。tagNames 为 nil 表示未提供，空字典表示已提供空映射；若真实关联 UUID 在已提供映射中仍缺名字，该行报告 missingAssociatedTagName，不能推导为无标签或通过排除条件入围。稳定 ID/noTags 不需要名字表。
- includedInSnapshots 明确声明所有输入任务的 subtasks 已完整提供，数组可为空；unavailable 表示无法判断，不能把快照默认空数组当读取证据。只有 taskOrSubtask 需要此辅助数据。任务自身 tagIDs 沿 TagIDList.parse 作为关联事实，不创造标签。

#### 实际支持条件与复用

| 条件 | todo 实际匹配规则 |
|---|---|
| scope / contentTypes | 原 composition 求交集，liveOnly 且包含 todo 才评估。global、tasks、标签内容组合只覆盖 todo 子集；trash 即使含 todo 仍 notApplicable。 |
| 文字、短语、OR、排除 | 条件间 AND，每条 clause 内 OR；多词可跨 title/notes，短语在同一字段连续命中，排除须两字段均不含对应文字。调用 BoardSearch.matches 的 localizedStandardContains：Foundation 当前语言环境的标准搜索，不计大小写/变音，不新加模糊、分词或编辑距离。普通文字不查标签名/子任务标题。 |
| 文本标签 | TagSyntax.normalizedName 的修剪、规范组合、POSIX 大小写/全半角折叠，**不去除变音**。TagIDList 解析任务自身真实关联，再按名称相等判断；支持排除、任一组和组间交集。 |
| page.tagID / noTags | own 直接检查任务；taskOrSubtask 复用原 ItemsListing 提取的 hasTag（任务自身或活子任务）。子任务 todoId 必须对应父项，重复子任务 UUID 隔离相关父项。noTags 只看任务自身解析后的空关联；stable tagID 即使全零也是真实 ID，不当 noTags 哨兵。 |
| 状态 / 优先级 / 提醒 / 来源 | status 用自身 isDone；优先级精确比较 important/urgent；提醒精确比较分钟值，reminderPresence 复用 Classification；sourceApplication 精确比较 Bundle ID。子任务完成不代替父项。 |
| itemKind / todoStatus / routineStatus | 前两项用 ItemsListing.todos 的既有语义；routineStatus 按原分类型契约对 todo 为中性，返回 typeNeutral 依据，绝不解释为完成态。 |
| date / created | date 用 dayKey；created 用真实 createdAt 按注入 Calendar 转民事日。组内并集、组间交集、包含端点。非规范日期、坏日期、非有限/不可表示创建时间隔离该行并诊断，不回卷修正。 |
| page.boardDate | listedDay 调 Classification.matchesDate；agenda 的 overdue/upcoming 调 AgendaProjection；items 调 ItemsListing.todos。保留逾期/即将要求未完成、recent 为 today…today+7 含端点且可含完成任务。 |

真实共同语义只提取了 ItemsListing.hasTag，原列表继续调用它；另给 Classification.matchesDate 加默认兼容的 Calendar 参数，并在 ItemsListing/本提供者传入实际日历，避免 recent 偷读系统日历。原生产调用默认值、旧 BoardSearch 解析/排序及其他规则不变。

明确未支持：has:image 返回 imageAssociationUnavailable 并 blocked。现有 AttachmentAccess/AttachmentOwnerIndex 依赖实体、类型和完整拥有者有效性，没有直接适用于此请求的已验证关联投影，本阶段不扩附件接入。手工构造 agenda 的 today/recent 等非现有页面语义返回 unsupportedAgendaDate，不发明解释。其他类型提供者、子任务独立结果、片段显示、相关性得分、全局排序、真实仓储/UI/执行均未实现。

#### 覆盖、诊断、身份与命中依据

- queryIsValid 复用 Session 静态有效性并拒绝重复条件 ID；文本/条件诊断原样返回。无效查询或指令输入为 invalidQuery，无结果；无 todo 范围或 deletedOnly 为 notApplicable。整体辅助数据缺失、不支持条件或日期上下文无效为 blocked，整个 todo 子集不返回，OR 不能绕过不支持条件。
- 可评估请求为 evaluated。providerTypes 为 todo；requestedTypes 来自 composition，coveredTypes 是本提供者在该范围可承担的 live todo 子集，**不是全部条件已满足的证明**。isPartialTypeCoverage 比较两者；isCompleteForCoveredTypes 还要求 evaluated 且无提供者诊断。坏数据行可隔离而返回其他有效行，调用方必须同时读状态/覆盖/诊断；todo 零命中不是全局零命中。
- 身份沿 CommandObjectReference 的 type＋UUID，todo 的 dayKey 仅为业务/展示值。重复 todo UUID 在整个输入中计数，包括已删行；同 ID 的所有行都不返回，诊断给对象和本请求输入下标，不 first-wins。正常记录保留输入相对顺序，非最终用户排序。
- 结果为只读值投影，含标题、单份备注、业务日、createdAt、完成态及依据；无实体、分数或操作授权。requestID 回传关联本次快照和查询，不是数据库版本/lease；未来异步适配仍须核验过期，不能凭结果直接执行操作。
- 依据含 conditionID、OR alternativeIndex、字段、positive/absence/typeNeutral 及可选关联对象。条件 ID 须在同次 requestID 的 Session 内解释；子任务标签命中附 child 类型身份，结果仍为父 todo。每个正向文字条件在每个命中字段保留首个范围，不枚举全部重复出现。
- 范围来自原字符串 localizedStandardRange，转 UTF-16 NSRange 并扩展到完整字素，避免组合重音/emoji 截断；不使用规范化副本偏移。排除/noTags 只给 absence，无正向高亮。本阶段未生成片段。Request/Response/Match 的 description/debugDescription 脱敏；显式业务字段仍不可随意记录日志，依据不复制关键词/备注。

#### 验证、差异与保留缺口

证据位于忽略目录 `build/TodoQueryQA/`，不提交产物：

| 检查 | 本次证据 |
|---|---|
| 新测试 | [TodoQueryTextTests](../AreaChainTests/Domain/TodoQueryTextTests.swift)、[TodoQueryAttributeTests](../AreaChainTests/Domain/TodoQueryAttributeTests.swift)、[TodoQueryDateTests](../AreaChainTests/Domain/TodoQueryDateTests.swift)、[TodoQueryIntegrationTests](../AreaChainTests/Domain/TodoQueryIntegrationTests.swift) 共 26 项；[夹具](../AreaChainTests/Domain/TodoQueryTestSupport.swift) 只用合成快照及原 QuerySessionFixture。 |
| 完整链路 | 原始查询经 ContentQueryParser / Session 到结果；验证 source/priority/date 页面默认、结构化提醒、用户接管日期、handoff 冻结标签/日期/范围与目标切页；每个有效条件 ID 都有结果依据。 |
| 旧搜索对照 | 8 组共同子集：跨字段文字、CAFE/CAFÉ、单/多标签、优先级、提醒、组合、空命中，todo ID 集合与 BoardSearch 一致。短语/OR/排除、新字段、空查询页面读取、坏数据隔离和输入顺序不纳入旧搜索等价声明。 |
| 定向回归 | `./scripts/build.sh test` 加 regression-command.json 中 22 套过滤：四套新测试、查询/会话/投影/页面/转交、DayKey/DayBoard、Classification/ItemsListing/Agenda、BoardSearch/UnifiedSearch/CatalogSearch/TagSyntax。**208 passed / 0 failed / 0 skipped**，参数化运行 **215 passed**；regression.log、regression-summary.json、DomainRegression.xcresult。 |
| Debug 构建 | `./scripts/build.sh` **passed**；build.log 的 staticSignatureVerified 为 true，distributionReady 为 false。仅构建/静态验签，不安装或启动生产应用。 |
| 静态、工作流、lint | `python3 -B scripts/quality_gate.py --profile static --format json` **passed**（含 174 项脚本回归）；`python3 -B scripts/check_workflow.py` **passed**；5 份相关 Domain 与 5 份测试文件的 `swiftlint lint --strict --quiet` **passed**。证据为 static-gate.json、workflow.log、lint.log；本次未改变检查器。 |
| 首轮失败及修正 | 25 passed / 1 failed：Cafe 后组合重音未在 Foundation 范围内，扩展原文字素后回归通过。同时磁盘仅余约 117 MiB，Xcode 系统诊断包写入失败（exit 251）；targeted.log、取回的 targeted-test-output.log 保留。只移除本轮未完成系统日志归档，没有清理其他成果。 |
| 源码与环境 | source-before-regression.json / source-after-regression.json 的源码/资源摘要一致。macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3；没有性能优化或规模预算声明。 |
| 指定复核 | 当前工具无 Cursor verifier 可调用入口，**blocked / 未执行，整体 partial**；没有重查登录、改认证或以其他代理/测试替代，历史缺口继续保留。 |

文档最终编辑后重跑受影响静态/引用检查。过程中并行剪贴板测试曾有两条日志扫描候选（控件类型/几何与截图路径）及未写完的工程文档锚点；并行成果更新后当前门禁通过，本任务没有修改其源码或验收记录。不运行会启动无关原生交互的全量 auto / swift profile，不宣称整树 Swift 门禁、原生、真实数据库/权限/外部服务、安装或发布通过。构建/测试日志已有架构选择、旧可访问性 API 和并行原生测试的 Swift 6 actor 警告，本次不扩展修复。

#### 后续有界建议与停止点

建议下一个提供者先做**活子任务独立结果**：注入父 TodoSnapshot 和完整 SubtaskSnapshot，保留 parent 类型身份、父存活/业务日与自身 title/tags/isDone/createdAt；验证同 UUID 跨类型身份不冲突。复用 Session 有效条件、composition/applicability、CommandObjectReference、TagSyntax/TagIDList 和本节依据约定。第二个真实消费者需要相同文字范围/区间规则时，再从 TodoQueryMatching 提取窄函数；不提前建注册中心或泛型引擎。习惯排程、私密手记、附件拥有者和真实库分别定界。

阶段 2A 到此停止，不进入后续提供者、生产 UI 或指令执行；当前为已实现、本地定向验证通过、指定复核缺失的部分完成状态。

### 9.15 阶段 2B：活子任务独立结果的只读快照提供者

#### 范围与核心接口（2026-10-01）

本次明确授权限定开发：仅注入快照的匹配、类型化结果与测试。开始工作区干净；执行期间出现 `SettingsButtonTestSupport.swift`、`SettingsToggleConsumerTests.swift` 的并行改动，保留。前阶段 partial、指定 Cursor verifier 缺失与历史整树门禁缺口不因此关闭，不重复登录或认证检查。

- [SubtaskQueryProvider.swift](../AreaChain/Domain/SubtaskQueryProvider.swift) — `SubtaskQueryProvider.read(_:)`；[SubtaskQueryRead.swift](../AreaChain/Domain/SubtaskQueryRead.swift) — `SubtaskQueryRequest / Response / Match / Coverage / Diagnostic / InputPosition`；[SubtaskQueryMatching.swift](../AreaChain/Domain/SubtaskQueryMatching.swift) — 提供者内部匹配。
- 输入直接复用 TodoSnapshot 内嵌 SubtaskSnapshot、ContentQuerySession.conditions / composition / queryDates、requestID、可选标签名字表与 TodoQuerySubtaskData。没有实体、仓储、文件、系统当前日或写入能力；不重新解析 source，不把父任务整条查询先跑一次。
- 只接受组成含 subtask 且删除策略 liveOnly 的子集，适用于 global、tasks、subtasks 与含子任务的标签内容组合；回收站为 notApplicable。providerTypes / coveredTypes 为 subtask，requestedTypes 来自原 composition。零命中不能解释成全局零命中，coveredTypes 也不表示所有条件已处理成功。
- queryIsValid / invalidQuery、notApplicable、blocked、evaluated 与 2A 含义一致，复用 TodoQueryReadState / TodoQueryIssue；原文本和条件诊断回传。重复条件 ID 拒绝；`isCompleteForCoveredTypes` 要求 evaluated 且没有提供者诊断。

#### 自身字段与父级页面约束

| 条件 | 实际语义与命中依据 |
|---|---|
| 文字、短语、OR、排除 | 只查子标题。条件间 AND、clause 内 OR，短语连续，排除不能被父标题/备注影响。沿 BoardSearch.matches 与 2A 的标准搜索；首个原文 UTF-16 范围扩展到完整字素。父标题只用于所属关系展示。 |
| 文本标签、page.tagID、noTags | 只查子任务自身 tagIDs；不继承父/兄弟。文本标签沿 TagSyntax.normalizedName 的精确名字关联。own / taskOrSubtask 在独立子结果上均要求自身关联；ItemsListing.visibleSubtasks 因父标签显示全部子行的布局行为不等于独立搜索命中。noTags 只看自身空关联；稳定全零 UUID 仍是真实标签。 |
| status:open/done | 自身 isDone；依据 completion，无父引用。不受父完成态替代。 |
| date | 父任务 dayKey；依据 parentScheduledDay＋父 todo 引用，不伪装为子任务创建日。 |
| created | 子任务真实 createdAt 按 queryDates.calendar 转民事日；依据 createdAt。父 createdAt 仅参加输入有效性检查。日期闭区间含端点，组内并集、组间交集，today 与转交冻结沿原会话。 |
| page.boardDate | 父任务日期与父完成态的页面入围：listedDay 用 Classification，items 用 ItemsListing，agenda 仅 overdue / upcoming 用 AgendaProjection。recent 含 today…today+7 与已完成父项；calendar 与 todayKey 使用谓词自带值。依据 parentScheduledDay＋父引用。 |
| page.todoStatus / itemKind | 委托 ItemsListing 的父任务入围规则；分别返回 parentCompletion / parentItemKind＋父引用。可同时存在自身 status 条件，二者分别求值。recurring 不包含一次性父项及其子任务。 |
| page.sourceApplication / reminderPresence | BoardSearch.subtaskHits 已有父级来源/提醒筛选口径；按 Classification 精确 Bundle ID / 提醒存在性判断，依据 parentSourceApplication / parentReminder＋父引用。没有为子任务虚构独立属性。 |
| page.routineStatus | ItemsListing 的分类型状态只限制习惯，对一次性父项及其子任务为 typeNeutral；依据 objectType＋父引用，不转换成子完成态。 |
| scope / page.contentTypes | 使用既有类型组成与收窄契约，contentTypes 查真实 subtask 类型。 |

**2B 历史时点记录：以下父级 priority 与全局矛盾缺口由 [2B-R](#916-阶段-2b-r父级页面条件与按类型可满足性) 修正；其余缺口保留。**

**明确阻止与缺口：** 显式 `!p1` 等 priority、`@15:30` 等 reminder、has:image 按 ContentQueryApplicability 为子任务不适用，返回 inapplicableCondition＋条件 ID，整个子任务子集 blocked，OR 不绕过。页面优先级当前同样投影为普通 priority clause，没有单独的父级页面谓词；本阶段不以 origin 猜测另一种字段语义，亦 blocked。非既有 agenda 日期组合返回 unsupportedAgendaDate。现有 ContentQueryConditionValidation 会把 overdue/upcoming 的 boardDate 与 status:done 判为全局 unsatisfiable，尚未分开父状态与子状态；提供者尊重该 invalidQuery，不绕过 Session，也未改前阶段契约。后续须先讨论类型化矛盾分析与父级 priority 表达，再开放这些组合。

#### 完整性、身份与结果

- subtaskData 必须为 includedInSnapshots，表示所有输入父项的子任务已完整提供，空数组可以是合法完整数据。unavailable 即使嵌套数组非空也 blocked / missingSubtasks，不能以快照默认空数组代替读取证据。
- tagNames 为 nil 与已提供空字典不同；文本标签条件（包括排除与 OR）缺表则 blocked / missingTagNames。已有自身关联 UUID 缺名字时隔离该子项，报告 missingAssociatedTagName；不推导成无标签。父/兄弟关联不参与此子项的名字完整性判断。稳定 tagID 与 noTags 不需要名字表。
- 父 ID 在全部输入中计数，包含已删父项；重复父 ID 的所有子项隔离。子 ID 在全部嵌套输入中计数，包含已删父/子项，同父或跨父重复均隔离所有相同子 ID。错归属不重挂到另一个父项。没有 first-wins；合法兄弟与其他父项可继续评估。
- 先做全部身份诊断，再评估唯一活父下的唯一活子。身份诊断保留 issue、类型引用和全部输入位置（parentIndex＋可选 subtaskIndex），不带正文；重复 ID 每组诊断一次，错归属逐位置报告。2A / 2B 隔离相同歧义身份；因 2A 仅在 taskOrSubtask 使用子关联、结果粒度为父项，其诊断可分属多个父项，2B 则定位子项并保留全部嵌套位置。
- 活父的规范安排日与 createdAt、活子的 createdAt 沿共用校验；非法父值隔离其子树，非法子值只隔离该子项。墓碑按 deletedAt 非 nil 排除，不解析其日期或返回回收站数据，与 2A 一致。合法 epoch 仍无法与快照旧缺省创建时间自动区分，真实调用方必须提供真实字段。
- 结果 id 是 CommandObjectReference(subtask, 自身 UUID)，parent 是独立 todo 引用；跨类型同 UUID 不冲突。结果只保存自身 title / isDone / createdAt、parent / parentTitle / parentScheduledDay 与 evidence；没有父备注或整份父快照。
- 顺序为父输入顺序＋嵌套子输入顺序，不按 sortOrder、业务日、创建时间或相关性重排。requestID 只关联本次结果与会话，不授予操作或异步版本有效性。
- 依据复用 ContentQueryMatchEvidence：conditionID、alternativeIndex、真实字段、positive / absence / typeNeutral、可选范围与关联对象。新增五个 parent 字段，保留 2A 字段和值语义；公共类型继续留在 TodoQueryRead.swift，没有建立全类型包装框架。Request / Response / Match 的 description / debugDescription 脱敏，数组反射也不展开标题或参数。

#### 共用提取与验证

第二个真实消费者出现后，从 2A 小范围提取 [ContentQuerySnapshotMatching / Validation](../AreaChain/Domain/ContentQuerySnapshotMatching.swift) 的文字原文范围、文本标签、区间包含、规范日与创建时间戳校验；[TodoQueryPageRules](../AreaChain/Domain/TodoQueryPageRules.swift) 提取父任务 boardDate / ItemsListing 入围。TodoQueryMatching / Provider 改为委托相同函数，没有改变自身字段、诊断或结果。没有修改 BoardSearch、Classification、ItemsListing、解析器或 Session 来凑等价。

测试为 [SubtaskQueryTextTests](../AreaChainTests/Domain/SubtaskQueryTextTests.swift)、[AttributeTests](../AreaChainTests/Domain/SubtaskQueryAttributeTests.swift)、[DateTests](../AreaChainTests/Domain/SubtaskQueryDateTests.swift)、[IdentityTests](../AreaChainTests/Domain/SubtaskQueryIdentityTests.swift)、[IntegrationTests](../AreaChainTests/Domain/SubtaskQueryIntegrationTests.swift)，夹具只用合成数据。原始 `/subtasks` / `/tasks` 经 ContentQueryParser → Session 有效条件 → 提供者 → 类型化结果；页面标签/日期、用户接管与转交冻结均有结果断言。旧搜索对照只比较共同子标题、多词、大小写/变音、标签及父级页面约束的 ID 集合，不比较旧排序/拼接标题；status / created、短语/排除/OR、坏数据策略与空查询不冒充旧搜索等价。

证据位于忽略目录 `build/SubtaskQueryQA/`，不提交产物：

| 检查 | 实际结果与证据 |
|---|---|
| 新测试与 2A 回归 | 五套子任务共 25 项＋原四套 todo 共 26 项，首轮 **51 passed / 0 failed / 0 skipped**；targeted.log / targeted-summary.json。 |
| 完整领域回归 | `./scripts/build.sh test` 加 regression-command.json 的 27 套过滤，**229 passed / 0 failed / 0 skipped**；regression.log、regression-summary.json、regression-tests.json 与 DomainRegression.xcresult。27 个 suite 均在结果树核实为 Passed，含解析/会话/页面/转交/日期/分类/列表/Agenda/旧搜索与标签。 |
| 兼容对照 | 六种旧页面筛选×六种共同查询；其中 noTags＋三条正标签查询由新 Session 判无效，旧子任务结果也为空，单独标注，不计有效查询等价。其余 33 组有效查询 ID 集合一致；不比较排序或把 status/created 当旧语法。 |
| Debug 构建 | `./scripts/build.sh` **passed**，build.log：staticSignatureVerified=true、distributionReady=false；只构建/静态验签，不安装或启动生产应用，不表示真实系统解锁验收。 |
| 静态、工作流、lint | `python3 -B scripts/quality_gate.py --profile static --format json` **passed**，含 174 项脚本回归、高风险与敏感日志候选均 0；`python3 -B scripts/check_workflow.py`、`git diff --check` 与本次 14 份 Swift 文件的严格局部 SwiftLint **passed**。最终文档编辑后重跑静态与引用检查。 |
| 输入与环境 | source-before-regression.json / source-after-regression.json 的 196 份 Domain 源码与测试摘要一致；macOS 26.6.2 arm64、Xcode 26.6、Swift 6.3.3、Python 3.9.6。无性能预算声明。 |
| 指定复核 | 当前工具无 Cursor verifier 入口，**blocked / 未执行，整体 partial**。没有重查登录、改认证或用其他代理/主代理自查替代。 |

测试构建日志仍有既有原生测试的 Swift 6 actor、Sendable 和旧可访问性 API 警告；本次未修改其规则或扩大修复。静态与定向证据不代表整树 Swift 门禁、原生 UI、真实数据库/权限/服务、安装或发行通过。不运行会启动无关原生交互的全量 auto / swift profile；真实数据接入仍未完成。

#### 停止点与后续建议

2B 到此停止：真实数据接入、生产 UI、全局聚合/排序/评分、父子视觉归组和指令执行均未完成，未安装或发布。下一提供者建议是**习惯定义的注入快照提供者**，先讨论区间内应执行日存在性、暂停/启停历史完整性、显式 occurrenceDay 的完成态，以及不适用条件对混合范围的反馈；不在本次实现。子任务遗留的页面 priority 表达与 boardDate＋自身 done 矛盾判定亦须先定界讨论。

### 9.16 阶段 2B-R：父级页面条件与按类型可满足性

#### 2026-10-01 已确认目标（实施前登记，不等于产品行为或验收通过）

本次只修正既有查询契约与 todo/subtask 注入快照提供者。保留 2B、前阶段及指定 Cursor verifier 的验收缺口；不重查认证，不实现习惯提供者、生产 UI、真实仓储或指令执行。

- 矛盾按对象和字段绑定判断：父任务未完成与子任务已完成可并存；同一对象同一完成字段 open AND done 才矛盾。父级页面日期隐含的父完成条件不能替代子完成条件。
- 页面优先级使用独立类型化谓词，todo 查自身、subtask 查父任务；文本 `!p1` 始终为自身 priority，子任务不适用。保留原 `BoardSearch.subtaskHits` 的 `isHighPriorityOnly` 排除子任务特例，明确 P1/P2/P3/P4 沿父任务筛选；不以 origin 临时换字段含义。页面映射、投影、编辑、用户维度接管、删除抑制及转交冻结须一致。
- 结构错误（含重复条件身份）全局拒绝；静态语义按请求类型分别分析。请求类型与仍可能匹配类型分开保留，不因 todo 矛盾让整个 `/tasks` 失效。字段不适用、逻辑矛盾、缺执行日独立报告，原始条件、来源、ID 和文本范围不变。
- 未能静态证明的组合留给提供者；暂未支持求值、缺辅助数据及歧义记录身份不包装成无结果。文本 date 继续沿 §9.8 的统一业务窗口交集；习惯页面的应执行日投影不与该窗口或完成字段直接类比，习惯完成态仍需显式执行日，不从 date 推导。
- 提供者继续完整检查条件与输入能力，返回类型化状态及理由；零 matches 不能代表结构有效、全类型覆盖或完整求值。未来习惯提供者的排程、skip 及历史完整性仍需另行讨论。


#### 2B-R 实际接口与兼容变化

| 入口 | 本轮职责 |
|---|---|
| [ContentQueryTypeAnalysis.swift](../AreaChain/Domain/ContentQueryTypeAnalysis.swift) — `ContentQueryTypeAnalysis / TypeAssessment / TypeReason`、`ContentQueryTypeValidation.analyze` | 对 composition 的请求类型逐一返回 reasons；possibleTypes 只排除已证明矛盾或字段不适用的类型。缺执行日和分析超限保留为未知；不包含提供者存在性或记录命中声明。 |
| [ContentQueryScope.swift](../AreaChain/Domain/ContentQueryScope.swift) — `ContentQueryApplicability.pageBinding` | 页面谓词按对象类型绑定自身/父级字段或 typeNeutral；中性仅用于已有 ItemsListing 的分类型状态规则，不把不适用转为 true。 |
| [ContentQueryCondition.swift](../AreaChain/Domain/ContentQueryCondition.swift) — `taskPriority(ContentQueryPagePriority)` | scope 与 highPriorityOnly 分别保存 BoardFilter 原输入。todo 查自身 Classification；subtask 查父 priority，且保留 highPriorityOnly 排除子项的旧特例。明确 highPriorityOnly scope 与原 Bool 即使人工构造不一致也不互相覆盖。 |
| [ContentQuerySession.swift](../AreaChain/Domain/ContentQuerySession.swift) — `isStructurallyValid / typeAnalysis / isReady` | 结构有效、按类型可行性独立暴露；兼容 isReady 为结构有效且存在静态可能类型，绝不代表缺执行日已解决或提供者完整求值。composition 的原显式范围/类型筛选语义保留，静态分析不改它或条件数组。 |
| [ContentQueryValidation.swift](../AreaChain/Domain/ContentQueryValidation.swift)、[ContentQueryConditionValidation.swift](../AreaChain/Domain/ContentQueryConditionValidation.swift) | 解析及条件诊断只处理结构、范围冲突和重复提示；重复条件 ID 为全局 ambiguousConditionIDs。原布尔/标量/区间可满足性算法由类型分析复用，语义矛盾及分析超限移至类型 reasons，不再充当解析失败。 |
| [TodoQueryRead.swift](../AreaChain/Domain/TodoQueryRead.swift)、[SubtaskQueryRead.swift](../AreaChain/Domain/SubtaskQueryRead.swift) | Response 增加完整 typeAnalysis；queryIsValid 明确只表示结构有效。ReadState 增加 unsatisfiable、inapplicableConditions、requiresInput，保留 invalidQuery / notApplicable / blocked / evaluated。真实消费者为 Domain 测试，已同步迁移；无生产 UI 接线。 |

静态 constraints 仅在相同绑定上共用原 AND/OR 算法：todo 页面完成态与自身 status 共用 ownCompletion；subtask 分为 parentCompletion 与 ownCompletion；文本 priority 和页面 taskPriority 在 todo 绑定自身，在 subtask 分别为不适用与 parentPriority。页面 overdue/upcoming 对 todo/subtask 展开为相应任务未完成及安排日窗口，today/recent 为日期窗口；自身 created 始终独立。routine 页面日期不做排程推断；todoStatus 在 routine 上仍为原有中性谓词。无标签与 taskOrSubtask 标签在 todo 上不再误判冲突（可以是父无标签、子有标签），独立子结果仍按自身标签判断。

页面优先级与文本 priority 共享“用户接管维度”，但不共享字段语义。输入 `!p1` 会接管并移除自动/转交父级优先级；它不能无损投影成旧页面筛选，因此列入 extendedConditions，页面筛选事件要求回查询编辑。显式 editCondition 可以将它转换为页面谓词并保留条件 ID；刷新/删除抑制/离页访问寿命/转交冻结继续复用原 Reducer，无新语法或平行状态。

响应判定顺序为结构非法 → 范围/删除策略不适用 → 当前类型静态拒绝 → 提供者能力与输入 → 完整匹配。静态理由可同时有多类；状态优先 contradiction、fieldNotApplicable、requiresOccurrenceDay，全部理由仍可查。analysisLimit 不证明无解，提供者仍逐条完整求值。blocked 继续表示缺标签表/子快照、图片关联或不支持日期组合；evaluated 带记录诊断仍非完整。coveredTypes 沿原提供者承担范围，requestedTypes 不因静态排除收窄，isPartialTypeCoverage 不变；isCompleteForCoveredTypes 仍须 evaluated 且无输入诊断。仅 todo 或 subtask 的完成求值不能证明 `/tasks` 完整覆盖。

#### 修正范围与未来习惯提供者

已实现的修正目标：父级页面优先级具备类型化表达；父页面完成/安排日与子完成态分开；混合类型矛盾不全局拒绝；字段不适用、逻辑矛盾、缺执行日与能力缺失分别表达。原始 source、条件 ID、origin 和 UTF-16 范围在只读分析/提供者中不改写。

保留：2B 的指定 Cursor verifier 复核、历史全量/原生验收缺口、生产适配、真实库/隐私、聚合/排序、图片关联及非既有 agenda 日期能力；没有实现习惯提供者或决定 skip。未来习惯提供者仍须先明确统一查询日期窗口内应执行日存在性、启停/暂停历史完整性、显式 occurrenceDay 及其与窗口关系、重复 checks 与 skip 口径、请求类型与实际提供者覆盖。analyze 的 occurrenceDay 只支持调用方显式传入，Session 本轮没有自动选择日期或扫描排程的路径。

#### 2B-R 验证与交接（2026-10-01）

证据位于忽略目录 `build/QueryTypeQA/`。仅合成快照，无生产数据读取或写入。

| 检查 | 实际结果与边界 |
|---|---|
| 回归先行与初始阻塞 | 修改生产代码前加入父逾期＋子 done 回归并运行原 build.sh 定向入口；当时被并行 `SettingsToggleConsumerTests.swift:207` 的闭包编译错误阻断，**未取得修正前该回归运行失败的证据**。旧误判已沿原 `pageConflicts` / Session / Provider 代码确认；reproduce.log 保留编译失败，不冒充业务复现通过。 |
| 首轮隔离与失败修正 | 临时 xcconfig 仅排除上述无关原生测试编译，10 项新测试中类型分析 6 项及状态寿命 2 项通过，2 项优先级夹具失败：父标题没有查询词，按完整条件正确不命中。修正合成标题，未删除或放宽断言。Xcode 在失败后写系统诊断归档因磁盘不足 exit 251；已保存 isolated-test-output.log，仅移除本轮未完成系统日志归档。 |
| 隔离领域回归 | 34 套测试 **276 passed / 0 failed / 0 skipped**，参数化共 **317 passed**；Regression.xcresult、regression-summary.json、regression-tests.json。直接复用 build.sh 的原测试参数及构建锁，额外关闭失败系统诊断采集；这是隔离证据，不代表原生套件通过。 |
| **最终普通入口回归** | 并行编译问题解除后，撤去源码排除，实际执行 `./scripts/build.sh test` 加 final-command.json 的 34 套过滤，**276 passed / 0 failed / 0 skipped**，参数化共 **317 passed**。final-regression.log、final-summary.json、final-tests.json；原结果为 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_19-01-14-+0800.xcresult`。包括 10 项新增测试、解析/条件/页面/Session、查询与指令转交、路径解析、两个提供者及日期/分类/列表/旧搜索回归。 |
| 最终源码对应 | source-before-final.json / source-after-final.json 的 Domain 源码与 Domain 测试摘要一致；最终普通回归包含最后补充的父安排日＋父完成状态证据，之后没有修改 Swift。 |
| Debug 构建 | 最终相关编辑后执行 `./scripts/build.sh`；结果见 final-build.log，仅构建/静态验签，不安装或启动生产应用。 |
| 静态与代码规范 | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check` 和受影响 ContentQuery/TodoQuery/SubtaskQuery 源码与测试的严格局部 SwiftLint；文档最后编辑后重跑。静态门禁包含 174 项脚本回归，无新增检查器或脚本接口。 |
| 指定复核与历史缺口 | 当前无 Cursor verifier 可调用入口，**blocked / 未执行，阶段整体 partial**。不检查登录、不改认证、不以主代理自查或其他代理替代。旧阶段验收、整树 Swift 门禁及原生/真实库/权限/外部服务缺口保留。 |

最终普通回归无源码排除；前面的临时隔离方式已不再作为唯一证据。构建日志仍有既有多架构目的地选择、原生测试 actor/旧可访问性 API 警告，不属于本轮修改范围。环境为 macOS 26.6.2 arm64 / Xcode 26.6；未声明性能预算、低版本真机兼容或生产行为验收。本轮保留并行设置界面及其测试/文档修改，未提交、推送、安装、发布或启动生产应用，到 2B-R 停止。

**最终收尾结果：** final-build.log 为 passed，staticSignatureVerified=true、distributionReady=false；final-static-gate.json 为 passed（174 项脚本回归，高风险/敏感日志候选均 0），final-workflow.log、final-lint.log 与 git diff --check 全部通过。Domain 源码/测试摘要与最终普通回归保持一致。指定复核缺口不变。

### 9.17 阶段 2C-1：习惯执行日、历史证据与只读状态契约

#### 2026-10-01 增量确认目标（实施前登记）

本阶段只增加纯领域语法、类型分析、注入快照归并与合成历史证据组合，不实现 RoutineQueryProvider、打卡写入、真实仓储、生产 UI、历史持久化、迁移、回填或修复。完成后停在 2C-1。工作区已有 2B/2B-R 查询和设置界面的并行改动，保留；前阶段 partial、指定 Cursor verifier 与历史验收缺口不自动关闭，不重复登录检查。

- **日期窗口**：无 date 查定义，不隐含今天应执行；当前启停及范围规则仍适用，“下一次安排”仅为展示参考。有 date 时先将所有 date 条件按组内并集、组间交集形成最终窗口，再判断是否存在有效应执行日，每个定义只返回一次。完成或跳过不删除原应执行日；逾期页面仍走旧闭合投影。
- **启停与历史**：创建前不应执行；当前星期、停用状态及暂停字段不等于完整历史，不能套到全部过去日期。窗口内一个可靠应执行日即可证明存在；只有全部相关日期确定不适用才证明不存在；其余报告历史不足。证据必须注明适用区间及来源性质，未覆盖日期保持可识别；调用方声明不证明数据库已核实。
- **状态**：done 为明确完成且无冲突；skipped 为明确跳过且未完成；open 为当天确认应执行、未完成且未跳过。非应执行日不入这三个状态；定义状态必须有明确执行日。新读取语义不改变旧完成、跳过、重开写入。
- **记录身份与冲突**：业务键为习惯 UUID＋执行日；完全相同状态可归并但标重复；不同状态以及单条 done＋skipped 均报冲突，不能 first/last-wins。问题只影响对应习惯和日期，不阻断其他可判断对象。完整无记录、未提供完整数据、已有未处理记录必须分开；无记录不能单独推出 open。完整性需限定习惯及覆盖日期/区间。
- **执行日语法**：新增 `on:yyyy-MM-dd` / `on:today`，中文别名“执行日”；只接单日，与 date 独立。`/routines on:today status:skipped` 合法；`date:today status:done` 仍要求 on。多个不同 on、借 OR 提供多个执行日均诊断，不取最后值。同时有 date/on 时 on 必须在最终 date 窗口；on 仅适用于习惯定义/执行记录。选中记录日以后可预填操作，本阶段不创建或执行操作。
- **类型分析**：todo/subtask 不支持 skipped 或 on，不能把 skipped 当 done=false；混合类型保留习惯可能性。普通状态、页面分类型状态和父级状态分别绑定；同一对象互斥状态仍矛盾。

实施前沿源码确认的缺失：ContentQueryStatus 仅 open/done；Atom/Dimension 无 on；AtomParser 对 on 与 skipped 报 invalidCondition；Applicability 仅按维度，todo/subtask matcher 用 `isDone == (status == .done)`；TypeValidation 的 occurrenceDay 仅由调用方参数提供，Session 无执行日。CheckSnapshot 无完整性/重复诊断，RoutineSnapshot 仅当前定义，旧 DayBoardCheckIndex first-wins 与 AgendaOpenDays 任一闭合不能当新搜索归并接口。以上是旧结构缺失记录，不要求旧代码支持尚未实现的新语法。

#### 2C-1 实际接口与语法

| 入口 | 已实现的纯领域责任 |
|---|---|
| [ContentQuery.swift](../AreaChain/Domain/ContentQuery.swift)、[AtomParser](../AreaChain/Domain/ContentQueryAtomParser.swift)、[OccurrenceDay](../AreaChain/Domain/ContentQueryOccurrenceDay.swift) | `ContentQueryAtom.on(String)` / dimension `.on` 与 `.status(.skipped)`；`ContentQueryOccurrenceDay.resolve` 区分 unspecified / selected / invalid。沿原 Lexer 保留原文与 UTF-16 位置，不新建词法器；today/今天仍由原 Dates 和注入 Calendar 解析。 |
| [Validation](../AreaChain/Domain/ContentQueryValidation.swift)、[ConditionValidation](../AreaChain/Domain/ContentQueryConditionValidation.swift) | on 缺值、不完整、非法日期、区间分别保留诊断。`occurrenceDayMustBeSingle` 拒绝区间（两端相同也拒绝）；`multipleOccurrenceDaysInGroup` 拒绝不同执行日 OR，即使外层条件会收窄仍拒绝；`conflictingOccurrenceDays` 拒绝不同 on。相同 on 原样保留并提示 duplicateCondition，同日 OR 可保留。结构化条件同样受约束。 |
| [Scope / Applicability](../AreaChain/Domain/ContentQueryScope.swift)、[TypeAnalysis](../AreaChain/Domain/ContentQueryTypeAnalysis.swift) | 新增按原子 `binding(for:to:occurrenceDay:)`，todo/subtask 的 skipped 不适用，包含 skipped 的 OR 也不能绕过；on 仅 routine/routineOccurrence 适用。Session 自动从有效条件取得 on；旧显式 occurrenceDay 参数保留，但与 on 不一致时拒绝。 |
| [Session](../AreaChain/Domain/ContentQuerySession.swift) 的 `occurrenceDay` | 读取完整 conditions（含用户、输入、页面与转交来源），没有可变的第二份执行日。`.on` 不接管 `.date`；原 reducer、页面投影和 handoff 无须新分支，on 留在 extended 条件，不能压成旧 BoardFilter。 |
| [ContentQueryDateWindow](../AreaChain/Domain/ContentQueryDateWindow.swift) | `resolve(_:dates:)` 把 date 条件化为规范区间并集及交集，返回 unconstrained / window / invalid。window 可为空；没有 date 与空窗口不同。明确排除 created、on 和 page.boardDate；不按年份跨度枚举。 |

同步的旧读取消费者为 [TodoQueryMatching](../AreaChain/Domain/TodoQueryMatching.swift) 和 [SubtaskQueryMatching](../AreaChain/Domain/SubtaskQueryMatching.swift)：显式拒绝 skipped/on，不能经布尔比较落入未完成。Provider 的原响应流程继续消费 Session.typeAnalysis，无新提供者分支。既有 [ContentQueryTypeAnalysisTests](../AreaChainTests/Domain/ContentQueryTypeAnalysisTests.swift) 更新缺 on 仍能识别互斥状态的断言；新增测试为 [ContentQueryOccurrenceTests](../AreaChainTests/Domain/ContentQueryOccurrenceTests.swift)、[RoutineCheckReadingTests](../AreaChainTests/Domain/RoutineCheckReadingTests.swift)、[RoutineScheduleHistoryTests](../AreaChainTests/Domain/RoutineScheduleHistoryTests.swift)、[RoutineOccurrenceIntegrationTests](../AreaChainTests/Domain/RoutineOccurrenceIntegrationTests.swift)，共同合成夹具在 [RoutineQueryTestSupport](../AreaChainTests/Domain/RoutineQueryTestSupport.swift)。文档只同步本节、组件目录、架构与技能路由，不新增流程或检查器。

实际文本为 `on:yyyy-MM-dd` / `on:today`、`执行日:yyyy-MM-dd` / `执行日:今天`，`status:skipped` / `状态:已跳过`。既有中英文 date/created/status 别名、文字/标签排除与保护区不变；未增加其他自然语言日期，也未增加生产 UI 文案或机器存储键。

定义的 date 为应执行窗口，on 为记录判断日；routineOccurrence 的 date/on 都约束该记录日。类型分析只在相应绑定里检查 on 是否落入所有 date 组的最终交集，created 和习惯 page.boardDate 不与其合并。缺 on 的定义状态保留 requiresOccurrenceDay，同时 open AND done / skipped 等互斥组合仍能证明 contradiction。页面 todoStatus 对习惯仍为 typeNeutral，routineStatus 为启停；子任务自身完成、父页面完成继续分开。旧原子维度入口供普通字段/页面绑定兼容，新值敏感消费者须使用按原子入口或完整 typeAnalysis。

#### 记录完整性、重复与冲突

[RoutineCheckReading.read](../AreaChain/Domain/RoutineCheckReading.swift) 要求 routineID、规范单日、原始 CheckSnapshot 数组、`RoutineCheckCoverage` 和日期上下文。业务身份复用 `CommandObjectReference(type: .routineOccurrence, id: routineID, dayKey: day)`；CheckSnapshot 不含记录 UUID，定位证据使用原输入下标，不虚构记录 ID。

- `RoutineCheckCoverage(routineID:completeIntervals:)` 明确限定习惯及完整区间，空数组表示未声明任何完整日期；相邻区间可合并，区间缺口不能继承完整性。`covers(_:calendar:)` 可检查单日或整个区间。这是调用方输入承诺，没有数据库查证。
- `RoutineCheckRead.state` 为 completed / skipped / unprocessed / absent / incomplete / conflict / invalidInput；`observedState` 仅说明已提供行，不代表完整最终状态。即使已有完成/跳过行，未完整提供时也返回 incomplete，避免漏掉尚未提供的冲突；已观察到冲突则直接 conflict。
- 相同 `(isDone, isSkipped)` 的多条记录只给一个读取结果，保留所有 inputIndices 并报 identicalDuplicates；状态不同报 conflictingRecords；任一行 done＋skipped 报 doneAndSkipped。两类冲突都不挑首尾，不进入确定状态匹配。
- 规范但属于其他习惯/日期的冲突不影响当前请求。请求日、覆盖范围或覆盖习惯非法时拒绝；同习惯注入非规范记录日时以 invalidRecordDay 和下标拒绝，不能归一化、丢弃后声称完整无记录。非法日期无法可靠定位其执行日，因此拒绝该习惯的此次输入；其他习惯不受影响。
- absent 只证明在调用方声明完整的范围里未提供该业务键；必须再有可靠应执行日才可组合为 open。unprocessed 与 absent 的记录事实保持可区分。

#### 历史证据与纯组合

[RoutineScheduleEvidence / RoutineScheduleHistory](../AreaChain/Domain/RoutineScheduleEvidence.swift) 不持久化历史。每份证据具备 routineID、闭区间、weekdays(mask) 或 notScheduled 规则，以及 currentDefinition(observedOn)、recordedSchedule(reference)、synthetic(reference) 来源。历史引用只标来源性质及关联，真实性由后续映射者负责；不能将任意调用方声明宣传成已还原历史。

`currentDefinition(_:observedOn:)` 只生成明确观察当日的证据，复用现有 WeekdayMask 清理和星期规则；调用方须保证快照确实对应该观察日。该来源不允许覆盖多日；不会根据 pausedOnDayKey 推算历次启停。一般历史规则须有非空来源引用和有效区间/掩码；当前状态、未来日期和未提供历史均无自动回填。存活/删除与范围资格由后续提供者处理，不能从当前 deletedAt 推测历史删除区间。

`history.day(_:)` 返回 scheduled / notScheduled / unknown / invalidInput，保留原因和原证据下标。创建前为 notScheduled；创建日以后无证据为 missingHistory；重叠证据在该日判断一致可用，相反则 unknown(conflictingEvidence)。无关习惯证据不连坐。创建日和同习惯证据须先合法；非法证据不是历史未知或零命中。

[RoutineQueryEvaluation.swift](../AreaChain/Domain/RoutineQueryEvaluation.swift) 提供两个窄组合入口：

- `history.existence(in:)` 对一个定义返回一个存在性结果：有可靠应执行日为 matches 并给 witnessDay；全窗口确定无安排为 doesNotMatch；无命中而存在未知为 unknown。按查询/创建/证据边界分段，每段最多检查七个星期位，不建设时间线数据库。`intervalsContainingUnknownDays` 表示该段至少含一个未知日，精确日期继续调用 day；即使存在性成立也保留未知片段。
- `RoutineOccurrenceEvaluation(schedule:records:)` 必须接同一 CommandObjectReference。应执行＋完整 absent/unprocessed 为 open，completed 为 done，skipped 为 skipped；非应执行日全部正常状态不匹配，历史未知或不完整记录保持 unknown，冲突保持 conflict（matching 返回 unknown，详细原因仍在 records）。非法输入/身份不一致拒绝。该类型不持有操作或保存能力。

#### 旧行为保持与 2C-2 输入要求

旧 BoardSearch、DayBoardLogic、DayBoardCheckIndex、AgendaProjection、AgendaOpenDays、WeekdayMask、DayKey 和 SwiftDataRoutineRepository 未接入新归并器。旧看板继续 first-wins；逾期继续任一完成或跳过即闭合；旧写入 `isDone=true && isSkipped=true` 仍保持原样，在新搜索读取中按本次确认规则报冲突。本阶段不合并、删除或修复真实记录；不把新状态解释反向传播到看板、连击、通知、完成/跳过/重开写入。

2C-2 必须继续提供完整 Session 有效条件及来源/ID、composition、queryDates；结构诊断和每种请求类型的分析不能被空结果替代。习惯定义状态需 selected on，不能借 date:today 或显示日期补默认值。读取须注入真实形状的 RoutineSnapshot、按业务键可定位的全部相关 CheckSnapshot、对应 routineID 与覆盖区间的完整性声明，以及有来源/区间的排程证据；裸 isEnabled、weekdayMask、pausedOnDayKey 或布尔“历史完整”不够。

后续提供者还需独立处理：定义身份重复、真实历史来源映射及缺失反馈、删除/启停与有日期范围资格、date 窗口与 on 的整体条件匹配、页面逾期旧投影、完整条件/匹配依据、请求与覆盖类型、结果身份去重及未知/冲突诊断展示。无 date 按当前启停和范围查定义，不隐藏筛今天；下一次安排只作参考。2C-1 每次存在性调用只处理一个定义，未实现提供者集合去重、真实数据适配、聚合排序、生产 UI 或操作预填/执行。

#### 验证状态与保留缺口

本轮证据目录为 `build/RoutineContractQA/`，全部夹具为合成数据。首轮 5 套定向测试 35 passed / 0 failed / 0 skipped；随后补充非法记录日拒绝及按原子适用性断言，最终证据以下方收尾记录为准，不把首轮结果当最终结果。

指定 Cursor verifier 在本次工具清单仍无可调用入口，**blocked / 未执行，阶段整体 partial**；未检查登录或改认证，也没有以测试、主代理自查或其他代理冒充指定复核。期间外部提交推进至 `482a831`，另出现隐私设置及其测试的并行改动，保留。本代理未提交、推送、安装、发布或启动生产应用，未访问真实用户库；不进入 2C-2，旧阶段验收记录和缺口保留。

**最终源码的本地证据（2026-10-01）：**

| 验证 | 实际结果与可证明范围 |
|---|---|
| 完整定向回归 | `./scripts/build.sh test` 加 `regression-command.json` 中 40 套过滤，**318 passed / 0 failed / 0 skipped**；结果树核实 40 个 suite 均 Passed。包括 30 项新测试及原查询/页面/父级/转交、todo/subtask、日期/星期/分类/列表、旧 BoardSearch/DayBoard/Agenda 回归。 |
| 测试产物 | `build/RoutineContractQA/regression.log`、`regression-summary.json`、`regression-tests.json`；原结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_19-37-44-+0800.xcresult`。`source-before-regression.json` / `source-after-regression.json` 的 Domain 源码及 Domain 测试摘要一致。 |
| Debug 构建/静态验签 | `./scripts/build.sh` **passed**，`build/RoutineContractQA/build.log`；先遵守已有构建锁等待并行任务，取得锁后正常构建。staticSignatureVerified=true、distributionReady=false；没有安装、启动生产应用或写 Apple 端资源。 |
| 局部 SwiftLint | `lint-command.json` 对本次 14 份 Domain 源码和 6 份 Domain 测试/夹具运行 `swiftlint lint --strict --quiet`，**passed / 0 违规**，`lint.log`。 |
| 工作流与质量门禁 | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check` **passed**；static-gate.json 含 **174 项脚本回归通过**，高风险/敏感日志候选均 0；最终文档编辑后重跑受影响检查。 |
| 兼容边界 | 开工/收尾哈希核对 DayBoardLogic、DayBoardCheckIndex、AgendaProjection、AgendaOpenDays、BoardSearch、WeekdayMask、DayKey 与 SwiftDataRoutineRepository 内容一致；旧规则另有真实定向运行证据，不仅凭未改文件下结论。新状态归并接口只由合成领域测试调用。 |
| 未运行/未完成 | 全量 auto / swift 门禁、无关原生 UI 套件、真实库/历史映射、系统认证、安装发布及指定 Cursor verifier 均未运行；定向检查不覆盖旧阶段这些缺口。指定复核 **blocked / 未执行**，整体 **partial**，停在 2C-1。 |

环境实际为 macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3、Python 3.9.6。测试构建仍有既有原生测试 actor、旧可访问性 API 与多架构目的地选择警告，未在此阶段清理；未声明低版本真机兼容、生产性能预算或真实历史完整性已验证。

### 9.18 阶段 2C-2：习惯定义只读快照提供者

本轮仅开发注入快照的纯领域提供者，停在 2C-2；2C-1 与前阶段的指定 Cursor verifier、历史验收缺口继续保留。没有真实仓储、生产 UI、记录修复、操作日期预填或指令执行接线。开工已有 2B-R/2C-1 与隐私设置改动，期间新增的 Stepper 测试等并行成果均保留，不计入本阶段。

#### 输入、复用与结果

| 接口 | 契约与实际消费者 |
|---|---|
| [RoutineQueryProvider.read](../AreaChain/Domain/RoutineQueryProvider.swift) | 只消费 requestID、完整 ContentQuerySession、RoutineSnapshot 数组、可选标签名字表、CheckSnapshot 数组、RoutineCheckCoverage 数组及 RoutineScheduleEvidence 数组。返回 live routine 定义，按输入顺序，不展开每日记录、不全局排名。实际消费者仅下面四套 Domain 测试。 |
| [RoutineQueryRequest / Response / Match / Diagnostic](../AreaChain/Domain/RoutineQueryRead.swift) | 复用 CommandObjectReference、TodoQueryReadState、ContentQueryTypeAnalysis 和 ContentQueryMatchEvidence；独立表达 routine 类型覆盖、undeterminedObjects、诊断严重度与 affectsDetermination。标题、备注每个结果各一份；request/response/match 的 description/debugDescription 脱敏。 |
| [RoutineQueryMatching](../AreaChain/Domain/RoutineQueryMatching.swift) | 使用 Session.conditions、composition、queryDates、occurrenceDay，不重解析 input.source；页面、用户及 handoff 冻结条件全部参与。直接复用 ContentQuerySnapshotMatching/Validation、History.existence 和 OccurrenceEvaluation；没有第二套文字、记录归并或历史存在性算法。 |
| [RoutineQueryPageRules](../AreaChain/Domain/RoutineQueryPageRules.swift) | 有界完整性检查后委托 Classification、ItemsListing、AgendaProjection；旧投影和新状态分开求值。完整性声明只按同 routineID 合并区间，不跨习惯借用。 |

辅助输入按条件读取：普通标题/备注查询不需要历史、打卡或标签名字表；稳定标签 ID 查询不需要名字表。文本标签需要名字表及自身关联名字；缺少关联名字仅使该对象相关条件未知。date 需要覆盖相关窗口的可靠排程证据；on 需要当天排程证据，status 还需要当天完整记录。单独 on 只约束当天应执行，可以在记录不完整时匹配，其记录读取状态与非决定性诊断仍保留。未声明完整性的空 checks 不是完整无记录。

身份为 routine＋UUID；重复定义 ID（包括已删除的同 ID 定义）全部隔离，诊断保留输入下标，不 first-wins。活定义的 createdDayKey 与 createdAt 使用现有校验，不补造时间。其他习惯的非法证据/覆盖不会污染当前对象；没有修复或归一化原始快照。辅助数据的来源始终只是调用方声明。

#### 支持条件与诊断

- global/tasks 默认启用定义；routines 包含启用与停用，显式 routineStatus/contentTypes 等继续沿 composition 与原类型分析求交。回收站和 routineOccurrence 独立结果为 notApplicable。
- 标题/备注 AND、括号 OR、短语、排除及 Unicode 原文 UTF-16 范围；标签名字/稳定 ID 只查自身；noTags、priority/taskPriority、reminder/reminderPresence、sourceApplication、created、itemKind、todoStatus 中性与 routineStatus 复用原规则。created 查真实 createdAt，启停查当前定义状态。
- has:image 没有可靠关联输入，报告 imageAssociationUnavailable；listedDay 无法唯一确定行日的组合报告 unsupportedListedDay，非 overdue/upcoming 的 agenda 报 unsupportedAgendaDate。能力缺口即使没有候选对象也会报告；不静默放宽。请求级能力诊断本身不假定某个对象未知，实际影响由对象求值决定。
- 响应区分 invalidQuery、notApplicable、unsatisfiable、inapplicableConditions、requiresInput、blocked（非法日期上下文）和 evaluated。evaluated 仅说明执行了对象求值，不表示所有对象确定或覆盖全部请求类型。
- 条件全部读取后再组合：AND 有确定不匹配即可排除，其他条件错误仍报告；无确定失败但有未知则列入 undeterminedObjects。OR 有确定匹配即可成立，其余分支诊断保留。相同重复记录是 warning，不单独造成未知；冲突、缺覆盖和历史不足分别保留原因。类型/条件身份错误在进入对象匹配前拒绝。
- isCompleteForCoveredTypes 仅表示当前注入候选在 routine 覆盖内已确定（state=evaluated、无未知对象且无影响确定性的诊断）；并不证明全局数据已读全、真实来源可靠或其他类型已覆盖。已知不匹配可消解结果不确定性，不会删除错误诊断。有未知对象的零 matches 不是完整无结果。

#### 日期、执行日与旧页面边界

date 经 ContentQueryDateWindow 得到最终并/交窗口，再调用 history.existence；已有可靠见证日即可命中一个定义，即使其他片段未知。无见证且有未知则对象未确定，全窗口可靠无安排才不匹配；创建前排除，currentDefinition 只覆盖观察日。结果 dateExistence 保留 witnessDay、含未知日的区间与原因；该见证仅证明存在，不是选中的操作日期。新增 unknownReasons 是原存在性算法内的最小证据扩展，不新建遍历算法；missingHistory 与 conflictingEvidence 可区分。

on 通过 ContentQueryOccurrenceDay 取得明确日，使用 History.day + CheckReading + RoutineOccurrenceEvaluation；on 指当天应执行，不能仅凭任意打卡入围。done/skipped/open 分开；可靠应执行且完整 absent/unprocessed 才推出 open。冲突重复、done+skipped、不完整输入不会变成 false/open；相同重复可以确定但有警告。缺 on 不补 today，date 不代替 on，date/on 的窗口关系沿原类型分析。日期见证与 occurrence.records.object.dayKey 分开保存。

页面 boardDate 的支持边界：

| evaluation | 本阶段支持与前提 |
|---|---|
| items | all/today/recent/upcoming/overdue 全部委托 ItemsListing；overdue 在创建日至页面 yesterday 需要完整 checks 声明。它使用旧当前排程投影，不要求新历史证据。 |
| agenda | overdue/upcoming 委托 AgendaProjection；overdue 需要上述完整区间，保留“任一完成或跳过即闭合”。非法记录日/覆盖显式诊断。 |
| listedDay | all 不额外筛日期；today 以页面 todayKey 唯一确定行日，复用 DayBoardLogic、DayBoardCheckIndex 和 Classification。today 日期条件不依赖闭合状态，因此不要求打卡完整声明。其他 scope 缺独立行日期输入，明确不支持；不借 on、date 或下一次安排补造。 |

没有修改旧看板 first-wins、新旧状态之间的差异或任何 skip/完成写入。页面投影的命中 field 为 legacyPageProjection，新状态为 completion/occurrenceDay；页面和显式 on/status 分别求值，旧投影不能吞掉新记录冲突诊断。ContentQueryMatchField 只追加 routineEnabled/scheduleExistence/occurrenceDay/legacyPageProjection；todo/subtask 原字段不变。ItemsListing 两处已有 Calendar 参数显式传给 isRoutineDue，避免新读取路径使用系统当前 Calendar；默认调用仍用原默认参数，排序与业务规则不变。RoutineScheduleEvidence 的描述新增脱敏，不打印 reference。

#### 本轮验证与后续适配

新增 [RoutineQueryProviderTests](../AreaChainTests/Domain/RoutineQueryProviderTests.swift)、[RoutineQueryTemporalTests](../AreaChainTests/Domain/RoutineQueryTemporalTests.swift)、[RoutineQueryPageTests](../AreaChainTests/Domain/RoutineQueryPageTests.swift)、[RoutineQueryBoundaryTests](../AreaChainTests/Domain/RoutineQueryBoundaryTests.swift)，共 24 项。覆盖注入链路、页面默认/用户接管/冻结、默认启停、Unicode/字段、最终窗口/见证/未知/冲突、状态矩阵、身份和跨习惯隔离、能力及脱敏。BoardSearch 对照仅选双方相同的启用定义文字查询；新历史/on/skipped 不要求旧算法一致。旧 first-wins 与 Agenda 任一闭合另作明确差异断言。

最终定向命令见忽略目录 `build/RoutineProviderQA/regression-command.json`，实际为 `./scripts/build.sh test` 加 44 套过滤：**342 passed / 0 failed / 0 skipped**，涵盖原 40 套查询、todo/subtask、2C-1、日期、分类、列表、旧看板/Agenda、转交回归。结果包为 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_20-24-21-+0800.xcresult`，汇总与结果树为 `regression-summary.json` / `regression-tests.json`。仅合成数据，无真实库读取。早期失败为测试夹具的 OR/范围写法和必填页面日期，已修正，不改变解析契约或弱化断言。

Debug 构建、最终静态/工作流门禁与严格局部 lint 的收尾结果另见本节后续记录。指定 Cursor verifier **blocked / 未执行，阶段整体 partial**：没有可调用的指定入口，不重复登录检查、不改认证、不以主代理自查或其他代理冒充。旧阶段、整树原生/真实库/权限验收缺口保留；本轮没有安装、发布、提交、推送或启动生产应用，也没有性能改善声明。

后续建议独立讨论手记定义快照提供者：先明确私密正文可见性的输入投影、标签/附件关联完整性及日期字段，再授权实施。习惯真实适配另需决定真实历史来源如何映射为有界证据、哪些区间可声明完整、如何表达缺口与冲突、listedDay 缺失行日期如何传入；不能从当前 weekdayMask/pausedOnDayKey 或偶然 checks 推断全部历史。本阶段没有执行这些后续工作。

**2C-2 最终收尾证据（2026-10-01）：** `./scripts/build.sh` passed（`build/RoutineProviderQA/build.log`，staticSignatureVerified=true、distributionReady=false）；44 个 suite 在结果树均 Passed。`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 174 项脚本回归，高风险/敏感日志候选均 0；`python3 -B scripts/check_workflow.py`、受影响 RoutineQuery/RoutineScheduleEvidence/ItemsListing/TodoQueryRead 与新测试的严格局部 SwiftLint、`git diff --check` 均通过。最后仅编辑文档并重跑静态/工作流/差异检查，最终领域回归后未修改 Swift。环境为 macOS 26.6.2 arm64 / Xcode 26.6；构建保留既有原生测试 actor、旧可访问性 API 及多架构目的地警告，不属于本轮清理范围。指定复核 blocked / 未执行、整体 partial 不变；不运行全量 auto/swift profile 或生产/真实数据验收，不进入下一阶段。

### 9.19 阶段 2D：手记只读快照提供者

仅开发注入快照与完整查询的同步纯值读取，活 diary 为唯一返回类型。保留开工时 2B-R / 2C、隐私设置与 Stepper 的并行修改，不接生产 UI、真实仓储、附件提供者或指令执行，不读取真实手记、标签、钥匙串，不调用解密、认证或隐私写入。正文不可读新规则已先登记在本文第 1 节。本轮开发授权不等于前阶段验收，指定复核及历史缺口不关闭。

#### 核心接口与辅助事实

| 接口 | 输入输出与复用 |
|---|---|
| [DiaryQueryProvider.read](../AreaChain/Domain/DiaryQueryProvider.swift) | requestID、完整 ContentQuerySession、DiarySnapshot 数组、DiaryQueryMetadata、Locale → DiaryQueryResponse。唯一消费者是五套 DiaryQuery Domain 测试；保持输入顺序，不按置顶排序。 |
| [DiaryQueryRequest / Metadata / Response](../AreaChain/Domain/DiaryQueryRead.swift) | 名字字典及私密标签 ID 集合分别为可选值，nil 表示未提供，空集合表示已提供空事实。结果含覆盖、类型分析、请求/条件诊断、确定匹配和 undeterminedObjects；请求标识不是授权票据或数据库代次。 |
| [DiaryQueryMatching](../AreaChain/Domain/DiaryQueryMatching.swift) | 只读取 Session.conditions/composition/queryDates；复用 ContentQuerySnapshotMatching / Validation、ContentQueryDates / DateWindow、TagSyntax / TagIDList。一次请求复用名字规范化与最终日期窗口；没有第二份 Parser 或万能提供者框架。 |
| [DiaryQueryEvaluation / Privacy](../AreaChain/Domain/DiaryQueryEvaluation.swift) | 局部三态组合先保留全部诊断；敏感判定调用 DiaryPrivacy，不另写敏感标签或旧标记识别。未改变已有 todo/subtask/routine 求值工具。 |
| [DiaryQueryMatch / Presentation](../AreaChain/Domain/DiaryQueryRead.swift) | diary＋UUID、归属日、真实创建时间、置顶和关联标签元数据；展示分 publicText 与 hiddenTitle。私密/不能确认公开时没有正文存储位，也完全丢弃 diaryBody 命中依据。 |

调用方必须保持 `DiarySnapshot.isPrivate` 与 `isContentAvailable` 的真实含义。已静态核对 `DiaryEntry.snapshot` 将 isPrivate / encryptedText / privacyVaultID 保护来源折入快照标志，`DiaryContent.snapshot` 读取成功填正文，失败置空并标记不可读/私密；本阶段没有调用该服务。裸占位字符串不证明正文存在，也不能通过将其标成可读来冒充真实正文。

标签名字资料须包含所给快照的关联标签，包括仍影响敏感性的已删除标签；私密 ID 集合须为同一读取上下文的完整事实。部分名字可以参与已知字段判断，但缺失关联名字不得当作没有关联。稳定 ID/noTags 仅依赖自身关联，不需要名字表；确定无关联时，结构化标签不存在可直接判定。非法 UUID 片段不能被 TagIDList 的容错解析静默变成无标签或公开记录：保留 invalidTagIDs 诊断，只在相关条件确实依赖缺失关联时未知。

可公开要求正文可读、DiaryPrivacy 未判敏感、名字表和私密集合均已提供、关联名字完整且关联格式可解释。否则隐藏；缺失敏感判定资料为独立 incompletePrivacyMetadata 诊断，只取决于元数据是否完整，不因正文中旧标记的有无改变诊断形状，也不自动使仅日期/稳定标签可决定的对象未知。输入事实不是新授权机制，提供者不核验其真实来源、不解锁，也不返回访问句柄。

#### 支持、三态与投影

- 范围：global、diaries，以及明确包含 diary 的组成，且 deletion=liveOnly。回收站及不含 diary 的范围为 notApplicable。原 contentTypes 校验只接受 todo/subtask/routine，本轮最小增加 diary；空类型、附件、标签、剪贴板和执行记录依旧拒绝。现有生产标签页类型不因此改变。
- 文字：沿 BoardSearch.matchesDiary 的正文或关联标签名语义，每个关键词可分别在适用字段成立；短语须在同一字段连续匹配，OR 与排除沿统一解析。普通、私密可读、正文不可读分别读取；isContentAvailable=false 时不搜索 text 内的任何占位文字。
- 三态：正向文字已有可读命中即匹配；没有命中且存在不可读字段为未知；字段完整且无命中才不匹配。排除条件已有命中即不匹配；字段完整且均不含才匹配，否则未知。AND 有确定不匹配即可排除，OR 有确定匹配即可入围，其余先看未知再决定。身份、敏感性和所有分支诊断保留，不因短路消失。
- 结构化标签：#标签、排除标签使用自身稳定关联和规范化名字；tagID、noTags、contentTypes 页面谓词直接消费，taskOrSubtask 对 diary 仍只看自身。关联缺名字时，已有命名标签命中仍可证明正向或排除，不必全对象阻断。
- 日期：date 按归属日，created 按真实 createdAt 经注入 Calendar 转民事日；DateWindow 保留 OR 并集/AND 交集。没有 date 不隐含今天。结果保留 isPinned 和输入顺序，不新增置顶文本语法。
- 不适用：priority、reminder、status、on 及旧任务页面的完成/启停/种类/优先级/提醒/来源/boardDate 均沿现有 Applicability/TypeAnalysis 拒绝；不虚构属性，不吞掉条件。手记页面当前默认仍只有范围与标签，显式 date 是独立合法查询条件。
- 能力缺失：has:image 的字段语义适用，但没有可靠附件关联输入，报告 imageAssociationUnavailable；受此条件影响而无法决定的对象为未知。即使没有候选也报告缺口，不能据此宣称附件能力已完成。

公开结果保存原始正文一次，正文证据位于 publicText.bodyEvidence；UTF-16 范围由既有工具在原文取得，组合重音扩展为完整字符。标签文字证据范围指向结果中同 relatedObject 的原始标签 name。metadataEvidence 不含 diaryBody；隐藏结果进一步去掉全部文字条件的依据（含标签文字命中和排除），防止 tags absence 等相关字段间接暴露某个正文排除分支是否成立。隐藏结果只有既有 `diary.private.title` 的 en/zh-Hans 标题及允许的元数据：不保存正文、片段、长度、正文范围、正文分支编号或命中次数；本阶段直接省略正文命中说明。request/response/match/presentation/metadata/tag 的 description/debugDescription 脱敏，诊断仅含枚举、身份、条件 ID 和输入下标。

#### 覆盖与旧行为差异

响应顺序保持结构非法 → 范围不适用 → 当前类型静态限制 → 日期上下文 → 对象求值。重复 UUID（包括活/删除重复）全部隔离；已删除不返回；非法日期/时间戳仅隔离该对象。对象级缺失不影响其他确定匹配。`evaluated` 仅说明已求值；coverage 表示提供者类型覆盖，severity 表示诊断严重度，affectsDetermination 与 undeterminedObjects 表示本次注入对象的结果是否未定，三者独立。

`isCompleteForCoveredTypes` 只在 evaluated、无未知对象且无影响确定性的诊断时成立，不表示真实库读取完整或全局类型覆盖。已知不匹配可消解未知对结果的影响，不能删除对应诊断；未知对象的零命中绝不是完整零结果。仅元数据已能决定的私密对象可以正常入围或排除。

旧 BoardSearch 保持不变。共同支持的关键词/关联标签子集用合成公开、私密可读、不可读快照对照命中身份和隐藏标题；旧布尔搜索把不可读且标签未命中记为 false，新提供者将该情况报告 unknown，这是明确新增反馈，不要求等价。新的短语/排除/OR、date/created、完整类型诊断及对象完整性属于统一查询契约，不反向改旧搜索。空查询仍可列出活快照，不等同旧 hits 的空输入无结果。

#### 验证、指定复核与停止点

新增 DiaryQueryProviderTests / UnknownTests / PrivacyTests / BoundaryTests / IntegrationTests 及合成夹具。覆盖跨字段、Unicode 范围、正负未知组合、标签足够证明、只读日期/标签、各敏感来源、资料缺失、占位、日期/置顶/顺序、重复/删除/坏数据、不适用/附件缺口、描述及递归存储泄漏检查、正文变化后隐藏输出等价、Parser→Session→类型→提供者、页面接管/冻结和旧共同子集。共享改动只有 contentTypes 增加 diary 及 ContentQueryMatchField 追加 diaryBody/diaryDay，既有提供者列入回归。

首轮五套新测试 23 passed / 1 failed / 0 skipped；失败指出上述旧 contentTypes 校验拒绝包含 diary 的组成，已按本次要求最小扩展并增加非法类型反例，未弱化断言。随后 49 套回归 368 passed / 0 failed / 0 skipped；主代理收尾检查进一步补强隐藏结果的文字排除依据和元数据诊断，新增正文变化后的等价断言。该检查不冒充指定复核，最终版本的重跑证据见本节收尾记录。

指定 Cursor verifier 在本次工具清单无可调用入口，**blocked / 未执行，阶段整体 partial**。不重复登录检查、不修改认证、不以其他代理或主代理自查冒充指定复核。合成测试不替代真实隐私接线验收，历史整树、原生和安全缺口保留。

下一提供者建议为独立定界的附件只读快照提供者：先明确带类型拥有者身份、唯一活父项、手记敏感元数据、删除状态与关联资料完整性，不把 filename 或孤立 ownerID 当作可见性证明。真实手记适配必须另行落实快照来源/完整性、既有可读性契约、锁定与失败后的缓存清除、异步代次淘汰、接收宿主隐私边界及独立真实安全验收；这些均未接线。本阶段完成开发验证后停止，不提交、推送、安装、发布或启动生产应用，不进入下一阶段。

**2D 最终本地证据（2026-10-01）：**

| 检查 | 实际结果与证据 |
|---|---|
| 最终定向回归 | `./scripts/build.sh test` 加 `build/DiaryProviderQA/regression-command.json` 中 49 套过滤，**370 passed / 0 failed / 0 skipped**；五套新增手记测试共 28 项，结果树核对 49 个 suite 均 Passed。含原 todo/subtask/routine、查询/类型/页面/转交、日期/标签及旧搜索回归。 |
| 结果与可追溯性 | `build/DiaryProviderQA/regression-summary.json` / `regression-tests.json` / `regression.log`；原包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_20-58-25-+0800.xcresult`。`source-before-regression.json` / `source-after-regression.json` 核对全部 Domain 源码及 Domain 测试一致，构建后再次核对未变化。 |
| Debug 构建 | 最终源码后运行 `./scripts/build.sh`，**passed**，日志 `build/DiaryProviderQA/build.log`；staticSignatureVerified=true、distributionReady=false。仅构建产物，没有安装、启动生产应用或 Apple 端资源写入。 |
| 严格局部 SwiftLint | `swiftlint lint --strict --quiet` 对 DiaryQuery 四份源码、六份测试/夹具、ContentQueryConditionValidation.swift、TodoQueryRead.swift 执行，**passed / 0 违规**。 |
| 静态/工作流/差异 | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check` **passed**。静态门禁含 **175 项脚本回归**，高风险/敏感日志候选均 0；产物 `build/DiaryProviderQA/static-gate.json` / `workflow.log`。最终仅补文档后重跑受影响门禁，不复用旧文档检查。 |
| 未执行与保留 | 指定 Cursor verifier **blocked / 未执行，整体 partial**；没有替代复核或重复认证检查。全量 auto/swift profile、无关原生 UI、真实库/隐私适配、锁定缓存/异步代次、系统认证、安装发布均未运行；本轮证据不关闭前阶段缺口。 |

环境实际为 macOS 26.6.2 arm64 / Xcode 26.6 / Swift 6.3.3 / Python 3.9.6。测试编译保留既有 AppKit 可访问性 API、actor/未用变量及多架构目的地警告；不在本阶段清理，不宣称旧版 macOS、生产性能预算或运行态安全验收通过。既有并行 UI/查询/检查器修改均保留，未提交、推送、安装或发布；开发停在 2D。

### 9.20 阶段 2E-1：类型化图片拥有者、关联完整性与只读可浏览投影

#### 范围与复用（2026-10-01）

新确认图片查询语义已先登记在第 1 节；本节只实现注入元数据的关联基础。没有图片查询解析/匹配、OCR、文件读取、仓储接线、生产 UI、系统权限或指令执行。保留开工时查询、习惯、手记及界面的并行修改；2A～2D 提供者和字段适用性不因本阶段获得 has:image 能力。历史指定复核和真实验收缺口继续保留，授权不等于前阶段已验收。

| 核心接口 | 输入、输出与真实消费者 |
|---|---|
| [ImageAssociationReader.read](../AreaChain/Domain/ImageAssociationReader.swift) | ImageAssociationRequest → ImageAssociationResponse。同步纯值读取；当前仅由四套新增合成测试消费，没有生产数据源。 |
| [ImageAssociationRead.swift](../AreaChain/Domain/ImageAssociationRead.swift) | 元数据、拥有者快照、范围完整性、记录级存在/浏览状态、公开图片投影和机器诊断。`association(for:)` 对未评价对象始终返回 unknown。 |
| [ImageOwnerResolver](../AreaChain/Domain/ImageOwnerResolution.swift) | 按 AttachmentOwnerKey 分组所有输入，复用 AttachmentAccess.isSingleLive 和 DiaryQueryPrivacy；短期持有输入快照，不进入输出。 |
| [ImageOwnerProjection.swift](../AreaChain/Domain/ImageOwnerProjection.swift) | 一份拥有者属性投影，由图片的 owner 引用；relatedObject 映射既有 CommandObjectReference。没有全文、备注、子项、打卡或历史副本。 |
| [AttachmentBrowseFacts](../AreaChain/Domain/AttachmentBrowseFacts.swift) | 提取原 canBrowse 的最小纯规则；[DiaryPrivacy.swift](../AreaChain/Domain/DiaryPrivacy.swift) 的实体入口委托同一规则，原 ownerIndex、存储、删除和恢复路径不改。 |

沿调用链核对 AttachmentItem / AttachmentRef / ExportedAttachment、AttachmentOwnerIndex、AttachmentPicker / AttachmentStore、OwnedAttachments / SoftDelete、DiaryPrivacy / DiaryQuery，以及三个拥有者快照。AttachmentRef 缺少创建/删除与普通图片归属；ExportedAttachment 不含保护来源，不能直接证明公开。因此新增必要的 ImageAttachmentMetadata：图片 ID、原始 ownerKind、ownerID、filename、createdAt、deletedAt、protection。protection 是隐私库标志的无标识投影（unprotected / protected / unknown），不带 privacyVaultID、storageID、路径、URL、二进制或授权票据；真实适配必须正确映射，缺少保护资料不能填 unprotected。

元数据输入声明对应现有图片附件能力：选图 PNG/JPEG/HEIC/GIF/TIFF/WebP，粘贴与截图的 PNG；不拓展任意文件。此层不按扩展名猜测内容或验证格式，更不会读取文件。AttachmentStore 本身并非图片格式校验器，真实接线仍须保持既有生产者约束。

#### 覆盖、唯一性与错误隔离

输入显式提供 images、todo/routine/diary 快照数组、DiaryQueryMetadata 与 ImageAssociationCoverage。可选数组的 nil 是未提供，非 nil 空数组是已提供空资料；它是否足以证明完整仍须读取覆盖声明。默认空快照字段不能自动证明真实读取成功。

四类覆盖分开声明：

1. `owners`：某类型或某 AttachmentOwnerKey 的全部同 ID 拥有者行，必须包括墓碑。
2. `associations`：某类型或某拥有者的全部图片关联，必须包括墓碑；用于证明没有活图片。
3. `imageIdentities`：全部图片 ID 或明确图片 ID 的所有同 ID 行，跨拥有者和类型，包含墓碑；按一个拥有者取全图片不等于完成此项。
4. `diaryPrivacy`：限定 diary 类型或具体 diary 的保护判定资料，含仍影响保护的已删除关联标签、名字和私密标签集合；不把某个手记的完整事实推广到其他手记。

每项为 notProvided / partial / completeIncludingDeleted / invalid。对象（图片则为 ID）声明优先于类型/全 ID 声明，因此局部 partial/invalid 不被更宽的完整声明覆盖。完整性都是调用方契约，本阶段只检查输入，不证明真实仓储确实读全、同代次或可信。

拥有者身份使用 kind＋UUID；跨类型相同 UUID 合法。整个输入先分组，活/活、活/删除和删除/删除重复均隔离，没有 first-wins。只有声明完整、实际提供、恰好一行且未删除才确认活拥有者；完整零行诊断 missingOwner，未完整则 unknown / ownerCoverageIncomplete，未提供数组为 ownerNotProvided，已删除为 deletedOwner。图片 ID 在所有输入中分组，任何重复都不输出图片身份；没有 imageIdentities 完整声明也不生成确定可浏览图。已删除图片保留诊断并不作为存在见证。

未知 ownerKind 不重挂到恰好同 UUID 的其他类型；诊断不保存原始字符串，仅阻止同 UUID 潜在拥有者的否定结论。已知但错类型的归属按该类型查找并报告 missing/unknown，不借用另一类型。坏数据只影响相关对象；同一记录另有可靠合法图片仍可证明存在，不能把一条坏关联扩散到全库。显式 invalid 关联范围不可信，该范围整体 unknown，其他范围继续求值。

#### 可浏览、存在、不存在、未知与受保护

`ownerState`（live / missing / deleted / ambiguous / unknown）、`presence` 和 `browse` 分别输出，未合并成 Bool。

| 情况 | presence | browse / 公开输出 |
|---|---|---|
| 已确认唯一活拥有者与唯一活图片，元数据公开可用 | present | available；输出 filename、图片 createdAt、image 类型身份及 owner |
| 存在合法且确认公开的活关联，但展示元数据非法 | present | unknown；无该图片明细，不把它伪装成无附件 |
| 唯一活拥有者、关联覆盖完整、全部相关关联可判且没有活图片 | absent | unavailable；不要求凭空提供不存在的图片 ID 覆盖 |
| 缺覆盖/未提供/身份歧义，且没有独立可靠存在见证 | unknown | unknown（无可用拥有者时为 unavailable）；不能当 false |
| 敏感/不可公开手记、保护资料不足，或记录含活 protected 图片 | protected | protected；记录级粗粒度状态，无图片明细、文件名、数量或拥有者属性副本 |

受保护手记有零张、一张、多张甚至重复图时公开输出等价；资料不足另有记录级 privacyMetadataIncomplete 诊断。图片 protection=unknown 同样只输出 protected，不能发布给普通 has:image 使用的存在真值。含受保护图片的普通记录也整体隐藏图片明细，避免混合结果泄露数量。这个受保护判断不提供授权后的 has:image 真值；已授权私密记录是否可用该条件留给后续真实隐私适配。未提供保护资料绝不默认公开。

只有公开、有效的图片元数据进入 `images`；其数组保持输入相对顺序，不是全局排序。可浏览资格不证明磁盘文件存在、可解码或可读，更不授予打开能力。没有文件 URL、访问令牌、认证票据或缓存授权。

诊断仅保存枚举与类型化拥有者，不保存图片 ID、行位置、重复数量、原始 ownerKind、文件名、标签名字或正文。对受保护对象省略逐图诊断，以免数量/关联形状泄漏。请求、结果、图片、拥有者及属性投影和内部快照包装的 description/debugDescription 脱敏；隐藏分支实际不存敏感标记，测试递归检查存储值而非只检查描述。

#### 2E-2 可用接口与接入要求

- `ImageAssociationResponse.images` 是公开图片元数据，后续文件名普通词/短语/排除匹配只消费这里的 filename；created 用此处 createdAt。此阶段未计算命中区间、查询真假、评分或结果聚合。
- `owners[image.owner]` 是最多一份的属性投影。todo 提供安排日、创建时间、标签、完成、重要/紧急、提醒与截止分钟；routine 提供定义创建日/创建时间、标签、启停、星期掩码、暂停日、优先级和提醒，不伪造某日完成态或历史；diary 只提供已确认公开的归属日、创建时间、标签与置顶，不复制正文或制造任务字段。
- 投影的业务日、创建时间有限性和标签 ID 结构先校验；失败时诊断 invalidOwnerAttributes 并省略属性投影，但独立有效的身份/图片关联仍能证明存在。后续须将缺失属性当作未知，不能默认空标签或日期。字段值保持原始语义，不修复输入、不将合法 epoch 猜成缺失、不把当前 routine 定义解释成历史证据。
- 所属字段命中须使用 owner＋relatedObject，明确显示“所属记录属性”。标签名字由后续匹配资料提供并检查覆盖，不能把稳定 ID 当名字。routine 的 date/on/status 必须复用 RoutineQuery 的排程/执行日/记录证据接口，不在关联层推算。
- `has:image` 接记录级 `association(for:)`：present 是合法关联存在证据；absent 才是可靠否定；unknown 和 protected 均不得直接映射为 false 或对其取反。未评价对象始终 unknown。保护记录的授权判断、锁定失效与异步代次尚未接入。
- 2E-2 必须另行实现图片字段适用性、完整查询组合、诊断和上述所属属性匹配，再接 todo/routine/diary 的 has:image；现有三个提供者本轮仍报告 imageAssociationUnavailable，子任务仍无自身图片属性。本阶段没有开启这些能力。

#### 验证、兼容与保留缺口

新增 ImageAssociationIdentityTests / CoverageTests / PrivacyTests / AttachmentBrowseCompatibilityTests 和纯合成夹具；覆盖类型碰撞、三类重复及墓碑、图片重复与错归属、未知/缺失/已删、空与未提供、局部覆盖、受保护与资料不足、存在/浏览分离、描述与实际存储脱敏。旧规则真值表及 SwiftData 隔离内存实体对照覆盖可浏览条件，不访问真实数据库或图片文件。抽取旧规则没有改变实体拥有者索引、隐私转换、附件写入、删除或恢复行为；新关联层额外要求完整性和图片 ID 唯一性，不能将这些新增输入门槛声称为旧 API 已具备。

首轮四套测试 22 passed / 0 failed / 0 skipped（参数化 30 次）；随后补强局部错误与三类重复，并在收尾把图片保护资料未知改为仅输出不可公开状态，避免提前发布普通 has:image 真值；受保护记录的诊断也不随隐藏图片保护字段变化。最终证据在下方收尾记录。既有检查器接口和规则没有变化，继续运行原工作流、静态质量（含脚本回归）、严格局部 lint、定向 Swift 及 Debug 构建，不新增专项检查器。

当前可调用工具无指定 Cursor verifier，**blocked / 未执行，阶段整体 partial**；没有重复登录检查、改认证，也不以主代理自查或其他代理冒充。保留历史整树原生、真实仓储、真实隐私与系统权限缺口。本阶段没有生产 UI，未运行整树 auto/swift profile；旧浏览消费者只选不读文件的合成回归。最终不提交、不推送、不安装、不发布、不启动生产应用，完成后停在 2E-1，不进入 2E-2。

**2E-1 最终本地证据（2026-10-01）：**

- 最终普通入口 `./scripts/build.sh test`（41 个过滤项，完整参数在忽略目录 `build/ImageAssociationQA/final-command.json`）实际运行 **39 套、255 passed / 0 failed / 0 skipped**，参数化 **268 passed**；四套新增共 27 项。包括 todo/subtask/routine/diary 全部提供者套件、查询/类型/会话/页面/转交、旧搜索、CatalogSearchEquivalence、SoftDelete，以及不读文件的旧 AttachmentAccess / WorkspaceAttachmentSearch 用例。已核实每套结果均为 Passed。
- 结果包：`build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_22-20-19-+0800.xcresult`；`build/ImageAssociationQA/final-summary.json`、`final-tests.json`、`final-regression-retry.log`。`source-before-final.json` / `source-after-final.json` 的 Domain 源码和领域测试摘要一致。最终测试没有源码排除，没有文件加载、图片解密或真实库读取。
- `./scripts/build.sh` **passed**，`final-build.log`：staticSignatureVerified=true、distributionReady=false；仅 Debug 构建/验签，不是安装、运行或发行。环境 macOS 26.6.2 arm64、Xcode 26.6（17F113）、Python 3.9.6。日志保留既有原生测试 actor / Sendable、旧可访问性 API 和多架构目的地警告，不扩展修改。
- 严格局部 SwiftLint、差异空白检查通过；早期静态/工作流检查通过。收尾过程中，外部追加的 `component-catalog.md` 第三阶段 G 链接暂未有对应 engineering 锚点，导致整树静态/工作流检查失败；本任务不删除或改写该并行交接。最终重跑仍为 failed：唯一问题是该并行文档锚点缺失。静态门禁其余项目 passed，包括 176 项脚本回归；高风险/敏感日志候选均 0。详见 build/ImageAssociationQA/final-static-gate.json 和 workflow.log。
- 收尾普通测试曾被并行 `DaybookControlsPreview.swift` 写只读环境值的编译错误阻断；尝试仅排除无关展示测试又因共享 StepperTestSupport 缺失失败，两次均不计通过。并行源码自行修正后，使用原普通入口、无排除重跑取得上述最终通过证据；没有修改这些界面测试。最初回归中过时的 CatalogSearchTests 过滤项未实际命中，最终改为真实 CatalogSearchEquivalenceTests 并核实通过，不将未命中算作通过。
- 指定 Cursor verifier 仍 **blocked / 未执行**，整体 **partial**。本地证据不关闭历史原生、真实数据/隐私适配或系统权限验收缺口；2E-2 完整图片查询、has:image 适配仍未实施。

### 9.21 阶段 2E-2A：公开图片元数据的只读搜索提供者

#### 范围与起始核对（2026-10-01）

本次消费第 9.20 节已核实的关联基础，仅实现 image＋liveOnly 的同步纯值查询。起始 `python3 -B scripts/check_workflow.py` 全项通过：上阶段第三阶段 G 的 engineering 锚点在当前并行工作区已存在。这个核实不改写 2E-1 当时失败的记录，也不表示前阶段已验收。保留查询、习惯、手记、图片关联及界面并行修改，未改写 G 的文档或实现。

#### 接口、真实消费者与共享改动

| 接口 | 契约 |
|---|---|
| [ImageQueryProvider.read](../AreaChain/Domain/ImageQueryProvider.swift) | ImageQueryRequest → ImageQueryResponse；同一次 read 调用 ImageAssociationReader，只将 response.images 与 response.owners 用于内容匹配。当前消费者仅五套 ImageQuery Domain 测试。 |
| [ImageQueryRequest / Response / Match / Coverage](../AreaChain/Domain/ImageQueryRead.swift) | requestID、完整 ContentQuerySession、当前 ImageAssociationRequest、可选标签名字表、有界 scheduleEvidence/checks/checkCoverage。输入由调用方绑定到同一读取上下文；没有注入旧关联响应的入口，requestID 不是安全授权或仓储代次。 |
| [ImageQueryMatching](../AreaChain/Domain/ImageQueryMatching.swift) | 所有 Session.conditions 均参与，包含页面、用户与转交冻结条件；不用 input.source 重新解析或只匹配文本。复用 ContentQuerySnapshotMatching/Validation、TagSyntax/TagIDList 和真实拥有者字段。 |
| [ImageQueryTemporal](../AreaChain/Domain/ImageQueryTemporal.swift) | 复用 ContentQueryOccurrenceDay/DateWindow、RoutineScheduleHistory、RoutineCheckReading 与 RoutineOccurrenceEvaluation。不重新实现排程、记录归并、冲突或状态规则。 |
| [ContentQueryApplicability / FieldBinding](../AreaChain/Domain/ContentQueryScope.swift) 与 [TypeAnalysis](../AreaChain/Domain/ContentQueryTypeAnalysis.swift) | image 的 tags/priority/reminder/status/on 和所属页面字段声明 requiresImageOwnerType；imageOwnerAssessments 保留 todo/routine/diary 三个分支及原条件 ID。只有所有分支均不可能才整体排除；仅部分分支缺 on 不阻断其他图片。 |
| [RoutineScheduleHistory](../AreaChain/Domain/RoutineScheduleEvidence.swift) | 新增 routineID＋createdDayKey 的最小标量入口，由图片公开投影实际消费；旧 RoutineSnapshot 初始化保持兼容并委托同一算法，不构造带假标题的快照。 |

`ContentQueryConditionValidation` 的 contentTypes 最小增加 image，允许全局/标签内容上下文显式包含图片；图片页默认仍只有 images scope，没有新增类型筛选控件。现有 todo/subtask/diary/routine 字段语义不变。静态分支复用原冲突分析，图片 created 与 owner date 始终为不同绑定；routine 的 on 必须在最终 date 窗口内，OR 不掩盖该拥有者不具备的字段。has:image 对所有图片分支明确不适用。

#### 支持矩阵与明确缺口

| 条件 | todo 所属图片 | routine 所属图片 | diary 所属图片 |
|---|---|---|---|
| 普通文字、短语、AND/OR、排除 | 仅原始 filename | 仅原始 filename | 仅原始 filename |
| created | 图片自身 createdAt | 图片自身 createdAt | 图片自身 createdAt |
| date | 所属任务安排日 | 有界历史窗口内应执行日存在性 | 所属手记归属日 |
| #标签、排除、多标签、任一组 | 所属自身关联 | 所属自身关联 | 所属自身关联 |
| 稳定 tagID、noTags | 自身；不继承子任务 | 自身 | 自身 |
| priority / reminder、页面优先级/提醒存在性 | 任务字段 | 定义字段 | 不适用 |
| status:done/open | 任务完成字段 | 显式 on＋可靠排程与记录 | 不适用 |
| status:skipped、on | 不适用 | 显式执行日；skipped 独立状态 | 不适用 |
| has:image | 不适用 | 不适用 | 不适用 |
| 页面来源 App | 缺公开来源字段，unknown | 缺公开来源字段，unknown | 原页面谓词不适用 |
| 旧 boardDate 页面投影 | listedDay/items 全部合法范围，agenda 仅 overdue/upcoming | 暂不支持旧页面排程投影，unknown | 原页面谓词不适用 |

图片上的旧 boardDate 任务分支委托 Classification.matchesDate，测试对照 TodoQueryPageRules；routine 的统一 date/on 已支持，旧 boardDate 需要另行适配原页面排程能力，不借新历史语义冒充旧页面投影。任务 todoStatus 与习惯 routineStatus/itemKind 页面谓词按真实所属类型求值；另一任务类型中原本中性的谓词仍中性，diary 不冒充任务。composition.routines 只定义独立 routine 结果的默认启停；图片不因此排除停用习惯的公开附件，须有显式所属启停条件才筛选。

名字资料 nil 或缺关联名字不能当作无标签；已有可靠名字命中可以决定该正向/排除条件，无命中且名字不全才 unknown。稳定 ID/noTags 只用已验证自身 tagIDs，不需要名字表；明确空关联可以决定无标签。taskOrSubtask 对图片始终只取自身拥有者关联，不继承子项或兄弟标签。没有公开来源字段就报告能力缺口，没有向投影复制全文或新增来源标量。

#### 结果、覆盖、未知与保护

结果为 ImageQueryMatch.image（ImageBrowseProjection：image＋UUID、filename、附件 createdAt、AttachmentOwnerKey）加条件证据、businessDay、dateExistence、occurrence。filename 原文只保存一份，UTF-16 范围由既有工具在该原文取得；不匹配拥有者标题/正文，不搜索标签名作为普通文字。ownerTags/ownerPriority/ownerReminder/ownerCompletion/ownerBusinessDay/ownerOccurrenceDay/ownerScheduleExistence 明确所属来源；公共证据新增 ownerObject，relatedObject 可同时指向标签或 routineOccurrence，条件 ID/OR 分支不丢失。owners 字典按类型化拥有者复用一份公开属性，无全文。业务 date 的 witnessDay 不是默认操作日期；只有显式 on 产生 occurrence，普通文件名查询不因无关历史或记录缺失而受阻。

- coverage.providerTypes 仅 image；requestedTypes/coveredTypes 单独表达类型覆盖，不由诊断严重度推导。
- coverage.associations 为 notRead / completeForDeclaredInput / incomplete，只说明本次声明范围内的关联资料，不保证真实仓储或全局候选枚举完整。沿用关联层诊断；确定墓碑排除和独立属性缺失不伪装关联缺失。未提供图片输入、无法映射类型的输入或关联诊断中的缺失/歧义保留 incomplete；类型覆盖检查不取原始 filename，也不输出未知行身份、位置或数量。
- associationDiagnostics 与 associations 原样保留关联层已有非明细反馈；containsProtectedContent 仅来自其 protected 状态。受保护图片没有 filename、图片 ID、计数、文本结果或逐图 undeterminedObjects，公开结果不会因隐藏图数量/位置改变。
- diagnostics 用枚举、条件 ID、公开图片与所属引用说明缺属性/历史/记录/能力；severity 与 affectsDetermination 分开。AND 有确定失败可排除，OR 有确定命中可成立，全部相关诊断仍保留；只有公开对象最终依赖未知事实才进入 undeterminedObjects。已确定公开命中与未知、受保护覆盖可同时存在，不全局 blocked。
- isCompleteForCoveredTypes 要求 evaluated、关联资料完整、没有 protected 覆盖、没有公开未知对象和影响确定性的诊断。带未知/保护的空 matches 不是完整零结果。完整性不等于没有 warning/error，也不代表其他类型已覆盖。

request/response/match/matching、既有图片/拥有者投影及排程来源的 description/debugDescription 不展开文件名、正文、原始查询或来源字符串。结果不含 URL、令牌、存储指针、权限或可打开句柄；本阶段没有文件 IO、OCR、解密、真实仓储、UI 或指令执行。

#### 2E-2B 的复用入口与停止点

2E-2B 应继续调用 ImageAssociationReader.read(ImageAssociationRequest)，通过 ImageAssociationResponse.association(for: AttachmentOwnerKey) 读取 presence/browse/ownerState。present 是可靠关联存在证据；只有 absent 才能判无图，unknown/protected 不得变成 false；未评价对象始终 unknown。不得从图片搜索 matches、可浏览列表或 filename 推导 has:image 的否定，也不得将 requestID 当授权。拥有者、关联、图片身份和手记保护资料的完整性声明继续按第 9.20 节，不复制判断。todo/routine/diary 本次仍报告 imageAssociationUnavailable；子任务不获得自身图片字段。

指定 Cursor verifier 当前无可调用入口，**blocked / 未执行，阶段整体 partial**。未重复登录检查、改认证或以其他代理/主代理自查冒充指定复核。历史全量原生、真实仓储、隐私适配和系统权限验收缺口保留。本次不提交、不推送、不安装、不发布、不启动生产应用；完成 2E-2A 后停止，不进入 2E-2B。

#### 本轮验证

首轮 9 套定向测试 **53 passed / 0 failed / 0 skipped**；五套 ImageQuery 的 26 项及相关类型/执行日/手记消费者均实际执行。后续补强未知类型输入的保守覆盖、已知标签命中和 todo 完成字段，最终源码后的回归、构建与门禁结果见本节后续记录。仅用合成数据，没有读取真实图片或真实库。

**2E-2A 最终本地证据（2026-10-01）：**

- 最终 `./scripts/build.sh test` 的完整过滤参数保存在 `build/ImageQueryQA/regression-command.json`：实际 **50 套、341 passed / 0 failed / 0 skipped**，所有过滤项均匹配真实执行结果。五套新增 ImageQuery 共 **29 项**。覆盖 2E-1、查询类型/条件/页面/Session/转交、todo/subtask/routine/diary、历史/记录/日期及旧搜索与不读文件的附件浏览回归。
- 结果包：`build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_23-08-08-+0800.xcresult`；`build/ImageQueryQA/final-summary.json`、`final-tests.json`、`final-tests.log`。`final-source-before.json` 与 `final-source-after.json` 的全部 Domain 源码/领域测试摘要一致；无源码排除、真实图片或真实库访问。
- `./scripts/build.sh` **passed**，`build/ImageQueryQA/final-build.log`：Debug、staticSignatureVerified=true、distributionReady=false。环境 macOS 26.6.2 arm64 / Xcode 26.6；保留已有多架构目的地、原生测试 actor/旧可访问性 API 等警告，没有修改并行 UI 测试来消除警告。构建不是安装、生产启动或真实系统验收。
- 最终静态质量门禁 `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、本轮 19 个 Swift 文件的严格局部 SwiftLint 与 `git diff --check` 均 **passed**。静态门禁含 **176 项脚本回归**，高风险/敏感日志候选均 0；产物为 `build/ImageQueryQA/final-static-gate.json`、`final-workflow.log`、`final-lint.log`。文档收尾后重跑静态/工作流/差异检查；不运行无关整树 auto/swift 原生 profile，不把局部证据当整树原生验收。
- 指定 Cursor verifier 仍 **blocked / 未执行，整体 partial**；历史验收缺口不关闭。保留并行新增的详情子任务测试等工作，不提交、推送、安装、发布或进入 2E-2B。

本轮文件范围：新增上述四个 ImageQuery 源文件，以及 [ProviderTests](../AreaChainTests/Domain/ImageQueryProviderTests.swift)、[TemporalTests](../AreaChainTests/Domain/ImageQueryTemporalTests.swift)、[BoundaryTests](../AreaChainTests/Domain/ImageQueryBoundaryTests.swift)、[PrivacyTests](../AreaChainTests/Domain/ImageQueryPrivacyTests.swift)、[IntegrationTests](../AreaChainTests/Domain/ImageQueryIntegrationTests.swift)、[合成夹具](../AreaChainTests/Domain/ImageQueryTestSupport.swift)。共享改动限定在 [ContentQueryScope](../AreaChain/Domain/ContentQueryScope.swift)、[ContentQueryTypeAnalysis](../AreaChain/Domain/ContentQueryTypeAnalysis.swift)、[ContentQueryConditionValidation](../AreaChain/Domain/ContentQueryConditionValidation.swift)、[TodoQueryRead](../AreaChain/Domain/TodoQueryRead.swift)、[RoutineScheduleEvidence](../AreaChain/Domain/RoutineScheduleEvidence.swift)、[RoutineQueryEvaluation](../AreaChain/Domain/RoutineQueryEvaluation.swift)，同步原 [ContentQueryContractTests](../AreaChainTests/Domain/ContentQueryContractTests.swift)、[ContentQueryOccurrenceTests](../AreaChainTests/Domain/ContentQueryOccurrenceTests.swift)、[DiaryQueryIntegrationTests](../AreaChainTests/Domain/DiaryQueryIntegrationTests.swift) 的旧适用性断言。文档仅修改本权威来源并追加 [组件目录](component-catalog.md)、[架构说明](architecture.md)、[技能路由](../skill-routing.md) 的本阶段入口；未修改检查脚本接口/规则，原脚本回归照常执行。


### 9.22 阶段 2E-2B：三类记录的图片存在性查询

#### 范围与一致输入边界（2026-10-01）

本次只在 Domain 接入 todo、routine 定义、diary 的 has:image。开工时前阶段查询/提供者、图片关联、UI、文档和检查器已有大量未提交改动，均沿当前版本增量实施并保留；没有接真实仓储、文件访问、生产 UI 或执行。授权不关闭旧阶段验收缺口，不改认证或重查登录。

| 核心接口 | 输入/输出与实际消费者 |
|---|---|
| [ContentQueryImageInput / Read](../AreaChain/Domain/ContentQueryImageRead.swift) | 可选图片元数据数组＋原 ImageAssociationCoverage；由三个提供者的 read 同步构建共用读取上下文。没有 owners、标签隐私表、requestID 或预计算 response 的第二注入口。 |
| [ContentQueryImageEvaluation](../AreaChain/Domain/ContentQueryImageEvaluation.swift) | 将唯一存在性求值适配成三个既有结果/诊断类型，不构造全类型查询框架。原因保留条件 ID、类型化 owner、严重度和 affectsDetermination；提供者将原因挂到本次对象。 |
| [TodoQueryRequest / Response](../AreaChain/Domain/TodoQueryRead.swift)、[Provider](../AreaChain/Domain/TodoQueryProvider.swift)、[Matching](../AreaChain/Domain/TodoQueryMatching.swift)、[Evaluation](../AreaChain/Domain/TodoQueryEvaluation.swift) | 请求新增默认 nil 的 imageInput；响应新增 undeterminedObjects，诊断新增 severity / affectsDetermination 和 imageAssociation 原因，复用原类型覆盖和字段依据。 |
| [RoutineQueryRequest](../AreaChain/Domain/RoutineQueryRead.swift)、[Provider](../AreaChain/Domain/RoutineQueryProvider.swift)、[Matching](../AreaChain/Domain/RoutineQueryMatching.swift) | 默认 nil 的 imageInput；共用读取器只接当前 routines。沿既有 RoutineQueryEvaluationResult 组合，历史/记录证据仍分别负责 date/on/status。 |
| [DiaryQueryRequest](../AreaChain/Domain/DiaryQueryRead.swift)、[Provider](../AreaChain/Domain/DiaryQueryProvider.swift)、[Matching](../AreaChain/Domain/DiaryQueryMatching.swift) | 默认 nil 的 imageInput；共用读取器直接使用当前 diaries 和 request.metadata，同一标签隐私真值继续供正文遮罩与关联判定消费。 |

一次提供者读取中，主请求的当前完整拥有者数组（含墓碑）与 imageInput.images / coverage 组成 ImageAssociationRequest，调用 ImageAssociationReader.read，再按 AttachmentOwnerKey 调用 response.association(for:)。不从图片搜索 matches、可浏览清单、文件名或另一个 ownerID 集合推导存在性。2E-1 的身份、局部覆盖和保护判断没有改写。

**快照关联选择：不支持注入预计算 ImageAssociationResponse。** 因而没有接受旧 response 再验证 requestID 的路径，也没有快照 token 或持久缓存系统。相同 requestID 再次读取仍按当前拥有者/metadata 重建；修改身份、墓碑、保护标志或私密标签事实均不能沿用上一读取的存在真值。调用方仍须在同一读取边界提供图片行和四类完整性声明，跨来源真实原子快照/异步代次尚未接线，不能凭本层纯值读取证明其真实性。

imageInput=nil 是未提供；imageInput.images=[] 加相应 owners/associations 完整声明才可能证明 absent，images=nil 或显式局部缺口仍不能证明无图。ImageOwnerCoverage / ImageIdentityCoverage 的对象声明优先于类型/全 ID 声明，完全沿 2E-1；一对象完整不替另一对象声明完整。图片 ID 唯一性仍按注入图片全集（含其他拥有者与墓碑）读取，不能提前筛成当前拥有者列表来隐藏重复。

没有有效 has:image 条件时，ContentQueryImageRead 在进入 Reader 前返回，不验证或遍历无关图片。已有普通文字、标签、日期、页面匹配不因附带坏图片资料改变；没有新增文案、UI、语言或保存语义。

#### 共用存在性、三态与对象完整性

| association.presence | has:image 行为 |
|---|---|
| present | 成立；仅增加 imageAssociation 字段依据、当前条件 ID/OR 分支与 ownerObject，不带图片 ID、文件名、数量、URL 或图片列表。 |
| absent | 不成立；仅由 Reader 的完整关联结论产生，不把空可浏览列表当否定。 |
| unknown | 当前条件未知；保留缺输入、覆盖、身份歧义等 Reader 原因，无已知原因时为 unknownAssociation。 |
| protected | 当前条件不可公开，按 unknown 参与组合；保留 protectedAssociation 和已有粗粒度资料错误，不发布 true/false，不认证。 |

共用入口先求值存在性，再由各提供者组合当前对象：AND 有确定不匹配则排除，否则有未知则未知；OR 有确定匹配则成立，否则有未知则未知。当前 Parser 只允许同维度 OR，因此真实 image OR 是多个图片条件；组合器另用合成已知分支验证一般三态规则。没有新增混维度 OR 或 has:image 否定，旧解析拒绝继续保留。

所有参与条件先保留诊断再组合。确定不匹配或另一 OR 分支足以决定时，相关未知/错误的 affectsDetermination=false，严重度不变。Reader 的墓碑诊断为 warning；独立合法图片见证可在另有坏关联时成立，同时保留不影响最终确定性的错误。输出不复制 Reader 的公开图片投影，也不输出关联错误中的图片身份。

Todo 不再以 imageAssociationUnavailable 阻止整个子集：可确定命中返回，确定无图排除，未知进入 undeterminedObjects。has:image 参与时，原来可按条件定位的标签名字缺口、子任务完整性/归属错误也下移到对象条件求值；无 has:image 时保留原 requirements / recordDiagnostics 行为。日期/时间非法与重复拥有者仍作为行输入错误隔离，并列入未知对象；这些原有错误不能因附件存在而放行。

类型覆盖仍只表示提供者支持当前类型；evaluated 仅表示已做对象求值。三个响应的 isCompleteForCoveredTypes 均要求 evaluated、无未知对象且无影响确定性的诊断，不等于无 warning/error、真实候选枚举完整或全局类型覆盖。Routine/Diary 在完全未提供 imageInput 时仍保留既有非决定性的请求级能力提示；实际对象是否未知由逐对象组合判断。

#### 三类接入与隐私边界

- Todo 使用 todo＋ID，不看子任务图片；重复拥有者与墓碑继续参与主请求身份检查和 Reader 关联读取。
- Routine 使用定义 ownerKey；仅 has:image 不生成 occurrence、不要求今天打卡或排程历史。与 date/on/status 组合时继续分别使用 DateWindow、ScheduleHistory、CheckReading、OccurrenceEvaluation，图片不能替代历史或记录完整性。
- Diary 的正文可读性不授予公开附件存在性的能力。isPrivate、既有敏感标记/标签或保护资料不足仍由 DiaryQueryPrivacy / Reader 决定 protected。正文隐藏标题和文字依据遮罩未改；只有 has:image 实际参与时才出现其无法确定原因。零、一、多张乃至重复/坏图片的受保护手记公开响应相同，不以诊断条数或关联字段透露数量。
- subtask 不继承父图，image 不把自己当附件，routineOccurrence 不获得独立附件；clipboard 的图片负载仍是既有独立字段适用性声明，未接本关联模型。授权后私密 has:image、锁定失效、真实隐私/仓储适配仍未开放。

#### 测试、指定复核与停止点

新增 [PresenceTests](../AreaChainTests/Domain/RecordImageQueryPresenceTests.swift)、[LogicTests](../AreaChainTests/Domain/RecordImageQueryLogicTests.swift)、[PrivacyTests](../AreaChainTests/Domain/RecordImageQueryPrivacyTests.swift)、[IntegrationTests](../AreaChainTests/Domain/RecordImageQueryIntegrationTests.swift) 和[合成夹具](../AreaChainTests/Domain/RecordImageQueryTestSupport.swift)。原 [TodoQueryIntegrationTests](../AreaChainTests/Domain/TodoQueryIntegrationTests.swift) 与 [ContentQueryTypeAnalysisTests](../AreaChainTests/Domain/ContentQueryTypeAnalysisTests.swift) 的 has:image 预期从整体 blocked 改为对象未知；原解析拒绝、普通搜索与四类提供者测试继续回归。

测试覆盖三类四态、nil/完整空/局部覆盖、跨类型同 UUID、重复身份与墓碑、坏覆盖与保护资料、独立命中继续返回、三态消解与诊断影响、todo 辅助缺口、routine 独立历史/状态、diary 正文可读不解除附件保护及零/一/多公开响应等价。完整链路从原文到 Parser/Session、页面条件与 handoff 冻结日期、关联读取和三个真实提供者；没有文件/数据库读取或执行调用。

首轮定向 **31 passed / 0 failed / 0 skipped**（参数化 41 次），随后补强 Todo 辅助缺口组合与非法覆盖回归；最终源版本的回归、构建与门禁记录在本节收尾。证据目录为忽略的 build/RecordImageQueryQA。公共入口已同步组件目录、架构及技能路由；检查器接口和规则没有修改，不新增专项检查脚本，继续实际运行原工作流、静态质量及脚本回归。

指定 Cursor verifier 当前无可调用入口，**blocked / 未执行，阶段整体 partial**。不重查登录、不改认证，不以其他代理或主代理自查冒充复核。历史整树原生、真实库/隐私适配、系统权限及前阶段验收缺口继续保留。

阶段 2 仍缺标签、显式剪贴板/回收站提供者，以及独立执行记录结果（当前只有习惯定义关联的执行日证据）；跨提供者聚合、去重、排序/分页、片段与全局完整性汇总尚未接入。图片所属来源与旧 routine 页面投影等 2E-2A 已登记能力缺口仍保留。完成本轮开发验证后停在 2E-2B，不提交、推送、安装、发布、启动生产应用或进入下一阶段。


**2E-2B 最终本地证据（2026-10-01）：**

| 检查 | 实际结果 |
|---|---|
| 最终定向回归 | `./scripts/build.sh test` 使用 build/RecordImageQueryQA/regression-command.json 的过滤清单，**54 套、367 passed / 0 failed / 0 skipped**，参数化运行 **392 passed**。四套新增 RecordImageQuery 共 **26 项**；结果树核对所有过滤项实际执行、全部 suite Passed。 |
| 可追溯性 | `build/RecordImageQueryQA/final-summary.json`、`final-tests.json`、`final-tests.log`；结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.01_23-55-58-+0800.xcresult`。source-before.json / source-after.json 的全部 Domain 源码及领域测试摘要一致，构建后再次核对一致。 |
| Debug 构建 | `./scripts/build.sh` **passed**，build/RecordImageQueryQA/build.log：staticSignatureVerified=true、distributionReady=false。只构建/静态验签，没有安装或生产启动。 |
| 静态、工作流、局部 lint | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、19 份本次 Swift 源码/测试的 `swiftlint lint --strict --quiet` 与 `git diff --check` 均通过；静态门禁含 **176 项脚本测试**，高风险/敏感日志候选均 0。文档收尾后重跑，证据为 static-gate.json、workflow.log、lint.log。 |
| 本轮失败与处理 | 扩展回归首次 366 passed / 1 failed：ContentQueryTypeAnalysisTests 仍断言图片缺输入导致 Todo 全局 blocked；按已授权对象未知语义改为 evaluated＋undeterminedObjects，并保留原类型分析断言，最终整组重跑通过。最初静态门禁工作流项曾失败，随后同一入口重跑通过；期间并行文档仍在更新，本任务未改其检查规则。 |
| 保留限制 | 指定 Cursor verifier **blocked / 未执行，整体 partial**。历史真实隐私/仓储、生产 UI、整树原生、系统权限、安装与发行缺口未关闭；无关 auto/swift 原生全量 profile 未运行。 |

环境为 macOS 26.6.2 arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6。原生测试的既有 actor / Sendable / 旧可访问性 API 及多架构目的地警告保留，没有为通过检查修改并行 UI 或签名。合成证据不证明真实图片、真实库、授权后私密存在性或生产接线已经验收。本轮已停止在 2E-2B。


### 9.23 阶段 2F：活标签只读快照搜索提供者

#### 范围与接口

2026-10-02 本阶段只消费调用方注入的纯值标签、完整 Session 与可选使用统计，不接真实仓储、生产 UI、标签写入、全局聚合或执行。开工时的查询、图片、习惯、手记与界面并行修改保留；历史指定复核和其他验收缺口不因本次授权关闭。

| 接口 | 职责与实际消费者 |
|---|---|
| [TagQuerySnapshot / Request / Match / Response](../AreaChain/Domain/TagQueryRead.swift) | 快照保存 UUID、原名、sortOrder、deletedAt、isPrivateDiary、原 colorToken；纯值且无保存方法。请求带 requestID、完整 Session、tags、可选 usage 及默认 inputOrder 的 view。新提供者仅由四套 TagQuery 领域测试消费。 |
| [TagQueryProvider.read](../AreaChain/Domain/TagQueryProvider.swift) | 同步求值活标签自身，返回 tag＋UUID、原始快照元数据、字段命中依据、可选准确统计、类型覆盖、排序依据、未知及诊断。 |
| [TagQueryUsageInput / Coverage / Reader](../AreaChain/Domain/TagQueryUsage.swift) | 直接复用 TagUsageRecord；区分未提供、局部与完整。调用方对同一读取上下文负责，本接口不证明真实统计完整或授权有效。 |
| [TagListFacts / TagUsage.filteredValues](../AreaChain/Domain/TagUsageFiltering.swift) | 最小纯值目录筛选提取；原 [TagUsage.filtered](../AreaChain/Domain/Catalog.swift) 委托同一规则，TagManagementPage 的 displayed/unusedTags 间接继续消费。计数生产者 records/subjects 及生产页面文件未改。 |

现有 DiaryQueryTag 只有身份与可选名字，不足以保留存活、保护与颜色；ExportedTag 属于导出契约且没有 isPrivateDiary。因此新增最小查询快照，不把导出对象提升为查询权威输入，也不增加实体映射或生产读取入口。

#### 名称、关联与类型适用性

- 支持 global、tags 或通过 contentTypes 明确包含 tag 的组合，且仅 liveOnly。回收站及不含 tag 的范围返回 notApplicable；同名不同 ID 分别保留。重复 UUID（包括活/删除重复）整组隔离并报告输入下标与未知对象，不 first-wins。
- 普通文字只匹配原 name；多词 AND、连续短语、同维度 OR 和排除沿现有 Parser/Session。复用 BoardSearch.matches 的 localizedStandardContains 与 ContentQuerySnapshotMatching；新证据字段 tagName 的 UTF-16 范围指向未经改写的 name，并扩展到完整字素。保留 conditionID、alternativeIndex，排除只有 absence、没有虚构高亮。
- `#工作` 始终是“对象关联工作标签”；标签自身无关联字段，`/tags #工作`、排除关联标签、tagID/noTags 页面条件均为 inapplicableConditions。诊断锚定原条件和字段绑定，绝不把它重写为名称查询或虚构自关联。
- date、created、done/open/skipped、priority、reminder、on、has:image 以及任务页面属性均不适用。sortOrder 和使用统计 latestCreatedAt 不能替代标签自身日期，不增加私密/预置/颜色文本语法。
- TagManagementPage 直接显示 tag.name；三个手记预置存储名沿 DiaryMemoTags 原规则识别，不新增英文别名、翻译或改名。保留原 colorToken 并通过 TagColorToken.resolved 提供既有回退；预置的颜色选择继续留给现有 DaybookPalette.tagMark。
- 所有有效 Session.conditions 都参与，包括页面自动、用户接管和 handoffPage 冻结来源。结构非法、类型矛盾、字段不适用、未来未支持条件能力与对象资料缺口分别保留；tag 子集零命中不能宣称全局零结果。公共修改仅增加 contentTypes 对 tag 的合法组成及 tagName 命中字段，不改其他类型的适用性。

#### 使用视图、完整性与排序

TagQueryView 是本次请求的显式页面视图选项，不存文字/筛选 AST 副本，不修改 Session。默认 inputOrder 保持注入标签的相对顺序；只有显式 catalog(filter) 才复用目录顺序。当前 ContentQueryPage.tags 仍只有范围，尚未把页面控件、视图选项或选项转交接到生产宿主；后续调用方须随同查询传递所选视图，不能按接收页面自动猜测或从文本再建可编辑真值。

| 显式视图 | 既有含义与本次实现 | 数据不足时 |
|---|---|---|
| all | 全部活标签，按 sortOrder；无需使用数据 | 名称正常匹配，usageState 保留未知。 |
| frequent | 全部活标签，包括零使用；activeCount 降序，sortOrder 升序打破相同计数 | 若名称命中的任何项统计不足，保留全部名称命中与输入顺序，ordering.requested=activeCountThenSortOrder、applied=inputOrder、isComplete=false；不把缺数项丢成“不常用”。 |
| recent | 只保留 latestCreatedAt 非空的标签；该值降序，同值按 sortOrder | 仅完整合法统计可确定成员资格；其他名称命中进入 undeterminedObjects。已知子集排序，ordering.isComplete=false。没有“近 N 天”窗口。 |
| unused | 只保留完整统计 activeCount=0，按 sortOrder | 未提供或局部统计不能证明零使用，进入 undeterminedObjects。 |

TagUsage 的口径保持不变：未删除的待办、习惯、子任务、手记各自贡献使用次数，不计打卡，不按完成/启停筛掉记录；latestCreatedAt 是这些活关联记录创建时间的最大值，不是最近访问、编辑或标签创建时间。subjects 对子任务按其自身 deletedAt 判断，本阶段不额外引入父级过滤或重算隐私口径。

- usage=nil 表示未提供；partial(completeTagIDs) 仅对集合内 ID 声明完整，其他 ID 即使出现记录也仍局部；complete 声明全部标签统计完整。覆盖集合可以含本次未注入的标签，但不据此创建结果。
- 缺字典项只有在对应 ID 完整覆盖时才生成准确的零数/nil 时间。局部正数本轮也不作为精确统计发布，usage=nil、usageState=partial；这是保守展示，不表示真实零使用。
- 负数、非有限/超出民事日期范围的时间、零数却有时间/正数却无时间以及重复 usage ID 明确诊断；重复统计不相加、不任选首项。异常只使该标签统计无效，不能污染其他准确结果。活标签的坏统计即使名称未命中仍诊断，但不影响已确定的匹配；无关 usage 行不作为标签候选。
- 2F 当时 Match.usage 保存完整且合法的 TagUsageRecord；2K-8 将公开字段收窄为只有 activeCount 的 TagQueryUsageSummary，精确时间只留内部排序（见 §9.44）。类型 coverage、每项 usageState、undeterminedObjects、ordering 与诊断 affectsDetermination 分开；isCompleteForCoveredTypes 只证明本次注入对象的查询/视图求值完整，不证明标签枚举完整、真实仓储读取或全局覆盖。普通名称查询可在统计未知时完整确定匹配，并保留统计警告；即使无候选，使用视图在 usage=nil 时仍有请求级能力提示。

#### 公开元数据与安全边界

目录已公开的标签原名、颜色、预置及 isPrivateDiary 标记继续可见，不因私密标记自动隐藏标签。本请求/结果没有关联手记正文、图片、来源、任务标题或关联对象列表，统计也不附对象明细。requestID 只关联本次读取，结果身份和元数据不授予标签管理、私密访问、恢复或写入能力。Snapshot / Request / Match / Response / UsageInput 的 description 与 debugDescription 默认脱敏；诊断只带枚举、类型化身份、条件 ID 与输入下标。

#### 验证与交接

新增 [ProviderTests](../AreaChainTests/Domain/TagQueryProviderTests.swift)、[BoundaryTests](../AreaChainTests/Domain/TagQueryBoundaryTests.swift)、[UsageTests](../AreaChainTests/Domain/TagQueryUsageTests.swift)、[IntegrationTests](../AreaChainTests/Domain/TagQueryIntegrationTests.swift) 及[合成夹具](../AreaChainTests/Domain/TagQueryTestSupport.swift)。覆盖原文解析到 Session/提供者、完整页面与冻结条件、UTF-16/Unicode/大小写变音、OR/排除、不适用字段、删除/身份冲突、同名不同 ID、预置/保护/颜色、三种统计覆盖、局部完整和非法统计、四种视图及排序回退、描述脱敏与旧目录同输入对照。独立保存的旧算法断言验证纯规则提取等价；旧名称搜索共同子集用单词或显式短语比较，不把旧“整段 substring”误写成新多词 AND。

首轮定向 33 passed / 0 failed / 0 skipped，参数化运行 44 passed；后续补充名称未命中的坏统计诊断，最终证据在本节下方记录。首次测试编译因夹具直接比较未声明 Equatable 的 ContentQueryDateContext 失败，已改为分别比较 todayKey/calendar，生产日期契约未改。

指定 Cursor verifier 没有当前可调用入口，**blocked / 未执行，阶段整体 partial**；没有登录检查、认证修改或其他代理替代。生产标签页/仓储未接线，领域通过不表示页面已验收。检查器接口和规则未改，继续原工作流、静态质量/脚本回归、严格局部 lint 与定向 Swift/Debug 构建，不新增专项脚本或运行无关原生全量 profile。

剩余阶段包括显式剪贴板、回收站提供者及独立习惯执行记录结果；全局聚合前还需真实候选枚举/统计覆盖与读取一致性、隐私与缓存失效适配、各类型能力缺口、类型化身份去重、排序/分页和全局未知汇总。2E-2A 的所属来源与旧 routine 页面投影缺口继续保留。本次不解决这些问题；完成 2F 本地开发验证后停止，不提交、推送、安装、发布、启动生产应用或进入下一阶段。


**2F 最终本地证据（2026-10-02）：**

| 检查 | 实际结果 |
|---|---|
| 最终定向回归 | `./scripts/build.sh test` 使用 build/TagQueryQA/regression-command.json 中 57 套过滤，**388 passed / 0 failed / 0 skipped**，参数化运行 **461 passed**。四套 TagQuery 共 **27 项**；结果树核对全部 57 套实际执行且 Passed，包括四套转交及各类提供者、标签目录/旧搜索回归。 |
| 可追溯性 | build/TagQueryQA/final-summary.json、final-tests.json、regression-tests.log；结果包为 build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_00-27-08-+0800.xcresult。source-before.json / source-after.json 的全部 Domain 源码与领域测试 SHA-256 一致，构建后复查一致。 |
| Debug 构建 | `./scripts/build.sh` **passed**，build/TagQueryQA/build.log：staticSignatureVerified=true、distributionReady=false。未安装、未启动生产应用。 |
| 静态与工作流 | 最终文档更新后运行 `python3 -B scripts/quality_gate.py --profile static --format json` 及 `python3 -B scripts/check_workflow.py`，均 **passed**；结果见 static-gate.json / workflow.log。静态门禁包含 **176 项脚本回归**，没有改写检查器或检查脚本。 |
| 严格局部检查 | 本轮 13 份 Swift 源码/测试执行 `swiftlint lint --strict --quiet` 通过，git diff --check 通过；新增文件单独核对尾空白/结尾换行。公共 ContentQueryConditionValidation / TodoQueryRead 的既有并行差异保留。 |
| 扩展回归失败与修正 | 首轮扩展 357 passed / 1 failed：旧 DiaryQueryIntegrationTests 把 tag 类型组合视为非法。最小改为验证 tag＋diary 合法，仍保留空集合、clipboardEntry、routineOccurrence 拒绝；上述最终 57 套已重跑通过。未改变旧手记提供者或适用性。 |
| 保留缺口 | 指定 Cursor verifier **blocked / 未执行，整体 partial**；真实标签枚举、统计权限/缓存失效、仓储、生产 UI、全局聚合与真实系统验收均未接入。本轮没有运行无关原生全量 profile，历史缺口不关闭。 |

本轮新增 4 份 Domain 源码（TagQueryRead / Provider / Usage、TagUsageFiltering）和 5 份测试/夹具；既有源码最小修改 Catalog、ContentQueryConditionValidation、TodoQueryRead，既有测试只更新 DiaryQueryIntegrationTests 上述组合断言。文档更新本权威来源及 component-catalog、architecture、skill-routing 的本阶段入口。环境为 macOS 26.6.2 arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6。构建中既有目的地/actor/旧可访问性 API 警告保留，其他任务新增的 ClipboardPickerConsumerTests 等界面文件未改动。

### 9.24 阶段 2G：显式剪贴板历史的只读搜索提供者

#### 2026-10-02 实施前确认

- 仅显式 clipboard 范围（含剪贴板页映射）求值注入记录；global/tasks、目录发现及独立指令参数不能自行扩大范围。本阶段不读系统剪贴板、不加载历史、不复制/粘贴/采集/修改/删除记录。
- `/clipboard` 普通内容默认统一语法：多词 AND、连续短语、同维度 OR、排除和适用结构化条件。不读取或继承 ClipboardHistorySession 的 mixed 偏好。
- 显式旧模式复用 ClipboardSearchMode 及旧规则：mixed 按字符顺序、localizedCaseInsensitiveCompare 匹配；exact 为区分大小写的连续子串；regex 为 NSRegularExpression caseInsensitive。三个模式都修剪首尾空白，空 needle 浏览全部，非空正则对空 plainText 不匹配；有效零长度范围仍是命中，不因高亮为空而降级。无效正则单独诊断，不回退统一搜索。
- 复用现有 `/clipboard/search` 的 query:shortText 与 mode:mixed/exact/regex；模式由既有参数选项补全，不增平行指令。为保留空查询浏览，仅将 query 调为可省略（省略代表空）；显式空白 shortText 仍沿参数校验拒绝。多参数指令沿 chooseParameter 意图，不发明尾段自由文本解析。
- 正则原文是完整 query 参数，括号、`|`、`#`、`!` 等不交给 ContentQueryParser；结构化筛选独立持有且拒绝另一份文字条件，不拼接字符串。日期与已有类型化 sourceApplication 条件取交集，不增加来源文本语法。模式显式返回供后续 UI 展示，本阶段不接 UI。
- 文字只查已有 plainText；不读取 HTML、RTF、文件或图片，不做 OCR。date 用 copiedAt 与注入 Calendar 的民事日；created、标签、任务状态/优先级/提醒/on 不适用。has:image 为记录自身 imageFile 引用，与任务附件模型分离；有效性沿现有 imageData(named:) 的非空且不含 `/` 判断，不证明文件存在或可读。
- 完整空、部分、未提供、读取失败分别声明；失败不伪装空数组，不改变 ClipboardHistoryStore.load 现有行为。重复 UUID 整组隔离，同文或同 contentHash 不合并，pinKey 不是身份。
- 默认输入相对顺序；仅输出必要纯文本、采集/固定元数据、负载类别和原字段 UTF-16 命中范围。结果没有 HTML/RTF/存储名/路径、文件能力或操作闭包；描述与诊断不带正文或模式输入。
- 正则每次请求只编译一次；不承诺同步 NSRegularExpression 可取消或超时。旧采集条数/负载限制不作为注入搜索的静默截断阈值，不新建索引、调度或缓存。
- 历史 Cursor 指定复核与验收缺口继续保留；当前没有可调用 verifier，不重查登录、不替代复核。最终开发验证后停止在 2G。

#### 实际接口与只读边界

| 核心接口 | 职责与消费者 |
|---|---|
| [ClipboardQueryRequest / Input / ModeRequest](../AreaChain/Domain/ClipboardQueryRequest.swift) | requestID、互斥 unified(Session) / explicit(ModeRequest)、记录集合及覆盖。ModeRequest 以不可变 mode/needle/filters 保存完整原文，构造时拒绝结构非法或任何第二份文字条件（含仍在 input AST 的文字）；不生成默认 clipboard 范围。日期上下文沿 Session.queryDates，含转交时冻结值。 |
| 同文件 `ClipboardQueryRecords` | complete(records)、partial(records)、notProvided、failed 绑定数据与状态；失败没有错误原文或可被误用的旧记录数组。没有 Store、闭包、Session 生产实例或系统读取入口。 |
| [ClipboardQueryProvider.read](../AreaChain/Domain/ClipboardQueryProvider.swift) | 同步评估显式 clipboard 子集；使用完整有效条件、类型分析、日期校验、身份隔离和记录覆盖，返回模式、诊断及完整性。不要求/不修改 UI 激活状态。 |
| [ClipboardQueryMatching](../AreaChain/Domain/ClipboardQueryMatching.swift) | 复用 ContentQuerySnapshotMatching 的文字与民事日期判断；AND/OR、排除及独立来源交集，没有全文字段扩张或第二套解析器。 |
| [ClipboardQueryMatch / Response / Payload](../AreaChain/Domain/ClipboardQueryRead.swift) | clipboardEntry＋UUID、原 plainText、copiedAt、pinnedAt/isPinned、pinKey、sourceBundleID、纯负载类别、统一条件证据与显式模式范围。响应持有请求关联、类型分析、覆盖、对象未知和排序完整性。 |
| [ClipboardTextMatching](../AreaChain/Domain/ClipboardTextMatching.swift) | 单次准备 needle/正则并提供 matches、ranges、matchRanges；旧 [ClipboardHistoryRules.filtered / highlightRanges](../AreaChain/Domain/ClipboardHistory.swift) 与新提供者共用。旧 filtered 继续调用 ordered；新提供者不调用它的排序部分。 |

新提供者仅由四套 ClipboardQuery 领域测试消费，旧生产消费者仍是 ClipboardHistorySession.visibleItems 与 ClipboardHistoryBrowser 的高亮。读取核对 Session.query/searchMode、setSearchMode/loadPreferences：旧默认 mixed 与持久化契约保持；新请求不读取它，也不实例化生产 Session。没有新增模型、存储格式或服务接线。

目录只改 [clipboard.search](../AreaChain/Domain/CommandCatalog+Clipboard.swift) 的 query.required；参数类型、ID、mode 三种值和独立指令性质不变。模式候选继续通过 `CommandPathArguments.options(for:locale:)`，选择结果经 `argument` 与 `CommandArgumentValidation` 进入 ModeRequest。多参数路径返回原 chooseParameter；本阶段没有实现自由尾段或模式 UI。query 可省略表示空；显式 shortText 仍要求非空、单行。直接类型化旧模式请求保留旧 needle 的空白/换行语义。不借此改变其他指令空值规则、权限或执行状态。

#### 字段、证据与完整性

- 统一文字沿 localizedStandardContains / localizedStandardRange，忽略大小写和变音；每个条件在原 plainText 上保留首个范围并扩到完整字素。三种旧模式分别保留旧 range(of:)、逐 Character 范围和 NSRegularExpression 全部可转换范围；不为统一高亮改写旧范围。零长度正则命中保存 length=0 的真实 UTF-16 范围，空 needle 是无高亮浏览，两者不混淆。Match 保存完整 plainText，没有用 flattened/180 字符 preview 计算偏移。
- 统一 evidence 保留 conditionID/alternativeIndex、命中字段或 absence；显式 modeEvidence 保留模式、clipboardPlainText 字段和全文范围，没有虚构条件 ID 或复制正则输入。共同新增字段 clipboardPlainText、clipboardCapturedDay、clipboardImage；其他提供者证据含义不变。
- sourceApplication 是已存在的类型化页面条件，本轮仅扩充 [ContentQueryApplicability.pageBinding](../AreaChain/Domain/ContentQueryScope.swift) 对 clipboardEntry 的绑定，逐字符串精确比较 sourceBundleID；冲突来源沿原类型分析拒绝。没有 `source:` 新文本语法。任务页面 date/priority/status、标签、created、on 等不具备的字段明确拒绝，不忽略条件。
- copiedAt 与可选 pinnedAt 均经 ContentQuerySnapshotValidation 校验有限时间和可表示民事日期；坏时间整条隔离。date 使用 copiedAt 的注入时区采集日，固定日/today/闭区间/交集沿公共规则；不以 copiedAt 冒充 created。
- imageFile=nil 是无图片；非空且不含 `/` 是引用；其余是 invalidReference 并诊断。has:image 遇到非法引用为未知；若其他 AND 条件已确定不匹配，仍诊断但不虚报匹配未知。普通文字查询可确定匹配并携带 invalidReference 警告。HTML/RTF/文件只提供是否存在的布尔类别，不输出其值/路径，不枚举磁盘、不走 ImageAssociationReader。
- complete([]) 是完整空历史；partial 即使空也不完整且保留已知匹配；notProvided / failed 分别 blocked，诊断不同。coverage.didEvaluateRecords 只在访问候选数组时置真。非 clipboard、非法查询、静态不适用等提前返回，不读取候选数组。
- 重复 UUID 按整组输入下标隔离，重复组即使有不匹配正文也不任选一条；不同 ID 的同文/同 hash/同 pinKey 全部保留。返回顺序始终是输入相对顺序，未提供旧排序选项或全局评分；ordering.isComplete 仅在完整集合且无未知对象时成立。isCompleteForCoveredTypes 还要求 evaluated、已求值及无影响确定性的诊断；不能推导真实读取或全局覆盖已完成。
- 同步正则每次请求最多编译一次（无效时也只一次），结果中的全部范围一次求值取得。未静默施加采集的 999 条/负载字节阈值；合成 1,030 条用例验证不截断。没有增加搜索规模承诺、取消/超时保障或性能预算，病态正则的同步执行风险仍存在。

#### 验证、指定复核与停止点

新增 [ClipboardQueryProviderTests](../AreaChainTests/Domain/ClipboardQueryProviderTests.swift)、[BoundaryTests](../AreaChainTests/Domain/ClipboardQueryBoundaryTests.swift)、[ModeTests](../AreaChainTests/Domain/ClipboardQueryModeTests.swift)、[IntegrationTests](../AreaChainTests/Domain/ClipboardQueryIntegrationTests.swift) 及[合成夹具](../AreaChainTests/Domain/ClipboardQueryTestSupport.swift)。旧算法对照在测试中独立冻结提取前实现，覆盖空白、大小写、变音/组合字符、emoji、换行、字符序列、无效及零长度正则；不是只比较两个已委托同一函数的入口。没有实例化 ClipboardHistorySession、读取历史或使用系统剪贴板。

首轮七套定向测试 **54 passed / 0 failed / 0 skipped**，参数化运行 **70 passed**；覆盖四套新测试、旧 ClipboardHistoryRulesTests、目录与参数。最终扩展回归、构建和静态证据将在下方登记。指定 Cursor verifier 当前无可调用入口，**blocked / 未执行，整体 partial**，不重查认证、不冒充复核；旧阶段的历史缺口保持。

剩余前置问题：回收站尚需软删除对象/父子同戳与图片墓碑可见性、恢复资格及读取完整性；独立习惯执行记录尚需 routine＋民事日业务身份、历史/记录覆盖与缺失/冲突状态的独立结果协议；聚合尚需真实候选枚举/读取一致性、隐私和缓存失效、各类型能力缺口、类型化身份去重、排序/分页/片段与全局未知汇总。图片所属来源与旧 routine 页面投影缺口继续保留。真实历史读取的失败适配、缓存和系统粘贴仍未接线；本次不更改 Store.load 的吞错行为，也不进入这些后续阶段。

**2G 最终本地证据（2026-10-02）：**

| 检查 | 实际结果 |
|---|---|
| 扩展回归 | `./scripts/build.sh test` 按 build/ClipboardQueryQA/regression-command.json 的 **66 套**过滤执行：**459 passed / 0 failed / 0 skipped**，参数化运行 **548 passed**；四套 ClipboardQuery 共 **23 项**。结果树确认全部套件实际 Passed，包含查询/类型/页面/转交、目录/参数/路径补全、旧剪贴板规则及其他提供者。 |
| 最终诊断脱敏补强 | 扩展回归后仅补两组非法输入诊断断言，重跑 ClipboardQueryIntegrationTests：**5 passed / 0 failed / 0 skipped**。再次确认无效正则和非法图片标识的诊断不回显输入。 |
| 结果包与指纹 | 扩展包 build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_00-57-48-+0800.xcresult；补强包 Test-AreaChain-2026.10.02_01-02-05-+0800.xcresult。摘要、结果树及命令在 build/ClipboardQueryQA；source-before/after.json 确认扩展回归期间全部 Domain 源码与领域测试指纹一致，之后仅上述测试断言变化记录于 source-final.json。 |
| Debug 构建 | 最终相关测试后 `./scripts/build.sh` **passed**；build/ClipboardQueryQA/build.log 的 staticSignatureVerified=true、distributionReady=false。只构建验签，未安装或启动生产应用。 |
| 静态、脚本与工作流 | `python3 -B scripts/quality_gate.py --profile static --format json` 与 `python3 -B scripts/check_workflow.py` **passed**；静态门禁包含脚本回归。并行 Picker 检查器先于目录更新曾使 component-catalog 暂态失败，相关并行文档同步后重跑通过；本任务没有修改其实现或检查器。最终文档编辑后再跑同一入口。 |
| 严格局部检查 | 本轮 **14 份 Swift 源码/测试**的 `swiftlint lint --strict --quiet` **passed**，git diff --check 通过，新增文件另查尾空白/结尾换行与行数。工作区其余修改保留；未提交、推送、安装或发布。 |
| 保留缺口 | 指定 Cursor verifier **blocked / 未执行，阶段整体 partial**；没有复查登录、改认证或替代指定复核。未运行无关原生全量 profile，历史缺口不关闭；真实库/系统剪贴板、UI、缓存、聚合和执行仍未接线。同步正则无取消/超时保证。 |

本轮新增 5 份 Domain 源码（ClipboardQueryRequest / Read / Matching / Provider、ClipboardTextMatching）和 5 份测试/夹具；既有源码只改 ClipboardHistory、CommandCatalog+Clipboard、ContentQueryScope、TodoQueryRead。文档维护本节及 component-catalog、architecture、skill-routing 的接口索引，检查器接口和脚本未由本任务改变。构建保留既有目的地/actor/旧可访问性 API 警告。到此停止在 2G，不推进下一阶段。

### 9.25 阶段 2H-1：回收站墓碑、删除关联与恢复条件的只读契约

2026-10-02。本轮只实现纯值输入、身份核验、删除关系、安全分组依据与测试；不实现查询提供者、恢复/删除 handler、文件操作、生产适配或 UI。保留开工时前阶段领域、文档、脚本和原生控件并行修改。主代理核对具体入口，并以只读探索补充仓储事实；这不是指定 Cursor verifier 复核。

#### 输入、范围与复用

| 接口 | 责任与边界 |
|---|---|
| [TrashTombstoneInput / TrashReadCoverage](../AreaChain/Domain/TrashTombstoneInput.swift) | 复用 TodoSnapshot、SubtaskSnapshot、RoutineSnapshot、DiarySnapshot、TagQuerySnapshot、ImageAttachmentMetadata；没有实体、ModelContext、文件 URL、vault 标识或操作闭包。隐私元数据复用 DiaryQueryMetadata 与 ImageOwnerCoverage。 |
| [TrashTombstoneIndex](../AreaChain/Domain/TrashTombstoneIndex.swift) | 跨活/删除行核对类型化 ID、实际父关系、精确删除戳与范围完整性；所有同 ID 行先分组，不 first-wins。 |
| [TrashTombstoneProjection](../AreaChain/Domain/TrashTombstoneProjection.swift) | 复用 DiaryQueryPrivacy、DiaryQueryPresentation、既有隐藏标题；形成安全对象字段和只读恢复条件。 |
| [TrashTombstoneReader.read](../AreaChain/Domain/TrashTombstoneReader.swift) | 同步读取，输出唯一对象数组与引用式分组；不调用 ImageAssociationReader 的 live-only 路径，也不修改 AttachmentBrowseFacts。 |
| [TrashTombstoneResponse / Group / RestoreConditions](../AreaChain/Domain/TrashTombstoneRead.swift) | 明确对象、关系、顶层/成员计数、输入覆盖与展示限制；保留子项独立身份及分类型字段入口供 2H-2 使用。 |

每类数组的 nil 为未提供，[] 为已提供空集合；空集合本身不证明读全。`TrashReadCompleteness` 分 notProvided / partial / completeIncludingDeleted / invalid。types 是整类型全部行声明；objects 是某个 type＋UUID 的全部同身份行声明（对象声明优先）；members 是某父项、某子类型的关联枚举声明（成员声明优先于整类型）。部分枚举允许保留已经核实的单项关系，显式 invalid 的关联范围则产生 unresolved.invalidCoverage，不推断级联。按一个父项读全图片/子任务不能证明该图片/子任务 ID 在别处没有重复，身份核验仍独立要求 completeIncludingDeleted。声明必须含活行与墓碑，不表示本层验证了真实仓储一致性。

`todos` 内嵌子任务和显式 `subtasks` 均参与核验，不静默去重；同一行不得投递两次。内嵌项的实际 todoId 不符容器 todo.id 时隔离并诊断，不用容器改写真实归属。**生产 `TodoItem.snapshot` 只保留活子任务，不能作为墓碑完整来源**；未来适配应提供完整 SubtaskSnapshot，或自行组成含墓碑的 TodoSnapshot，保留真实 todoId。`SubtaskItem.snapshot` 在 todo 引用为空时返回 nil，这类无法形成快照的原始行必须由未来适配保留读取缺口，不能伪造父 UUID 或声明完整。

结果只回显类型级覆盖；不复制可能含隐藏图片 ID 的 objects/members 输入表。某父组的 subtaskRead 表示子项读取状态，坏行隔离时降为 partial；imageInputRead 保留该父图片输入范围声明，imageRead 始终为 displayLimited。后者不因零/一/多张受保护图片而变化。枚举覆盖、合法身份、安全展示是不同事实。

#### 身份、关系、分组与顺序

- 身份复用 `CommandObjectReference(type, UUID)`，此阶段 dayKey 始终为空。todo/routine/diary/tag 的同 UUID 互不冲突；同类型重复 ID（包括活/删除重复）全部隔离。图片身份以 image＋UUID 核验，拥有者以 ownerKind＋ownerID 核验；不存在子任务图片 owner 类型。
- 所有非有限 deletedAt 均明确诊断并隔离，不归一化、不按日期修补。合法活行不作为墓碑返回，但参与重复身份与父存活判断。
- root 是没有父归属的对象。cascaded 先要求唯一、范围完整的真实父关系，且父仍删除，再直接复用 `SoftDelete.shouldRestoreChild` 精确同戳判断。没有归属关系的同戳对象不关联。
- independent.timestampsDiffer 保留不同时戳的独立删除事实（含父删除前已独立删除的子项）；independent.parentIsLive 表示父已恢复而子项仍是墓碑，不能继续伪装为当前级联。
- unresolved 区分 parentNotProvided、parentPartial、parentMissing、parentAmbiguous、parentInvalid；完整范围内确实缺行才是 parentMissing。非法 ownerKind 仅产生无位置诊断，不通过其他类型相同 UUID 修补。
- `objects` 每个安全可见对象仅一份；todo 输出清空内嵌 subtasks，避免原始嵌套绕过隔离或重复计数。`groups` 只存父/成员身份，当前仍删除且同戳的子项收在父组下；独立、孤立或未知关系项保留顶层位置。
- 顶层数与展开成员数分开，均只描述安全可见投影。稳定顺序为 todo、subtask、routine、diary、tag、image，再按 UUID 字符串；不实现相关性、删除时间排序、分页或查询命中提升。

#### 逐类型恢复现状

| 类型 | 已核实的既有能力 | 本层描述与保留边界 |
|---|---|---|
| todo | SwiftDataTaskRepository.restoreTodo 清父墓碑，恢复同戳子任务及同类型图片 | existingEntry；子项 mayRestoreWithParent 只在当前确定级联时出现。 |
| subtask | 协议、仓储与 TrashRow 均没有独立恢复入口 | notProvided；确定同戳时可说明可能随父恢复，不为独立墓碑新增操作。 |
| routine | restoreRoutine 清定义墓碑并恢复同戳图片，不修改启停、暂停日或 checks | existingEntry；RoutineCheck 无 deletedAt，不产生独立墓碑或“恢复打卡”描述。硬删才由关系 cascade 删除 checks。 |
| diary | restoreDiary 清墓碑并恢复同戳图片，方法自身不解密、不检查隐私授权 | existingEntry＋后续保护复核要求；隐藏标题不代表方法不可恢复，也不提供正文访问。 |
| tag | restoreTag 清墓碑；预置分类也允许恢复，提交后更新 DiaryPresetRetention | existingEntry；预置约束是不能改名/改色/合并，不杜撰恢复禁令。恢复保留关联，purge 才解绑四类记录。 |
| image | TrashRow.attachment 只在同类型唯一活 owner 下允许独立恢复；底层 DayBoardMutations.restoreAttachment 仅清墓碑 | 活 owner 为 existingEntry；已删 owner 为 requiresLiveOwner；未知/缺失/歧义为 undetermined。同戳可另说明可能随父恢复。 |

所有条件都要求提交前重新核对身份、存活/删除、权限、数据和业务规则；没有 canRestore、可执行证明、文件存在性证明或成功保证。旧四类仓储按 ID 的 fetchLimit=1 不是唯一性校验，且 restore 方法没有独立墓碑 guard；新读取更严格的身份要求不能冒充旧执行层已补齐。图片独立恢复的保护条件也不能照搬普通浏览：旧恢复入口没有非私密 guard，公开浏览才排除受保护图片与敏感手记。后续真实操作须复用原安全流程另行定界，不能由本层重建认证逻辑。

AttachmentCleanup 的真实 purge 会清 storageID/retiredStorageID 指向文件，成功后移除元数据，失败保留重试；父 purge/清空会收集同类型拥有者的活附件与墓碑。本轮只核对来源和使用注入 removeFile 的内存回归，不调用默认业务目录清理。

#### 安全展示与尚未开放的披露

公开任务/习惯/标签保留各自快照字段；标签的私密标记不自动隐藏标签本身。手记复用 DiaryQueryPrivacy 判定，只有保护资料完整且可确认公开才发布正文；否则使用 `diary.private.title`，隐藏分支没有正文/片段存储位。名字、私密标签集合包含仍影响保护的已删除标签；不可读正文占位不能变成公开内容。手记仅保留已允许的日期、置顶和标签元数据。

受保护、protection=unknown、无法确认公开的手记拥有者图片不输出对象、文件名、成员身份、计数或行级诊断；混合拥有者与跨拥有者同 ID 的保护碰撞也不输出局部图片明细。未知 ownerKind 只保留无身份/无位置的机器诊断。所有请求、结果、字段封装与诊断的 description/debugDescription 默认脱敏；输出不持有原 request 或原始私密正文。

旧 TrashPage 仍按五类平铺，手记图片可有逐行隐藏标题；目标分组未接 UI。本阶段采取更窄的公开图片投影，不复制旧逐图占位数量到新分组，也不放宽非手记图片的异常保护披露。**受保护图片的独立命中、关系诊断与计数仍是未开放能力**，不能在 2H-2 为了展示结果偷偷恢复。零个可见成员永远不能推断“没有其他图片”。

#### 2H-2 接入要求与停止边界

2H-2 可复用 Input、Reader、对象的 fields/relation/restoration 与 groups 身份引用。查询应在显式 trash 组成内处理墓碑类型、字段适用性、读取缺口及未知结果；对子项单独匹配，命中时提升具体子项并保留父关系，不能只遍历顶层或因父组不匹配隐藏子项。独立身份用于结果去重及后续目标选择，不继承父项恢复入口。

仍需独立落实：真实含墓碑候选枚举与同次读取一致性、无父引用子任务的原始缺口适配、合法字段/未知值与查询三态、受保护图片可披露范围、排序/分页/片段与跨提供者汇总、提交前唯一性与业务/保护重查。没有查询结果、文件完整性、真实恢复、授权后私密能力或生产 UI 证据；不进入 2H-2，不提交、推送、安装、发布或启动生产应用。

#### 本轮验证

本轮使用合成值、SwiftData 内存模型、既有假系统密钥及注入文件清理回调。新增 TrashTombstoneRelationTests / CoverageTests / PrivacyTests / CompatibilityTests 与共用夹具；最终新增 34 项测试通过。指定 Cursor verifier 仍 blocked / 未执行，阶段整体 partial。没有重复登录检查、改认证或以只读探索/主代理自查冒充指定复核；历史整树原生、真实隐私/仓储、系统权限和发行缺口保留。

| 实际检查 | 结果与范围 |
|---|---|
| `./scripts/build.sh test`，四套墓碑、SoftDeleteTests、SubtaskModelTests、AttachmentCleanupTests、AttachmentBrowseCompatibilityTests、三套 ImageAssociation | 78 个测试定义 / 87 次参数化执行，零失败、零跳过；结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_01-29-17-+0800.xcresult`。此时新增测试为 31 项。 |
| 四套墓碑，加五个带 `()` 的精确旧测试筛选 | 38 项通过，零失败、零跳过，其中新增 33 项；结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_01-35-23-+0800.xcresult`。五个旧用例为 SwiftDataTaskRepositoryTests.softDeleteTimestampAlignmentAndSelectiveRestore、AttachmentOwnerLookupTests.trashRowBlocksRestoreWhenOwnerIsNotLive、TagRepositoryTests.softDeleteRestoreAndPurgeKeepThenDropLinks、DiaryPrivacyTests.confirmationUsesLivePrivacyProjectionInsteadOfKeepingCleartextCopy / typedOwnerPreventsPublicTaskFromExposingPrivateDiaryAttachment。 |
| 显式无效关联范围补修后，最终四套墓碑重跑 | 34 项通过，零失败、零跳过；结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_01-39-44-+0800.xcresult`。旧 SoftDelete、浏览及仓储实现未改，前两批旧回归证据仍适用。 |
| `swiftlint lint --strict --quiet AreaChain/Domain/TrashTombstone*.swift AreaChainTests/Domain/TrashTombstone*.swift` | 本次 10 个 Swift 文件严格局部检查通过；没有用全库历史警告替代本次证据。 |
| `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`、`git diff --check` | 工作流、引用、差异及静态质量门禁通过；静态入口包含原脚本回归 177 项。检查器接口/规则未改，没有新增专项检查脚本。 |
| `./scripts/build.sh` | Debug 编译与静态验签通过；仅产物构建，不安装或启动生产应用。 |

首轮局部 lint 发现测试别名过短，已改为 Fixture；补充内存手记测试一度使用不存在的构造参数，改为已有 DiaryPrivacy.assign 后最终通过。首轮五个单方法筛选未带括号，结果树确认没有执行，已用正确筛选补跑，未把未选中的方法算作通过。现有 actor / Sendable / 旧可访问性 API 及多架构目的地警告保留，没有修改并行 UI 来消除警告。

环境为 macOS 26.6.2 arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6。未运行无关 auto/swift 全量原生 profile、真实仓储/文件/安全认证或安装发行；测试与构建不关闭指定复核及历史验收缺口。最后代码行为验证后仅修正文档与契约注释，相关静态检查重新执行。本轮到 2H-1 停止。

### 9.26 阶段 2H-2：显式墓碑只读搜索与命中归组

2026-10-02。本轮消费显式注入的合成完整快照，新增纯值查询、独立命中提升、分组与完整性响应。前阶段及并行 UI/脚本修改保留；不读取真实库、不执行恢复/永久删除/文件操作，不接生产应用或下一阶段。指定 Cursor verifier 沿历史记录仍不可用，未重复登录检查、改认证或替代指定复核，整体状态 **partial**。

#### 核心入口与同批次读取

- [TrashQueryRequest / Response / Match / Group](../AreaChain/Domain/TrashQueryRead.swift)：requestID、完整 ContentQuerySession、TrashTombstoneInput，以及可选标签名字典/明确覆盖、可选 TrashQueryRoutineInput；响应不保存请求或原始查询。
- [TrashQueryProvider.read](../AreaChain/Domain/TrashQueryProvider.swift)：先检查完整 Session 结构、条件 ID 唯一性及 `scope == catalog(trash)`、`deletion == deletedOnly`，再在同次 read 调用 TrashTombstoneReader；global/tasks/diaries/images 等不读取墓碑、不回显覆盖。
- [TrashQueryMatching](../AreaChain/Domain/TrashQueryMatching.swift) 与 [TrashQueryFields](../AreaChain/Domain/TrashQueryFields.swift)：只接安全对象字段及允许的辅助资料，不接 TrashTombstoneInput 或原始 DiarySnapshot。复用 ContentQueryTypeAnalysis / Applicability、ContentQuerySnapshotMatching / Validation、日期、标签、公共命中依据与 TodoQueryEvaluation 的三态组合。没有改 deletedAt、构造伪活记录或调用 live-only 提供者。
- [TrashQueryTemporal / RoutineInput](../AreaChain/Domain/TrashQueryTemporal.swift)：复用 RoutineScheduleEvidence、RoutineCheckCoverage、RoutineScheduleHistory、RoutineCheckReading、RoutineOccurrenceEvaluation 和 ContentQueryDateWindow。默认 nil 是未提供；空证据不证明历史或记录完整，当前定义也不自动生成历史证据。

Reader 内复用已有身份/关系结果，只有 cascaded / independent 且父唯一、覆盖完整时才发布 `parentAttributes: ImageOwnerProjection?`。公开父属性来自 ImageOwnerInput 的既有校验与最小投影，包含任务日期/标签/完成态/优先级/提醒、习惯创建日/标签/启停等、公开手记日期/标签；没有父标题、备注、正文、子项或原始请求。父已恢复仍能提供允许属性，但不成为墓碑命中或上下文对象。缺失、重复、部分/无效身份及 unresolved 关系不提供父属性。聚合字段校验失败也使投影缺失；子项自身标题、created 和自身完成态不因此失效。

生产 TodoItem.snapshot 仍过滤已删子任务，不能充当完整墓碑枚举。测试使用显式 SubtaskSnapshot 或含墓碑的合成 TodoSnapshot；同一子项重复投递仍隔离。真实无父引用的原始行、事务一致性与枚举覆盖继续留给后续仓储适配。

#### 支持矩阵与明确能力缺口

| 对象 | 文字与标签 | 日期 / created | 状态与属性 |
|---|---|---|---|
| todo | 自身 title/notes；自身标签名、标签 ID、无标签 | date 为安排日；created 为自身创建时间 | 自身完成态、优先级、提醒、sourceApplication、itemKind；页面 routineStatus 类型中性 |
| subtask | 自身 title、标签；不搜索父文字 | date 为经核验的父安排日；created 为自身创建时间 | 文本 status 为自身完成态；页面 todoStatus/priority/reminder 取父字段；自身 priority/reminder 仍不适用 |
| routine | 自身 title/notes、标签 | created 为自身创建时间；date 需明确排程证据 | 自身优先级、提醒、来源、启停与类型；on/status 复用指定日排程/记录证据，没有输入按对象未知 |
| diary | 只匹配 publicText；隐藏标题从不匹配；允许标签可独立求值 | date 为归属日；created 为自身创建时间 | 不伪造任务属性；私密/资料不足时正文相关正向与排除均未知 |
| tag | 原名文字、短语、排除；不重命名 | 日期/created 不适用 | 标签过滤、任务属性不适用，沿类型分析明确返回 |
| image | 仅公开 filename；标签取允许的 owner 属性 | created 为图片自身创建时间；date 为 owner 业务日，routine owner 需排程证据 | 按 owner 类型检查适用性，任务属性/完成态或 routine on/status；不读取文件或证明文件可用 |

所有文字沿公共 AND、同维度 `(A | B)`、短语、排除与 Unicode 原文范围规则；条件 ID 和 alternativeIndex 只在同一 requestID 的 Session 中解释。deletedAt 只用于墓碑展示与关系，既不代替 date/created，也没有新增 deleted: 语法。

明确保留以下条件能力缺口：

- `has:image` 不复用活关联存在性，也不按安全可见成员数推断；适用对象返回 imageAssociationUnavailable，不适用类型仍由静态分析解释。
- 页面 `boardDate` 暂为 unsupportedCondition，未复制 live-only 列表/Agenda 逻辑；普通文本 date 已按上表支持。
- todo 的页面 `tagID(taskOrSubtask)` 暂为 unsupportedCondition，不把已删子项自动当父项命中；own 标签模式正常。
- 子任务父来源与图片 owner 来源未包含在安全父投影，相关 sourceApplication 条件返回 unsupportedCondition；自身 todo/routine 来源支持。
- routine 的 schedule/check 缺失、日期覆盖不足、冲突与非法值沿既有接口，保留按对象/条件的原因；纯 on 不因无关记录缺失丢掉确定排程结果。没有重建习惯引擎或执行记录独立结果。

#### 隐私、覆盖与三态

手记复用 2H-1 的隐藏标题分支；此分支无正文存储位，不能回到原始 DiarySnapshot 读取。Reader 另外保留 `TrashDiaryFields.hasValidTagIDs`，防止坏标签经规范化后伪装为无标签。标签名字典按同次请求显式注入，覆盖必须 completeIncludingDeleted，关联名字缺失不能按不匹配处理；安全隐私元数据仍单独沿原保护路径判定。

每个条件都求值再组合：AND 的确定 false 可决定不匹配，OR 的确定 true 可决定命中；其他依赖未知资料的条件保持 unknown。诊断保留，非决定性的诊断标记 affectsDetermination=false。缺父日期不会阻断子项标题命中；隐藏正文不能使排除条件变 true。

响应区分 invalidQuery、notApplicable 与 evaluated；evaluated 内有 restrictedTypes（静态不适用/矛盾）、typeCoverage（含未提供/部分/无效）、readingDiagnostics、按条件能力诊断、undeterminedObjects、nonmatchingObjects 及确定 matches。零命中不清空这些信息。未知的安全可见身份按对象去重；受保护图片不加入逐对象未知列表。完整输入声明不代表真实仓储已经读取。

受保护、unknown protection、私密/未确认公开手记 owner、混合 owner 或跨 owner ID 保护碰撞，仍沿 2H-1 隐藏整个受影响图片投影。查询、提升、上下文、诊断和计数均不重新公开身份/文件名/数量。`imageDisplayLimited` 是 evaluated 请求的固定粗粒度限制；`countsDescribeVisibleProjectionOnly` 始终为 true，不能从完整覆盖或零个公开图片推导实际图片总数。请求、响应、匹配/分组、内部字段和诊断 description/debugDescription 脱敏，不写业务日志。

#### 命中身份、归组与恢复描述

1. 每个安全对象单独求值，身份仍为 CommandObjectReference(type, UUID)；父子命中互不继承。
2. 只沿 Reader 的 TrashTombstoneGroup 合并已确认级联。独立删除、未知关系、不真实归属的同戳对象不合组。
3. 组内 `matches` 只引用确定命中身份。`displayAnchor` 为该组按原顺序的首个命中；只有子任务/图片命中时具体子项提升为锚点，`source` 仍保留父组与原读取/展示限制。
4. `context` 是同组其余安全对象，明确不是命中、没有默认选中状态；即使作为上下文出现，父项也不计入命中数。
5. definiteMatchCount、visibleGroupCount、visibleContextCount 分别来自唯一命中对象、非空命中组及非命中上下文；不互相替代，不包含隐藏图片。顺序沿 2H-1 固定类型/UUID 与关系顺序，无相关性排名、分页或跨提供者排序。
6. 命中对象原样携带 TrashRestoreConditions；独立入口未提供、需活 owner、可能随父恢复及未知条件均保留。无 canRestore/canExecute、handler、闭包、真实权限票据或文件可用证明。

#### 验证与剩余前置

新增六套 TrashQuery 测试及共用合成夹具，覆盖显式范围、六类型字段、Parser→Session→Reader→匹配→分组、父子独立命中、三种计数、恢复描述、重复/缺失父身份、标签和正文三态、受保护图片零/一/多/重复时的公开投影不变、routine 历史/记录证据与缺口。活提供者匹配实现未改，Reader 最小扩展同步回归 2H-1 与旧软删除路径。

真实墓碑枚举、读取失败/无父引用原始行的覆盖适配、生产搜索 UI、恢复/永久删除/文件执行及提交前业务/保护复核均未接线。独立执行记录提供者仍需 routine＋民事日业务身份、历史/记录覆盖、缺失/冲突状态与独立结果协议。聚合仍需真实候选枚举与读取一致性、隐私/缓存失效、类型化去重、各类型能力缺口、全局完整性汇总、排序/分页/片段。2E-2A 所属来源与旧 routine 页面投影缺口保留。本轮完成本地开发验证后停止，不进入上述后续阶段，不提交、推送、安装或启动生产应用。

本轮实际验证（最后 Swift 编辑之后）：

| 检查 | 结果 |
|---|---|
| `./scripts/build.sh test --only-testing …`，六套 TrashQuery、四套 TrashTombstone、SoftDelete、四套 TodoQuery、五套 SubtaskQuery，以及 DiaryQueryIntegration/Privacy、ImageQueryIntegration/Privacy/Temporal、RoutineQueryTemporal、TagQueryIntegration、ContentQueryTypeAnalysis/Session/Integration | **182 项通过，0 失败、0 跳过**；其中本轮新增 31 项。结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_01-56-54-+0800.xcresult`。 |
| `swiftlint lint --strict --quiet AreaChain/Domain/TrashQuery*.swift AreaChain/Domain/TrashTombstone*.swift AreaChainTests/Domain/TrashQuery*.swift` | 严格局部检查通过。 |
| `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`、`git diff --check` | 工作流、引用、静态质量和差异通过；静态质量包含原脚本回归 **177 项通过**。检查器及脚本测试接口未更改，无新增专项执行器。 |
| `./scripts/build.sh` | 最后 Swift 修改后的 Debug 构建与静态验签通过；没有安装或启动生产应用。 |
| 指定 Cursor verifier | **未执行 / 缺口保留**；测试、构建与主代理自查不替代指定复核。 |

首轮新增测试构建发现夹具试图修改 let 隐私元数据字段，已改为构造完整值；随后 22 项中 OR 夹具使用未支持的裸 `A|B` 语法，修正为协议既有 `(A | B)` 后通过。扩展及最后回归分别为 113 项、182 项通过。最后代码验证后仅追加文档证据，并重跑文档/静态检查。现有并行代码的 actor/Sendable、旧 AppKit API 和多目的地警告保留，不为本任务修改无关 UI。没有运行无关全量原生 auto/swift profile、真实库、附件文件、系统认证或发行验收；本轮到 2H-2 停止，历史验收缺口仍未关闭。

### 9.27 阶段 2I：显式日期窗口内的习惯执行情况只读提供者

#### 2026-10-02 实施前确认

本次限定授权只实现注入快照的 routineOccurrence 独立结果及合成测试。开工工作区干净；持续保留并行修改。指定 Cursor verifier 与历史验收缺口保留，不重复登录检查、不改认证、不以其他复核替代，不表示此前阶段已经验收。完成本阶段后停止，不接真实仓储、UI、聚合或任何写入。

- 仅显式 `ContentQueryScopeSelection.routineOccurrences` 求值。普通 global/tasks/routines 不混入每日记录；`/routines/checks` 仍是既有目录分组，不改变命令路径。专用文本范围入口留待后续接线，本阶段使用合法类型化选择。
- 必须有 date、on 或明确记录浏览窗口；没有窗口返回需要选择日期，不默认今天或全部历史。date 多条件沿原并/交规则；浏览窗口与 date 同时提供时必须一致，不能静默覆盖。on 与窗口求交且必须落在窗口内；每行已有明确日期，状态无需额外 on，习惯定义搜索仍保持原要求。
- 使用唯一、存活定义；重复 ID 整组隔离，已删除定义不进入活执行情况，回收站不自动展开记录。范围沿既有启停组成，当前停用不抹去可靠历史。创建前不派生；当前 weekdayMask/启停不冒充历史，currentDefinition 只证明明确观察日。
- 业务身份为习惯 ID＋民事日。可靠排程确认应执行且该习惯/日记录完整时：completed → done，skipped → skipped，unprocessed 或完整无行 → open。无行派生只存在于读取投影，不插库、不创建打卡；已有行与派生来源分开。
- 排程未知、冲突证据或记录不完整时不派生 open。观察到一条记录不等于完整最终状态；冲突记录不进入任何确定状态命中。非应执行日实际行、无法确认应执行日的行保留待核对信息；相同重复只出一条业务结果并保留诊断。缺失/歧义定义的记录单独报告无法归属，不伪造标题。
- date 是行执行日，created 不适用；记录不继承定义正文、标签、优先级、提醒、附件等搜索属性。所属标题仅作上下文展示，所属字段查询没有已确认契约，明确不适用并登记后续需求。完整 Session 的用户/页面/冻结条件、类型分析与日期上下文均参与，不跳过其余条件。
- 使用既有历史证据分段，未知以区间表达；明确注入输入规模、工作量和结果预算，截断报告剩余范围，确定结果可以与未知/未处理覆盖并存。请求窗口、定义枚举声明、记录完整性、历史完整性、枚举完整性和类型覆盖分别表达，不实现全局分页或持久游标。
- 默认定义输入顺序后按日期升序；结果保留所属引用、状态、来源、重复标记和公共日期/状态依据。确定命中与未知、冲突、异常分开；结果不持有实体、文件、执行闭包或权限。调试描述和诊断不展开标题、查询或多余记录资料。

#### 实际接口与条件边界

| 入口 | 本阶段责任 |
|---|---|
| [RoutineOccurrenceQueryRequest / Response](../AreaChain/Domain/RoutineOccurrenceQueryRead.swift) | requestID、完整 Session、RoutineSnapshot/CheckSnapshot、按习惯/区间声明的 RoutineCheckCoverage、RoutineScheduleEvidence、definitionCoverage、可选 browseWindow 与可注入 budget。全部为调用方声明，不核实真实仓储；定义枚举完整性独立于记录完整性。响应不保存请求或查询原文。 |
| [RoutineOccurrenceQueryProvider.read / Matching](../AreaChain/Domain/RoutineOccurrenceQueryProvider.swift) | 结构校验、显式范围、日期上下文/窗口、原类型分析及完整条件匹配。只接受 routineOccurrences/liveOnly；不修改 Parser、目录路径或 Session。缺窗口 requiresInput，冲突窗口 invalidQuery，on 在窗口外 unsatisfiable；类型不适用及矛盾沿原 readRestriction 返回。 |
| [RoutineOccurrenceQueryInput / Pattern](../AreaChain/Domain/RoutineOccurrenceQueryInput.swift) | 按习惯切片并把局部记录/证据下标映射回原请求；归并调用原 RoutineCheckReading，排程调用 History.day，结果组合调用 RoutineOccurrenceEvaluation。History 原分段方法只由 private 改为内部可复用；记录覆盖边界再细分，每段至多采样七个星期位，不重写历史判断。 |
| [RoutineOccurrenceQueryEnumeration](../AreaChain/Domain/RoutineOccurrenceQueryEnumeration.swift) | 有界枚举应执行日与窗口内实际记录的并集，同一业务日只求值一次；定义输入顺序后日期升序。未知排程或不完整记录区间不派生占位行，实际行仍进入核验。没有全局评分、游标或写入。 |

`coverage.window` 保留原 date 窗口、browse 窗口、on 和最终 effective。date 仍按同维 OR 并集、条件间 AND 交集；browse/date 同时存在要求规范化窗口相等，on 在其中明确收窄单日。显式空窗口与缺窗口不同；空 date 交集仍由原类型分析判矛盾。`queryIsValid` 仅表示 Session 结构有效，外部窗口一致性及读取资格由 state/diagnostics 表示。

每个合法有效条件都经过类型分析及匹配；支持的行字段为 date/on/status，命中使用现有 occurrenceDay/completion/scope 依据及原 conditionID、alternativeIndex。范围本身不伪造日期条件 ID；纯 browse 的行日期见 id.dayKey 与 occurrence.schedule，不能把浏览参数冒充文字命中。排除仅沿原语法允许范围，不能排除 date/status 绕过状态规则。

记录无自身文字/标签/优先级/提醒/附件/createdAt；类型分析明确拒绝这些条件，包括排除文字。routineTitle 只作关系上下文，未参与文字匹配。页面 boardDate、routineStatus、todoStatus、itemKind、sourceApplication、taskPriority、reminderPresence 等对记录仍沿现有类型契约不适用，不忽略冻结页面条件或借用定义字段。`page.contentTypes` 的现有合法集合不含 routineOccurrence；不因本阶段扩大它，合法记录选择继续使用 `.scope(.routineOccurrences)`。文本专用范围、所属属性查询和记录页面谓词均是后续接线/产品契约缺口。

#### 确定结果、异常与覆盖

- `matches` 只含已确认应执行且记录输入完整的 done/open/skipped。source 为 existingRecords 或 derivedUnprocessed；后者必须 records.state=absent，前者包括明确 unprocessed 行。身份是 `CommandObjectReference(type: .routineOccurrence, id: routineID, dayKey: day)`，另带 routine 引用和必要标题；没有 createdAt、文件、实体、闭包、canExecute 或权限票据。
- `reviewRecords` 只描述实际观察到的业务日，kind 区分 unknown/conflict/notScheduled/unattributed/invalidInput；records 保留原归并状态、完整性和重复/冲突诊断，schedule 保留应执行证据或未知原因。非应执行日同时存在冲突时 kind=notScheduled，records.state=conflict 与对应诊断仍保留，不掩盖任一事实。
- 相同重复记录只返回一次，保留原下标与 warning，不自行降低确定性；不同状态或 done+skipped 均不匹配正常状态。未提供完整记录时，已观察到 completed 也只在待核对中展示。原始记录下标仅对本次 requestID 有意义，不是可写记录 UUID。
- 当前停用定义保留可靠历史；删除定义不枚举也不展开记录。重复定义含删除副本时整组隔离；缺失/歧义定义的实际行单列无法归属，保留记录完整性，不生成标题或正常结果。非法同习惯记录日仍沿 2C-1 拒绝该习惯的记录输入；其他习惯不受影响。
- `coverage.gaps` 区分 schedule(missingHistory/conflictingEvidence/invalidInput)、recordsIncomplete、invalidRecordInput、ambiguousDefinition。区间带精确星期掩码，表示区间中这些星期存在缺口，不声称每天均未知；创建前排程仍由原 History 排除。状态冲突与“输入是否完整”分别表达，完整输入也可能包含冲突。
- 请求窗口、definitionCoverage、requested/covered/providerTypes 与 deletion、历史缺口、记录缺口、枚举剩余分别保留。historyIsComplete / recordsAreComplete 针对本次已枚举的注入范围；未枚举、无归属记录或各自缺口会保留对应不足。定义枚举不完整另由 definitions 表示。`isCompleteForCoveredTypes` 还要求 evaluated、定义完整、无待核对行及影响确定性的诊断；不代表真实来源可信或全局所有提供者已完成。
- 不适用/缺窗口/矛盾的请求未进入枚举，enumerationIsComplete=false；evaluated 也可能带未知或截断，空 matches 不能解释成完整零结果。新请求、结果、内部习惯切片与诊断的 description/debugDescription 均脱敏，没有业务日志。

#### 技术预算与剩余范围

暂无已确认的统一提供者枚举预算。本阶段选择可注入 `maxInputItems=4096`、`maxWork=100000`、`maxResults=1000`，用于限制同步读取的内存与排程/归并工作；这些是本地技术限制，不宣称性能基线、分页大小或产品规模上限。

输入计数包含定义、原始行、证据、覆盖声明/内部区间、条件/内部项、窗口区间；超限在建立输入索引前返回 inputLimit 和整个 effective 窗口。预处理受输入个数限制，不解析或匹配所属标题等大文本。工作单位按各习惯的记录、覆盖、证据数估算切片/分段/七日采样/单日归并成本，并计入 weekday 查找的固定开销；它是可重复的工作预算，不是毫秒或 CPU 指令计数。每个已知排程片段最多采样七日，长跨度未知/未完整记录直接出区间；有应执行日的片段只枚举可靠完整候选和实际记录，并复用公共单日读取。

maxResults 同时限制 matches 与 reviewRecords 行，原重复行不重复消耗结果名额；范围诊断不计行数，但受输入与工作量边界限制。达到 workLimit/resultLimit 时返回已得到的确定结果，unprocessed 按习惯保留尚未求值的窗口后缀；后续习惯保留完整窗口。无法归属的未处理实际行使用 unprocessedCheckIndices，并保留原请求窗口。分散窗口仍保留区间集合，不把空隙变成待处理日期。所有截断均 enumerationIsComplete=false；不产生持久游标或假完整计数。

#### 聚合前的差异与保留缺口

1. routine 定义身份只含 UUID；routineOccurrence 必须同时带日键，不能在聚合中按 UUID 去重或合并。旧定义 date 是“窗口内存在应执行日”，本提供者 date 是具体行日；旧定义状态仍要求 on，记录状态不要求额外 on。
2. 各提供者结果和完整性结构尚未统一。此处额外区分定义枚举、历史、记录、行枚举及未归属行；不能把其他提供者的 evaluated 或空结果直接折算为全局完整。Trash 仍有安全分组/保护计数限制，Clipboard 仍有历史覆盖/模式，图片仍有 owner/保护分支。
3. 记录没有可用于通用文字片段或创建时间排序的自身字段，routineTitle 仅为展示关系；所属文字/标签等查询未获类型化契约。页面谓词、page.contentTypes 的记录支持和文本显式记录范围入口尚未接通，`/routines/checks` 语义保持。
4. 真实定义/记录枚举、跨输入快照一致性、可靠历史来源与覆盖声明适配均未实施；requestID 不是数据库版本。真实仓储、缓存失效、隐私适配、生产 UI、全局排序/分页/片段/聚合、操作资格和执行仍需独立工作。
5. 指定 Cursor verifier 当前可调用工具清单无入口，未执行；未重复登录、修改认证或使用其他代理替代。前阶段及历史整树原生、真实数据、系统权限和发行缺口保持，本阶段整体 partial。本次不提交、推送、安装或启动生产应用，完成后停止。

#### 本轮验证与停止点（2026-10-02）

| 检查 | 本次实际证据 |
|---|---|
| 四套新增 RoutineOccurrenceQuery 测试 | 最终 **40 项通过**；首轮为 33 通过/1 失败，原因是夹具使用原契约禁止的 `.all` 空筛选；改用合法 p1/set，文字优先级/提醒使用原 `!p1` / `@15:30` 后 34 项通过，再扩展六项冻结/日期/覆盖/预算边界并纳入最终回归。没有修改旧筛选规则来放宽测试。 |
| `./scripts/build.sh test --only-testing …` | **70 套、520 项通过，0 失败、0 跳过**。覆盖新提供者、2C-1/2C-2、ContentQuery 全链路/类型/转交、七类已有提供者、图片存在性、目录/路径、旧 DayBoard/Agenda/BoardSearch/ItemsListing/日期/分类，以及 SwiftDataRoutineRepository 合成内存回归。命令清单与结果摘要在忽略目录 `build/RoutineOccurrenceQA/regression-command.json`、`regression-summary.json`、`regression-tests.json`。结果包为 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_09-34-02-+0800.xcresult`。 |
| `./scripts/build.sh` | 最后 Swift 编辑后的 Debug 构建及静态验签通过，staticSignatureVerified=true、distributionReady=false；没有安装或启动生产应用。构建使用原锁等候并行任务，没有绕过锁或改变签名。 |
| 严格局部 SwiftLint | `swiftlint lint --strict --quiet AreaChain/Domain/RoutineOccurrenceQuery*.swift AreaChain/Domain/RoutineQueryEvaluation.swift AreaChainTests/Domain/RoutineOccurrenceQuery*.swift` 通过。 |
| 工作流、质量和差异 | `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static` 与 `git diff --check` 通过；最终静态质量包含当前工作区原脚本回归 **178 项通过**，高风险/敏感日志候选均 0。Swift 验证使用上述定向测试与构建，不运行无关全量原生 auto/swift profile。最后仅维护文档证据并重跑受影响检查，没有再编辑本阶段 Swift。 |
| 指定复核 | 当前工具清单无 Cursor verifier 可调用入口，**未执行，整体 partial**。未检查登录、修改认证或用主代理自查/测试冒充指定复核；历史缺口继续保留。 |

本次环境为 macOS 26.6.2 arm64 / Xcode 26.6 (17F113) / Python 3.9.6。保留既有原生测试的 actor/Sendable、旧 AppKit API 和多目的地警告，不在此阶段清理。自身生产改动仅四个新领域文件及 History.segments 的访问范围/契约注释；DayBoardLogic、AgendaProjection、BoardSearch、RoutineCheckReading、RoutineScheduleEvidence 和习惯写入仓储未改。真实仓储历史适配、真实用户数据、UI/系统认证与发行均未验证，本次有限授权不关闭历史验收缺口。

并行修改持续保留，包括设置 Picker 与宿主测试、Theme/Settings、工程文档和工作流检查器/脚本测试；这些不计作本阶段实现。本阶段没有更改检查器接口或新增脚本；最终静态运行使用当时工作区的检查器。结果顺序仅对 matches 定义为定义输入顺序、日期升序；无法归属行先按原始输入的首个业务键读取并消耗共享行预算，不能因此宣称确定结果前缀覆盖了全部正常定义。

完成本阶段后停止；不进入跨提供者聚合，不提交、推送、安装或发布。

### 9.28 阶段 2J-1：同步批次、跨提供者类型化结果与完整性汇总

2026-10-02 本轮授权仅实现注入快照的同步读取聚合。保留开工已有 2I 的 RoutineOccurrenceQuery 文件、RoutineQueryEvaluation 及设置 Picker、测试宿主、工作流检查器和文档的并行修改；没有把它们计作本阶段修改或关闭历史验收缺口。不接真实仓储、生产 UI、排序/分页、缓存或执行。指定 Cursor verifier 无可调用入口，不重复登录检查、不改认证、不冒充指定复核；整体仍 partial。

#### 批次入口、单一输入与实际保证

| 接口 | 职责与实际消费者 |
|---|---|
| [ContentQueryBatch / Snapshots / Facts / Options](../AreaChain/Domain/ContentQueryBatch.swift) | 单份 Session、requestID、分型源、辅助覆盖及显式选项。日期只取 Session.queryDates（含 handoff 冻结环境）。当前只由四套 ContentQueryBatch 领域集成测试消费，没有生产调用方。 |
| [ContentQueryBatchReader.read](../AreaChain/Domain/ContentQueryBatchReader.swift) | 唯一聚合入口；选择提供者、装配请求、同步调用、隔离冲突并生成摘要。不接受预计算响应、任意提供者列表或额外 Session。 |
| [ContentQueryBatchAssembly](../AreaChain/Domain/ContentQueryBatchAssembly.swift) | 共用任务视图、图片资料、手记保护资料、习惯定义/记录/证据；直接调用既有九个提供者。没有匹配、排程、日期或隐私判断的新实现。 |
| [ContentQueryBatchMatch / ProviderRead / Response](../AreaChain/Domain/ContentQueryBatchResult.swift) | 关联值枚举直接保存既有安全投影及原生响应；matches 是各响应的派生视图，不再保存第二套全文或可操作实体。 |
| [ContentQueryBatchCompleteness](../AreaChain/Domain/ContentQueryBatchCompleteness.swift) | 区分结构、原请求类型、静态可行类型、实际评估、缺源、限制、对象未知、覆盖、保护、历史/记录、枚举与排序提示。 |
| [ContentQueryBatchIdentity](../AreaChain/Domain/ContentQueryBatchIdentity.swift) | 同类型业务身份冲突隔离、保留原提供者诊断；不跨类型去重，不把原始重复输入转成“干净完整”。 |

`ContentQueryBatchSource<Value>` 将 notProvided / failed / partial(values) / complete(values) 与数据绑定。complete 表示调用方声明该类型候选及同身份核验所需行已提供，包含墓碑；不是空数组的默认含义，更不是本层验证了仓储已读全。Clipboard 继续使用原 ClipboardQueryRecords。未提供/失败不带可误认为当前值的旧数组；不构造完整空请求骗过提供者。

任务主源的 TodoSnapshot 必须不含内嵌子项，SubtaskSnapshot 平面数组是唯一子任务源。需要活子任务或父项 taskOrSubtask 标签条件时，按原 todoId 一次装配嵌套视图，todo/subtask 提供者共用；不修正归属、不丢弃重复。存在第二份内嵌源时隔离任务读取并报告 nestedSubtaskInput，其他类型继续。活子项找不到输入父项时保留 uncontainedSubtasks，不能把组装时无法容纳的行悄悄丢掉后宣称完整；墓碑直接消费两份原始平面类型源，允许孤立行沿原 Reader 表达未知父关系，不重复投递嵌套子项。

RoutineSnapshot 只有一个主源；routine、image owner 与 routineOccurrence 使用同一 checks/checkCoverage/scheduleEvidence。记录完整性仍按习惯/窗口声明；缺证据不补当前排程或今天。图片主源也只有一份，ImageQueryProvider 的 association 与三类记录 has:image 的 imageInput 使用同一数组/覆盖；图片拥有者来自同批 todos/routines/diaries。DiaryQueryMetadata 的名字与私密标签事实同时供普通记录、图片关联及墓碑使用，没有第二份保护表。标签名字资料属于关联辅助资料，可含仍生效的已删除标签，不从本次标签搜索结果反推它。

主源为部分枚举时，图片关联和墓碑的整类型 completeIncludingDeleted 声明被收窄为 partial；图片主源部分时，整集合图片身份/关联声明也收窄。对象级精确覆盖仍按原读取器优先规则解释。覆盖表、公开元数据和保护声明都是调用方事实，本层不能证明其真实来源；没有新增认证机制或授予能力。

保证仅限**同一同步调用的值输入一致**：请求全部使用 batch.session/requestID，临时数组采用 Swift 值语义；重复 requestID 仍重新读取本次输入。没有数据库事务快照版本、跨线程一致性、异步查询代次、缓存新鲜度或锁定失效承诺。Options 仅含 Locale、标签原视图、剪贴板原模式及执行记录原浏览窗口/技术预算；显式剪贴板模式用同份 Session 构造原 ModeRequest，第二份文字条件仍由原构造器拒绝。

#### 提供者选择与顺序

- global 固定 todo → subtask → routine → diary → image → tag；tasks 为前三者的原 composition 子集，各单范围只调用对应提供者。contentTypes 继续取原 Session 的交集，不扩大其合法集合。
- clipboard 必须显式；trash 必须显式且只调用 TrashQueryProvider，不混入活提供者；routineOccurrences 只调用记录提供者，不混习惯定义。记录范围仍为类型化选择，没有修改 `/routines/checks` 或新增文本语法。
- 结构非法、条件身份重复或独立命令输入不调用任何提供者。请求类型和静态可行类型均保留；单类型矛盾、不适用、需要 on 等通过原 assessment/readRestriction 说明，不从原请求删除后声称覆盖完整。无需读取的静态受限类型不访问其主源；其他可行类型继续。
- 缺失某个普通主源时不调用该提供者，摘要报告 source 与 notProvided/failed，其他类型照常返回。部分源可以交给原提供者，但批次不能声称完整。子任务和图片的父/拥有者、墓碑的组上下文属于必要依赖；仅标签墓碑不读取其他家庭与图片。非标签墓碑可能含图片上下文，完整图片身份/保护检查需要同批跨类型拥有者。无关剪贴板模式、记录预算与其他主源不触发读取。
- 每种 provider 在固定选择表中只出现一次，入口没有响应投递/重放通道。现阶段不建立分发框架、缓存、并发任务或重复响应协议。
- 返回 order=temporaryProviderThenInput：保留提供者自己的结果顺序（包括显式标签目录视图、墓碑原分组顺序和记录原枚举顺序），无评分、全局结果上限、重排或分页。该顺序不称为相关性排序。

#### 身份、安全投影与来源诊断

普通结果使用 CommandObjectReference(type, UUID)；执行记录使用 routineOccurrence＋routine UUID＋dayKey。相同 UUID 的不同类型、定义与每日记录、父子、图片与拥有者、标签与同名记录均合法并存，不跨类型合并。单份响应内同类型同业务身份重复时全部隔离，即使值完全一样也不能作为 first-wins；原提供者已报告的重复输入继续保留对象/输入下标及不完整性。相同 CheckSnapshot 的归并警告仍由 2C-1/2I 区分，不误当重复响应或正常结果冲突。图片关联诊断不含隐藏图片 ID，聚合不得回查原输入补出冲突身份。

readings 的枚举分支是诊断来源；其中 coverage/typeAnalysis 与原 diagnostics 的 object、conditionID(s)、inputIndices/positions 保留影响类型、条件及输入位置。墓碑 request 级原因使用该 reading 的 requestedTypes，对象级原因使用其 type。全局 textDiagnostics/conditionDiagnostics 只从唯一 Session 提供一份；不跨 provider 合并原因或按错误文本去重。摘要的 determiningDiagnostics 是指向该来源诊断的限制类别，不替换或删除原明细。图片 associationDiagnostics、公开 owners/associations 原样保留，不统计其条数推断隐藏图片数量。

结果不持有批次或原始快照请求，不回补被提供者遮罩的手记正文，不展开 hiddenTitle，没有隐藏图片 ID/数量/文件名。所有新输入/结果包装的 description/debugDescription 脱敏，测试用合成标记递归检查实际存储字段。引用仅供读取关系；无 URL、实体、闭包、认证票据或执行能力。Todo 安排日、Subtask 父安排日、Diary 归属日、Image 附加时间/owner 业务日、Routine 存在性见证及 Occurrence 执行日保持原语义；不补造记录 createdAt，不把见证日设为操作日。原字段依据和真实时间供后续独立排序/片段设计使用。

#### 完整性、展示计数与剩余工作

批次不 AND 各提供者 isCompleteForCoveredTypes。Completeness 同时提供 queryState、requestedTypes、possibleTypes、evaluatedTypes，以及按来源分组的 limitations/hints：

1. 结构/命令由 queryState 区分；静态矛盾、字段不适用、需要参数保留 assessment 全部 reasons、binding、conditionIDs。缺记录窗口/日期环境由原响应 state/diagnostic 区分。
2. 主源 notProvided/failed/partial 与提供者覆盖单列；实际 evaluatedTypes 不能由“已支持”或“被请求”推断。墓碑 restrictedTypes 和记录 didEnumerate 继续收窄实际评估。
3. 对象级未知列表、输入歧义/冲突与 provider 诊断原样保留。能力缺失不当字段不适用；AND/OR 已消解的影响仍保留诊断提示，不重新运行条件。
4. 图片 associationCoverage 与 nonPublicCoverage 分开；手记已知元数据命中的隐藏展示只作 nonPublicPresentation 提示，不凭隐藏正文直接宣称匹配未知。实际正文/has:image 未定仍沿原对象与诊断反馈；记录 has:image 的保护问题若已被其他确定不匹配条件消解，只保留 nonPublicCoverage 提示和原诊断，不重新制造匹配未知。墓碑固定 imageDisplayLimited 保守阻止全范围完整性声明，不按是否有隐藏图改变形状。
5. 执行记录的历史、记录、枚举、review 分开汇总；原 coverage.gaps、weekdayMask、unprocessed 窗口、unprocessedCheckIndices、workUsed/resultRowsUsed 与具体预算原因全部保留。review/冲突/异常/未知占位不进入 matches 或命中数；枚举截断不是聚合分页。
6. 标签 frequent 的 usage 问题只影响排序/统计可用性；聚合将其归为提示并保留原诊断标志，不否定已知名称成员资格。recent/unused 的未知成员仍限制完整性。原 ordering.requested/applied/isComplete 可检查；没有改 TagQueryProvider 或复制目录规则。

definiteMatchCount 只数安全确定 matches；visibleGroupCount/visibleContextCount 只适用于墓碑展示。TrashQueryGroup.source、displayAnchor、matches、context 和 TrashRestoreConditions 保留原提升/分组语义；非命中父项/兄弟仅为上下文，不计命中、不默认成为目标。零个可见图片不代表没有隐藏图片。

canDeclareCompleteNoMatch 仅在结构有效、请求类型非空、所有请求类型均有来源摘要、无任何匹配完整性限制且 definiteMatchCount=0 时成立。它只描述本批声明的注入范围；不是全库或事务证明。空结果同时有缺源、静态限制、未知、保护或记录剩余时必须为 false；排序提示可以与完整匹配判断并存。

#### 排序、片段、键盘与分页前仍需定稿

- 各类型的相关性依据和稳定并列规则：缺自身日期的标签/执行记录、只有日期见证的定义、不同业务日期不能靠一个伪造 createdAt 排序。
- 安全片段协议：原 UTF-16 依据指向哪个结果字段/原文、多个依据如何截取、隐藏手记只显示何种说明；记录标题只是关系上下文，不能伪装自身文字命中。
- 墓碑按命中还是按展示组分页、上下文如何跟随提升、键盘如何区分命中和非操作上下文；不能把组数替换命中数。
- 2I 工作/结果预算与未来全局分页/继续读取协议的关系，包括未知区间、待核对与无法归属下标；本轮没有续读游标或最终总数。
- 真实含墓碑枚举、同身份覆盖、孤立子项、可靠历史来源与保护资料如何原子读取；随后才可定义异步查询代次、隐私失效、锁定撤回及跨线程责任。

这些问题只登记，不实现后续服务框架、排序/片段、统一键盘序列、分页/缓存或真实适配。本阶段结束后停止。

#### 本轮验证与交接（2026-10-02）

新增测试与夹具：[ContentQueryBatchSelectionTests](../AreaChainTests/Domain/ContentQueryBatchSelectionTests.swift)、[ContentQueryBatchCompletenessTests](../AreaChainTests/Domain/ContentQueryBatchCompletenessTests.swift)、[ContentQueryBatchProtectionTests](../AreaChainTests/Domain/ContentQueryBatchProtectionTests.swift)、[ContentQueryBatchOccurrenceTests](../AreaChainTests/Domain/ContentQueryBatchOccurrenceTests.swift) 及 [ContentQueryBatchTestSupport](../AreaChainTests/Domain/ContentQueryBatchTestSupport.swift)。共 **30 项**，全部从原文/Parser/Session 或合法类型化 Session 经批次装配调用真实只读提供者；不手工拼响应。完整、缺失、失败、部分源均为合成资料。

| 检查 | 实际结果与边界 |
|---|---|
| 最终集成及提供者回归 | `./scripts/build.sh test` 配 69 套 `--only-testing`，**477 passed / 0 failed / 0 skipped**。涵盖 30 项新批次测试、完整查询/页面/转交、九个提供者、图片关联/has:image、墓碑、习惯历史与记录回归。精确命令见忽略目录 `build/ContentQueryBatchQA/regression-command.json`；regression-summary.json / regression-tests.json 保存汇总及结果树。 |
| 最终结果包 | `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_10-20-20-+0800.xcresult`；Domain 与其测试文件在此次回归前后摘要一致，见 source-before.json / source-after.json。并行 UI 文件不在本轮行为验收声明内。 |
| Debug 构建 | 最终 Swift 编辑与回归后 `./scripts/build.sh` **passed**，build/ContentQueryBatchQA/build.log 中 staticSignatureVerified=true、distributionReady=false。此前等待原构建锁，不中止其他会话或更改锁/签名配置。没有安装或启动生产应用。 |
| 严格局部 lint | `swiftlint lint --strict --quiet AreaChain/Domain/ContentQueryBatch*.swift AreaChainTests/Domain/ContentQueryBatch*.swift` **passed**；源码/测试均低于 500 行。 |
| 静态、工作流与脚本 | `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check` **passed**；静态门禁含原脚本回归 **178 项通过**，高风险/敏感日志候选均 0。最后仅改文档并重跑受影响门禁。未修改并行检查器接口或另建专项执行脚本。 |
| 指定复核 | Cursor verifier **未执行，整体 partial**；当前可调用工具无指定入口，按本次要求不重复登录/认证检查，不用测试、主代理自查或其他代理冒充指定复核。旧阶段缺口继续保留。 |

先后修正了新调用的 Swift 参数标签及测试对非 Equatable 日期环境的比较方式，未改日期契约。自查补充标签墓碑的最小读取范围、主源部分覆盖限制，以及已由其他条件确定不匹配时保留保护提示的反例；上述最终回归包含这些修改。保留既有编译警告与并行改动，没有扩展 UI 修复或全量原生验收。

本阶段只新增六个 Domain 文件和五个测试/夹具文件，并在本权威文档、架构、组件目录与技能路由增量交接。没有改九个提供者的匹配算法、持久化模型、原生产消费者或执行/认证边界。真实仓储、系统权限、原生 UI、异步/跨线程失效、安装与发行未运行；不宣称完整全库一致性或旧阶段已验收。没有提交、推送、安装、发布、生产应用启动，也不进入下一阶段。

### 9.29 阶段 2J-2A：安全聚合结果的相关性与最近排序

2026-10-02 已确认本阶段仅排列 2J-1 已返回的确定命中，不改变集合、不重新读取提供者、不接真实仓储、UI、片段、分页或缓存。历史指定 Cursor verifier 与验收缺口保留，限定授权不表示此前阶段已验收。

#### 已确认规则与实施边界

- 明确提供 relevance（相关性）和 recent（最近）。相关性依次为：自身名称完整匹配；全部正向文字条件命中自身名称；部分命中自身名称、其余命中适用其他字段；仅其他字段命中。受限或无公开文字证据也落最后档，单独返回原因，不猜测隐藏字段。
- 正向文字仅未排除的普通词/短语；结构化标签、日期、状态与排除条件不加权。OR 按实际满足分支的 conditionID/alternativeIndex 判断，不要求所有替代词出现；重复条件不重复加权，一个条件的证据不能顶替不同 AND 条件。单一去重词/短语且无 OR 歧义、公开名称证据范围覆盖整个字段时才判完整匹配；多词/OR 保守使用后续档，不拼接搜索串。
- 自身名称仅任务/习惯标题、子任务自身标题、标签名称和图片文件名。父/拥有者标题不是子项名称；手记/剪贴板首行不作为标题，执行记录所属标题不作为自身文字。不使用置顶、类型权重、隐藏正文位置/次数/长度。
- 无正向文字回退 recent，返回实际模式与原因。显式剪贴板 mixed/exact 只消费原 modeEvidence，公开有效非空范围可作为其他字段依据；regex 不拆成关键词、不重跑表达式，缺可比较正向文字时明确回退 recent。模式依据不生成名称高档。
- 最近时间只用真实 createdAt、剪贴板 copiedAt、执行记录 dayKey；标签无自身创建时间，不借关联使用时间。缺失或坏时间排在有时间之后，不借修改/置顶/删除时间，不把哨兵值当真实时间。
- 使用同批显式 Calendar/时区：先民事日降序，同一天精确时刻在仅日期之前，精确时刻再倒序；只日期保留日键，不伪造时刻。最后按类型稳定 rawValue、UUID、执行日打破完全并列，不用 hashValue、输入或字典顺序。
- 批次绑定不可变最小排序上下文；排序 API 不接受另一个 Session 或原始对象。检查证据条件引用、替代分支与字段范围；坏证据不能升级排名。原安全投影和完整性/保护/诊断仍保留，结果只声称本批已知子集有序。
- 墓碑非命中上下文不参与排序或命中数。原 groups、关系与恢复条件保持；平面命中序列不是最终墓碑布局，展示组顺序、键盘进入子项和分页留待后续。

#### 已确认、留待 2J-2B 的片段规则

默认最多两行摘要，选覆盖更多正向词的紧凑片段；排除条件不高亮。私密手记不产生正文片段、范围或长度信息；图片仅文件名和所属信息；执行记录不伪造正文。复用各类型安全投影，不补回隐藏字段。两行是未来 UI 排版要求，字符数测试不代替原生两行验收。本轮不实现这些规则。

#### 实际接口与保守判据

| 接口 | 本阶段实现与后续复用 |
|---|---|
| [ContentQuerySorter.sort / ContentQuerySortedResponse](../AreaChain/Domain/ContentQuerySort.swift) | 只接受原响应和明确 mode；requested/applied/fallback、ordered、onlyKnownSubset 与 source。ordered 每项为 CommandObjectReference、可选 tier、reason、time；source 原样保留原批次完整性、保护限制、类型分析、诊断和 groups。 |
| [ContentQuerySortContext](../AreaChain/Domain/ContentQuerySortContext.swift) | BatchReader 同次构造，Response 以 let 持有；conditionIDs、clauses 的原 id/terms、dates、explicitMode、hasExplicitText。没有第二份 Session 或完整输入字符串，显式模式仅保存模式及非空标记，不保存正则原文。 |
| [ContentQueryRelevance](../AreaChain/Domain/ContentQueryRelevance.swift) | 单个条件只读取同 ID 的 alternativeIndex，检查未排除 text、positive、允许字段和 UTF-16 范围。未知 ID、坏替代项/范围或 owner 冒用不能升档，返回 invalidEvidence；无证据返回 noPublicTextEvidence，隐藏正文返回 protectedText。 |
| [ContentQuerySortFields](../AreaChain/Domain/ContentQuerySortFields.swift) | 从原安全 Match 短暂取得公开字段核验范围，不存入排序键或解释；不访问父/owner 标题、不展开 hiddenTitle。 |
| [ContentQuerySortTime](../AreaChain/Domain/ContentQuerySortTime.swift) | source、day、instant、issue；执行日只有 day，缺失/非法/无效日期环境只有原因，无伪时间。比较固定按档位、民事日、时刻存在性、精确时刻、类型 rawValue/UUID/dayKey。 |
| [BatchReader](../AreaChain/Domain/ContentQueryBatchReader.swift) / [BatchResponse](../AreaChain/Domain/ContentQueryBatchResult.swift) | 仅新增绑定上下文，原安全投影、匹配与聚合完整性未重算；[Evidence 契约](../AreaChain/Domain/TodoQueryRead.swift) 明确相同 requestID 不足以证明查询一致。 |

OR 的正向实际满足分支中有名称依据即可覆盖该组，不要求所有替代词；若该组仅由合法 absence 排除分支满足，则它不贡献正向文字，也不要求正向替代词命中。不同 AND 条件必须各有自身证据；重复相同条件只影响原诊断，不加分。最高档要求去重后唯一单词/短语条件、无 OR，且公开名称的范围覆盖全字段并通过不计大小写/变音的全文相等检查；组合字符扩展范围本身不证明完整相等。其余组合即使名称全部覆盖也保守为 allName。

统一查询存在正向文字但某条结果无公开文字依据时保留 relevance，以 otherFields 加受限原因表达；不会反推隐藏证据。显式 mixed/exact 只有同模式、有效非空公开 modeEvidence 可作为 otherFields；空依据、空查询或 regex 回退 recent。显式模式不会伪造统一条件 ID，也不比较模式命中的位置、次数或长度。recent 模式不作分档，tier=nil，reason=recentOnly，fallback 只在实际回退时非空。

时间环境必须是能按原日期协议往返的显式公历/时区，坏环境给 invalidDateEnvironment；非有限、超出原协议范围及 distantPast/distantFuture 哨兵给 invalid，不写入 day/instant。无时间与坏时间在同档有时间之后，彼此按稳定身份，不按错误类别给产品权重。仅日期在同日所有精确时刻之后，未给其创建零点时刻；类型只在时间完全并列后比较。onlyKnownSubset 依据原 matchingIsComplete，false 也仅指本批声明范围完整，不代表全库或真实读取完整。

2J-2B 可直接复用 source.readings/matches 的安全 Match、ContentQueryMatchEvidence 的 conditionID/alternativeIndex/field/kind/range/relatedObject、剪贴板 modeEvidence、同批 clauses 及 ordered.id。片段应沿对应安全字段取值；排序解释不保存正文、文件名、命中范围、频次或长度。墓碑 groups 原样保留，片段、组布局和分页仍未实现。

#### 本轮验证与停止交接（2026-10-02）

本轮新增五个 Domain 文件（Sort、SortContext、SortFields、SortTime、Relevance）和四个测试/夹具文件；最小扩展 BatchReader/BatchResponse，更新 TodoQueryRead 的同批证据注释及原有权威文档、架构、目录、路由和工程交接。保留开工已有 2I、2J-1、Picker/设置/标签管理、工作流检查器及持续并行文档修改；未修改提供者匹配算法、检查器接口或新增执行器。

新增 [ContentQueryRelevanceTests](../AreaChainTests/Domain/ContentQueryRelevanceTests.swift)、[ContentQuerySortTimeTests](../AreaChainTests/Domain/ContentQuerySortTimeTests.swift)、[ContentQuerySortIntegrationTests](../AreaChainTests/Domain/ContentQuerySortIntegrationTests.swift) 与[合成夹具](../AreaChainTests/Domain/ContentQuerySortTestSupport.swift)，共 **27 项**。覆盖四档/跨类型、短语/OR/重复/排除、证据引用/字段/范围反例、父与 owner、正文首行、隐藏正文不干涉、置顶、真实时间来源/时区/混合精度/缺失与坏值、身份/洗牌/比较器性质、显式三模式、墓碑上下文、部分源和 Parser→Session→BatchReader→Sorter。合成无效安全 Match 只用于排序边界反例，其余集成经原提供者读取，不接真实数据。

| 检查 | 实际结果与限制 |
|---|---|
| 最终 Swift 回归 | `./scripts/build.sh test` 配 72 套 `--only-testing`，**504 passed / 0 failed / 0 skipped**；包括上述 27 项、原批次 30 项、完整查询/页面/转交及九类提供者、关联/墓碑/习惯历史与记录回归。精确命令在忽略目录 `build/ContentQuerySortQA/regression-command.json`，日志及 summary 同目录。 |
| 结果与输入一致性 | `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_10-58-46-+0800.xcresult`。回归前后 Domain 与 Domain 测试文件 SHA-256 完全一致，source-before.json / source-after.json 留存证据；不把并行 UI 的行为纳入本次验收声明。 |
| Debug 构建 | 最终 Swift 回归后 `./scripts/build.sh` **passed**；build/ContentQuerySortQA/build.log 的 staticSignatureVerified=true、distributionReady=false。没有安装或启动生产应用，构建不表示系统解锁/发布验收。 |
| 严格局部 lint | `swiftlint lint --strict --quiet` 覆盖 ContentQuerySort*.swift、ContentQueryRelevance.swift、ContentQueryBatch*.swift、TodoQueryRead.swift 及新增测试，**passed**。所有新增文件低于 500 行。 |
| 工作流、静态与脚本 | `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、`git diff --check` **passed**；静态门禁含当前原脚本回归 **179 项通过**，高风险与敏感日志候选均 0。最终文档编辑后重跑受影响门禁。 |
| 指定复核 | Cursor verifier **未执行，整体 partial**。当前可调用工具无指定入口；未重复登录检查、改认证或以其他代理/主代理自查冒充指定复核。历史阶段缺口继续保留。 |

首轮编译发现新局部变量遮蔽辅助函数名，已显式限定 Self 后修复；新增测试先 22 项、补边界后 25 项通过，最终 27 项纳入上述 504 项回归。保留原有 actor/Sendable、AppKit 弃用和构建目的地警告，未扩大修改面处理无关 UI。纯领域阶段不运行无关全量原生 auto/swift profile；本轮没有真实仓储读取、文件读取、系统认证、安装、发布或生产应用启动，没有提交或推送。

已在 2J-2A 停止。2J-2B 只有已确认规则和可复用接口，没有片段实现或原生两行验收；墓碑展示组顺序、分页、缓存及真实读取完整性仍未处理。


### 9.30 阶段 2J-2B：安全摘要、命中片段与高亮映射

2026-10-02 本轮只消费 2J-2A 的安全排序响应生成纯展示值。保留开工已有 2I、2J-1/2A、设置/Picker、测试宿主、工作流检查器及文档的并行修改。当前可调用工具没有指定 Cursor verifier；按本轮要求不重复登录检查、不改认证、不用其他代理或主代理自查冒充指定复核，整体保持 **partial**。本次限定授权不关闭任何旧阶段验收缺口。

#### 接口、身份与共享边界

| 接口 | 本次职责与消费者 |
|---|---|
| [ContentQueryPresenter.project](../AreaChain/Domain/ContentQueryPresenter.swift) | 输入同一个 ContentQuerySortedResponse、明确 budget/locale；唯一生产来源是 source.matches 与同批 sortContext。输出 rows 严格跟随 ordered.id，顶层只保留一次原 sorted/source。当前仅新增领域测试消费，没有 UI 或服务接线。 |
| [ContentQueryPresentationResponse / Row / DisplayText](../AreaChain/Domain/ContentQueryPresentation.swift) | 行含稳定身份、可选 primary/summary、结构化 reasons/relations/metadata、公开内容省略标记、公开字段 expansion 引用及机器诊断。原来源、排名、计数、保护、覆盖、组和完整性不重算。 |
| [ContentQuerySortFields](../AreaChain/Domain/ContentQuerySortFields.swift) | 排序与片段共用同一安全字段提取和 positiveText 条件/范围门槛；没有复制九类全文提取器。排序保留原 String 范围校验，展示额外复用一次建立的 NSString 索引检查 surrogate 边界；不会因展示的更严校验改变原排名。 |
| [ContentQueryPresentationEvidence](../AreaChain/Domain/ContentQueryPresentationEvidence.swift) / [EvidenceRules](../AreaChain/Domain/ContentQueryPresentationEvidenceRules.swift) | 条件 ID、合法 OR 分支、排除/中性、字段类型、允许的 parent/owner/related 引用和 UTF-16 范围核验。SortContext 最小增加同批 presentationConditions，保存无宿主位置的条件值以核验元数据分支，不新增 Session、原始快照或替换查询参数。 |
| [ContentQuerySnippet](../AreaChain/Domain/ContentQuerySnippet.swift) | 在已知合法范围周围枚举有界候选，选择窗口、字素收边、插入省略号和生成原文/片段映射。 |
| [ContentQueryPresentationDetails](../AreaChain/Domain/ContentQueryPresentationDetails.swift) | 只处理已公开的元数据和所属关系；隐藏主展示直接使用 DiaryQueryPresentation.hiddenTitle，日期保留 DayKey 等既有字段语义，标签沿已有颜色和统计安全值。 |

按完整 CommandObjectReference（类型、UUID、执行日）定位，禁止仅 UUID 回退。缺失/歧义 source 身份或 ordered 重复时，该位置保留身份与明确诊断，不挑 first-wins 对象；source 中未出现在 ordered 的身份给顶层诊断，不私自补行。墓碑 context 不进入 rows、命中数或 expansion；原 TrashQueryGroup/source/displayAnchor/关系完整保留在顶层来源。展示引用不是恢复、选择或执行资格。

#### 技术预算、窗口与映射

默认技术预算为 maxUTF16=160、contextUTF16=24、maxEvidence=128、maxCandidates=64；可显式注入。合法上限分别为 16384、maxUTF16、4096、256，非法参数返回逐行 invalidBudget，不静默修改输入或削减命中集合。每条结果只检查有界依据前缀；超限报告 evidenceLimit。条件去重仅在被检查的依据中进行，重复相同语义条件只投一票，保留其各自条件来源；重复依据不加权。

每个已知范围最多提出两个窗口起点（命中前 context、命中起点），候选达到上限即停止；没有窗口组合幂集。先比较不同正向条件覆盖数，再比较实际覆盖跨度和稳定原文位置。mixed 的非连续范围共同证明同一次模式命中：可完整容纳全部已知范围的窗口优先；不会把字符伪装成统一条件 ID。短字段能完整放入预算时保留原字段；长字段再在获胜窗口内保留紧凑命中区及上下文。

全文只作已公开字段的 UTF-16 索引，不为候选复制长字符串；实际字符串只为选中的片段构造。普通文字只在提供者给出的范围内核验字面内容，且其字素扩展必须恰好对应该范围，拒绝过期/扩大范围。此核验不发现新位置、不重跑全文搜索、模糊匹配或正则。提供者可能只保留字段首个命中，因此本阶段仅声称“在已知证据和预算内选择”，不声称全文最优或实测性能基线。

保留原文换行和空白，不压缩，不解析 Markdown、HTML、URL 或 /指令。原始证据使用 UTF-16，校验后高亮扩到完整字素；截取边界向内收拢，不切开 surrogate pair、emoji、组合字符。开头单个字素放不进预算时无片段并给 graphemeExceedsBudget；已知命中整体放不进预算时给 hitExceedsBudget，不伪装成完整的局部命中。公开字段仍可作为展开引用。ContentQueryTextMapping 分别保存原字段范围和片段范围；首尾省略号是额外展示字符，不进入映射或高亮。重叠高亮合并外观范围，同时 contributions 保留各条件的原字段/片段子范围；不跨不相邻范围涂满间隙。本版每个摘要只输出一个连续窗口，不拼接两个远离片段。

#### 各类型回退与隐私

- 任务/习惯：主标题；仅备注存在合法文字依据时附命中附近摘要。仅标题、元数据或无正向文字时不无条件堆备注。
- 子任务：自身标题及 parentTask 引用；活子任务使用原 parentTitle。墓碑未公开父名称时只给真实类型引用，不从其他原始输入补名，也不制造父标题高亮。
- 公开手记：正文命中附近摘要；无正向文字（包括仅排除条件）可使用公开开头。正向文字仅命中标签等元数据时省略正文摘要，返回 metadataOnlySummaryOmitted 和真实结构化理由。无合法公开文字依据时返回 noPublicTextEvidence；不影响已确定的匹配。
- 隐藏手记：仅原隐藏标题、允许的日期/置顶/标签元数据。没有正文摘要、范围、长度、截断或展开引用；公开投影相同时输出相同，不检查占位标题推测正文。
- 图片：filename 及原安全 owner 类型引用；当前安全图片投影没有拥有者名称，不从同批其他命中或原始输入补回。受保护图片没有新增明细、读取、预览或打开入口。
- 标签：原名称、已有允许颜色和使用统计状态；不查真实标签库，缺名字的关联只保留引用。
- 剪贴板：仅 plainText；统一查询回退同公开手记。显式模式只消费 modeEvidence，mixed 可分段高亮，regex 零长度只给 zeroLengthModeMatch，不伪造字符。无合法范围仍给安全开头及 noLegalModeRange，不重跑模式算法，不展开富文本或文件负载。
- 执行记录：所属习惯标题/引用、执行日和状态；没有伪造自身标题/正文片段。
- 回收站：同类型安全展示加原删除时刻与关联说明；非命中上下文留在原组，未发布的正文/图片信息不恢复。

omittedPublicContent 表示公开字段有内容因技术截取或简洁策略未显示；策略省略不自动生成省略号或展开按钮。expansion 只指向实际被技术预算截取的公开原字段，canRequestExpansion 由这些引用决定。行内不复制原全文或整个 BatchResponse，也不持有文件、实体、权限或执行闭包。新增展示容器、元数据、关系及诊断的 description/debugDescription 默认脱敏；合成测试覆盖数组和嵌套可选值，不记录用户正文。

#### 两行、展开与后续待定问题

lineLimit=2 与 canRequestExpansion 仅为呈现契约。本阶段没有原生字体/宽度测量、真实展开/收起、键盘导航、组布局、分页、异步查询、缓存、锁定失效或真实读取/认证接线。UTF-16 预算测试不证明两行已验收。

下一阶段需先定稿：平面 ordered 与墓碑分组布局如何共存；键盘如何区分独立命中、提升项和非操作上下文，如何进入/退出展开摘要及保持焦点；分页按命中还是按组计量、上下文如何跟随，稳定排序与继续读取如何绑定同一批次；2I 剩余窗口/未知范围与全局页边界的关系；原生双语宽度下两行与展开控件的布局。上述事项仅登记，本阶段完成后停止。

#### 本轮验证与停止交接

本轮新增六个 Domain 文件（Presentation、Presenter、PresentationDetails、PresentationEvidence、PresentationEvidenceRules、Snippet）和五个测试/夹具文件；最小修改 ContentQuerySortFields、ContentQuerySortContext、ContentQueryRelevance，增量更新本权威文档、架构、组件目录及技能路由。没有修改原提供者匹配、UI、持久化、检查器或认证边界。排序的字段提取及原范围/排名行为继续由旧回归证明。

新增 [ContentQueryPresentationTests](../AreaChainTests/Domain/ContentQueryPresentationTests.swift)、[ContentQuerySnippetTests](../AreaChainTests/Domain/ContentQuerySnippetTests.swift)、[ContentQueryPresentationBoundaryTests](../AreaChainTests/Domain/ContentQueryPresentationBoundaryTests.swift)、[ContentQueryPresentationProtectionTests](../AreaChainTests/Domain/ContentQueryPresentationProtectionTests.swift) 与[合成夹具](../AreaChainTests/Domain/ContentQueryPresentationTestSupport.swift)，共 **34 项**。覆盖九分支及六种墓碑字段、标题/备注/后段正文、OR/重复/排除、紧凑与稳定窗口、中文/emoji/组合字符/换行、重叠条件贡献与省略号映射、无效/过期/错类型/错关联依据、显式模式、无文字开头、双语隐藏投影不干涉、图片无名称回填、记录无正文、组上下文不提升、身份/计数/完整性和百万 UTF-16 单位长文/候选预算。身份反例经最后加严，确实复用 source 已有 UUID，仅改变类型/执行日；不是仅用一个从未出现的 UUID 证明不回退。

| 检查 | 实际结果与边界 |
|---|---|
| 排序/聚合/提供者及展示回归 | `./scripts/build.sh test` 配 76 套 `--only-testing`，**538 passed / 0 failed / 0 skipped**；包括 34 项新测试及原 504 项查询、排序、聚合、九类提供者、关联、墓碑和记录回归。精确命令为忽略目录 build/ContentQueryPresentationQA/regression-command.json。 |
| 回归来源与结果包 | 回归到 Debug 构建的 Domain 与 Domain 测试 SHA-256 一致：source-before.json、source-after.json、source-after-build.json。原包 Test-AreaChain-2026.10.02_11-41-37-+0800.xcresult，独立保留在 build/ContentQueryPresentationQA/Regression.xcresult；summary 与完整结果树同目录。并行 UI 文件不在本轮行为验收声明内。 |
| 最后身份断言加严 | 只修改一个测试中错误身份的 UUID，使其与 source 真正相同；生产源码不变。四套展示测试最终复跑 **34 passed / 0 failed / 0 skipped**，随后 Debug 构建 **passed**；final-source-before.json / final-source-after.json 完全一致。final-targeted-command.json、final-targeted-summary.json、final-targeted.log 和 build.log 保存最终证据。 |
| Debug 构建 | 上述 538 项回归后 `./scripts/build.sh` **passed**，staticSignatureVerified=true、distributionReady=false。测试使用脚本的普通隔离路径，不开启真实钥匙串授权，没有安装或启动生产应用。 |
| 严格局部 lint | `swiftlint lint --strict --quiet` 覆盖六个新 Domain、三个共享修改及五个测试/夹具文件，**passed**；均低于 500 行。最终测试断言加严后已重跑通过。 |
| 工作流、静态与脚本 | `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、`git diff --check` **passed**。静态门禁含原脚本回归 **179 项通过**，高风险和敏感日志候选均 0；最终文档后重跑受影响门禁；未改原检查器接口或另建执行器。 |
| 指定复核与原生验收 | Cursor verifier **未执行，整体 partial**，不重复认证检查、不替代指定复核。原生实际两行、展开/收起、键盘及组/分页均未实现或验收；所有历史阶段缺口保留。 |

过程中修正了 mixed 单条件紧凑度可能只选末字符的问题、UTF-16 surrogate 半边拒绝、条件包装的嵌套描述脱敏、已公开标签关联的 UUID 核验，并区分完整命中超过预算与单个字素超过预算。失败测试与修复后回归不混记；敏感标记断言先计算布尔值，避免失败诊断展开合成正文。既有 AppKit 弃用、actor/Sendable、构建目的地警告仍保留。技术长文/窗口测试不是原生行数或性能 SLA 验收。

完成本阶段后停止；未提交、推送、安装、发布、启动生产应用或进入键盘/分页/真实读取阶段。

### 9.31 阶段 2J-3A：展示分组、可见命中序列与键盘选择

#### 2026-10-02 实施前确认

默认显示确定命中，未命中关联上下文收起。↑↓只遍历当前已展示的确定命中；标题、说明、上下文、未知和待核对项不进入序列。Return 请求打开当前命中，子任务保持自身定位及父导航，执行日保持日期，回收站只请求查看。Tab 可达展开按钮与上下文控件，但不混入命中序列。输入编辑器聚焦时现有编辑/补全优先。

多选仅保存确定命中身份；选择已展示与选择全部已知是两个显式事件，追加展示不自动扩大选择。折叠或翻页不删除多选，但活动对象不能不可见。刷新/重排按稳定身份保留，消失对象清除，活动对象消失请求回到输入框，不按相似标题替换或自动选另一个可执行对象。浏览选择不创建、修改或清空 CommandDraftTargets，也不证明最新业务授权。

展开不抢焦点；收起隐藏当前控件时返回其展开按钮。正文展开仅使用已有 ExpansionReference，隐藏手记没有正文入口。上下文控件显式指定目标，不从当前命中猜目标。所有列表事件绑定展示版本；仅输出打开/焦点意图，不接 NSEvent、NSWindow、FocusState 或监视器。

普通搜索平铺。回收站仅沿已核实删除关联归组，组位置取组内排名最高的命中，组内沿全局排名；父未命中只是上下文，不参与排名。组身份与最佳命中分离；独立删除和未知关系不强制合组。缺失、歧义、冲突显式诊断，合法命中安全回退独立展示，不按标题拼接、不 first-wins、不从原始墓碑补回隐藏对象。

后续分页仅登记：普通按命中、回收站按组，默认每次 20 个展示单位且可配置；加载更多追加同批结果，大组可分段并明确已知未展示命中数。查询/排序/批次变化不能拼接旧页。本阶段仅接受显式已展示单位/成员，不实现页码、游标。

后续继续读取仅登记：与加载更多分开，沿同查询同快照处理剩余工作，数据变化发新查询；不支持安全增量时可同快照提高预算重算，但不称增量续读。新结果重新排序/分组，不能简单尾部追加；保留对象选择及可见位置稳定身份。历史不足、保护限制、冲突不能靠预算解决，不无限自动读取；取消保留最后完整发布版本。

#### 实际接口与 2J-3B 接入点

| 接口 | 本阶段契约 |
|---|---|
| [ContentQueryDisplayBuilder.build](../AreaChain/Domain/ContentQueryDisplayBuilder.swift) | 仅接受同批 ContentQueryPresentationResponse，沿 ordered 组装单位；不匹配、不排序、不生成摘要、不读取原始数据。校验组 ID、成员归属、命中/上下文分离及唯一性，缺失引用、冲突与独立回退分别诊断。 |
| [ContentQueryDisplaySnapshot / Unit / Context](../AreaChain/Domain/ContentQueryDisplay.swift) | 顶层唯一安全来源；普通 `.row(object)`、墓碑 `.trashGroup(source.id)`。hits 引用 Row，context 引用原 TrashQueryGroup.context。sourceGroup、displayAnchor、bestMatch 分别保存原组、原显示锚点和当前排名最佳命中，排名变化不改组 ID。 |
| `ContentQueryDisplayVisibility` | 显式单位集合＋成员集合，两者同时包含才可见；任意输入顺序不会重排结果。默认 all，支持组内子集。visible 为当前展示顺序，known 为全部合法确定命中集合，knownUndisplayedCount 及按单位重载提供已知未展示数量。没有页号、游标或自动追加。 |
| [ContentQueryBrowseState / Event / Action](../AreaChain/Domain/ContentQueryBrowse.swift) | active、selected、expanded 分开；只存类型化对象/控件身份。apply 消费版本绑定事件，publish 使用 replacing 当前版本比较并替换；已发布版本不可重放。状态内 snapshot 仅持有同份安全呈现来源，选择集合没有正文、实体或操作草稿。 |
| `ContentQueryBrowseOpen / Focus / Effect` | 仅返回打开/焦点意图及拒绝原因。打开携带实际对象、已有父导航和 viewingTrash；对象仍需最新业务核验。焦点可指输入、命中或明确控件；没有执行闭包、窗口或认证能力。 |

普通单位顺序与 ordered 完全一致。墓碑沿全局 ranked 身份一次累计各组成员，在第一次遇到该组命中时输出组；组内仍沿全局顺序。组内排列会让低排名成员显示在下一组之前，这是已确认的组布局规则，不改写 source.ordered。组引用整体不合法时，原合法命中沿 ranked 顺序独立出现，不携带未经核实的组上下文；源响应、覆盖和诊断仍保留。排序层缺失/歧义/重复身份无法提供确定可执行行时给 invalidHit 或沿 Presenter 的 unorderedSourceIdentity 保留诊断，不凭外部下标补行。

每次 build 生成独立 UUID 展示版本，包含本次安全响应、排序、分组与显式可见性；包括只改变成员可见性的发布。publish 必须给当前版本，旧事件返回 staleVersion 且无打开/焦点输出。同一批次刷新仍发新展示版本；不把 requestID 当数据库快照版本，不声称解决未来异步查询或真实隐私失效。

↑↓首次向下到首项、向上到末项，边界停留；只有显式 move/activate 才改变活动对象，不由快照发布选择替代对象。selectVisible 将浏览多选替换为当前序列集合，selectAllKnown 替换为全部已知集合，select(id, Bool) 显式增减。发布只做身份交集，不自动加入新对象。活动项不可见/消失时清空并请求输入焦点，不选替代命中；仍存在但隐藏的多选保留。保留选择不代表权限或执行资格。

contextToggle / bodyToggle 为稳定展开按钮身份，context / body 是明确目标的区域控件。toggleControls 与 reachableControls 提供 Tab 可达性，不实现系统 Tab 顺序；focusControl 只对当前可达控件发意图。展开不改变活动对象或请求焦点；收起隐藏焦点控件时回到对应按钮。发布隐藏控件时回到仍可达的对应按钮，否则回输入；活动命中消失的输入意图优先。expansionReference(for:) 只返回已有、已展开且可达的公开正文引用；没有给非命中上下文重新生成正文引用，隐藏手记无正文控件。

2J-3B 可直接复用 UnitID、units、hits、context、visibility.units/members、visible、knownUndisplayedCount 和版本绑定 publish。分页策略、20 单位默认、组内分段调度、加载更多与继续读取尚未实现；需由后续明确授权的宿主提供新的可见身份集合或完整重新计算的安全响应。本阶段没有生产消费者，实际消费者仅三套新 Domain 测试及合成夹具。

#### 本轮验证与停止交接（2026-10-02）

本轮新增三个 Domain 文件及三个测试文件/一个夹具；TodoQueryRead 中 ContentQueryMatchField 只从 Equatable 扩展为 Hashable，为类型化控件身份服务，不改变字段或匹配行为。更新本权威文档、架构、组件目录与技能路由；保留原有和并行的设置/主题/搜索修改，没有修改检查器接口、认证、原匹配排序或生产 UI。

新增 [ContentQueryDisplayTests](../AreaChainTests/Domain/ContentQueryDisplayTests.swift)、[ContentQueryBrowseTests](../AreaChainTests/Domain/ContentQueryBrowseTests.swift)、[ContentQueryDisplayProtectionTests](../AreaChainTests/Domain/ContentQueryDisplayProtectionTests.swift) 与[合成夹具](../AreaChainTests/Domain/ContentQueryDisplayTestSupport.swift)，共 **25 项**。覆盖平铺顺序、组最佳排名/子项提升/父子同时命中、上下文默认收起/不进入键盘、重复/缺失/冲突组回退、独立与未知关系、成员可见性、↑↓/打开/多选/两种全选、追加不扩选、展开/收起焦点意图、重排/对象消失/同名不替代、旧版本及重放拒绝、子任务/执行日导航、私密手记与受保护图片、未知/review 排除及 Parser→Batch→Sort→Presenter→分组→选择链路。

| 检查 | 实际结果与边界 |
|---|---|
| 最终 Swift 回归 | `./scripts/build.sh test` 配 **79 套** `--only-testing`：**563 passed / 0 failed / 0 skipped**，包含本轮 25 项及原 538 项排序、片段、聚合、九类提供者、墓碑、关联与记录回归。xcresult 按参数运行展开为 615 次，测试摘要按 563 项报告。精确命令为忽略目录 build/ContentQueryDisplayQA/regression-command.json。 |
| 证据与并行修改 | 回归前、回归后、Debug 构建后的 Domain 和 Domain 测试 SHA-256 一致。source-before.json / source-after.json / source-after-build.json 与 Regression.xcresult、regression-summary.json 保存在 build/ContentQueryDisplayQA。期间出现的并行 Theme/Features/资源修改保留，不纳入本轮 UI 行为验收。 |
| Debug 构建 | 回归后 `./scripts/build.sh` **passed**，staticSignatureVerified=true；只构建验签，未安装、发布或启动生产应用。普通测试未开启真实钥匙串授权。 |
| 局部 lint | `swiftlint lint --strict --quiet` 覆盖三个新 Domain、TodoQueryRead 及四个新测试/夹具文件，**passed**；所有新增 Swift 文件低于 500 行。 |
| 工作流与质量 | 最终文档后运行 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json` 和 `git diff --check`，均 **passed**；门禁内原脚本回归 **180 项通过**，高风险与敏感日志候选均 0。Swift 行为另由上述定向回归和构建验证，不运行无关全量原生 profile。原检查器接口/规则未改变，沿已有脚本回归，不新增执行器。 |
| 指定复核 | 当前可调用工具中没有 Cursor verifier，**未执行，整体仍 partial**。不重查登录、不改认证、不以主代理自查或其他代理冒充指定复核；本次限定授权不表示旧阶段已验收。 |
| 原生与后续范围 | 原生 UI、真实 Tab/焦点/键盘、分页、续读调度、指令执行均未实现或验收。纯状态用例不能证明原生行为；既有历史验收缺口继续保留。 |

实现停在 2J-3A；未提交、推送、安装、发布、启动生产应用或进入 2J-3B。

### 9.32 阶段 2J-3B：展示分页、组内分段与浏览状态接续

2026-10-02。本轮限定授权仅控制 2J-3A 已构造安全展示来源的可见范围。保留已有搜索、原生控件、文档和脚本的并行修改；不重新读取、匹配、排序、生成片段，不接生产 UI、真实焦点、滚动或预算续读调度。本阶段本地证据不关闭前阶段缺口；指定 Cursor verifier 当前无可调用入口，未检查登录、修改认证或使用其他复核冒充，整体 **partial**。

#### 来源与可见性版本

- [ContentQueryDisplaySnapshot](../AreaChain/Domain/ContentQueryDisplay.swift) 内部持有不可变 `ContentQueryDisplaySource` 引用，每次 `DisplayBuilder.build` 新建随机 `sourceID`。它绑定安全 PresentationResponse、排序/分组、诊断及安全身份索引，不能由调用方指定 ID 或替换已绑定内容；不使用正文散列或 requestID 推断同源。即使 requestID 相同、命中身份相同，新 build 也必须作为新来源。
- `version` 是单次展示修订的随机 UUID；`revisingVisibility` 只接受单位/成员/上下文身份集合，生成新 version 并共享原来源。`sharesSource(with:)` 可核对实际引用同一性。分页不会调用 build、Presenter、Sorter 或提供者；仅重建可见身份集合，不重复构建业务快照或片段。源数据仍为原安全值，分页进度不存正文。
- [ContentQueryPaginationStamp / Event / State](../AreaChain/Domain/ContentQueryPagination.swift) 同时绑定 sourceID 与 revision（即 snapshot.version）。加载事件必须携带产生时的 stamp；首次成功发布即使旧事件失效，同修订竞争事件也只能成功一次。拒绝时不改进度、浏览状态或修订，不发打开/焦点意图。没有接受任意数组追加的接口。
- `reset(to:replacing:focused:)` 要求当前 stamp 与未在本分页会话发布过的新来源；同源修订不能用来重置，已退役来源也不能重新发布。新查询、新排序、新读取批次均从首段重建，不拼接旧页。此接口是纯同步比较并替换，不宣称解决未来异步查询取消、仓储一致性或隐私失效。

#### 顶层、组内与上下文分页

`ContentQueryPaginationPolicy` 的 `units`、`members`、`contexts` 是三个独立额度，默认分别为 20。建立分页时三个值均须为正数，否则抛出 `invalidPageSize`；进度以 `count + min(size, total - count)` 计算，合法 Int.max 额度不会产生加法溢出。空来源仍能建立合法状态。

| 操作 | 单位与边界 |
|---|---|
| `loadMoreUnits` | 普通搜索每个命中行占一个单位；回收站每个既有组占一个单位，独立行也占一个。初始取前 units 个，之后扩展下一段，顺序完全来自 snapshot.units；组不会拆到多个顶层页。新出现单位初始化自己的成员/上下文前缀，已出现单位的进度保持。 |
| `loadMoreMembers(UnitID)` | 只接受当前已展示的回收站组，按 unit.hits 原顺序扩展前缀，不重新排序。最佳命中 hits.first 必在初始段；只影响指定组，最后一段可不足额度。普通独立行无需组内加载。 |
| `loadMoreContexts(UnitID)` | 与命中前缀独立，按 unit.context 原顺序扩展。分页始终显式提供有界 visibility.contexts；未加载的组、未知组被拒绝。上下文不占命中额度、不进入命中数或全选。 |

到对应末尾返回 `exhausted`，不生成新修订或任何读取需求。所有加载均须显式事件，不实现页码跳转、上一页、无限自动加载或真正的继续读取命令。

上下文默认仍收起。每个已出现组预分配有界上下文前缀，只有原 Browse 的 contextToggle 已展开时才暴露控件。`visibleContext(in:)` 表示该组可用的上下文范围；实际可达性还须经 `BrowseState.reachableControls`。Tab 不可进入前缀外或收起的上下文。`loadedContextCount` 与展开后的 `contexts.displayed` 分开；收起保留前缀进度，重新展开恢复该前缀。显式加载上下文不会自动展开。旧 2J-3A 调用可省略 contexts（nil 为其原全上下文语义），分页路径始终传入集合。

#### 浏览状态接续与稳定锚点

PaginationState 只组合一份既有 `BrowseState`，`applyBrowse` 委托其原事件入口；active、selected、expanded 仍只有原状态机这一份所有者。所有展示改变均调用版本绑定的 `publish`，旧版本浏览事件继续返回 staleVersion。

- 同源加载保持原活动身份、已有选择和合法展开，不自动选新命中、不抢焦点、不请求打开；新增命中自然进入原 visible 的 ↑↓序列，新增公开正文/上下文控件按原 toggleControls/reachableControls 契约暴露。
- selectVisible 只选择当前已展示确定命中；selectAllKnown 可选择来源中尚未展示的确定命中。两者均排除未知、review、非命中上下文和安全投影已隐藏的对象。浏览多选不复制到 CommandDraftTargets，保留身份不代表业务资格或权限。
- 新来源发布按原 publish 取选择与新 known 的交集，合法展开按可见按钮交集保留；不复用旧成员进度。活动对象仍在初始范围则保留；不在初始范围或已消失则清空活动身份并返回 `.input` 焦点意图，不按相同下标替换。
- `BrowseState.activeAnchor` 与 `PaginationEffect.previousAnchor` 提供 `ContentQueryBrowseAnchor(unit, hit)`。reset 返回发布前稳定身份供后续定位；这里只保存引用，不自动扩页、激活、选择替代对象或计算像素滚动。控件被新首段隐藏时，原 publish 回退到仍可达展开按钮，否则回输入；活动命中不可见时输入回退优先。

#### 计数、完整性与安全

[ContentQueryPaginationStatus](../AreaChain/Domain/ContentQueryPaginationStatus.swift) 输出 stamp、visibility、顶层 units、全局 hits、各组命中/上下文数量，以及原始 `ContentQueryBatchCompleteness`。`hits.known` 仅为已有安全确定命中数，`hits.displayed` 为 snapshot.visible.count；`remaining` 与原 `knownUndisplayedCount` 一致。组计数也只取 unit.hits/context，不从原始图片或墓碑输入补数量。

`hasMoreUnits` / `hasMoreKnownHits` / `hasMoreToLoad` 描述已读取内容的展示余量；最后一个还含未分配的上下文前缀，收起但已加载的上下文由 expand 控制。`hasProviderUnprocessedWork` 单独反映原执行记录提供者的 unprocessed / unprocessedCheckIndices 是否非空，不将其条数解释为未知命中数，不生成续读操作。

原 completeness 的来源/输入不足、历史/记录缺口、review、保护限制及非公开提示原样保留，细节仍沿 snapshot.source 访问同份安全响应。`canDeclareCompleteNoMatch` 直接沿原批次判断。展示到末段不意味着查询完整；提供者不完整也不妨碍加载已知命中；历史或保护限制不能解释成“加预算就能读取”。隐藏图片数量变化不能改变公开分页计数。State、Status、Display 的描述均脱敏，无全文游标、磁盘游标、隐藏计数或新权限能力。

#### 2J-3C 可复用接口与停止边界

后续预算续读若有独立授权，可读取原提供者余量/完整性，生成新的 Batch→Sort→Presenter→Display 来源后调用 reset，复用稳定选择与 previousAnchor；不能把旧源 loadMoreUnits 当续读，不能尾部拼接新读取结果，不能因同 requestID 复用旧页。锚点只有稳定组/对象身份，真实滚动位置、原生焦点、取消和最后完整发布、读取预算调度及安全增量能力均待后续实现与验收。

实际消费者为四套新 Domain 测试及合成夹具，原 Display/Browse/保护、排序/片段和提供者回归继续复用。没有新增检查器规则、脚本或生产消费者，文档/组件引用仍由原 check_workflow.py 与原脚本测试验证。指定复核和所有历史验收缺口继续保留。本轮到 2J-3B 停止，不进入 2J-3C。

#### 本轮验证与交接（2026-10-02）

生产代码新增 Pagination / PaginationStatus 两文件，局部扩展原 Display / DisplayBuilder / Browse；未更改提供者、排序器、Presenter、业务保存或认证。测试新增 [PaginationTests](../AreaChainTests/Domain/ContentQueryPaginationTests.swift)、[GroupPaginationTests](../AreaChainTests/Domain/ContentQueryGroupPaginationTests.swift)、[PaginationBrowseTests](../AreaChainTests/Domain/ContentQueryPaginationBrowseTests.swift)、[PaginationStatusTests](../AreaChainTests/Domain/ContentQueryPaginationStatusTests.swift) 共 **23 项**，共用 [QueryPaginationFixture](../AreaChainTests/Domain/ContentQueryPaginationTestSupport.swift)。本权威文档、架构、组件目录和技能路由同步；其他已有和并行修改保留。

| 检查 | 实际证据与边界 |
|---|---|
| 分页与直接消费者 | 四套新分页加原 Display/Browse/DisplayProtection，**48 passed / 0 failed / 0 skipped**；参数化展开 57 次。覆盖 0/1/19/20/21/整页/尾段、三个非法额度与 Int.max、防重放/跨源/旧浏览版本、组/独立行、安全回退行、独立成员/上下文进度、选择/展开/焦点意图、重排锚点、保护不泄露、预算与完整性分离。首轮两处夹具假设（独立墓碑的单成员组、无命中备注不提供展开）沿原契约修正，未修改产品规则。 |
| 最终扩展 Swift 回归 | `./scripts/build.sh test` 配 **83 套** `--only-testing`，**586 passed / 0 failed / 0 skipped**，参数化展开 **647 次**；包含本轮 23 项及原 563 项展示/浏览、排序、片段、聚合、九类提供者、墓碑、关联、查询和记录回归。精确参数位于忽略目录 build/ContentQueryPaginationQA/regression-command.json；同目录保存 Regression.xcresult、regression-summary.json 与日志。 |
| 源码与并行一致性 | Domain 及 Domain 测试在最终回归前、回归后、Debug 构建后 SHA-256 一致（source-before / source-after / source-after-build.json）；新文件集合也一致。并行原生主题/设置等不纳入本轮运行行为验收。 |
| Debug 构建 | 回归后 `./scripts/build.sh` **passed**，staticSignatureVerified=true；只构建验签，普通测试未启用真实钥匙串授权。保留原多架构目标选择警告；定向测试编译中的旧原生 API/并发警告不在本轮修改范围，不写成零警告。 |
| 严格 lint 与静态门禁 | `swiftlint lint --strict --quiet` 覆盖五个本轮 Domain 文件及五个测试/夹具文件，通过；最终文档后重跑 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、`git diff --check`，结果见同目录 workflow.log / quality.json。原静态质量门禁包含 **180 项脚本回归**；未改检查器接口/规则，不新增执行器。 |
| 指定复核 | Cursor verifier **未执行 / blocked，阶段整体 partial**。当前无可调用入口；不重复登录检查、不改认证、不以主代理自查或其他代理冒充指定复核。本轮授权不表示前阶段已验收。 |
| 未执行与停止 | 没有生产 UI、真实 Tab/焦点、像素滚动、预算续读调度或完整恢复算法的实现/验收；无关全量原生 profile 未运行。所有历史真实库、隐私、系统与发行缺口保留。未提交、推送、安装、发布或启动生产应用，完成本地开发验证后停在 2J-3B。 |

### 9.33 阶段 2J-3C：预算续读、同快照重新求值与结果发布协调

2026-10-02。限定使用注入值和既有同步领域管线。保留工作区前序搜索与并行原生控件修改；不接真实仓储、UI、系统线程调度、持久缓存、认证或业务执行。历史指定 Cursor verifier 与验收缺口保留，本阶段整体 **partial**，不把前阶段授权解释为验收通过。

#### 冻结来源、任务与展示版本

| 接口 | 所有权与职责 |
|---|---|
| [ContentQueryReadOwner](../AreaChain/Domain/ContentQueryReadOwner.swift) | 唯一保留冻结 ContentQueryBatch 及展示配置的运行内所有者。begin 接受新值输入并返回初始任务；continueReading 只接受来源令牌和预算，不接受另一组快照、查询、日期或响应。宿主须串行调用，无 Sendable/后台线程承诺。 |
| ContentQueryReadSource | 每次 begin 新建随机 generation；同一个 requestID、相同命中身份甚至相同 Batch 值再次 begin 也建立新来源。旧来源不能再求值、续读、完成或失败回写。 |
| ContentQueryReadTask | 独立随机任务身份、来源代次、原 Batch requestID、预算与 initial / sameSnapshotReevaluation 方法。requestID 保留提供者证据/输入下标关联用途，不能单独证明新鲜度；任务不保存正文、文件名、Batch 或执行闭包。 |
| ContentQueryReadTicket | 只能由本文件内的完整 evaluate 链签发，调用方不能拼装 Response 或替换候选；票据不是当前结果。描述脱敏，内部只保留原安全 Display 来源，不重复冻结输入。 |
| ContentQueryReadPublication | 最后完整发布任务及 PaginationState；响应经 pagination.snapshot.source 回溯原唯一安全展示链，不另存平行 Response。新来源正在准备、取消或失败时，这份结果仍标注原 source，不会被重标成新查询结果。 |

读取代次、单次任务身份、Batch requestID、提供者预算、Display.sourceID 与分页 revision 各自表达不同语义。加载更多可改变分页 revision，同时不改变读取任务；发布使用当时最新合法分页状态，而不是准备任务时的旧页戳。

冻结保证仅限 Swift 值输入：外部修改原 Batch、数组、辅助事实或模式不会改变所有者冻结的版本。evaluate 仅在调用栈中临时换入任务预算，完整调用原管线，不将源输入复制到各层长期保留。没有真实数据库事务快照或锁定失效接线；没有正文序列化、正文散列、日志新鲜度证明或新增权限。

#### 续读资格、预算增长与同快照重算

[ContentQueryContinuationRemainder / Policy](../AreaChain/Domain/ContentQueryContinuation.swift) 只从 evaluated 的 routineOccurrence 读取中识别 `coverage.unprocessed` 的 inputLimit / workLimit / resultLimit。无法归属记录的 unprocessedCheckIndices 还须有原提供者相应预算诊断。历史/记录不足、冲突、缺失来源、身份歧义、权限/保护、字段不适用、正则或展示片段限制均不生成续读维度。

- 加载更多只转交原 Pagination 事件；展示到末页不会触发读取。反之，只要有预算余量，不必先耗尽已知展示页。
- 调用方显式提供下一份 RoutineOccurrenceQueryBudget，原默认值仍为输入 4,096、工作 100,000、结果 1,000，没有自动加倍或循环。
- 本协调层技术硬上限分别为 **16,384 / 400,000 / 4,000**，策略 maximum 可再调小。选择原预算四倍作为本阶段有限复算空间，避免引入无限增长；这是工程约束，未建立生产数据规模、主线程性能或产品总量保证，不能据此扩大默认读取规模。
- 全部维度须合法、非递减且不超过策略上限，至少一个实际中断维度严格增长；只增加无关维度、重复预算、负数、减小预算或 Int.max 越界均拒绝。比较验证不做乘法/加法增长，因此没有预算倍增溢出。已到相关维度上限返回 atBudgetLimit，超限输入返回 budgetExceeded。
- attemptedBudget 记录本来源最近已接受的尝试，即使取消、失败或无进展也不回退，避免同预算重复启动；再次尝试必须显式提高相关预算。更换查询、日期解释环境、快照、保护事实、排序/展示或匹配模式都必须 begin 新来源。
- sameSnapshotReevaluation **从冻结输入重新运行全批 BatchReader**，不是增量游标，不从未处理下标起拼接，不声称只处理剩余数据。新响应完整替换旧响应；没有跨提供者结果合并器。

#### 准备、计算、发布、失败与无进展

1. begin 或 continueReading 生成绑定来源和随机任务身份的任务；同来源有 prepared / computing / awaitingPublication 请求时，继续读取返回 busy。
2. evaluate 核验来源、任务与 prepared 阶段，依次调用 **BatchReader → Sorter → Presenter → DisplayBuilder**，完整返回票据后进入 awaitingPublication。不能重复计算同一任务。
3. publish 再次核验来源、当前任务和阶段。只有完整候选通过检查并完成 Pagination.reset 后，才替换 published；已消费、被取消、失败、跨所有者或被新来源取代的票据均拒绝。
4. 继续读取若没有进入枚举、增加已处理结果/待核对行或推进实际未处理区间/下标，返回 noProgress，保留旧结果、分页、选择和锚点，清除忙碌状态。workUsed 增加或中断原因变化本身不算进展；不自动重试。continuationRemainder 仅更新最近完整求值的预算维度：例如工作预算变充足后才发现结果预算仍为零，下一次显式请求应提高结果预算；这份反馈不是发布新结果。
5. fail 只记录封闭失败状态，不接收可能泄露正文/文件名的原始错误字符串；丢弃任务发布资格并保留最后完整结果。提供者覆盖缺口仍由原 Response 表达，不把部分覆盖伪装成成功读取全部数据。

cancel 的结果明确为 **publicationCancelled**：取消结果发布资格，保留完整旧结果及合法浏览状态。当前同步函数执行中无法由此入口立即中断；测试用准备、求值返回和迟到发布事件证明拒绝，不声称正则或所有枚举即时停止，不强制终止线程。真实异步调度、合作式取消、CPU/内存和主线程预算仍待生产读取适配。

#### 分页重置、选择与身份锚点

[PaginationState.reset](../AreaChain/Domain/ContentQueryPagination.swift) 增加可选 `preservingActiveVisibility`，默认 false 保持 2J-3B 原行为；ReadOwner 发布时显式启用。reset 从新来源重建初始额度，内部沿当前 Browse.activeAnchor 的 unit/hit 寻找原对象，优先同组、再按稳定对象身份定位。能定位时只扩展到该单位及成员所需的最小前缀，其他新进入组保持初始成员/上下文额度，不复用旧下标或游标。

- 所有新结果重新聚合、排序、生成安全片段与分组；新增高相关命中或较新日期可进入前方，不能简单尾部追加。墓碑关系仍只来自原 TrashQueryGroup/DisplayBuilder。
- 选择、展开与活动身份继续由原 Browse.publish 管理；多选取原选择和新 known 的交集，新命中不自动加入。未显式选择任何新对象，不产生打开或执行权限。
- previousAnchor 返回发布前稳定身份，activeAnchor 返回新来源中的活动身份。对象消失时原 publish 清空 active 并返回 input 焦点意图，不选相邻下标；控件被首段隐藏时沿原可达展开按钮/输入框回退。
- 发布后旧分页 stamp 和旧浏览 version 均失效。同源准备/计算期间合法的加载更多和选择仍可发生，最终发布按最新状态恢复。
- 输出仅为身份锚点和焦点意图，没有像素滚动或原生焦点实现。无预算余量不等于全局完整；原历史、记录、review、保护、缺源与类型限制在完整性汇总中继续保留。

#### 来源失效与真实隐私边界

invalidateSource 是供未来隐私代次变化消费的显式入口，核验当前令牌后释放本所有者的冻结输入、最后结果、任务和预算；旧任务/票据/令牌不能再发布或续读。它与普通 cancel 的保留策略分开。未来保护边界变化须先调用失效入口，不能用普通取消或保留旧结果的新查询过渡代替敏感展示清理。

本阶段没有接锁定服务，也不能清理调用方已经持有的票据/结果副本、原生视图、展开正文或真实缓存。真实敏感结果清理、对外引用寿命、锁定中计算结果处置与锁后不可见性必须作为后续独立适配验收，不能从本值失效测试推断已实现。

#### 本轮验证与停止交接

新增生产文件 ReadOwner / Continuation，局部扩展原 Pagination.reset；没有修改匹配器、排序器、片段算法、分组规则或原提供者。测试新增 [ContinuationTests](../AreaChainTests/Domain/ContentQueryContinuationTests.swift)、[ReadLifecycleTests](../AreaChainTests/Domain/ContentQueryReadLifecycleTests.swift)、[ReadPublicationTests](../AreaChainTests/Domain/ContentQueryReadPublicationTests.swift)、[ReadSnapshotTests](../AreaChainTests/Domain/ContentQueryReadSnapshotTests.swift) 共 24 项，复用 [QueryReadFixture](../AreaChainTests/Domain/ContentQueryReadTestSupport.swift) 及前序 Batch/Sort/Presentation/Trash 合成夹具。

| 检查 | 实际证据与边界 |
|---|---|
| 新领域行为 | 四套新增测试共 **24 项**，全部纳入最终回归；覆盖输入/工作/结果余量、非续读原因、显式上限/溢出/无效增长、无进展与中断维度切换、同源全批重算、忙碌/重放/异主/旧来源、取消迟到/失败保留、来源替换、重新排序、墓碑关系、分页重置、稳定选择/锚点/消失回退及脱敏。全部使用合成 Batch，求值和票据均经真实既有读取及展示管线。 |
| 最终 Swift 回归 | `./scripts/build.sh test` 配 **87 套** `--only-testing`，**610 passed / 0 failed / 0 skipped**；含新增 24 项及既有 586 项提供者、聚合、排序、片段、分组、分页与相关查询/记录回归。精确命令、Regression.xcresult、regression-summary.json 和日志位于忽略目录 build/ContentQueryReadQA。 |
| 并行修改与中间失败 | 首轮扩展回归曾因并行新增 CalendarSpanTestSupport 把 UUID 数组赋给 String 而编译失败，测试未运行；该文件由并行修改自行修正，本轮未修改。最终成功结果对应修正后的工作区。此前首轮局部 28 项通过只作过程证据，不替代最终结果。 |
| 源码一致性 | 最终回归前、回归后和 Debug 构建后的 Domain 与 Domain 测试文件集合及 SHA-256 一致，见 source-before / source-after / source-after-build.json；仅比较源码文件，不对用户正文作散列。并行原生界面行为不纳入本轮验收。 |
| Debug 构建 | 回归后 `./scripts/build.sh` **passed**，staticSignatureVerified=true；仅构建验签，未安装或启动生产应用。测试保留旧原生 API/并发编译警告及多架构目标选择提示，不宣称零警告。 |
| 严格 lint 与静态检查 | 三个本轮生产文件及五个测试/夹具文件的 `swiftlint lint --strict --quiet` 通过。最终文档后运行 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json` 和 `git diff --check`；quality.json 包含原有 **180 项脚本回归**。Swift 行为采用上述定向命令，未运行包含无关原生测试的全量 profile。原检查器接口/规则未改，无新增执行器。 |
| 指定复核与未验项 | Cursor verifier 当前无可调用入口，**未执行 / blocked，整体 partial**；不重复登录、不改认证、不用主代理自查或其他代理冒充。值冻结/取消测试不证明真实数据库事务、同步计算即时中断、敏感副本清理或原生焦点；所有历史缺口继续保留。 |

阶段 2 剩余接线条件：真实仓储冻结读取与多源一致性证据、历史/关联资料适配、实际隐私代次与敏感结果清理、异步调度及合作式取消、产品规模与主线程性能、两宿主入口/双语布局/键盘焦点/像素滚动、真实打开与业务资格重新校验，以及指定复核和历史验收收口。本轮不实施这些条件，不提交、推送、安装、发布或启动生产应用，到 2J-3C 停止。

### 9.34 阶段 2K-1：任务与子任务的 SwiftData 只读快照适配

2026-10-02。本轮仅将显式注入的真实 SwiftData 模型装配为既有 Batch，并使用合成内存库验收。保留前序搜索与并行原生界面修改；Domain 无改动。没有生产页面调用方，不获取生产 Persistence 单例、不打开用户库、不安装或启动生产应用。指定 Cursor verifier 及历史验收缺口继续保留，整体 **partial**；本次授权不表示旧阶段已验收。

#### 接口、上下文所有权和实际读取

[TaskContentQueryReader](../AreaChain/Services/TaskContentQueryReader.swift) 是 Services 的 `@MainActor` 同步适配器。调用方通过 `init(context:)` 注入已有 ModelContext，并调用 `readTasks(session:requestID:options:)`；Session、requestID、日期环境和 BatchOptions 原样传入，不改写查询或页面条件。`init(reads:)` 接收同文件的窄读取闭包集合 TaskContentQueryReads，供故障注入，不是新仓储框架或服务定位器。注入者必须保持同一执行域、同一上下文与只读依赖契约；任意自定义闭包的副作用不能由类型系统自动证明。

| 来源 | 实际 fetch 与投影 | 覆盖边界 |
|---|---|---|
| todo | 以 TaskRepositoryProtocol 持有 SwiftDataTaskRepository，调用 `fetchAllTodos(includeDeleted: true)`；无查询谓词/身份 fetchLimit，沿原创建时间排序。逐行使用 TodoItem.snapshot 后清空其临时嵌套子任务视图。 | 包含活行、软删除和重复 ID 行；不预先根据查询、父项状态或身份去重。Batch.todos 中所有 subtasks 均为空。 |
| subtask | `context.fetch(FetchDescriptor<SubtaskItem>())` 独立枚举整表，包括软删除和无父关系行；逐行调用实际 SubtaskItem.snapshot。 | 唯一权威平面数组；BatchAssembly 在需要时同次组装活提供者的嵌套视图，墓碑直接消费平面源。不能用 TodoItem.snapshot 过滤后的子数组声明完整。 |
| 标签名称 | 收集投影中任务/子任务关联的 UUID；无关联不 fetch，否则以这些 UUID 为谓词 fetch TagItem，不设数量上限、不滤软删除。 | 只供这些任务的条件匹配与展示，不接 TagQueryProvider。按 ID 分组核验，重复 ID 即使同名也不选 first；缺失、冲突或私密标记均不建立可信映射。 |

TagItem 当前没有通用 snapshot 属性；本轮仅投影核验过的 `id/name`，不添加标签快照框架。标签读取不遍历手记或正文、不调用 ensurePresetTags / resolveOrCreateTag，不读取图片、附件、历史文件、钥匙串或系统剪贴板。私密标签名称保守返回不可用，不把局部标签 fetch 当成全局私密资料证明；metadata.privateTagIDs 始终 nil，snapshots.tags 始终 notProvided。

纯 command 输入、结构无效或 possibleTypes 明显不涉及 todo/subtask 时三类 fetch 全部跳过。进入任务读取范围后枚举两张任务表，以满足父子查询与完整身份核验；未来总协调者可决定是否调用这个显式入口，不引入动态注册。routine、diary、image、clipboard 等始终 notProvided。`/tasks` 仍包含 routine，因此本轮只能声明 todo/subtask 来源覆盖，不能宣称完整 `/tasks` 或全局搜索已接入。

#### 完整性、故障与只读证据

TaskContentQueryReadResult 保存冻结 Batch、封闭类别 issues 和仅针对所需关联 ID 的 tagNamesCoverage。成功完整枚举的来源使用 complete；重复身份行完整保留后交由既有提供者拒绝，所以 complete 表示枚举完整，不表示身份唯一、查询或整个来源体系完整。独立失败分别标为 failed，绝不转换为 complete([])。无关已确定的来源继续按原 Batch 覆盖规则求值，缺父来源的子任务不能独立伪造活结果。

- SubtaskItem.snapshot 在无父关系时返回 nil：记录 `unconvertibleSubtask(id:index:)` 并将来源降为 partial，不补造父 UUID、不修改关系。这种行无法进入现有 SubtaskSnapshot，诊断保留其身份和本次输入位置；同 ID 的可转换行也从可用子项中排除，避免丢掉坏行后制造唯一身份。其他可转换子项继续保留。
- 能转换但父 ID 不在成功读取的父源中时，保留实际 todoId 和快照，记录 `uncontainedSubtask` 并标 partial；原 BatchAssembly 再报告关系不一致。父读取失败不等同证明父不存在。
- 原始错误文本、SQL、正文均不进入公开诊断；三种 fetch 失败只报告封闭类别。结果 description/debugDescription 脱敏，不新增日志。
- 标签资料缺失、重复或私密名称不可用标 partial，fetch 异常标 failed。既有提供者只有可选名称字典，没有逐 ID 覆盖契约，因此任一所需名称不能核验时传 nil，让依赖名称的条件保持未知，不把无资料解释成没有标签。非名称条件仍沿原提供者判断。所需 ID 集合为空时 complete 只表示该空集合的辅助资料已满足。
- 仅完整的 todo/subtask 来源更新对应 trashCoverage 类型；其余墓碑来源与 trashTagNamesCoverage 保持未提供，不能把真实任务墓碑分组测试解释为完整回收站接线。

适配器不调用 save、rollback、processPendingChanges、删除、修复、ModelChanges、BoardEvents.changed、通知或日历。ModelChanges 原“成功保存后才发布”契约不变，读取不借用其 value/transaction 包装。测试中的 insert/save 只用于合成建库；正常读取和失败读取均保留既有未保存变化。独立 ModelContext 验证保存态仍是旧值，boardDidChange 观察计数为零；未提交插入可见、未提交删除不再枚举，并且读取不会代替调用方提交或撤销。

#### 同步一致性、冻结结果与重新读取

所有必要 fetch 和投影在一个 MainActor 同步调用内完成，没有 await、UI 回调、后台监听、缓存或异步调度。实体只存在于读取闭包与投影栈，不进入 Batch/结果、不跨 actor，也没有 `@unchecked Sendable`。这个保证是**同一上下文一次同步装配与冻结值输入**：SwiftData 多次 fetch 不能由此证明磁盘事务原子性，也不保证多个上下文或外部进程的同一数据库版本。requestID 保留请求关联语义，不充当数据库版本号。

上下文已发生但尚未 save 的模型变化属于本次可见状态；尚未写入模型的 UI 编辑草稿不在读取范围。适配器不访问 EditDrafts，不提交、不丢弃任何一类草稿；调用方的 autosave 设置也不由适配器改写。测试夹具关闭 autosave 是为了明确验证未提交状态，并非更改产品保存策略。

读取所得 Batch 交给原 ContentQueryReadOwner.begin 后，经 BatchReader → Sorter → Presenter → DisplayBuilder → Pagination 发布。之后改实体不会改变冻结 Batch 或已发布结果，也不会自动触发重算；必须显式再次 readTasks 并 begin 新来源。即使沿用 requestID，ReadOwner 仍建立新来源代次，旧 task/ticket/分页事件被拒绝。本轮没有自动监听真实业务变更，也没有把普通重读当作隐私失效清理。

#### 隔离测试与交接

新增 [TaskContentQueryReaderTests](../AreaChainTests/Services/TaskContentQueryReaderTests.swift)、[TaskContentQueryFailureTests](../AreaChainTests/Services/TaskContentQueryFailureTests.swift)、[TaskContentQueryIntegrationTests](../AreaChainTests/Services/TaskContentQueryIntegrationTests.swift)。[TaskRepositoryFixture / TaskContentQueryFixture](../AreaChainTests/Services/TaskContentQueryTestSupport.swift) 从原 SwiftDataTaskRepositoryTests 提取既有全 schema 内存容器入口；原仓储测试继续复用。所有模型均为合成数据。

集成用例实际创建并保存 TodoItem/SubtaskItem/TagItem，注入读取器产生最终快照，测试中不手工注入最终 Batch.snapshots。验证标题精确命中排序、备注摘要、子项父引用、墓碑分组、首段与加载更多、冻结值、新来源拒绝旧票据。失败由窄闭包注入，不破坏真实数据库制造错误；成功 fetch 与未保存状态通过真实 SwiftData 路径取证。

| 检查 | 最终实际证据与限制 |
|---|---|
| 新服务测试 | 三套共 **19 项 / 27 次运行**，全部通过；覆盖空库、字段、活/删父子、平面来源、无父与缺父关系、父/子重复 ID、标签缺失/冲突/同名重复/私密/失败、不相关范围、未保存插改删、无业务通知、冻结及新旧来源。没有跳过用例。 |
| 扩展 Swift 回归 | `./scripts/build.sh test` 配 **38 套** `--only-testing`，**254 项 / 271 次运行 passed，0 failed / 0 skipped**；含新增服务、原 SwiftDataTaskRepository / ModelChanges、Batch、todo/subtask、ReadOwner、排序/摘要/分组/分页及墓碑查询。精确命令见忽略目录 `build/TaskContentQueryQA/regression-command.json`；最终结果包为 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_16-31-05-+0800.xcresult`，摘要及测试树同在 TaskContentQueryQA。 |
| 隔离与来源稳定 | 全部本轮模型数据来自内存容器。测试脚本串行执行并清除真实钥匙串授权；测试宿主在访问磁盘前切换内存库。回归前、回归后和构建后核对 Domain/Services 及对应测试源码，内容未变；并行 CalendarMonthNavigationTests 等界面改动保留且不纳入本轮行为验收。 |
| Debug 构建 | 回归后 `./scripts/build.sh` passed，`staticSignatureVerified=true`；仅构建验签，未安装、启动生产应用或执行系统认证。保留既有原生 API 弃用/并发警告及多架构目标选择提示，不宣称零警告或发行通过。 |
| lint、脚本和工作流 | 本轮 6 个 Swift 文件 `swiftlint lint --strict --quiet` passed；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` **61 passed**；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 **181 项脚本回归**；`python3 -B scripts/check_workflow.py` 与 `git diff --check` passed。最终文档后重跑静态门禁，Swift 行为使用上述定向回归，不运行无关原生全量套件。原组件守卫仅增加稳定入口及反例，不新增执行器。 |
| 指定复核与未验项 | Cursor verifier 当前无可调用入口，**未执行 / blocked，整体 partial**；按本轮约定不重查登录、不改认证、不用主代理或其他代理冒充。历史缺口保留；未验跨上下文/进程事务一致性、大库性能、自动失效、生产 UI 和真实敏感数据/系统集成。 |

没有修改业务仓储实现或 Domain 契约，也没有对用户正文作散列；源码散列仅用于验证并行修改是否影响本次证据。测试产物不是生产数据。

后续建议先单独定界 routine 定义与 RoutineCheck 只读适配：复用现有仓储/快照，先确认历史排程来源、记录覆盖、重复业务身份与显式枚举窗口；缺历史证据保持未知，禁止补造历史或创建派生 open 记录。继续使用注入内存库，不接生产 UI、调度或业务执行。手记/附件应另行确认隐私投影与失效清理前置，剪贴板需明确历史读取失败语义；它们均未获本阶段实施授权。本轮到 2K-1 停止，不提交、不推送、不安装、不发布。


### 9.35 阶段 2K-2：习惯与打卡的 SwiftData 只读适配及任务类同批装配

2026-10-02。本轮只实现显式注入上下文的存储读取与内存数据库集成；保留既有 2I～2K-1 和并行界面/文档/检查器修改。没有读取生产库、接 UI、自动监听、真实执行或历史迁移。指定 Cursor verifier 仍无当前可调用入口，未执行、不重查登录、不修改认证、不以主代理自查或其他代理冒充；整体 **partial**，历史阶段验收缺口不因此关闭。

#### 接口、实际 fetch 与投影

| 入口 | 实际责任与边界 |
|---|---|
| [TaskFamilyContentQueryReader / ReadResult](../AreaChain/Services/TaskFamilyContentQueryReader.swift) | `init(context:)` 为任务和习惯依赖绑定同一个 ModelContext；`read(session:requestID:observation:options:)` 同步建立一份 Batch。结果保留 taskIssues、routine 读取明细、tagIssues 和 tagNamesCoverage，调试描述脱敏。只读依赖重载用于故障测试，调用方仍须保证同上下文且无副作用。 |
| [TaskContentQueryReader.readSources](../AreaChain/Services/TaskContentQueryReader.swift) | 从 2K-1 原入口提取任务/平面子项装配，原 `readTasks` 保持任务专用范围与诊断兼容；不复制任务读取器、不先生成第二份 Batch。 |
| [RoutineContentQueryReads / Observation / CheckPlan](../AreaChain/Services/RoutineContentQueryRead.swift) | 定义通过 RoutineRepositoryProtocol 持有 SwiftDataRoutineRepository，调用 `fetchRoutines(includeDisabled: true, includeDeleted: true)`。保留启停、活/墓碑、重复身份核验行，排序仍沿仓储 sortOrder；逐行使用真实 DailyRoutine.snapshot。 |
| [RoutineContentQueryReader](../AreaChain/Services/RoutineContentQueryReader.swift) | 有记录依赖时，独立 `context.fetch(FetchDescriptor<RoutineCheck>())` **完整读取整张记录表**，不按日/父关系预滤，不设置 fetchLimit，不调用 `fetchRoutine(id:)` 或每习惯 `fetchChecks(for:)`。在 MainActor 栈内调用实际 RoutineCheck.snapshot，保留原 isDone/isSkipped。 |
| [ContentQueryTagNames](../AreaChain/Services/ContentQueryTagNames.swift) | 旧任务入口与家庭入口共用窄标签读取；家庭收集三类源关联 ID 的并集，一次调用原 TaskContentQueryReads.tags 谓词读取，不过滤软删除。没有新仓储框架、标签创建或补预设。 |

生产实现不访问 Persistence 单例，不把 SwiftData 实体放入输出/后台任务，没有 `@unchecked Sendable`。没有 save、rollback、processPendingChanges、创建/启用/桥接/修复、ModelChanges、BoardEvents.changed 或系统同步调用。所有相关 fetch 与投影在一次无 await 的 MainActor 调用中完成；注入测试依赖必须遵守只读约定，类型系统不能证明任意外部闭包无副作用。返回 Batch 和读取明细均为冻结纯值。

#### 覆盖计划、坏关系和失败

普通名称、标签、定义字段或仅 date 的习惯查询不读取打卡历史；定义 status 缺 on 保持原 needs-input 限制，不默认今天。有 on 时计划该日；显式 routineOccurrences 使用原 date 窗口/显式 occurrenceWindow/on 的一致性规则，on 只保留所选单日。缺记录窗口、冲突窗口不全量扫描，交给原提供者反馈。未接入动态提供者注册或通用读取调度。

旧页面 overdue 的 items/agenda 投影分别要求每个启用定义的 createdDayKey 到页面 yesterday；listedDay/today 计划页面当天。这些区间与 on 覆盖独立计算再合并，不能用 on 一天证明全部逾期记录完整。无法解释的 listedDay/agenda 组合仍由原领域报告；页面 Calendar 不匹配时记录服务问题、不从该页面推导覆盖。旧 DayBoardCheckIndex 的 first-wins 与 Agenda 的任一闭合规则完全未改。

记录实际 fetch 是全表，包含窗口外记录；`fetchScope=allStoredRows` 明确其 IO 范围。完整区间却只授予本次需求，按每个已枚举的习惯 UUID 分别声明：一天不推广到其他日期，枚举之外的习惯没有覆盖；实际已完整枚举所有定义与记录时，可给多习惯各自的所需日期。无 per-routine N+1。**2I maxInputItems 只限制领域枚举，不限制数据库 fetch 或同步投影成本**；本阶段没有数据库行数预算、有界分页、后台取消或大库性能保证，未建立性能基线。

| 输入或失败 | 保留证据与限制 |
|---|---|
| 完整空记录 | `checkSource=complete`，按所需区间给 RoutineCheckCoverage；只有另有可靠排程才派生 open。无窗口不读，标 notProvided。 |
| 同业务日多条记录 | 不物理去重、不合并状态。每条实际记录 UUID 和输入下标存入 `RoutineContentQueryCheckRow`，snapshotIndex 指向同批 CheckSnapshot；业务身份仍为习惯 ID＋日。RoutineCheckReading 继续报告 identicalDuplicates、conflictingRecords、doneAndSkipped。 |
| 相同记录 UUID | 单独报 duplicateCheckID，保留全部行/值，限制相关父习惯全部请求覆盖；不同记录 UUID 的同日记录不属于该问题。 |
| 缺 routine / snapshot 为 nil | 保留 recordID、inputIndex、nil snapshotIndex 和不含身份组合的 missingCheckParent 问题，不伪造 routineID。无法可靠归属，全部记录覆盖撤回，集合标 partial。 |
| 父关系歧义或不在完整定义源 | 从独立定义枚举按业务 ID 核对数量，再核对实际 persistentModelID；不以单个父 relationship 证明唯一。保留可转换原值，记录安全类别与行下标，限制对应父 ID；定义重复原样交领域隔离，不建立当前排程证据。 |
| 非法日键 | 保留原 CheckSnapshot，报 invalidCheckDay，并撤回该习惯全部日期覆盖；无法可靠缩成某一天，其他习惯仍可确定。全表中窗口外的非法日键也属于这次实际输入。 |
| 定义读取失败 | 主源 failed，未建立定义/排程证据；若有显式记录窗口仍可观察记录值，但不授予任何完整覆盖。独立任务来源继续。 |
| 记录读取失败 | `checkSource=failed`，无记录覆盖，不等于 complete 空集合；封闭 checkFetchFailed 类别，不保留原始数据库错误、SQL、正文或标识组合。 |

[BatchRoutineFacts](../AreaChain/Domain/ContentQueryBatch.swift) 增加可选 `checkSourceProblem`：仅 `incompleteUnattributedInput` / `readFailed`，默认 nil 不声明记录完整。它使“只有孤立行而没有任何定义”也不能在 [BatchReader](../AreaChain/Domain/ContentQueryBatchReader.swift) 汇总为完整无结果；[BatchCompleteness](../AreaChain/Domain/ContentQueryBatchCompleteness.swift) 用 `checkSource` 限制保留到 ReadOwner/展示来源。可定位问题仍依靠 RoutineCheckCoverage 和原提供者逐对象核验，不把局部问题自动扩大成无关习惯不可读。既有纯快照调用未提供该字段时保持原契约。记录源问题只附到实际相关 routine/routineOccurrence/含 routine 的 trash 汇总，不替代各提供者的诊断。

#### 当前观察与查询/转交冻结日期

`RoutineContentQueryObservation(instant:calendar:)` 是每次 read 的必需参数，没有默认系统时间或查询 today 回退。调用方负责在实际读取环境采样本次时刻；它不是可缓存的历史证明。本阶段没有生产调用方，隔离测试注入受控时刻。日期以该 instant 和与 Session.queryDates 相同的 Calendar/时区转换；不匹配或非法时刻不生成证据，并返回 observationCalendarMismatch / invalidObservation。

只调用 `RoutineScheduleEvidence.currentDefinition(snapshot, observedOn:)`，证据区间只含明确观察日，启用沿当前 mask，停用为该观察日 notScheduled。不新增历史表，不从 pausedOnDayKey 重建暂停/恢复，不根据打卡存在推定当天应执行，不把当前 mask 推广到过去或未来。查询 date/on/today、转交冻结 today 与实际观察日是不同来源：冻结只控制查询语义，跨午夜显式再次读取必须注入新观察时刻，旧结果仍冻结。创建日之前仍由原领域返回 beforeCreation；其余未覆盖日期缺历史保持 unknown。

#### 同批标签、只读集成与剩余来源

Batch 只含一份原样 Session/requestID/options，todo/subtask/routine 的关联名字共用一份 metadata，不合并两个独立 Batch 或覆盖彼此名字。标签缺失、重复 ID（即使同名）或私密标签均不提供可信名字；任一所需名称不可核验时沿原提供者契约传 nil，tagNamesCoverage=partial；fetch 失败为 failed。privateTagIDs 仍 nil，不把局部名字读取当作全局保护事实。`snapshots.tags/diaries/images/clipboard` 仍 notProvided，has:image 没有真实关联证据，不能宣称能力完整。

`/tasks` 现在可以覆盖 todo/subtask/routine 三种定义来源，但字段不适用、缺 on、历史或图片关联仍决定匹配完整性。显式执行记录只进入原 2I；可靠观察日排程＋完整空/未处理记录才派生 open，未插入打卡行。普通任务范围不混入每日结果。

实际内存模型 → 家庭读取 → ReadOwner.begin/evaluate/publish → BatchReader/Sorter/Presenter/DisplayBuilder/Pagination 的测试没有手工替换最终 snapshots。同批验证标签字典、标题优先排序、备注摘要、子项父关系、分页和来源更新；实体后续变化不改旧 Batch 或发布结果，显式再次读取产生新来源代次，旧计算票据不能覆盖。测试通过独立 ModelContext 对比已保存状态，验证未保存插入/修改/删除保留、失败也不回滚，业务通知计数为零。

同步多 fetch **不等于跨上下文/进程数据库原子快照**。调用方 autosave 配置不被更改；夹具关闭 autosave 只用于验证未提交状态。未完成生产监听/缓存/失效清理、跨库版本一致性、数据库有界读取与性能保证、合作式后台取消。没有 UI、生产数据库、真实系统或历史迁移验收。

#### 本轮验证与停止点

本次新增测试与夹具为 [RoutineContentQueryReaderTests](../AreaChainTests/Services/RoutineContentQueryReaderTests.swift)、[CoverageTests](../AreaChainTests/Services/RoutineContentQueryCoverageTests.swift)、[ObservationTests](../AreaChainTests/Services/RoutineContentQueryObservationTests.swift)、[FailureTests](../AreaChainTests/Services/RoutineContentQueryFailureTests.swift)、[TaskFamilyContentQueryIntegrationTests](../AreaChainTests/Services/TaskFamilyContentQueryIntegrationTests.swift) 和 [RoutineContentQueryTestSupport](../AreaChainTests/Services/RoutineContentQueryTestSupport.swift)。其容器复用原 TaskRepositoryFixture / TaskContentQueryFixture。除上文 5 个 Services 与 3 个 Batch 文件，本阶段只同步本权威文档、架构、组件目录、技能路由，以及原 check_workflow.py / test_check_workflow.py 的稳定入口和反例；未改旧仓储、模型、看板或 Agenda。

| 检查 | 最终实际结果与证据 |
|---|---|
| 新服务验证 | 5 套 **28 项 / 38 次运行 passed**；覆盖启停/墓碑、实际 snapshot、定义和记录身份重复、同日冲突/原 flags、孤立/非法/缺父、局部覆盖、完整空/故障、普通查询不读历史、范围/on/旧页面覆盖、观察日/午夜/转交冻结、Calendar 拒绝、同批标签、原 ReadOwner/排序/摘要/分页、未保存变化及零业务通知。无跳过。 |
| 最终 Swift 回归 | `./scripts/build.sh test` 配 **97 套 --only-testing**，**697 项 / 767 次运行 passed，0 failed / 0 skipped**。包含原 2K-1 三套、SwiftDataTaskRepository / SwiftDataRoutineRepository / ModelChanges、习惯历史/记录/2I、各查询提供者、Batch、ReadOwner、排序/展示/分页以及旧 DayBoard/Agenda/ItemsListing/日期/分类。精确命令与测试树见忽略目录 `build/RoutineContentQueryQA/regression-command.json`、`regression-summary.json`、`regression-tests.json`；97 套全部在结果树核实为 Passed。结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_17-00-57-+0800.xcresult`。 |
| 编译问题与修正 | 初轮 8 套服务验证 44 项 / 62 次运行通过。补午夜测试后首次扩展回归在编译期发现测试误把非 Equatable 的 ContentQueryDateContext 做整体比较；改为核对完整 Session，保留观察日前后断言后重跑取得上述最终结果。未修改产品规则或删掉失败断言。 |
| 源码与只读隔离 | `source-before-regression.json` / `source-after-regression.json` 核对 Domain/Services 及其测试，回归前后、Debug 构建后无变化。所有本阶段模型来自真实内存 ModelContainer；普通 test 入口清除真实钥匙串授权、串行运行，既有测试宿主在访问磁盘库前使用内存分支。保存只在合成建库，读取成功/失败均不提交或撤销模型变化。没有生产应用运行或真实用户记录读取。 |
| Debug 构建 | 最终 Swift 修改后 `./scripts/build.sh` **passed**，`staticSignatureVerified=true`，`distributionReady=false`；仅构建验签，未安装/启动生产应用或执行系统认证。结果见 `build/RoutineContentQueryQA/build.log`。 |
| 静态、lint、工作流 | 14 个本阶段 Swift 文件严格局部 `swiftlint lint --strict --quiet` passed；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` **62 passed**；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 **182 项原脚本回归**、高风险/敏感日志候选均 0；`python3 -B scripts/check_workflow.py` 与 `git diff --check` passed。最终文档后重跑受影响静态检查。现有检查器只新增稳定入口与反例，没有新执行器。Swift 验证使用上述定向回归，不运行超出本阶段范围的全量原生 UI profile。 |
| 指定复核与未验项 | **Cursor verifier 未执行 / blocked，整体 partial**。没有重查认证或替代复核。历史验收缺口、生产接线、真实用户库、跨上下文原子性、数据库有界 IO/性能、自动失效及真实系统层均未验收。 |

本次环境为 macOS 26.6.2 arm64 / Xcode 26.6 (17F113) / Swift 6.3.3 / Python 3.9.6。保留既有原生测试 actor/Sendable、旧 AppKit API 和多目标架构提示，不据此宣称零警告、低版本兼容或发行通过。

下一存储适配建议先单独定界 diary 的公开元数据与正文保护投影：在合成隔离库明确 privateTagIDs 全局覆盖、锁定/失焦/来源失效清理与历史旧格式边界后，再决定实现；真实私密数据、钥匙串/认证、生产库读取及任何转换仍需独立明确授权。图片适配再核实真实 owner 关联及隐藏资料边界；本阶段不实施它们。到 **2K-2 停止**，不提交、不推送、不安装、不启动生产应用、不进入下一阶段。

### 9.36 阶段 2K-3：标签目录的 SwiftData 只读适配与同批装配

2026-10-02。本阶段只读取显式注入上下文的标签模型，接入原 TagQueryProvider 和任务家庭同批装配。模型均由原全 schema 内存 ModelContainer 夹具生成；不读生产库、手记正文或附件，不接生产 UI、标签写入及真实系统操作。保留并行代码/文档改动和历史验收缺口。指定 Cursor verifier 无当前可调用入口，未执行、不重查认证、不以主代理自查或其他代理替代；整体仍 **partial**，本次限定授权不表示旧阶段已验收。

#### 实际读取、接口与按需计划

| 入口 | 实际行为与覆盖 |
|---|---|
| [TagContentQueryReads](../AreaChain/Services/TagContentQueryReader.swift) | `init(context:)` 显式注入 ModelContext，以 CatalogRepositoryProtocol 持有 SwiftDataCatalogRepository，唯一生产读取为 `fetchTags(includeDeleted: true)`。沿原仓储 sortOrder 排序，无数量上限、名称谓词、身份 first-wins 或墓碑过滤。窄 allTags 闭包只用于故障/调用次数验证，注入者须遵守同上下文只读约定。 |
| [TagContentQueryReader.readSources](../AreaChain/Services/TagContentQueryReader.swift) | 只在非命令、结构有效且 possibleTypes 含 tag 时读取；不相关范围、仅任务关联名字、无效查询及 tag 字段不适用时不全量 fetch。完整保留 ID/name/sortOrder/deletedAt/isPrivateDiary/原 colorToken，直接转 TagQuerySnapshot。未使用 ExportedTag、名称规范化副本、颜色修复、预设补齐或 resolveOrCreate。 |
| [TaskFamilyContentQueryReader.read](../AreaChain/Services/TaskFamilyContentQueryReader.swift) | 继续接收原 session/requestID/observation/options，增加可选 `injectedUsage`，结果增加 `tagCatalog: TagContentQueryReadDetails`。原上下文入口为三类读取依赖绑定同一 ModelContext；故障重载显式接收 tasks/routines/tags。先装配任务与习惯，再装配标签，最后安装同批关联名字；全程只创建一份 Batch，不合并两个批次。 |
| [ContentQueryTagNames.read / project](../AreaChain/Services/ContentQueryTagNames.swift) | 原保护/歧义规则提取为 project。全量目录与任务关联名字都需要时，同一次 fetch 的实体分别投影；否则继续原 tasks.tags 按关联 ID 集合读取。没有关联 ID 时不做额外 fetch。只输出纯值，不持有实体。 |
| `TagContentQueryReadDetails` | source 区分 notProvided / complete / failed，issues 只有封闭 fetchFailed 类别；usageOrigin 只有 notProvided / injected。description/debugDescription 脱敏，不保存原始数据库错误、SQL、标签值或新增日志。 |

全量成功包括完整空目录，Batch.tags 为 complete；重复 ID 行保留在完整枚举中，再由 TagQueryProvider 隔离所有冲突行，不触发 uniqueKeys 崩溃，也不把同名不同 ID 合并。枚举 complete 不表示查询、身份或全局内容完整。完整成功只提升 trashCoverage.types[tag]，不提升其他来源或隐私覆盖。失败时 tags=failed，标签墓碑覆盖撤回，绝不等价 complete([])；任务类独立成功来源保留。相关名字同批 fetch 失败时为 failed，不再用第二次 fetch 拼出另一观察时点。

#### 标签内容与关联名字的公开边界

目录内容继续遵守 §9.23：标签原名、颜色、预置识别和 isPrivateDiary 标记允许用于标签自身结果；预置识别和颜色解释仍调用已有 TagQuerySnapshot/领域规则。软删除行仅作核验及已有墓碑提供者输入，不出现在活标签结果。

关联名字只对同批 todo/subtask/routine 的关联 ID 投影，不把完整目录字典直接塞入 metadata。任一所需 ID 缺失、重复（即使同名）或 isPrivateDiary 为 true，仍沿原 ContentQueryTagNames 返回 nil/partial，让依赖名字的条件保持未知；不相关私密目录行不污染已核验的关联集合。目录可展示名称不是关联内容或私密正文的公开授权。

生产家庭入口的 metadata.privateTagIDs 仍 nil，trashCoverage.diaryPrivacy、trashTagNamesCoverage 及图片保护资料不因目录完整而提升。标签 reader 自身不覆盖 Batch 已有 metadata、其他 snapshots、routine facts 或 options；最终家庭装配只有一个 metadata 所有者。diaries/images/clipboard 仍 notProvided。全局请求即使标签和任务类均已读取，也不能宣称全局匹配完整。

#### 统计的实际支持与未完成部分

以下为 2K-3 当时状态；2K-8 已补充受控真实读取，见 §9.44，默认及显式 injected 接口仍保持原边界。

**本阶段没有实际全来源统计适配，也没有自动从任务类快照生产部分统计。** 默认 tagUsage=nil、usageOrigin=notProvided，单项 usageState=unavailable。普通名称搜索、inputOrder 和 catalog(all) 不依赖使用量，继续准确匹配；目录初始输入顺序来自仓储 sortOrder，不把该顺序称为使用量排名。

`injectedUsage: TagQueryUsageInput?` 原样交给同批 facts.tagUsage 和原 TagQueryProvider，非 nil 明确标为 **注入统计（injected）**。partial(completeTagIDs)、complete、重复/非法统计的校验仍由原领域处理；标注 injected 不验证或扩大调用方的完整声明。注入 complete 的集成测试只证明契约可消费合成统计，不能称作真实全来源统计已读取。无关查询跳过标签读取时也不安装注入统计。

frequent/recent/unused 继续经 TagUsage.filteredValues：frequent 统计未知保留名称命中，requested=activeCountThenSortOrder、applied=inputOrder、isComplete=false，并保留排序提示；recent/unused 的未知项进入 undeterminedObjects。缺记录或局部零值都不证明 unused，局部正数也不作为精确计数发布。测试中的任务类部分统计用 TagUsage.subjects / records 生成，覆盖明确 partial(completeTagIDs: [])；全量合成统计同样复用 TagUsage.records，并与旧 TagUsage.filtered 同输入对照，没有新计数算法。

现有完整口径包含未删除的待办、习惯、子任务和手记，不计打卡；latestCreatedAt 仍为关联活记录的最近创建时间。只读任务类不能知道未读手记的关联情况，因此真实全来源统计、准确使用量排名和可靠 unused 目录仍是功能缺口，需在手记元数据读取边界明确后单独补齐，不计入本阶段完成项。

#### 只读、失败与冻结证据

所有 fetch 和投影都在无 await 的 MainActor 调用内完成，实体不逃逸到 Batch/结果、后台任务或后续投影闭包。不使用 unchecked Sendable 或生产 Persistence 单例；没有 save、rollback、delete、processPendingChanges、BoardEvents、事务包装、补预设或模型修复，也不修改调用方 autosave 设置。隔离测试的 save/insert/delete 仅用于合成建库与构造未保存变化。

真实保证是**同一上下文的一次同步装配和纯值冻结**，不是跨上下文/进程数据库事务原子性。未建立全目录行数预算、后台取消或大库性能基线。读取保留调用方未保存插入、修改与删除；成功和注入 fetch 失败后独立 ModelContext 仍看到旧保存态，业务通知计数为零。模型后续改名、改色、删除标记或私密标记不修改旧 Batch/发布结果；显式再次读取交给 ReadOwner.begin 产生新来源代次，即使 requestID 相同，旧票据不能发布。没有自动失效监听，不能把普通重读当作隐私失效清理。

实际 TagItem → 家庭 reader → Batch → ReadOwner.begin/evaluate/publish → BatchReader/Sorter/Presenter/DisplayBuilder/Pagination 通过隔离集成测试连接，最终 snapshots 未被手工替换。分页首段、加载更多、纯值冻结和旧来源拒绝均由原领域链路执行，没有生产原生页面验收。

#### 验证与交接

新增 [TagContentQueryReaderTests](../AreaChainTests/Services/TagContentQueryReaderTests.swift)、[UsageTests](../AreaChainTests/Services/TagContentQueryUsageTests.swift)、[IntegrationTests](../AreaChainTests/Services/TagContentQueryIntegrationTests.swift)、[FailureTests](../AreaChainTests/Services/TagContentQueryFailureTests.swift) 与[薄夹具](../AreaChainTests/Services/TagContentQueryTestSupport.swift)。复用 RoutineContentQueryFixture / TaskContentQueryFixture / TaskRepositoryFixture；原 RoutineContentQueryTestSupport 只补显式标签读取依赖。Domain、原标签仓储和生产 UI 未改。稳定入口登记沿原 check_workflow.py 和反例测试，不新增检查执行器。

| 检查 | 本轮实际结果与限制 |
|---|---|
| 新服务测试 | 四套最终 **19 项 / 30 次运行 passed，0 failed / 0 skipped**。覆盖完整空/普通/预置/私密标签、原值与墓碑、重复身份/同名异 ID、无需统计的名称搜索、注入统计各覆盖与旧筛选对照、frequent 回退、recent/unused 未知、同批投影边界、按需 fetch、失败与旧覆盖撤回、未保存变化、冻结、ReadOwner 与展示分页。 |
| 最终 Swift 回归 | `./scripts/build.sh test` 配 **77 套 --only-testing**，**546 项 / 603 次运行 passed，0 failed / 0 skipped**。包括新标签服务、四套 TagQuery、原 TaskFamily/TaskContentQuery/RoutineContentQuery、SwiftDataCatalogDiaryRepository/TagCatalog/TagRepository/TagSyntax、任务/习惯仓储及 ModelChanges、查询/批次/排序/摘要/展示/分页/ReadOwner、原提供者和保护回归。77 套均在结果树核实为 Passed。精确命令及结果见忽略目录 `build/TagContentQueryQA/regression-command.json`、`regression-summary.json`、`regression-tests.json`；结果包 `build/development-DerivedData/Logs/Test/Test-AreaChain-2026.10.02_17-19-07-+0800.xcresult`。 |
| 来源稳定与隔离 | `source-before-regression.json` / `source-after-regression.json` 核对 Domain/Services 及对应测试，最终回归前后无变化，Debug 构建后复核一致。普通 test 入口串行并清除真实钥匙串授权；全部本轮数据来自内存 ModelContainer，未访问生产库。并行时间控件、页面与文案修改保留，不纳入本轮界面验收。 |
| Debug 构建 | 最终 Swift 修改后 `./scripts/build.sh` **passed**，`staticSignatureVerified=true`、`distributionReady=false`；构建等待既有仓库锁后执行，没有干预并行任务。日志 `build/TagContentQueryQA/build.log`。只构建/静态验签，未安装、启动生产应用或验证真实认证。 |
| lint、脚本与工作流 | 本轮 9 个 Swift 文件 `swiftlint lint --strict --quiet` passed；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` **63 passed**；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 **183 项原脚本回归**、高风险/敏感日志候选均 0；`python3 -B scripts/check_workflow.py` 与 `git diff --check` passed。最终文档后重跑受影响静态检查；Swift 采用上述定向范围，没有运行超出本阶段的全量原生 UI profile。 |
| 指定复核与未验项 | **Cursor verifier 未执行 / blocked，整体 partial**。仅检查本会话可用工具清单，无指定入口，不重查登录/认证、不替代复核。历史验收缺口、生产 UI、真实用户库、跨上下文原子性、自动失效、大库性能与真实系统均未验收。 |

环境为 macOS 26.6.2 arm64 / Xcode 26.6（17F113）/ Swift 6.3.3 / Python 3.9.6。保留编译中的既有原生 API 弃用、actor/Sendable、未使用变量和多目标架构提示，不宣称全库零警告或低版本兼容已验收。

#### 后续手记安全读取须先确认的边界

1. 可枚举的元数据字段与数据形态：手记 ID、民事日期、创建时间、删除状态、tagIDs 和记录级保护字段是否可读；当前模型 fetch 是否会物化正文/密文，如何证明元数据路径不读取或输出正文。不能因 Swift 属性未被访问就宣称底层未读取敏感列。
2. privateTagIDs 的全局覆盖、缺失/重复标签及孤立关联的处理；记录级保护、私密标签、旧密码遮罩和未知格式如何共同保守判定，目录公开名称不能替代保护证据。
3. 若后续允许正文投影，明确公开/保护/解锁/显式显示各状态允许的字段，以及锁定、失焦、来源变更时 Batch、ReadOwner、摘要、分页和迟到票据的清理时机；认证及真实系统操作仍须独立授权。
4. 统计是否允许计入受保护手记的关联元数据、计数和最近创建时间，哪些输出会暴露存在性；明确全来源/逐标签完整声明与失败撤回规则后，才可接真实统计。

本阶段到 **2K-3 停止**，不提交、不推送、不安装、不发布、不启动生产应用，不进入上述下一阶段。

### 9.37 阶段 2K-4A：手记存储读取、隐私失效与统计边界的只读核验和方案设计

#### 本阶段范围、证据与停止点

2026-10-02，只读核对当前工作区源码，唯一修改是本文的本节及顶部索引。核对时 HEAD 为 `93f8bba561c4746fb71877af0f843074cc2dc973`；工作区已有 2K-1～3 的未跟踪读取器/测试、Domain 修改，以及原生控件、页面、文案、工程文档、检查器与本文的并行修改，均保留。下列 `file:line` 对应本次工作区而非仅 HEAD；后续实施须重查差异与符号位置。

这是**设计交付，不是敏感读取授权或运行验收**。§1、§9.19 的已确认规则不重新讨论：不自动解锁；不可读正文不当作空；元数据可决定时正常判断，否则三态未知；私密结果只有隐藏标题及允许元数据，无正文、片段、长度、正文范围；图片不扩大披露；历史/模板不自动保存敏感输入。本段记录 2K-4A 当时状态；后续 D1～D3 已获确认，2K-4B 实际增量见 §9.38，其余“建议”“拟新增”仍未实现。

读取与统计、失效事件分别作只读探索，主代理沿出处核对关键结论；该探索不是指定 Cursor verifier。指定复核仍未执行 / blocked，不重查登录、不改认证、不使用其他代理冒充，历史整树、原生、真实系统与前阶段 partial 状态继续保留。2K-4A 当时完成文档后停止；现 D1～D3 已确认，但仅 2K-4B 的元数据隔离实施获得本轮授权，不表示旧阶段已验收。

#### 已核实事实一：模型物化、正文读取与转换状态

| 问题 | 核实事实及源码依据 |
|---|---|
| 持久化字段 | [Models.swift](../AreaChain/Domain/Models.swift):270–312 `DiaryEntry`：普通正文为 `text: String`；保护后密文为 `encryptedText: Data?`，库归属为 `privacyVaultID`，另有 `isPrivate`。`hasProtectedContent` 在三者任一指示保护时成立。`dayKey/createdAt/deletedAt/tagIDs/isPinned` 独立存储。旧格式仍可把敏感明文放在 text，新增保护字段默认 false/nil，不是已迁移证明。 |
| fetch 会得到什么 | [SwiftDataDiaryRepository.swift](../AreaChain/Services/Repositories/SwiftDataDiaryRepository.swift):32、218–247 返回完整 `DiaryEntry` 模型，按创建时间及置顶排序；没有本项目可证明的独立元数据表或仅列投影。fetch 本身没有调用应用的解密函数；但框架可能加载 text/密文或保留已注册模型，**无法保证元数据 fetch 不物化正文，也无法保证内存没有正文**。这里没有执行 SQL/内存实验，也没有框架保证可作为证据。 |
| snapshot / text 的区别 | `Models.swift:302` 的 `entry.snapshot` 直接复制 `entry.text`，仅将保护标志折入 isPrivate/isContentAvailable，并不先清空 text，也不解密。直接读 `entry.text` 访问持久化明文字段，无自定义解密 getter。因此“受保护标志为真”不能证明 snapshot 内没有旧明文。 |
| DiaryContent 的读取 | [DiaryContent.swift](../AreaChain/Services/Privacy/DiaryContent.swift):6–21：未保护模型会枚举完整 TagItem 并检查私密标签，然后返回 text；受保护模型先检查 vault 已解锁，再要求密文与 vaultID，调用 `keys.open`，返回新 String。它不主动认证，也不把解密结果回填模型。`:24–35` 的 snapshot 先复制 entry.snapshot，再尝试 read；失败清 text、置 isPrivate=true/isContentAvailable=false。成功仍可能产生敏感正文值副本。不能将该 API 当成无正文元数据接口。 |
| 仓储旧搜索不能直接复用 | `SwiftDataDiaryRepository.swift:43–60` 的 `searchDiaries` 使用 BoardSearch、活标签字典、DiaryContent.snapshot；它可能解密，且 `Dictionary(uniqueKeysWithValues:)` 不是重复 ID 的保守归并。新入口复用枚举方法，不调用旧搜索；按 ID 的 `fetchDiary` 有 fetchLimit=1，也不适合证明重复身份不存在。 |
| 写入边界 | `DiaryContent.swift:38–51` 保护写入密文/vaultID/isPrivate 并把 text 置空；`SwiftDataDiaryRepository.swift:201–215` 的 writeContent 可标记磁盘清理、转换附件并写正文。`:128–150` 的改标签是读正文后事务写入。新 reader 不调用这些方法、save/rollback、ensurePresetTags、resolveOrCreateTag 或通知发布。 |
| 初始化做了什么 | [Persistence.swift](../AreaChain/Services/Persistence.swift):14–28 在生产容器打开前尝试 `PrivacyStoreMaintenance.finish`，失败被 `try?` 保留；还修复任务/习惯 NULL notes。测试入口先返回内存容器。该初始化不是手记全库保护迁移；[PrivacyVault.swift](../AreaChain/Services/Privacy/PrivacyVault.swift):51–69 只加载/校验配置与清理日志，状态 locked/unconfigured/unavailable 也不是手记格式就绪证明。 |
| 迁移/清理如何发生 | [DiaryProtection.swift](../AreaChain/Services/Privacy/DiaryProtection.swift):27–32、111–134：转换候选可选择 includeLegacy，实际 applyTags 要新鲜认证、必要备份，并在事务中加密/更新私密标签。没有自动把全部旧密码标记升级的读取路径。[PrivacyStoreMaintenance.swift](../AreaChain/Services/Privacy/PrivacyStoreMaintenance.swift):20–59：标记先于转换，isPending 仅表示待清 SQLite 空闲页/WAL；冷启动 finish 做 checkpoint/VACUUM 并删除成功标记。无标记不证明全部旧数据已转换、有标记也不等于当前行无法读取。 |

结论：不能复用一个不存在的“全库安全初始化完成”布尔值。可复用调用方**已打开的 context**、已存在 vault 的只读状态，以及由既有维护路径报告的 pending/unknown 事实；不能由新搜索调用 `Persistence.makeSession`、初始化全局服务或触发 finish/applyTags 来取得就绪状态。即使已有合成迁移测试，[PrivacyMigrationTests.swift](../AreaChainTests/Services/PrivacyMigrationTests.swift):9 起也是显式转换后的独立旧库夹具，不能证明当前真实库已完成转换。本阶段没有运行它。

“仅元数据”在推荐方案中准确指**不显式读取/复制 text，不调用应用解密，返回值没有正文**；不承诺 SwiftData 底层列隔离。若实施授权要求连物化都必须避免，则当前模型路径不足，必须保持 diary 来源未接入，另行研究存储设计，不能偷偷换 SQLite 私有表查询或新增迁移。

#### 已核实事实二：保护资料及完整性

| 资料 | 用途及不足 |
|---|---|
| isPrivate / hasProtectedContent | 存储标志及密文/vaultID存在性仅说明必须按保护处理；不证明密文有效、可解密或旧 text 已擦除。新投影保留 `hasProtectedContent`，不得只复制 isPrivate。 |
| isContentAvailable | [DayBoardLogic.swift](../AreaChain/Domain/DayBoardLogic.swift):95 的快照能力字段，不是持久化列或认证许可；true 仅表示本次实际提供可读正文。元数据投影必须 false，即使 vault 已解锁。不能把空占位设为可读来证明排除文字。 |
| 私密标签与旧名称 | [DiaryPrivacy.swift](../AreaChain/Domain/DiaryPrivacy.swift):11–23 的 isSensitive 同时看快照 isPrivate、正文旧标记，以及关联标签的 isPrivateDiary/密码名称。[DiaryMemoTags.swift](../AreaChain/Domain/DiaryMemoTags.swift):11–12 保留中文“密码”和英文 password 名称规则；不能擅自替换成另一种规范化匹配。 |
| 旧正文标记 | `DiaryPrivacy.swift:54–55` 的 `#密码` / 不区分大小写 `#password` 依赖实际正文。标签元数据无异常仍不能排除旧正文标记；元数据模式不读取它，也不宣称该记录公开。自动标签关键字另见 `DiaryMemoTags.swift:20`，不是已完成保护转换的历史证明。 |
| 写保护与展示判定不同 | `DiaryPrivacy.swift:34–42` 的 requiresProtection 依赖 isPrivateDiary（text 重载还能从正文解析名字）；它不是 isSensitive 的同义函数。`DiaryContent.read` 未保护分支只调用 tagIDs 重载，不能单凭 read 成功宣称通过所有旧格式展示检查。 |
| Query 的保守规则 | [DiaryQueryEvaluation.swift](../AreaChain/Domain/DiaryQueryEvaluation.swift):42–60 在正文不可用时忽略占位；要求名字表存在、所有关联有名字、privateTagIDs 非 nil、原 tagIDs 可解释，且正文可用/不敏感才 canPublishBody。完整性诊断不依赖旧正文标记。结果 [DiaryQueryRead.swift](../AreaChain/Domain/DiaryQueryRead.swift):83–96 删除隐藏结果全部文字条件证据；[DiaryQueryMatching.swift](../AreaChain/Domain/DiaryQueryMatching.swift):82–121 保留文字正负及 AND/OR 的三态。 |
| 标签墓碑与历史资料 | 保护目录必须含已软删除标签的原 id/name/isPrivateDiary，以及同 ID 的所有行；不能使用 liveTags、搜索命中或显示出来的标签反推保护全集。`SwiftDataDiaryRepository.swift:255` 的 protectionTags 也明确含墓碑。已彻底删除的名字/标志没有在 DiaryEntry 中另存历史副本；孤立 tagID 无法追溯时必须保持未知，不能自动补标签或认定公开。 |
| 缺失、重复与坏关联 | 名称为空/不可解释、关联缺失或重复 ID 均不能挑第一行；完整私密集合不能由不完整目录拼出。保留原 tagIDs，让 Query 的 invalidTagIDs 生效；[Classification.swift](../AreaChain/Domain/Classification.swift):90 的容错解析不能代替完整性校验。重复关联 ID 与重复实体 ID 分开，后者包括活行/墓碑冲突，交给既有 Provider 隔离。 |

现有 [ContentQueryTagNames.swift](../AreaChain/Services/ContentQueryTagNames.swift):16–46 只收集任务/子任务/习惯 ID，遇缺失、重复或私密标签名便返回 names=nil；同批全目录不改变此限制。[TaskFamilyContentQueryReader.swift](../AreaChain/Services/TaskFamilyContentQueryReader.swift):38–47 是唯一 metadata 装配者，当前 privateTagIDs 恒 nil。不能在新增 reader 内先填完整隐私资料，然后又被家庭装配覆盖；也不能为了填满 diary 名字，顺带放宽任务关联名字的既有边界。

图片有独立门禁：[ImageOwnerResolution.swift](../AreaChain/Domain/ImageOwnerResolution.swift):60–69 先要求 diaryPrivacy 覆盖完整，再运行同一个 DiaryQueryPrivacy；[ImageAssociationReader.swift](../AreaChain/Domain/ImageAssociationReader.swift):43–59 对 protected 或 diary privacy unknown 都返回统一 protected，不表达零/一/多图，也不发布图片明细。**名字完整、目录完整、vault 解锁都不自动提升 diaryPrivacy**。首批元数据投影的 canPublishBody 始终 false，不能借这个事实把未知保护格式标为“已核验完整”。

#### 已核实事实三：事件、所有权与失效缺口

| 事件/状态 | 实际语义与接线要求 |
|---|---|
| privacyWillLock | `PrivacyVault.swift:104–113` 同步发通知在 generation 递增、keys.clear 和 state 更新**之前**。回调此时仍可能读到 unlocked 与旧 generation；必须无条件先撤销本搜索来源，不能等待 didChange，也不能据旧 state 放行。 |
| 自动/系统锁定 | `PrivacyVault.swift:120–144、209–215`：空闲阈值后 lock，common RunLoop 每秒检查；睡眠、系统会话失活、屏幕锁定、退出走 lock。后台搜索不能 touch 续期。 |
| privacyMask / 窗口失焦 | 应用失活仅发 privacyMask，不改密钥、state、generation 或 revision。`DiaryNoteCard.swift:310–325` 另区分本窗口失去 key。[DiaryEditorSession.swift](../AreaChain/Features/Diary/DiaryEditorSession.swift):194–218 的 mask 与 sealForLock 分开，后者在钥匙清除前封存未保存正文；封存失败保留会话并遮罩，不是随意丢草稿。 |
| generation / revision | `PrivacyVault.swift:147–173` 在认证开始推进 generation，但此时没有 privacyDidChange；认证成功核对代次/配置后通知。`:176–205` 的 revision 还包含配置、清理日志等变更，并非纯认证代次。只订阅 didChange 不覆盖认证开始。vault 是 @Observable @MainActor，可观察既有 generation/state/isAuthenticating/revision；新增观察接线仍需验证通知顺序和重入。 |
| PrivacyAccess / Presenter | [PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift):129–159 可主动请求认证，已解锁路径还能 touch；不是无副作用的搜索资格检查器。搜索不能调用 perform/withDiary/request，显式打开后的现有编辑入口仍保持自己的认证责任。 |
| ReadOwner 冻结 | [ContentQueryReadOwner.swift](../AreaChain/Domain/ContentQueryReadOwner.swift):49–86 内部持有 Batch（含 Session/原快照）及展示配置；task 只含身份/预算。begin 换来源但保留 published；cancel/fail 也保留旧结果。`:102–114` 同步完成 BatchReader→Sorter→Presenter→DisplayBuilder，无后台安全/合作式中断承诺。 |
| 结果链与票据 | `ContentQueryReadOwner.swift:23–38、119–141`：ticket 含候选 DisplaySnapshot；publication 通过 Pagination→Browse→Display→Presentation→SortedResponse→BatchResponse 保留安全结果。原文字条件仍可存在 [ContentQuerySortContext.swift](../AreaChain/Domain/ContentQuerySortContext.swift):16–31，因此“结果正文隐藏”不代表整条响应链没有用户输入。选择/展开属于 Browse，分页进度属于 Pagination；不能只清可见行。 |
| 真正失效 | `ContentQueryReadOwner.swift:158–165` 的 invalidateSource 才撤销 frozen/published/任务/预算。`:192–198` 阻止旧 source/task 发布，但外部持有的 ticket/publication/值副本不会被它远程擦除。普通取消保留旧结果不适合隐私失效；begin 新来源也不是清理替代品。 |
| 宿主与转交 | [CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift):4–30 只持 query/operations/plan/execution，presentationEvent 故意不操作草稿，没有 ReadOwner 或隐私戳。[CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift):34、86、130 的 lease/ownership 只管宿主所有权；[CommandHandoffContract.swift](../AreaChain/Domain/CommandHandoffContract.swift):3 明确它不是认证凭据。没有生产宿主读取/敏感草稿接线。 |

#### 已核实事实四：元数据与统计披露

[Catalog.swift](../AreaChain/Domain/Catalog.swift):24–54 的 TagUsage 统计未删除待办、习惯、子任务和手记，使用 tagIDs、createdAt、deletedAt；不读正文，不排除受保护手记，不计打卡，不按完成/启停过滤。子任务从 todo 关系取出，只按子任务自身删除状态计数。`latestCreatedAt` 是这些来源的最大创建时间，**不是最近阅读或编辑时间**。

这不只是内部计算：[TagManagementPage.swift](../AreaChain/Features/Workspace/TagManagementPage.swift):125、265–295 实际显示 activeCount；[TagUsageFiltering.swift](../AreaChain/Domain/TagUsageFiltering.swift):26 的 recent 使用最近创建时间排序，但该标签行没有直接显示时间。新搜索输出精确 latestCreatedAt 或根据内容查询统计命中数，都会增加与原标签页不同的推断途径；“旧函数算过”不足以授权披露。

| 元数据 | 当前可见/可查询边界及推荐限制 |
|---|---|
| 标签 | 旧手记行显示关联活标签，标签目录本身显示标签；保护判定另外需要墓碑资料。[DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift):94、340–358。不得把用于保护核验的全量历史名字无条件输出给所有消费者。 |
| 归属日期 dayKey | §1/§9.19 已允许 diary date 查询；`DiaryQueryMatching.swift:55–62` 与 created 分开。不能把旧 UI 的创建日期误称为归属日，也不据此开放正文。 |
| 创建时间 | `DiarySummaryRow.swift:361–369` 在隐藏正文时仍显示创建日期/短时间；QueryMatch 已保留真实 createdAt。单条允许元数据与跨来源最近时间统计是不同披露面。 |
| 置顶/私密标记 | `DiarySummaryRow.swift:321–335` 有图钉/锁图标；`DiaryQueryRead.swift:73–96` 保留置顶，隐私通过 hiddenTitle 投影，不输出 vaultID、密文存在性明细、认证状态或格式故障原因。元数据模式的“隐藏”不等于新宣称所有记录都确认为私密。 |
| 正文未知与统计准确性 | 如果另行批准“全部活关联元数据均计入”，旧 TagUsage 可不读正文算准确次数/最大创建时间，前提是全部来源、关系及字段可靠且口径一致。若要排除私密/旧格式，元数据不足以排除旧正文标记；若统计当前正文查询命中，则未知对象使统计不完整。不能把可读子集称为全来源，或用缺项推导 unused。 |

#### 推荐接线 A：首批手记元数据读取器（D1 已确认，2K-4B 实现见 §9.38）

建议首批采用 **metadataOnly（仅元数据投影）**，连已解锁受保护正文也不读取；普通正文同样暂不提供。代价明确：普通手记在这条新路径也以隐藏标题显示，文字只有已提供标签可决定，否则未知。此限制仅属于首批 Services 适配能力，不修改 DiaryQuery 已支持的可读正文规则，也不接生产 UI 让用户误认为全文搜索已完成。以后开放普通正文或解锁正文须分别授权敏感接触与验证。

以下为 2K-4A 原方案，生命周期部分留在 2K-4C；2K-4B 改为无 vault 依赖的仓储静态枚举，实际接口以 §9.38 为准。原拟新增 `AreaChain/Services/DiaryContentQueryReader.swift`，沿现有 Task/Routine/Tag reader 模式，必要纯值类型放同目录 `DiaryContentQueryRead.swift`，不新增隐私服务：

- `DiaryContentQueryReads`：显式注入已有 ModelContext 和已有 vault，默认枚举闭包只调用 `SwiftDataDiaryRepository.fetchDiaries(for: nil, includeDeleted: true)`；不使用 fetchDiary 的单行截断。构造仓储显式传 vault，不能因默认参数意外初始化 shared。全量包含墓碑是为身份冲突核验，首批只发布 live diary，不启用回收站读取或图片能力。
- `readSources(into:contextFacts:)`：输入调用方唯一 Batch（session/requestID/options/日期）、同批标签资料和来源覆盖、只读生命周期戳；戳包含明确 vault 实例身份、generation/revision/state、宿主本地失效序号，**不含 configuration、vaultID、密钥或认证闭包**。统计输入保持原注入接口，不由该 reader 生成。
- 返回 `DiaryContentQueryReadDetails`：来源覆盖、body 模式、封闭问题类别（未提供/读取失败/保护资料不完整/来源失效），并只填 Batch.diaries；不返回模型、密文、正文闭包、文件路径或底层 error.localizedDescription。维护 pending/unknown 只作限制事实，不伪造 migrationComplete，也不把清理状态回显为逐条格式细节。
- 每行显式组装 DiarySnapshot：id/dayKey/createdAt/deletedAt/tagIDs/isPinned 原值，isPrivate=`entry.hasProtectedContent`，text 为空且 isContentAvailable=false。不调用 entry.snapshot/DiaryContent.snapshot/read，不将该空字符串作已读正文。hasProtectedContent 的可选密文字段检查仍可能接触密文，属于 D1 已接受的模型接触边界。
- 无 diary 需求、指令输入或结构非法时不 fetch；fetch 失败为 `.failed`，未授权模式或失效为 `.notProvided` 并有来源问题，绝不 `.complete([])`。成功全枚举可标“记录源完整”，与正文/隐私资料完整独立。非法日期、重复 diary ID 交原 Provider 隔离，不自行修复。vault 未配置/锁定/unavailable 不等于元数据为空；只要来源有效仍可投影隐藏元数据，但绝无正文能力。
- 读取前后核对同一来源戳；来源改变时丢弃这次结果，不混合旧 diary 与新 tag。同步 MainActor 同一 context 不保证跨进程/上下文事务原子性，不设置 autosaveEnabled、不 save/rollback，不把调用方未保存变更清掉。模型注册缓存由 context 拥有，reader 返回后清自身引用不能保证 context 也释放敏感字段。

同批 metadata 只在 TaskFamily 最后装配一次。扩展 `ContentQueryTagNames.associatedIDs` 纳入本批 diary ID；需要手记保护资料时通过现有 Catalog 仓储枚举完整标签（含墓碑），同次 rows 供 TagContentQueryReader 与保护投影复用，不拿两个独立 Batch 拼接。**保留 ContentQueryTagNames 现有私密名字拒绝规则**；它返回 nil 时接受名字查询未知，不悄悄扩大任务/手记名字可见范围。以后希望对私密关联显示名字应另行核对，不在此首批顺带实施。

全目录成功、身份唯一且保护字段可解释，才可把全局 isPrivateDiary ID 集合填入 privateTagIDs；重复目录 ID、读取失败或无法证明全集时仍 nil，不以空集合代替。旧密码名称由 DiaryPrivacy 复用，不造另一份关键字规则。名字缺失/歧义仍阻止 canPublishBody。没有正文旧标记核验时，`imageCoverage.diaryPrivacy` 和 `trashCoverage.diaryPrivacy` 保持 notProvided/已有更保守值；也不提升 trashTagNamesCoverage、图片身份/关联覆盖。后续要放宽完整性必须单独证明，不能由本节读取器存在推导通过。

#### 推荐接线 B：失效、发布与宿主生命周期（D3 已确认，搜索生命周期实现见 §9.39）

以下保留 2K-4A 当时的设计措辞与限制；当前实际实现及证据以 §9.39 为准，敏感草稿封存仍未实现。

拟由 `AreaChain/Services/ContentQueryReadSession.swift` 中的 `@MainActor` 宿主读取适配持有现有 ReadOwner、待发布票据、当前呈现引用和订阅。它只协调搜索生命周期，不负责认证、加解密或持久化；不把实体或票据塞入可复制的 CommandHostSession。生产工作台/菜单栏尚未接线，先做隔离宿主测试。

1. 注入明确 vault 实例；订阅该实例 `.privacyWillLock/.privacyDidChange/.privacyMask`。willLock 同步先推进本地失效序号、关闭发布闸门，再 invalidateSource、清宿主持有的票据/展示链/摘要/分页/选择/待打开引用；此处不能读旧 unlocked 来跳过。没有当前 source 时同样清宿主引用。begin 普通替换保留旧 published 的行为保持不变，保护变化必须先 invalidate。
2. 用现有 Observation 对 `vault.generation/state/isAuthenticating/revision` 建立只读跟踪，以补认证开始无通知的缺口；变更回调按“即将失效”处理，不依赖回调里读到新值。复订阅完成前闸门关闭，随后读取当前值建立新戳。该 adapter 不调用/改写 beginAuthentication、lock、persist 或认证方法；Observation 的回调时序、actor 假设及重复订阅是后续必测项，不能仅靠 didChange 宣称即时撤权已覆盖。无法可靠覆盖时，不上线需要即时失效的正文读取。
3. 冻结来源绑定 `(host lease/ownership, local invalidation epoch, vault instance + generation/revision/state, ReadOwner.source)`；这些值功能不同，requestID 不能代替任何一个。读取、evaluate 前后，以及 publish/loadMore/applyBrowse/打开意图消费前都核对；检查与 publish 在同一个 MainActor 同步片段内，之间不 await、不补盖新戳给旧任务。任何不一致先清除再拒绝。认证结束/再次解锁只允许新读取，不复活原票据或自动显露旧内容。
4. `.privacyDidChange` 或业务保护/标签变化先失效后重建。已保存变更沿 [ModelChanges.swift](../AreaChain/Services/ModelChanges.swift):31–39、100 的提交后 `BoardEvents.changed()` → [BoardEvents.swift](../AreaChain/Services/BoardEvents.swift):33–34 的 `.boardDidChange` 接入（通知不带 context，首批可保守失效，不据此宣称指定库的精确代次）；未保存实体变化不保证有通知，必须由实际宿主观察/显式重读，现有家庭 reader 不是观察器。涉及隐私判定变化时不走保留旧结果的普通重读。首批未接生产前需明确实际宿主的变化来源，不能假称完整业务失效已覆盖。
5. `.privacyMask` 与本宿主 `NSWindow.didResignKeyNotification` 只撤销显示资格，不调用 vault.lock，不改变认证。建议遮住查询输入及结果，释放派生结果链、令旧票据失效；宿主内查询可短暂保留，重新聚焦不会自动恢复敏感结果，须显式恢复并重读。willLock 则按 D3 清查询文字。失焦不清操作草稿、不把遮罩当作加密，保留的 String 仍在内存。
6. D3 已确认真正锁定时清除**搜索查询**的原文、用户文字/标签名条件、补全缓冲、返回快照与排序上下文，只从可信页面重新建自动范围/日期；不能只清编辑框而留 Session.conditions。没有无内容证明的用户输入都按敏感处理，不用关键词猜测。公开结果也先撤整条旧链（其 sort context 可能有输入），随后允许从安全新查询重建日期/置顶/已允许标签及隐藏标题，不沿用旧排名、数量、游标或锚点。清查询是已确认但尚未实施的生命周期行为，留在 2K-4C。
7. CommandHostSession 的操作草稿/计划/执行与搜索查询分开。本阶段不接敏感写草稿；后续须复用 DiaryEditorSession/SealedDiaryDraft 的封存和失败保留，而不是清整个 HostSession。Handoff 仍依原 lease 原子转交普通查询/草稿；不转移 ticket、结果、解锁或显式显示许可，源目标旧读取分别失效，目标重新读取。私密草稿接线未完成前，不能把普通 Handoff 作为私密转交能力交付。

同步 evaluate 在执行期间不能即时处理排队到主线程的系统事件；它完成后先回到调度边界，再在单独发布步骤重核闸门，且所有入口核对当前戳。此办法可拒绝已处理失效后的迟到结果，**不证明长同步计算期间事件零延迟**。首批无正文路线也须测事件次序；大库耗时与合作式取消另有缺口，不能在本轮把 ReadOwner 移到后台或宣称已有线程安全。

清引用和值冻结分别证明逻辑不可再访问、输入不随模型变化；不证明物理内存擦除。Swift String 写时复制、临时值、Task 捕获、外部副本及 SwiftData 注册对象均可能延长存活。不得承诺字符串安全零化；公开 response 的 description 脱敏也不是内容访问控制。

#### 推荐接线 C：统计暂不接入真实来源（D2 首批限制，2K-8 更新）

以下保留首批决策；后续明确授权的全来源元数据统计与隔离证据见 §9.44。

首批新搜索 `tagUsage=nil` / usageOrigin=notProvided，结果为 unavailable；不为补齐统计读取手记，不自动包含或单独计出受保护手记，不输出精确最近时间，不新增“受保护若干条”的计数。旧 TagManagementPage 行为保持原样。

若后续仅有任务类/公开子集或读取失败，表达 `partial(completeTagIDs: [])`，只对能够证明所有来源与披露许可均完整的标签列入 completeTagIDs；不发布部分正数、假零或“至少 N”。[TagQueryUsage.swift](../AreaChain/Domain/TagQueryUsage.swift):45–64 已使 unavailable/partial 不带 record；只有完整覆盖缺项才补零。[TagQueryProvider.swift](../AreaChain/Domain/TagQueryProvider.swift):102 起已有 frequent 保留目录次序回退、recent/unused 未知反馈，继续复用。来源失败后撤回旧 complete，不能沿用上一批统计。

若用户选择未来对齐旧全来源统计：可参与的字段限定稳定 tagIDs、createdAt、deletedAt及必要归属/唯一身份；计入受保护手记但不读正文、不发布私密子计数。必须核对所有 todo/subtask/routine/diary 的枚举完整、孤立/重复/坏日期及墓碑影响；不能对当前搜索确定命中子集调用 TagUsage 后声明全目录完整。精确 latestCreatedAt 对外显示相对旧标签页是新增信息，需再明确允许才进入实现；仅同意“旧次数/最近排序”不隐含同意精确时间披露。

#### 文件、符号、消费者与最小改动建议

以下是后续影响清单，不是本轮差异，也不是未经核验的代码补丁；目前只改本文。拟新增文件以代码格式列名，不创建空文件。

| 文件/符号 | 最小改动与消费者 |
|---|---|
| `Services/DiaryContentQueryReader.swift`、必要时 `DiaryContentQueryRead.swift` | 新增明确依赖的只读枚举及 metadataOnly 投影；消费既有 DiaryRepository 的枚举、DiarySnapshot/QueryProvider；首先由 Services 隔离测试和家庭装配消费。无写入/解密/全局初始化。 |
| `Services/TaskFamilyContentQueryReader.swift` | 唯一 Batch 装配增加 diary 源与 details；同批标签只 fetch 一次，metadata 最后赋值一次；旧任务类入口默认不开 diary，兼容原 Services 测试。名称是否日后泛化不在首批重构。 |
| `Services/ContentQueryTagNames.swift`、`TagContentQueryReader.swift` | associatedIDs 加入 diary；窄扩展同批目录资料复用，保留私密名拒绝/失败撤回。全目录保护集合与公开关联名字是两种投影，不能用一个 coverage 替换。 |
| `Services/ContentQueryReadSession.swift` | 拟新增搜索宿主适配，显式 vault + ReadOwner + 事件订阅；承接原 source/ticket/pagination，处理清理和发布前检查，不发认证请求。 |
| `Domain/ContentQueryReadOwner.swift` 与展示/分页 | 优先直接复用 invalidateSource/身份拒绝，不改变普通 cancel 保留语义；若隔离测试证明生命周期 API 不足，再提出最小变更。不复制 Sorter/Presenter 或增加敏感结果缓存。 |
| `Domain/CommandHostSession.swift` / `ContentQueryReducer` / Handoff | D3 已确认，2K-4C 才增加“只清搜索”的明确领域事件，覆盖原文与返回状态；操作草稿/计划不动。实际生产宿主与敏感转交另阶段接入。 |
| DiaryContent / DiaryPrivacy / PrivacyVault / PrivacyAccess / DiaryProtection / Persistence | 首批只复用/读取既有契约，不改认证、密钥、加密、迁移或存储格式；完整性与事件缺口不能在这些文件里悄悄补高风险实现。 |
| Catalog / TagQueryUsage / ImageAssociation | 保留算法与披露边界，新增夹具回归即可；统计及图片真实读取均不随 diary 元数据读取启用。 |
| Services/Domain 对应测试、本文、原组件目录/架构/路由 | 后续实际新增公共入口时同步原索引与检查规则所需测试；2K-4A 未新增入口，按本次授权只维护本文，不建立平行报告或第二套检查器。 |

#### 后续可执行的隔离验证计划（本轮未运行 Swift）

在重新检查工作区、签名/测试入口和注入隔离条件后，复用原内存 ModelContainer、固定 Calendar/时钟、MemoryVaultConfigurationStore、FakeSystemVaultKeys 与 TaskFamily/Tag 夹具。不得初始化生产 Persistence.session 或读取真实用户库/偏好；测试计数只记录封闭操作类型，不记录查询/正文。普通脚本入口清除真实钥匙串授权；不要为了消除 skipped 而启用真实用例。

| 场景 | 输入与断言；需新增的证据 |
|---|---|
| 未配置/锁定/已解锁/访问失败 | 注入四态 vault、失败 fetch、失败配置加载。metadataOnly 所有态均无 DiaryContent.read/keys.open；成功只给元数据，失败保留 failed/unknown。若未来授权正文模式，再用 fake keys 验证 read 失败降为不可用而非空，不自动解锁、不 touch。 |
| 普通/受保护/旧格式/资料不足 | 合成 text、保护标志单独为真、密文或 vaultID 单独存在、旧 #密码/#password、明文与密文并存、坏日期/重复 ID。首批全部 text=""/available=false，模型原字段前后不变；旧格式不被清理/修复。完整行覆盖不等于完整隐私覆盖。 |
| 标签完整性 | 完整空、缺名/空名、重复标签 ID（含活/墓碑）、同名不同 ID、删除私密标签、旧密码名、孤立 tagID、非法/重复关联片段。全局私密集合不足保持 nil；元数据已有证据可判断，无证据才未知；不创建标签。 |
| 真实锁定与迟到发布 | 分别在 prepare 后、evaluate 前、票据完成后、publish 前注入 willLock/代次变化；尤其 willLock 回调仍 unlocked/旧 generation。断言立即撤引用、旧票据拒绝、重新解锁不能复活旧 source，旧分页/选择事件拒绝。 |
| 认证开始/订阅重入 | 不运行认证，使用 fake/隔离 vault 的受控代次推进与同 actor 变更；验证 Observation 在 didChange 缺席时也关闸，复订阅间隙拒绝发布，取消/失败也不恢复旧结果。仅 notify 模拟不能证明真实属性观察有效，需直接改变被观察的注入对象。 |
| 计算中失效 | 原 evaluate 同步，不伪造“并行修改同一个 owner”测试。先验证可控调度的完成/失效/发布顺序；若未来增加异步计算，必须另测计算完成前取消和晚到任务拒绝，不能拿现有同步测试宣称合作式中断。 |
| 失焦遮罩 | 分别发 privacyMask、本窗口与另一窗口 resignKey；检查不调用 lock、vault generation 不变、不清操作草稿；只遮罩/撤显示资格。真正 lock 清查询按 D3 执行，回到前台不能自动显露旧敏感结果。原生事件测试留给未来隔离宿主，非本轮整套 UI。 |
| 三态/安全输出 | 日期、tagID、允许标签名可决定的结果与正文依赖 unknown 分开；正负/AND/OR 用原 DiaryQueryUnknownTests；输出递归检查无原正文、片段、范围、长度或原始错误，含 SortContext 中查询残留的清理。 |
| 图片 | 同一受保护手记分别零/一/多图，完整/不完整 diaryPrivacy、重复/坏图片元数据；安全公开结果等价，不能因标签完整或解锁输出文件名、图片数量/存在真值。新 reader 不读取图片文件。 |
| 统计 | 默认 unavailable；仅部分来源是 partial 且 record=nil；不得以零证明 unused，recent 未知/frequent 回退；锁定前后不能残留上一批精确统计。若将来选择全来源口径，另测受保护记录贡献、创建时间而非编辑时间、失效撤回，仍不单独披露保护数量。 |
| 只读副作用与释放 | 用独立 ModelContext 核对持久化前后及未保存插入/修改/删除保留；注入 spies 断言解锁、密钥读取、转换、save、rollback、业务通知和系统权限写入均零。外部持票据副本时失效仍必须拒绝发布；释放测试只证明所有者/引用生命周期，不证明 String 零化。 |

可先复用的现有回归命令（后续实施时串行执行，**不是本轮执行记录**）：

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DiaryQueryPrivacyTests \
  --only-testing AreaChainTests/DiaryQueryUnknownTests \
  --only-testing AreaChainTests/DiaryQueryBoundaryTests \
  --only-testing AreaChainTests/ImageAssociationPrivacyTests \
  --only-testing AreaChainTests/RecordImageQueryPrivacyTests \
  --only-testing AreaChainTests/ContentQueryReadLifecycleTests \
  --only-testing AreaChainTests/ContentQueryReadPublicationTests \
  --only-testing AreaChainTests/TagQueryUsageTests \
  --only-testing AreaChainTests/TagContentQueryUsageTests \
  --only-testing AreaChainTests/TaskFamilyContentQueryIntegrationTests
```

新增 reader/生命周期测试必须从实际模型→家庭装配→ReadOwner→展示/分页验证，不能手工替换最终 snapshot；受影响 Swift 最终编辑后再做定向回归和 Debug 构建。旧 PrivacyMigration/PrivacyStoreMaintenance 测试可作为夹具设计参考，首批只读验证不需要执行转换/冷库重建；真实钥匙串、真实系统锁屏、生产数据实验均不在本计划授权内。

#### 实施授权、风险与回退

| 拟议项 | 复用还是边界变化 | 实际风险、验证与回退 |
|---|---|---|
| 元数据 reader | 复用仓储枚举和安全 Query；**增加新入口对 DiaryEntry 模型/保护字段的接触**，即使无显式正文访问 | SwiftData 可能物化明文/密文；D1 已明确接受该物化限制。用隔离模型/副作用 spies/输出断言验证，不能证明底层零接触。关闭新 reader 恢复 diary=notProvided 只阻止后续读取，还需撤去已存在结果/上下文引用。 |
| 失效 adapter / D3 查询清理 | 复用 vault 事件/可观察代次、ReadOwner 失效；**改变查询及派生值存活期** | 通知在状态改变前、迟到任务、外部副本、误清业务草稿。用事件顺序/观察重入/旧票据测试；出问题先关闭新搜索读取并撤结果，回退 adapter 代码不能让过期票据重新有效。 |
| 首批 metadataOnly 安全投影 | 无正文解密和格式转换；新搜索获得已允许的单条元数据查询能力 | 隐藏标题也暴露记录存在性，允许范围沿已确认 §1，不扩到图片细节、历史名字全集或故障信息。使用输出等价和三态测试；回退读取/呈现入口，不改原手记页面。 |
| 统计 unavailable | 复用原未知统计契约，首批不增加精确统计披露 | 用户可能无法使用新入口的 recent/unused 完整筛选；明确 unavailable，不假零。若以后开启受保护贡献/精确最近时间属于额外披露，须另定界、测覆盖，回退时撤掉统计及依赖排序，不能仅隐藏数字。 |
| 普通/受保护正文后续开放 | 属于**敏感数据接触与生命周期扩大**，不是此次读取方案自动附带 | 复用 DiaryContent/DiaryPrivacy 仍需验证锁定、读取失败、内存副本与公开输出；当前暂缓，未获授权不能实施。回退禁止新读取并清逻辑引用，不承诺擦除全部内存。 |

四种回退必须分清：**关闭入口**阻止新读；**撤去内存结果**使已有发布/票据/查询失效；**回退代码**恢复软件行为但不会自动清正在运行进程或其副本；**恢复数据**是独立高风险操作。本方案没有数据迁移、格式写入或数据库修改，因此正常回退不需要恢复数据，更不能以回退之名重置库、解保护或重做转换。若隔离测试发现任何写入，停止接线并调查，不能把备份恢复当作只读 reader 的常规后续。

#### 已由用户确认的三个决策（2026-10-02）

| 决策 | 已确认要求 | 实施状态 |
|---|---|---|
| D1 首批接触边界 | 暂时仅 metadataOnly；接受 SwiftData 可能物化正文/密文，不显式访问或复制正文、不解密，不宣称正文完全未进入内存。正文判断未知、隐藏展示，不替换生产搜索。普通正文搜索和既有授权下私密正文匹配仍是最终必须完成能力。 | 2K-4B 仅隔离实现，见 §9.38；生产入口须等待隐私失效接线及相关验收。 |
| D2 新搜索统计 | 首批真实统计 unavailable 的阶段限制在 2K-8 按新增明确授权补齐：全来源含受保护手记，仅元数据、旧次数与最近排序，不公开精确时间或私密分项；旧页不变。缺源仍回退/未知。 | 2K-8 已增加隔离存储适配与受门禁发布，见 §9.44；生产入口、性能和指定复核仍未完成。显式注入统计继续独立标为 injected。 |
| D3 真正锁定后的查询 | 清除搜索文字、查询条件、结果、摘要、选择、展开，立即失效旧任务/票据；锁定通知到来立即撤销发布资格，不等待 generation 递增。普通失焦/收起保留查询，仅遮罩敏感展示，不自动认证/提交；再次解锁不自动恢复已清查询或结果。操作草稿不能直接丢弃，敏感内容须沿已有封存/遮罩机制，封存失败反馈并保护唯一草稿，不宣称清理成功。清引用不等于字符串安全零化。 | 2K-4C 仅实现搜索生命周期、只清搜索和发布门禁，见 §9.39；敏感草稿封存仍未实现。指定复核与历史验收缺口保留。 |

本轮用户仅明确授权 **2K-4B** 的注入上下文元数据读取、同批标签与隔离回归，完成后停止。**2K-4C** 仍待单独实施读取生命周期 adapter、Observation/发布闸门和只清搜索事件，先做 fake vault 与隔离宿主验收，不改认证；敏感操作草稿封存仍需明确后续阶段。后续正文能力与完整统计是必须完成的交付项，不因本阶段暂缓而从最终目标删除。4B 不可先于合格失效接线和相关验收开放生产全局手记搜索。每步共享契约复核仍指定 Cursor verifier，不可用继续 partial，不以其他代理或测试替代。

#### 本轮实际检查与未执行项

本轮只进行了源码/既有测试静态阅读、事实出处抽查、同一权威文档更新；实际运行 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json` 和 `git diff --check -- docs/unified-search-commands.md` 均 passed；static 包含 184 项原脚本回归，高风险/敏感日志候选均为 0。静态检查针对当时整工作区，不能认领并行 Swift 的运行验收，也不证明本方案安全接线已通过；最终文字修订后复跑同一门禁。没有运行 Swift 测试、构建、原生宿主、真实钥匙串、生产应用或生产数据实验；没有修改产品 Swift、认证/加密/权限/统计算法，没有提交、推送、安装、发布或新增平行报告。已有测试中的断言与前阶段通过数量仅是来源，不计作本轮通过证据。


### 9.38 阶段 2K-4B：手记元数据只读适配、同批标签装配与隔离回归

#### 范围与实际接口

本阶段只处理注入的已打开 ModelContext 和隔离合成数据库。D1～D3 确认见 §9.37；D3 仅登记，不实现监听、ReadOwner 生产失效适配、窗口接线或敏感草稿封存。指定 Cursor verifier 仍未执行 / blocked，不重复登录检查、不改认证、不冒充指定复核；整体 partial，历史阶段验收缺口继续保留。

- [DiaryContentQueryReader / Reads / ReadDetails](../AreaChain/Services/DiaryContentQueryReader.swift)：`init(context:)` 或窄闭包依赖，`readSources(into:)` 只填调用方 Batch.diaries。`TaskFamilyContentQueryReader(context:diaryMode:)` 默认 nil，只有显式 `.metadataOnly` 才启用；窄依赖初始化显式传 diaries 也表示开启。无手记需求、指令/非法查询、回收站范围均不读取。旧任务入口默认兼容。
- [SwiftDataDiaryRepository.fetchAllDiaries(in:)](../AreaChain/Services/Repositories/SwiftDataDiaryRepository.swift) 复用原私有枚举和排序；原仓储实例方法也委托同一枚举。静态入口无需构造 vault/附件依赖，不初始化全局 PrivacyVault 或 Persistence。包含活行、墓碑、重复身份核验所需所有行，不设 fetchLimit、不去重、不修复。
- 手工投影 ID、dayKey、createdAt、deletedAt、tagIDs、isPinned；`hasProtectedContent` 的布尔结果保留在快照 isPrivate。该已有 getter 判定 isPrivate、密文是否存在、vault 标识是否存在；不复制密文或库标识，不把 false 当作已确认公开/迁移完成。
- `DiarySnapshot.text=""` 是无正文占位，`isContentAvailable=false` 恒成立；ReadDetails 明确 mode=metadataOnly、bodyNotRead/protectionNotEstablished。普通、保护标志、旧格式形状均如此，vault 已解锁也不会改变限制。所有匹配经既有 DiaryQueryPrivacy / DiaryQueryProvider 安全投影，不另建隐私分类。
- 不调用 entry.snapshot、DiaryContent.snapshot/read、旧 searchDiaries、认证、解密、保护转换、维护修复、save/rollback、ensurePresetTags/resolveOrCreateTag。SwiftData 仍可能物化正文并由 ModelContext 缓存；测试和源码边界检查不证明正文完全未进入内存。
- fetch 失败返回 failed 和封闭 fetchFailed，不伪装 complete([])，不返回底层错误。dayKey/createdAt/tagIDs/重复身份继续由 Query 验证；deletedAt 无效时间另在读取详情诊断，原值保留。只保证同一上下文、同步调用的值投影，不声明多次 fetch 跨上下文/进程事务原子性。读取不调整 autosave、不保存、回滚或清理已有未保存变化。

#### 同批 metadata、覆盖及统计

TaskFamily 先读取任务、平面子任务、习惯和显式开启的手记，再合并关联 tagID。手记成功枚举时，TagContentQueryReader 通过原 Catalog 仓储完整枚举一次标签（含墓碑）；同一 rows 同时用于按需 TagQuerySnapshot、ContentQueryTagNames 和 [DiaryContentQueryTagPrivacy](../AreaChain/Services/DiaryContentQueryTagPrivacy.swift)，最后仅在 TaskFamily 赋值唯一 metadata。不合并独立 Batch，不在目录失败后追加另一次关联读取。

ContentQueryTagNames 保持原公开名字限制：缺失、重复关联 ID、isPrivateDiary 名字不可用分别诊断，任何问题仍 names=nil，不静默放宽其他来源。全目录身份唯一才输出私密标签 ID 集合，含未关联的私密墓碑；任意重复目录 ID 或 fetch 失败时集合为 nil，分别报告 ambiguousID/fetchFailed。名称缺失与全目录私密标志资料是不同事实，旧正文标记核验又是第三种事实。私密名字查询因此可保持未知，不因此公开私密关联名称。

元数据枚举 complete 不提升 imageCoverage.diaryPrivacy、trashCoverage.diaryPrivacy、图片身份/关联、手记回收站类型或 trashTagNamesCoverage。单独手记查询为保护读全标签目录，也不宣称标签内容来源已接入；仅原请求需要标签提供者时装入 tags。图片、剪贴板仍 notProvided，无文件、附件读取。

不生成真实 TagQueryUsageInput，不从手记计数推导全来源完整；默认 unavailable，all/名称仍可用，frequent 沿原明确回退，recent/unused 未知。injectedUsage 仅原显式测试接口，origin=injected 不表示本阶段真实统计已完成。旧标签页和 TagUsage 口径不变。普通正文、既有授权下私密正文匹配及完整统计仍须后续交付，默认统计披露以旧页公开口径为目标。

#### 隔离验证与证据状态

新增 DiaryContentQueryReaderTests、TagTests、FailureTests、IntegrationTests，复用原 TaskRepositoryFixture 全 schema 内存容器。覆盖真实 DiaryEntry → metadataOnly → 同批 Batch → DiaryQuery → ReadOwner → 排序/摘要/分页；同时检查普通/受保护/旧格式形状、墓碑/重复身份、字段异常、缺名/重复/私密标签墓碑、未知正负文字、零业务通知、未保存变化、冻结输出与其他来源不被覆盖。源码禁止调用核对与这些运行测试分开记录；不读取真实内容或运行内存物化实验。

2026-10-02 最终 Swift 修改后的实际证据：

| 检查 | 结果与边界 |
|---|---|
| 隔离串行 Swift 回归 | 40 套、234 个测试（292 次含动态参数运行），零失败、零跳过；涵盖四套新服务测试及 DiaryQuery、任务/习惯/标签读取、TagQuery、Batch、ReadOwner、排序/摘要/分页、图片隐私回归。使用架构文档的隔离 xcodebuild 方式，目录 `build/DiaryMetadataQA`、标识 `com.areachain.diary-metadata-qa`、本地临时签名，清除六个真实钥匙串授权变量、`-parallel-testing-enabled NO`，合成内存库。结果 `build/DiaryMetadataQA/Logs/Test/Test-AreaChain-2026.10.02_18-05-22-+0800.xcresult`。 |
| 首轮失败及修正 | 新集成测试最初用混合维度 `(unknown | #工作)`，当前语法拒绝，未生成 diary 提供者；改为合法文字分支 `(unknown | 工作)`，通过已有文字对标签元数据匹配验证确定 OR。没有改解析器、三态规则或删掉未知/排除断言；最终整组回归通过。 |
| 局部严格 SwiftLint | 本阶段 6 个 Services Swift 文件和 5 个测试/夹具文件，`swiftlint lint --strict --quiet <上述文件>` 通过，无警告。 |
| Debug 构建及验签 | `./scripts/build.sh` exit 0，静态签名核验通过；使用原配置，未改变签名、安装或启动产物。隔离测试全 target 编译仍报告其他文件既有未使用返回值与废弃 API 警告，不将它们认领为本阶段修复。 |
| 工作流与脚本 | `python3 -B scripts/check_workflow.py` 通过；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` 65 项通过；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含完整 185 项 scripts/tests 回归，高风险/敏感日志候选为 0。原组件守卫只增加两个入口及对应反例，未建立第二个检查器。最终文档回填后再跑工作流、静态门禁和差异检查。 |
| 源码调用边界 | 单独核对五个读取/装配/名字/保护投影文件和仓储静态枚举段：无 entry.text、encryptedText 内容复制、snapshot、DiaryContent、PrivacyVault/Persistence 初始化、旧搜索或写入/认证调用。仓储静态段仅共享 fetch 与排序，hasProtectedContent 沿既有布尔存在性 getter。此为源码取证；运行测试证明安全值输出、失败、冻结、未保存变化和零业务通知，不声称监测 SwiftData 物化或证明字符串零化。 |

本轮按用户“仅隔离”限制使用静态质量 profile，加上述严格 SwiftLint、显式 QA 定向测试与 Debug 构建；未运行 `quality_gate.py --profile swift`，因为它固定调用普通全套 `build.sh test`，不能传入本次 QA 标识与定向范围。未认领全树 Swift/原生验收。指定 Cursor 复核仍未执行 / blocked，整体 partial；未运行生产宿主、真实系统认证/锁屏、真实库、安装或发布。

本次文件增量：上述 6 个 Services 文件（含原 ContentQueryTagNames、TagContentQueryReader、TaskFamilyContentQueryReader 及仓储），[ReaderTests](../AreaChainTests/Services/DiaryContentQueryReaderTests.swift)、[TagTests](../AreaChainTests/Services/DiaryContentQueryTagTests.swift)、[FailureTests](../AreaChainTests/Services/DiaryContentQueryFailureTests.swift)、[IntegrationTests](../AreaChainTests/Services/DiaryContentQueryIntegrationTests.swift)、[夹具](../AreaChainTests/Services/DiaryContentQueryTestSupport.swift)，以及本文、[架构](architecture.md)、[组件目录](component-catalog.md)、[技能路由](../skill-routing.md)、[原检查器](../scripts/check_workflow.py)和[原反例测试](../scripts/tests/test_check_workflow.py)。保留这些文件已有并行修改和其他不相关改动。


#### 2K-4C 的准确前置与停止点

后续首先处理 `privacyWillLock` 在 generation/state 变化之前同步到来的顺序：立即撤销本地发布资格和旧 source/ticket，再清查询及派生状态，不能等待代次增长或据回调中的旧 unlocked 放行。补齐 generation/state/isAuthenticating/revision 的 Observation、复订阅空窗和重入验证；只监听 didChange 不足以覆盖认证开始。读取、evaluate、publish、分页、选择/展开、打开意图消费需要一致的宿主归属/本地失效序号/来源戳检查，检查与发布之间不能 await，也不能给旧任务补新戳。

真正锁定清搜索原文、条件、返回查询、结果链、摘要、排序上下文、选择和展开；再次解锁不能自动恢复。失焦/收起保留查询，只遮罩敏感展示，不自动认证或提交；操作草稿保护与搜索清理必须分开，封存失败仍保护唯一草稿并反馈。上述均为已确认要求而非本阶段实现。未保存模型变化的通知来源、真实宿主归属、外部票据/值副本、Observation 时序及敏感草稿后续衔接仍待实现和验收；清逻辑引用不等于字符串零化。

完成 2K-4B 后停止。不进入 2K-4C，不开放生产全局手记搜索；不提交、推送、安装、启动生产应用或访问真实用户库。


### 9.39 阶段 2K-4C：搜索隐私失效、查询清理与结果发布门禁

本阶段获用户明确授权实施 D3 的搜索生命周期部分。复用 §9.37 推荐接线 B 和 §9.38 的 metadataOnly；没有修改 PrivacyVault 的认证、加密、配置或持久化规则，没有接生产入口、真实窗口、真实用户库、真实系统钥匙串或隐私转换。操作草稿仅使用普通合成设置草稿验证保留；**敏感操作草稿封存仍未实现，不具备安全承接敏感草稿的声明**。指定 Cursor verifier 未执行 / blocked，历史缺口不因本阶段授权消失；整体 partial。

#### 实际接口与唯一所有权

| 接口 | 责任与消费边界 |
|---|---|
| [ContentQueryReadSession](../AreaChain/Services/ContentQueryReadSession.swift) | `@MainActor`，显式注入 vault、独占 ReadOwner、CommandHandoffCoordinator、固定 CommandHostOwnership 和通知来源。`install/detach` 管理生命周期；`prepare(read:) → evaluate → await publish` 为唯一 Services 发布链。任务句柄只有不可外部拼装的 UUID，响应票据只保存在适配器内部。当前消费者仅新增隔离测试。 |
| [ContentQueryReadNotifications / Gate / Subscriptions / VaultStamp](../AreaChain/Services/ContentQueryReadLifecycle.swift) | 显式 privacy/model/focus center、失焦通知名及对象；无生产窗口查找。Gate 使用 macOS 14 可用的 OSAllocatedUnfairLock，同步记录本地失效序号和误投递故障，不持有正文或查询。 |
| [CommandHandoffCoordinator.invalidateSearch(ownedBy:)](../AreaChain/Domain/CommandHandoffCoordinator.swift) | 系统失效核对 coordinator、host、ownership generation，允许同一所有权内已更新的用户修订；随后通过原 `send` 和 HostSession 的查询 reducer 清理，并推进 lease revision。旧用户事件仍必须带原 lease，不能使用该入口给旧事件重盖新 lease。转交后来源旧 ownership 被拒绝，不清接收方的新内容。 |
| [ContentQueryEvent.privacyInvalidated](../AreaChain/Domain/ContentQuerySession.swift) / [Reducer.privacyReset](../AreaChain/Domain/ContentQueryReducer.swift) | 与 `clearUserQuery` 独立：清原文、所有用户及自动/冻结条件、suppressed、返回与转交上下文；连旧 page 的筛选/reference 也撤去。只重建空查询，使用无条件 overview、空 reference、新 visitID 和固定占位日期，标记 `independent(.privacyInvalidated)`。没有返回/页面同步意图；宿主必须明确 `enterPage` 传可信当前页面，才重新生成允许的自动条件；此前普通编辑/rebind 被拒绝，读取返回 `pageContextRequired`，不能使用占位日期解析新查询。已清查询转交时两端继续等待可信页面。 |

查询 reset 仅替换 HostSession.query；CommandDraftSession 的 active/retained/pending、CommandPlan 和执行记录原样保留，不提交、不恢复、不封存。补全缓冲由适配器 `setCompletionBuffer(expecting:)` 按当前 lease 接收，真正锁定时释放；未来原生输入、撤销/IME、候选控件若另持原文必须纳入宿主生命周期，不能声称这个字段已清除尚未接入的 UI 缓冲。

#### 事件、Observation 与线程

- `PrivacyVault.lock()` 现有顺序是同步 `.privacyWillLock` → generation 增长 → 清密钥/状态 → `changed()`。订阅 `queue:nil`，先比较通知 object 与注入 vault 的对象身份；Gate 在回调入口同步推进失效序号，再进入 MainActor 清 source、票据、显示引用、待打开意图和查询。willLock 不读取旧 unlocked 决定是否清理，也不等 generation。
- `withObservationTracking` 跟踪实际 `generation/revision/state/isAuthenticating/isChangingMethods`。onChange 按 will-change 处理；此时不假定字段已经更新。同步撤权与释放旧读取，停止当前一次性跟踪；只安排一个 MainActor 重订阅任务，空窗期间 `isTrackingReady=false`，所有新读取被拒绝。重订阅结束也不签发许可、不恢复结果；必须显式 prepare。没有把旧任务盖上新代次。
- 一次性 Observation 没有公开取消句柄。每次跟踪有独立可停用 token，重订阅先停用旧 token；旧 registrar 闭包只弱捕获适配器，不再派发或保留查询。重复 install 幂等；detach 取消重订阅任务、移除通知订阅并关闭 token；重装使用新 installation 身份，旧任务/回调不能修改新安装。销毁也关闭订阅并 invalidateSource。
- actor 依据来自现有 `@MainActor PrivacyVault` 的 lock/changed/实际属性写入，以及 NotificationCenter 同步投递、Observation 同步 will-change。桥接在检查 `Thread.isMainThread` 后使用有上述依据的 `MainActor.assumeIsolated`；没有新增 unchecked Sendable、后台读写 vault 或 main.sync。若明确通知源被错误地从非主线程投递，锁内立即撤权，MainActor 清理排队执行，该安装保留 `unexpectedExecutor` 并持续关闭；不把这种误投递当成同步清理通过。
- `.privacyDidChange` 保守撤去来源及显示；`.privacyMask`、注入的目标宿主失焦信号或 `loseFocus(expecting:)` 保留查询、撤去整条旧显示链并设遮罩。采用整链撤回可避免旧排序条件/摘要经公开行引用存活。不会调用 lock、认证或提交；恢复焦点本身不能复活旧结果。`resumeDisplay(expecting:)` 只解除本地遮罩，还需显式新读取。

#### 读取、发布、分页和打开资格

每次准备读取前后、求值前后、发布前、读取 presentation、加载更多、继续预算读取、浏览及消费打开意图，都核对固定宿主的当前 lease、installation 所属 Gate 的本地 epoch、注入 vault 身份与实际状态戳、ReadOwner.source；任务还核对内部 handle、owner.request 和原 task。准备闭包非逃逸，返回后再查查询相等与准备身份，重入不得让较早的读取覆盖新任务。首批拒绝可读正文/非空正文的 diary 快照，只接受 metadataOnly 的手记数据。

适配器独占 owner；原 `begin/evaluate/publish/invalidateSource`、Pagination/Browse 和安全投影链不被复制。普通新读及 cancel 可保留最后完整结果；隐私失效无条件撤去适配器引用，即使 owner.source 已空也清 displayed、票据和待打开意图。所有清理先关闭资格；清理或过期宿主失败只返回封闭诊断，不记录查询、正文、标签名、文件路径或底层错误，不发起认证补救。

`publish` 先 `await Task.yield()`，之后核验与 owner.publish、displayed 赋值处于同一 MainActor 同步片段，中间没有 await 或调用方回调。`browse` 不将 open 值直接交出去，暂存意图，`consumeOpenIntent` 再核验当前资格与可见性版本后只消费一次；它仍要求新鲜业务校验，不授予真正打开/编辑/恢复能力。旧分页、浏览和打开版本在失效及显式重读后均被拒绝。

#### 模型变化与生产接线责任

注入 model center 的 `.boardDidChange` 保守失效。实际 `BoardEvents.changed/changedLocally → notifyUI` 不携带 ModelContext，故不能解释为某个库的精确代次，也没有监听全部未保存实体变化。`modelDidChange(expecting:)` 是宿主对未保存/保护事实变化的显式失效入口，随后由宿主决定新读；reader 本身不是观察器。

后续产品入口必须独占 owner，使用 Services 适配全部门禁入口；不得直接调用 Domain owner 发布或通过旧副本显示/导航。宿主在转交提交后应解绑两端旧适配、按新 ownership 建立新适配并显式重新读取；旧适配访问时会拒绝过期所有权，来源旧回调只能清来源自身缓存。未来 UI 必须把输入、候选、缓存视图与打开路由接到这一生命周期，并在遮罩/锁定时撤去自己保存的值；本阶段没有提供原生视图刷新接线。

同步 evaluate 仍无法即时处理排队事件；让出一次调度只提供发布前重新核验机会，不保证排空所有外部事件，也不证明长计算可中断或零延迟。拒绝的是已处理的失效事件、当前状态/来源不匹配及迟到任务；大库预算、可合作式取消和真实调度仍待后续。

`presentation()` 与最终消费的打开意图仍返回 Swift 值，调用方可以复制；清 owner/adapter 引用不撤回这些外部副本，不保证 Swift String 零化、清除全部进程内存、SwiftData 注册对象或 UI 撤销缓存。接口没有“全库安全就绪”布尔值；`hasPublicationPermit` 仅表示此适配器当前搜索读取资格。

#### 本轮验证记录与交接

最终源码验证结果如下。测试使用原 DiaryContentQueryFixture/内存 ModelContext、MemoryVaultConfigurationStore、FakeSystemVaultKeys、HandoffFixture 与普通设置草稿；通过真实 vault 方法产生 lock、认证开始和方法变化，未改私有状态、未初始化 `.shared` 生产 vault。当前四套新增测试覆盖 willLock 前置撤权、prepare/evaluate/publish 之间锁定、迟到票据、无 source 清理、解锁不恢复、失焦遮罩、Observation 空窗/多次变化/重装、异实例、旧来源转交、查询/草稿保留、旧分页/浏览/打开、普通取消区别、销毁、模型显式失效及 metadataOnly 实际链路。

| 检查 | 最终实际证据与限制 |
|---|---|
| 隔离 Swift 定向回归 | 56 套、381 个测试定义 / 含动态参数 433 次执行，零失败、零跳过；其中本阶段新增四套共 27 个测试。最终结果 `build/SearchLifecycleQA/Logs/Test/Test-AreaChain-2026.10.02_18-57-44-+0800.xcresult`。Xcode 26.6 / Swift 6.3.3、macOS 26.6.2 arm64；不代表最低 macOS 14 真机通过。 |
| 实际隔离参数 | 沿架构文档的 `env -u` 六个真实钥匙串变量，`xcodebuild -quiet -project AreaChain.xcodeproj -scheme AreaChain -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/SearchLifecycleQA AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements PRODUCT_BUNDLE_IDENTIFIER=com.areachain.search-lifecycle-qa INFOPLIST_KEY_LSUIElement=NO -parallel-testing-enabled NO`，逐个 `-only-testing:AreaChainTests/<suite>` 后 `test`。 |
| 定向范围 | Domain 的 ContentQuery 全套（含解析/会话/页面/类型/转交/聚合/排序/片段/展示/分页/续读/ReadOwner）、CommandHandoff、CommandHostSession、CommandPlan、CommandDraft、DiaryQuery；Services 的新增 ContentQueryReadSession 三套、DiaryContentQuery 四套及 TaskFamilyContentQueryIntegrationTests。只运行纯值/内存合成回归，不选择 PrivacyVaultTests 的真实钥匙串探测或 SystemVaultIntegrationTests。 |
| willLock 实际时序 | `actualWillLockClearsBeforeGenerationChanges` 在真实 lock 的 generation setter 的 Observation will-change 回调中验证：generation 仍旧、state 仍 unlocked，搜索门禁/显示/查询已经撤去；没有用手写 didChange 代替真实 lock。认证开始测试使用公开 unlockWithSystem 加 FakeSystemVaultKeys 的受控挂起，验证 revision 未变、isAuthenticating=true 时旧结果已撤去。 |
| 初次失败与修正 | 两处测试编译问题（异步断言与快照必填 createdAt）已修正。续读新测试最初复用含可读 diary 的旧混合 Batch，被 `metadataOnlyRequired` 正确拒绝；改为明确 routineOccurrences 范围且 diary=notProvided。没有削弱正文门禁或删除失败断言；最终整组重跑通过。 |
| 严格局部 SwiftLint | 本轮 11 个 Swift 文件（四个 Domain、两个 Services、五个测试/夹具）执行 `swiftlint lint --strict --quiet`，通过。全 target 测试编译仍报告其他已有文件的未使用返回值、废弃 API 与 Swift 6 隔离警告，本阶段新文件没有这些编译警告；不认领并行改动或全库 lint 验收。 |
| Debug 构建与验签 | 最终编辑后 `./scripts/build.sh` exit 0，`staticSignatureVerified=true`，产物 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`；沿已有配置，不修改个人签名、不安装、不启动产物。 |
| 工作流与质量门禁 | `python3 -B scripts/check_workflow.py` passed；检查器定向 `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py` 66 项通过；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 186 项完整脚本回归，高风险/敏感日志候选均 0；最终文档回填后复跑工作流、静态门禁、局部 lint 和 `git diff --check`。 |
| 指定复核与未验 | Cursor verifier 未执行 / blocked，不重查登录、不以主代理自查或上述测试冒充指定复核；整体 partial。`quality_gate --profile swift` 固定运行普通全套测试、不能传本轮 QA 标识/定向范围，所以继续采用 static 加显式隔离 Swift 和 Debug 构建。未运行全树 Swift/UI、真实认证/锁屏、真实库、真实窗口适配、安装或发布。 |

本轮文件：Domain 的 [ContentQuerySession](../AreaChain/Domain/ContentQuerySession.swift)、[Reducer](../AreaChain/Domain/ContentQueryReducer.swift)、[HandoffCoordinator](../AreaChain/Domain/CommandHandoffCoordinator.swift)、[HostSession](../AreaChain/Domain/CommandHostSession.swift)；Services 的 [ReadSession](../AreaChain/Services/ContentQueryReadSession.swift)、[Lifecycle](../AreaChain/Services/ContentQueryReadLifecycle.swift)；[锁定测试](../AreaChainTests/Services/ContentQueryReadSessionLockTests.swift)、[Observation 测试](../AreaChainTests/Services/ContentQueryReadSessionObservationTests.swift)、[交互测试](../AreaChainTests/Services/ContentQueryReadSessionInteractionTests.swift)、[清查询/转交测试](../AreaChainTests/Domain/ContentQueryPrivacyResetTests.swift)、[隔离夹具](../AreaChainTests/Services/ContentQueryReadSessionTestSupport.swift)；本文、[架构索引](architecture.md)、[组件目录](component-catalog.md)、[技能路由](../skill-routing.md)、[原检查器](../scripts/check_workflow.py)与[原反例测试](../scripts/tests/test_check_workflow.py)。原 PrivacyVault/钥匙/加密/持久化文件未改；保留这些文档/脚本原有增量和其他并行修改。

停止在 2K-4C。后续需补指定 Cursor verifier 与历史指定验收；另行实施并确认敏感操作草稿封存及失败保护、普通/授权私密正文读取、真实窗口/输入缓冲与显示刷新、保存及未保存模型变化接线、转交适配生命周期和最终打开前业务校验。完整真实统计继续按 D2 留待后续；不把本阶段的 metadataOnly 或本地门禁扩大成生产可用声明。不提交、不推送、不安装、不启动生产应用，不进入下一阶段。


### 9.40 阶段 2K-4D：受搜索生命周期门禁约束的手记正文读取

本阶段用户明确授权：读取普通正文，以及仅在注入 vault 已有有效解锁状态下经既有 API 读取受保护正文用于搜索。授权限实现及合成内存库隔离验证；不主动认证、不访问生产库或生产窗口，不改变加密、存储格式、密钥生命周期、隐私转换或写回语义。§9.38 的 metadataOnly 保留为明确回退；§9.39 的生命周期门禁继续有效。指定 Cursor verifier 未执行 / blocked，不重查登录、不替代复核，整体 partial。

#### 实际入口、所有权与同批资料

- `ContentQueryReadSession(vault:bodyReads:coordinator:ownership:notifications:)` 内部创建唯一 ReadOwner，不接受或导出 owner 别名。`prepareBodies(observation:options:presentation:)` 使用协调者当前查询；读取前检查宿主、Observation 就绪、遮罩、vault 忙碌状态及本地失效代次。只有该校验路径可构造 `ContentQueryBodyReadPermit`，构造器 fileprivate，调用方无法获取票据或原始正文 Batch。
- 原 `prepare(read:)` 仍硬性拒绝可读或非空手记正文，不能传旧 Batch、requestID、布尔标志来升级；原接受外部 owner 的初始化只能使用 metadataOnly。正文模式的新读取先撤旧来源；其 cancel 同样撤来源，不继承旧 metadataOnly 模式保留上次完整展示的取消语义。
- `ContentQueryBodyReads` 显式注入已打开 context、完整手记/标签枚举及只读阶段观察依赖。阶段观察仅能接收 willRead/didRead，不返回字符串或获取正文；真实读取实现不可由调用方替换。它们属于可信装配边界，必须来自同一 context；故障注入不是安全权限声明。同次调用复用 TaskFamilyContentQueryReader 装配任务、子任务、习惯和标签，手记及全目录各读取一次，metadata 仍由家庭读取器唯一赋值。捕获本批实体仅用于内部正文投影，不返回正文结果给普通调用者。
- `DiaryContentQueryReader.readBodies` 只接受不可外部构造的 permit。先核对实体 context、同批元数据相等、完整标签目录及关联 ID，再按含墓碑的全枚举分组身份。重复身份不会先解密再择一；删除行不读正文。缺失/歧义目录、坏关联或无法建立事实的行保持不可读投影。
- `DiaryContent.read(_:vault:protectionTags:permit:)` 是最小共享校验重载，必须持有同一内部许可，外部不能传空目录绕过旧安全检查。旧入口仍只在未保护且有 modelContext 时 fetch 全标签，然后调用同一检查；保护行仍检查当前解锁、密文及 vault ID，并由原 keys.open 核验归属和加密上下文。新搜索显式传入同一 vault 和同批完整目录，避免逐普通手记再次 fetch 标签；不删除旧检查、不调用先复制 entry.text 的 snapshot。

#### 可用正文与可公开正文

可靠普通正文在 vault 未配置或锁定时仍可读取；不能仅依据 isPrivate=false，必须通过完整资料、既有 read 及读取后的 DiaryPrivacy 检查。正文中旧密码标记、关联密码标签、私密标签名语法等旧敏感明文保持未知/隐藏，不以“API 返回字符串”认定可公开或可搜索。缺资料、损坏密文、错误归属、读取失败均没有 entry.text 回退，不修复、不迁移、不 save/rollback、不发布业务事件。

实际读取成功且许可仍有效时才设置 isContentAvailable=true。受保护正文可临时进入内部冻结输入用于匹配，但 isPrivate 保留为真；DiaryQueryPrivacy / DiaryQueryPresentation 隐藏分支剥离正文、范围、长度及依赖正文的文字证据。排序和 Presenter 只消费安全 Match，私密正文不进入排名字段、摘要、展开引用、高亮或诊断描述；正文“可读”不等于“可公开”。未知继续沿三态组合，排除条件不能把未知取反为成立。

#### 失效和残余风险

正文依赖调用前后、冻结前、同步求值前后、让出调度后的发布、展示/分页/打开消费都核验生命周期。准备身份不随异步回调更新，重入的新准备不能为旧输入重新盖戳。已读取行的元数据、密文/vaultID 和标签保护资料另保留内部比较闭包；变化使许可失效，清理闭包与冻结来源引用。willLock 仍在旧 unlocked 状态变化前撤权并清查询；失焦保留查询但撤资格；再解锁、再聚焦及转交不能恢复旧正文。

比较闭包持有本批模型引用及密文、标签名字的值副本，清理不保证 SwiftData 注册对象、外部引用、String/Data 写时复制内存或所有进程副本被擦除。调用方获得的安全展示值也无法强制收回；生产宿主必须遵守门禁显示协议。完整枚举的新插入/删除、未保存正文变化和未捕获目录行变化仍要求真实宿主明确发送 modelDidChange 或已有业务通知；本阶段没有生产观察器接线，不声称对任意外部模型修改自动完备。

为保守验证同批资料，每次正文前后会比较已捕获行及目录；因此当前最坏成本为 O(D × (D + T))，无后台调度或大库性能基线，不适合据此宣称生产规模已达标。同步计算仍不能即时处理主线程排队事件，发布前 yield 不保证排空全部事件。未提升图片/回收站隐私覆盖，不读取私密图片，不生成真实标签统计，tagUsage 继续未提供。

#### 验证状态（本轮最终）

新增 ContentQueryBodyReadTests、ContentQueryBodyLifecycleTests、ContentQueryBodyBoundaryTests 与合成夹具，覆盖普通/保护正文、旧格式和失败、重复身份、同批目录、生命周期重入、迟到任务、失焦、转交、metadataOnly、旧 API 等价及不写回。源码边界检查与实际运行结果分别记录：

- 最终源码的严格局部 `swiftlint lint --strict --quiet`、Swift 语法解析与 `git diff --check` 通过；工作流检查通过，检查器定向 68 项通过。`python3 -B scripts/quality_gate.py --profile static --format json` 通过，含 188 项完整脚本回归，静态扫描高风险及敏感日志候选均 0；文档最终回填后重跑原门禁。
- 首次隔离 xcodebuild 使用独立 `com.areachain.search-body-qa`、`build/SearchBodyQA`、ad-hoc 签名、串行测试，并清除六个真实钥匙串授权变量。因磁盘耗尽在 OpenGL 模块编译时失败，未进入测试运行；失败目录仅本轮新建部分已清理。
- 磁盘空间随后由外部恢复，本轮未删除历史构建。最新接口收紧后的 **67 套隔离回归、449 个测试定义 / 含参数化 536 次执行通过，零失败、零跳过**。本阶段三套新增测试共 23 个定义 / 25 次执行。最终产物：`build/SearchBodyQA/Logs/Test/Test-AreaChain-2026.10.02_19-27-13-+0800.xcresult`；Xcode 26.6、Swift 6.3.3、macOS 26.6.2 arm64，不代表最低 macOS 14 真机通过。
- 定向选择 Domain/Services 下以 ContentQuery、DiaryQuery、CommandHandoff、CommandHostSession、TaskContentQuery、RoutineContentQuery、TagContentQuery、DiaryContentQuery、TaskFamilyContentQuery、ImageAssociationPrivacy、RecordImageQueryPrivacy 开头的 `*Tests.swift` 对应套件；参数沿 §9.39 命令，仅改隔离目录为 `build/SearchBodyQA`、QA 标识为 `com.areachain.search-body-qa`。没有选真实钥匙串套件、生产 UI 或真实认证。
- 首次实际运行 23 个测试定义中三项失败：锁定后的两项夹具没有显式 enterPage，被 pageContextRequired 正确拒绝；私密输出测试误要求合法 scope 元数据依据也为空。修正为显式新页面操作，并严格断言剩余依据只能是无范围 scope；正文/摘要/展开/排名断言保留。之后两轮完整回归通过；最后一轮覆盖同批重载必须持有许可、阶段观察不能替换正文的最终接口。
- `./scripts/build.sh` exit 0，Debug `staticSignatureVerified=true`；产物 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`。只构建/验签，未安装、启动或变更签名配置。全 target 编译仍有其他既有测试的废弃 API / Swift 隔离警告，本轮文件未报告新增编译警告。
- 源码边界独立核对：新搜索适配无 `.shared`、模型 `.snapshot` 捷径、原始 entry.text/row.text 读取、认证、保存/回滚或模型正文赋值；实际正文只进入旧 read 共用检查。运行证据由上述隔离断言提供，静态扫描不充当运行或指定复核。
- 指定 Cursor verifier 仍未执行 / blocked，整体 partial，历史缺口保留。不重查登录或改认证配置，不用主代理检查/单测冒充指定复核。`quality_gate --profile swift` 不能传本轮隔离标识和定向范围，继续使用 static 加显式隔离 Swift 及 Debug 构建；未运行全树 UI、真实窗口、真实库、安装或发布。

本轮只修改 Services 正文适配/共享 read 校验、对应测试与原文档索引/入口检查，不修改认证、密钥、转换或生产 UI。代码回退无需重写用户数据；应先撤许可、冻结来源和展示，再切回 metadataOnly，不能恢复旧敏感结果。

完整正文目标已实现并隔离验证受控读取与安全投影；仍缺指定复核及生产窗口/输入缓冲/模型事件适配和实际运行验收。敏感草稿封存与失败保护、图片读取、真实标签统计、性能敏感后台调度和生产打开前业务校验均未实施。本阶段结束后停止，不提交、推送、安装、启动生产应用或进入下一阶段。


本轮入口与文件：服务层 [ReadSession](../AreaChain/Services/ContentQueryReadSession.swift)、[BodyReads](../AreaChain/Services/ContentQueryBodyReads.swift)、[DiaryReader](../AreaChain/Services/DiaryContentQueryReader.swift)、[正文投影](../AreaChain/Services/DiaryContentQueryBodies.swift)、[旧 read 共享校验](../AreaChain/Services/Privacy/DiaryContent.swift)；测试 [正文读取](../AreaChainTests/Services/ContentQueryBodyReadTests.swift)、[生命周期](../AreaChainTests/Services/ContentQueryBodyLifecycleTests.swift)、[边界/旧 API](../AreaChainTests/Services/ContentQueryBodyBoundaryTests.swift)、[正文夹具](../AreaChainTests/Services/ContentQueryBodyTestSupport.swift)、[原生命周期夹具扩展](../AreaChainTests/Services/ContentQueryReadSessionTestSupport.swift)；以及本文、[架构索引](architecture.md)、[组件目录](component-catalog.md)、[技能路由](../skill-routing.md)、[原检查器](../scripts/check_workflow.py)与[反例测试](../scripts/tests/test_check_workflow.py)。这些文件中的前序/并行修改均保留，本轮不认领它们的全部差异。

### 9.41 阶段 2K-5：剪贴板历史文件只读适配与受门禁发布

2026-10-02。本轮仅实现显式存储读取与合成临时文件集成，不读取生产历史，不访问系统剪贴板，不初始化 ClipboardHistorySession / Monitor、不监听、不复制粘贴、不修改历史记录。保留开工时前序搜索、界面、文档与检查器并行修改；指定 Cursor verifier 仍未执行 / blocked，不重复登录检查、不修改认证、不以其他复核替代，整体 partial，历史阶段不因此验收。

#### 接口、格式与失败映射

| 接口 | 当前责任 |
|---|---|
| [ClipboardHistoryStore.readHistory(readData:)](../AreaChain/Services/ClipboardHistoryStore.swift) | 读取既有 history.json 一次到 Data，使用同一私有 ClipboardHistoryFile / ClipboardHistoryRecord 解码；窄 Data 依赖用于权限/重入故障测试。 |
| 同文件 ClipboardHistoryReadResult / Failure | missing、decoded(records)、failed(fileReadFailed / decodingFailed)；decoded 空/非空由值明确区分。只接受系统 Cocoa fileReadNoSuchFile 或 POSIX ENOENT 为缺失，不依据 fileExists=false、不追溯不明外层错误的 underlyingError 推断缺失。 |
| [ClipboardContentQueryReader.read(session:requestID:options:)](../AreaChain/Services/ClipboardContentQueryReader.swift) | 必须注入已构造存储，不自行选择 Application Support。输出 Batch 与不含负载的 notRequested / missing / decodedEmpty / decodedRecords / failed 状态；仅显式 clipboard 且结构有效、可读类型和独立模式筛选合法时执行 IO。 |
| [ContentQueryReadSession.prepareClipboard](../AreaChain/Services/ContentQueryReadSession.swift) | 使用协调者当前 Session 与显式 reader/requestID/options/presentation，返回原任务句柄和此次安全读取状态；新的无 owner 注入初始化入口内部创建唯一 ReadOwner，宿主仅走 evaluate / publish / presentation / loadMore。 |

当前格式只有 items，没有格式版本字段，不新增版本机制或磁盘字段。坏 JSON、错误结构、缺必填值及类型解码失败都映射 decodingFailed；权限、目录或其他读取错误为 fileReadFailed。整个文件有任一解码失败即失败，不提取前半段或猜 JSON。错误不保存 NSError、底层描述、正文、正则、文件路径或原始 JSON；结果 description/debugDescription 脱敏。

旧 load() 委托新入口，成功返回原数组，missing 或任何失败继续返回 []，保持原消费者兼容。新搜索不调用 load：missing（尚无保存历史）及 decoded([]) 均映射 complete([])，正常解码映射 complete(records)，失败映射 failed，无需读取时保持 notProvided。存储层不去重、不排序、不截断、不 first-wins、不修复坏字段；完整解码不等于合法记录或完整匹配，重复 ID、坏日期、图片引用继续由原 ClipboardQueryProvider 诊断。

#### 快照、负载与成本

一次读取仅得到该次文件值快照。不承诺与运行中的 ClipboardHistorySession.items 一致，不涵盖未保存内存历史，也不承诺与其他 SwiftData 来源形成跨存储事务。生产宿主选择运行内还是磁盘历史尚未实现。

实际为**全文件读取与全格式解码，无文件大小上限**；旧采集条数/maximumPayloadBytes 和提供者枚举预算都不是磁盘读取预算。合成超 999 条及超过旧单负载阈值的文件验证不静默截断；不因此给出大库耗时/内存预算或生产性能承诺。Data 与解码记录可同时占用内存，富文本解码成本随文件增大；未新增技术上限或历史保留规则。同步正则仍无即时取消/超时保证，没有改引擎或截断正文。

原格式会解码 plainText、HTML、RTF Data、图片存储名、文件路径及 hash，不宣称只读取纯文本字段。读取链不打开/读取/验证引用指向的文件，不读图片二进制，不将 HTML/RTF 转正文；只调用原 Provider 搜索 plainText 并产生安全 Match，公开展示链不附原始记录、富文本、存储名、路径或 hash（用户 plainText 本身若含路径仍是原公开文本语义）。文件读取没有建目录、空文件修复、save、writeImage、pruneImages、损坏重写或临时文件清理路径；测试夹具独立创建和清理自己拥有的临时数据。

#### 受门禁发布、冻结与重读

链路为临时真实 history.json → readHistory → ClipboardQueryRecords → Batch → ReadSession → 内部 ReadOwner → 原排序/摘要/展示/分页。prepareClipboard 委托原 prepare，读取前核验宿主/lease、Observation、遮罩与 vault 状态，读取后核验上下文与准备身份；同步 evaluate 前后、yield 后 publish、展示与分页继续走原门禁。没有新隐私生命周期或随机 requestID 授权证明；同 requestID 明确重读仍产生新来源。

修改文件不会追改已冻结 Batch；分页不会重新读文件，显式 prepareClipboard 才取得新文件。读取重入后旧准备被拒绝，旧任务不能覆盖新来源。锁定撤旧来源、票据、显示及搜索查询；失焦保留查询但撤展示资格，恢复显示后须显式重读。普通取消沿原非正文入口语义保留最后已发布结果，不能发布已取消票据。文件失败仍形成本次 failed 来源，发布后是空失败展示与不完整诊断，不把旧成功记录拼入；发布前或普通取消后可暂留的旧结果仍带原 task/source，不伪装为新读取成功。

没有监听文件变化、后台调度或生产窗口接线；外部已复制安全展示值仍由宿主负责撤去，清引用不保证内存零化。沿原规则，锁定本身不永久禁止后来新的显式公开剪贴板查询，但必须先完成可信页面恢复与新读取，不复活旧查询。

#### 本轮验证与停止交接

测试入口为 [ClipboardHistoryReadTests](../AreaChainTests/Services/ClipboardHistoryReadTests.swift)、[ClipboardContentQueryReaderTests](../AreaChainTests/Services/ClipboardContentQueryReaderTests.swift)、[ClipboardContentQueryLifecycleTests](../AreaChainTests/Services/ClipboardContentQueryLifecycleTests.swift) 及[临时文件/fake vault 夹具](../AreaChainTests/Services/ClipboardContentQueryTestSupport.swift)。新增 18 个测试定义、22 次含参数化执行。缺失/空/正常文件、坏 JSON/结构/字段、注入权限与目录错误、旧 load、按需读取、模式与独立筛选、重复/异常行、富文本负载、不写回清理、冻结/重读/分页、锁定/失焦/重入/迟到及安全展示均有实际断言。

| 验证 | 实际结果与边界 |
|---|---|
| 首轮定向 | 71 个测试定义、91 次执行通过，零失败/跳过；随后补强门禁模式及公开展示负载断言。 |
| 最终隔离回归 | **422 个测试定义、496 次含参数化执行 passed，0 failed / 0 skipped**。选择 61 套 Domain/Services 回归，加原 ClipboardHistoryStoreTests 的旧格式单个方法；结果树核实 62 个套件全部 Passed。包含 ClipboardQuery/原纯规则、ContentQuery 查询/Batch/ReadOwner/排序/摘要/分页、ReadSession/正文生命周期、CommandHandoff/HostSession、DiaryQuery/DiaryContentQuery。 |
| 隔离参数与产物 | 沿 §9.39 的六个 env -u、串行、ad-hoc 参数，独立标识 com.areachain.clipboard-storage-qa，目录 build/ClipboardStorageQA。结果包 build/ClipboardStorageQA/Logs/Test/Test-AreaChain-2026.10.02_19-50-10-+0800.xcresult；精确命令、摘要、结果树及前后 Swift 指纹见该目录 regression-command.json、regression-summary.json、regression-tests.json、source-before.json / source-after.json，指纹完全一致。Xcode 26.6、Swift 6.3.3、macOS 26.6.2 arm64；不代表最低 macOS 14 实机验收。 |
| 失败定位与修正 | 首次扩展回归中新增夹具误用未支持的 is:pinned，被 ModeRequest 正确拒绝；改用既有 has:image 独立筛选，保持原断言目标，不改语法或产品规则。另消除可选句柄断言的类型推断警告，确保不能退回另一次 prepare。最终整组回归通过。 |
| Debug 构建 | 最终 Swift 编辑后 ./scripts/build.sh exit 0，staticSignatureVerified=true、distributionReady=false；产物 build/development-DerivedData/Build/Products/Debug/AreaChain.app。只构建/验签，未安装/启动或修改个人签名。保留既有多目标匹配警告；测试 target 编译仍有其他文件的隔离/旧可访问性 API 警告，本轮文件无新增编译警告。 |
| 静态与脚本 | 本轮 7 个 Swift 文件的 swiftlint lint --strict --quiet 和 git diff --check 通过；python3 -B scripts/check_workflow.py 通过；检查器定向 **69 项**通过；python3 -B scripts/quality_gate.py --profile static --format json 通过，包含 **189 项**脚本回归，高风险/敏感日志候选均 0。最终文档回填后重跑工作流、静态门禁和局部检查。 |
| 未运行与指定复核 | 原存储套件的复制/粘贴和 ClipboardHistorySession 初始化用例未运行，避免越过本次禁止边界；只选旧格式读取方法并以新临时文件测试覆盖存储失败和兼容。quality_gate 的默认 auto / swift 会扩大到非本轮授权测试，因此沿前阶段采用 static 加显式隔离定向与构建，不冒充完整 Swift profile。Cursor verifier 无当前可调用入口，未执行 / blocked，阶段整体 **partial**；未重查登录或修改认证，未运行生产历史、系统剪贴板、真实 UI、系统认证、安装或发布。 |

本轮修改清单：Services 的 [ClipboardHistoryStore](../AreaChain/Services/ClipboardHistoryStore.swift)、[ClipboardContentQueryReader](../AreaChain/Services/ClipboardContentQueryReader.swift)、[ContentQueryReadSession](../AreaChain/Services/ContentQueryReadSession.swift)；上述三套测试与夹具；本文、[组件目录](component-catalog.md)、[架构索引](architecture.md)、[技能路由](../skill-routing.md)、原[检查器](../scripts/check_workflow.py)与[反例测试](../scripts/tests/test_check_workflow.py)。对已存在并行增量仅作局部扩展，不认领其全部差异。生产磁盘格式未变，回退代码不需要用户数据迁移；宿主仍须撤旧许可和展示，不复活旧票据。

剩余事项：图片实际存储与关联读取、墓碑来源适配、完整真实标签统计、生产运行内/磁盘来源选择、监听/失效事件和宿主窗口/输入缓存/打开前校验均留后续；敏感操作草稿封存与历史指定验收继续保留。本轮到 2K-5 停止，不提交、不推送、不安装、不发布、不启动生产应用、不进入下一阶段。

### 9.42 阶段 2K-6：图片元数据只读适配、同批图片查询与 has:image

#### 授权、入口与回退

本阶段用户明确授权读取图片元数据、核实拥有者，并在既有搜索门禁内读取候选普通手记正文检查保护标记。只使用隔离数据库和合成资料；不为公开图片列表解密受保护正文。原查询需要手记结果时，仍可沿 §9.40 已有许可读取正文；可读的私密正文仍不能使图片公开。本阶段不改认证、加密、迁移、存储或业务写入规则，不读取生产数据或图片文件，不接生产入口，完成后停止。指定 Cursor verifier 的历史 blocked / 未执行状态保留，不能以本地检查冒充指定复核，整体 partial。

| 接口 | 实际责任和消费者 |
|---|---|
| [ImageContentQueryReads / ImageContentQueryPlan](../AreaChain/Services/ImageContentQueryReads.swift) | 显式 context 与窄模型枚举依赖。只有有效 live 查询需要 image 或记录 has:image 时读取 AttachmentItem；只可由不可外部构造的 BodyReadPermit 调用。 |
| [ImageContentQueryCapture](../AreaChain/Services/ImageContentQueryCapture.swift) | 包装原 TaskFamilyContentQueryReader 的任务、习惯、手记和标签依赖；记录同批实体证据并在许可检查时重新枚举。没有独立附件索引或 canBrowse。 |
| [ContentQueryReadSession.prepareImages](../AreaChain/Services/ContentQueryReadSession.swift) | 图片模式内部创建唯一 ReadOwner；受控准备、求值、发布、分页和展示共用原生命周期。外部 prepare 不接受正文或 imagePrivacy 证据。 |
| [DiaryContentQueryBodies / DiaryImageProtectionFacts](../AreaChain/Services/DiaryContentQueryBodies.swift) | 复用原正文读取及 DiaryPrivacy；仅生成对象级图片保护结论。构造/写入证据限制在该文件的受控检查中，没有任意 isPublic=true 注入入口。 |
| [ContentQueryBatchAssembly](../AreaChain/Domain/ContentQueryBatchAssembly.swift) | imageQuery 与记录 ContentQueryImageRead 都消费 Batch 唯一图片源、主拥有者快照及 metadata；ImageOwnerResolver 最小增加独立保护证据分支。 |

回退关闭图片读取适配并撤销 ReadSession 来源、关联事实和已发布结果，恢复 notProvided / unknown / protected。无格式迁移，无用户数据修改。图片公开投影只证明元数据可用，不证明文件存在、解码或打开成功；本阶段没有图片打开、预览、URL、另存为或删除能力，亦不消费 ClipboardHistoryRecord.imageFile。

#### 实际 fetch、投影与完整性

- 附件使用无谓词、无 fetchLimit 的 `FetchDescriptor<AttachmentItem>()`，包括活行与墓碑。只投影 id、ownerKind、ownerID、filename、createdAt、deletedAt，以及 privacyVaultID 是否存在形成的 protection。没有读取或返回 storageID / retiredStorageID 定位信息、路径、URL、图片二进制或凭据；SwiftData 可能物化整个模型，不能声称数据库列级裁剪。
- `/images` 读取三种拥有者的完整表，包含零图对象和墓碑，避免保护对象零/一/多图改变公开关联状态。todo 复用 TaskRepository 的 includeDeleted 全枚举；routine 复用 includeDisabled / includeDeleted 定义枚举；diary 复用 SwiftDataDiaryRepository.fetchAllDiaries。记录单独 has:image 只要求其实际类型；主记录与辅助拥有者使用同一次家庭装配，辅助输入不改变 Session，不额外选择记录提供者。
- 同批全标签目录复用 TagContentQueryReader；只有关联名字需求时沿原按 ID 读取。metadata 在家庭读取器中统一赋值。标签墓碑和私密标志参与保护检查；不建立全来源统计，tagUsage 继续未提供。
- `snapshots.images.coverage` 表达图片枚举；`imageIdentities` 表达跨类型全图片 ID 核验范围；`owners` 表达各拥有者类型枚举；`associations` 表达关联枚举；`diaryPrivacy.objects` 仅表达实际完成保护检查的对象。完整枚举不等于数据唯一，重复活/活、活/删仍交原领域规则隔离。
- complete 注入必须与同 context 物理行集合相符；不能先 live-only 截断再声明唯一。partial、notProvided、failed 与 complete([]) 独立保留，失败不变成空或 absent。每次新建 Batch 和覆盖，不继承上一批 complete。
- 图片身份与拥有者身份分开核验，拥有者使用 kind + UUID；跨类型同 UUID 合法，未知类型不重挂，重复先隔离。四态继续由 ImageAssociationReader / ContentQueryImageRead / Evaluation 决定，unknown 和 protected 不作为普通 false，排除条件不能把它们变成 true。

#### 最小保护证据与正文边界

已知受保护手记直接登记 protected；没有手记结果需求时根本不进入其正文 API，即使 vault 已解锁或密文损坏也不尝试解密。候选普通手记先核对全枚举身份唯一、活状态、关联标签结构及目录覆盖，再以同一注入 vault、同一不可外部构造许可调用 ContentQueryBodyReads.readContent → DiaryContent.read 的同批目录重载，随后复用 DiaryPrivacy.isSensitive / requiresProtection 检查旧密码标记、关联密码标签和私密标签名称语法。无 .shared、无 entry.text 失败回退、无自动认证或修复。

图片需要的是保护结论。临时检查普通正文时只在局部使用字符串，不放进图片结果或排序上下文；没有手记结果需求时 Batch.diaries 保持 text="" / isContentAvailable=false。确有手记查询需求时同一次检查同时填入合法正文事实，保留 isPrivate，不进行第二次为图片而解密。不会用空正文 + isContentAvailable=true 伪造公开证据。

DiaryImageProtectionFacts 只保留元数据快照和保护枚举，与同批 metadata 及当前拥有者快照绑定。已知保护对象可以在目录不足时保持 protected；普通对象缺失资料、读取失败或旧敏感明文保持 unknown/protected。只有实际检查成功或已知保护的对象获得 diaryPrivacy.objects 完整声明；没有 diary 类型级完整保护声明。原 ImageOwnerResolver 的纯值旧调用仍兼容，但真实适配显式传入本批受控证据，不能借正文可读性提升图片公开资格。

公开诊断继续不带隐藏图片 ID、文件名、行位置或数量；保护零/一/多图和重复图保持同一公开语义。候选原始元数据只留在私有冻结源，排序、摘要、分页消费原提供者安全投影。

#### 生命周期、成本与残余限制

附件读取前后、拥有者/标签读取前后、普通正文检查前后、冻结前、求值前后、发布与展示/分页/浏览消费前均走原许可。ContentQueryBodyReadPermit 的事实校验由单个闭包改为累积校验，避免后装配的正文事实覆盖图片事实。元数据校验保留内部物理行标识和最小投影，重新 fetch 同一 context 比较完整行集合及字段；插入、删除、墓碑变化或重入修改使旧许可失败，旧任务不重新盖代次。实际正文读取使用 Observation 跟踪其访问字段，读后明文或保护属性改变同样撤销资格，不为监视另取明文副本。

willLock、失焦、保护变化和宿主转交沿原门禁撤权；新准备/取消会释放旧来源与展示，重新解锁/聚焦不能恢复旧文件名、关联结果或票据。requestID 仍只用于请求关联，不代表新鲜度或授权。适配器不接真实窗口监听，不承诺跨 context / 进程的数据库事务原子性；其他 context 变更的合并和宿主通知仍是后续接线责任。撤引用不保证 SwiftData、String/Data 或外部持有副本内存零化。

成本明确采用全表读取和保守重复枚举校验：一次装配的附件依赖调用一次，主拥有者及目录各投影一次，但生命周期每次校验会重新 fetch 已登记类型的全表；每个正文检查也触发校验。最坏成本随 D 次正文读取及 A/T/R/D/G 全表大小增长，约 O(D × (A + T + R + D + G))，另有展示操作复查成本。领域查询预算、排序及分页不会限制数据库 fetch；尚无大库性能基线，不声称适合生产规模。

墓碑本轮只服务唯一性、存活与否定核验；统一回收站的 SwiftData 读取、真实全来源统计、生产宿主接线和性能优化仍未实施。验证结果另列下方，历史指定复核与原生验收缺口不因本阶段关闭。

#### 本轮验证证据（2026-10-02）

- 新增 ImageContentQueryIntegrationTests / PrivacyTests / FailureTests / LifecycleTests 共 **22 项**，参数化 **30 次**。覆盖三类真实拥有者、跨类型同 UUID、墓碑与重复碰撞、缺失/部分/失败/完整空集、辅助输入不出正文结果、无需求不读附件、私密图片不解密、旧标记/私密标签/缺资料、正文前后撤权、同查询私密正文可匹配但图片隐藏、保护零/一/多图等价、同批 has:image、文件定位字段不投影及不保存/回滚、元数据/标签/正文/新增重复行变化、失焦/锁定/转交/重入与迟到发布。两条链路均从内存 SwiftData 实体经过原提供者、排序、摘要、分页和 ReadSession 发布，不是手工组装响应。
- 最终采用架构文档的隔离 xcodebuild 入口，`PRODUCT_BUNDLE_IDENTIFIER=com.areachain.image-metadata-qa`、`-derivedDataPath build/ImageMetadataQA`、local 临时签名、串行执行并清除六个真实钥匙串授权变量。**60 套、388 passed / 0 failed / 0 skipped；参数化 462 passed**。包括全部 2E 图片关联/图片提供者/记录 has:image、2K-4D 正文、生命周期、任务家庭/标签/手记/习惯适配、Batch、排序/摘要/展示/分页和剪贴板生命周期回归。每套实际结果均为 Passed。
- 完整命令及结果保存在忽略目录 `build/ImageContentQueryQA/regression-command.json`、`regression.log`、`regression-summary.json`、`regression-tests.json`；结果包 `build/ImageMetadataQA/Logs/Test/Test-AreaChain-2026.10.02_20-35-11-+0800.xcresult`。`source-before.json` 记录的相关 Domain/Services/测试摘要在测试后逐项一致；没有依赖旧源码的测试结果。环境 macOS 26.6.2 arm64；测试时间不作为产品性能基线。
- `./scripts/build.sh` **passed**，`build/ImageContentQueryQA/build.log` 中 `staticSignatureVerified=true`、`distributionReady=false`。只构建与验签 Debug，没有安装、启动生产应用或发行。
- 工作流检查、严格局部 SwiftLint、差异空白检查通过；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` **70 passed**。扩展原组件目录守卫并加入两个适配入口缺失的反例，没有新建检查执行器。静态质量门禁 `python3 -B scripts/quality_gate.py --profile static --format json` **passed**，含脚本回归 **190 passed**、高风险和敏感日志候选均 0。最终文档编辑后再次运行工作流和静态质量门禁。
- 初次普通测试曾被并行 MonthGridDropTestSupport 编译错误阻断；早期隔离命令临时排除该夹具及对应月历测试，仅用于本阶段诊断，没有改动其源码。并行修正后，以上最终 60 套回归**无任何源码排除**。初轮新测试还暴露旧准备在重入新查询后误清新任务的问题，已将 preparation 身份检查提前，并通过本轮与原生命周期回归。测试中曾误假定 `/tasks` 不含习惯以及 `-has:image` 可解析；已按原契约修正断言，没有修改产品语法。
- 未运行整树 auto/swift profile：其无过滤应用测试包含本阶段之外的原生界面及文件测试；本次使用静态门禁加明确筛选的 60 套隔离回归。编译保留既有测试 actor / Sendable、旧可访问性 API 等警告，没有顺带改写。未运行真实窗口监听、图片文件访问、生产数据库、系统钥匙串、安装、发行或大库性能验收。
- 指定 Cursor verifier **blocked / 未执行，阶段整体 partial**；没有重查登录、改认证或以其他复核冒充。本阶段实现及上述本地验证已交接，保留历史指定复核、原生/生产验收缺口；停止在 2K-6。

### 9.43 阶段 2K-7：完整墓碑只读适配与受门禁回收站搜索

#### 授权、入口与唯一装配

用户已明确授权完整枚举墓碑，并在现有门禁内读取候选普通已删除手记正文、核对保护标记，确认公开后供搜索。受保护墓碑不解密；不执行恢复、删除、清空、迁移、图片文件操作或真实认证。实现仅接显式注入的隔离上下文，未接生产 Persistence 或窗口。指定 Cursor verifier 的历史缺口仍保留，整体 **partial**，不重复登录检查或用主代理自查冒充指定复核。

| 核心接口 | 责任与实际消费者 |
|---|---|
| [TrashContentQueryReads / Plan / Details](../AreaChain/Services/TrashContentQueryReads.swift) | 复用 TaskContentQueryReads、RoutineContentQueryReads、DiaryContentQueryReads、TagContentQueryReads 与 ImageContentQueryReads 的全枚举依赖。只在有效显式 trash / deletedOnly 查询启用；普通范围返回未提供，不读额外墓碑。 |
| [TrashContentQueryReader](../AreaChain/Services/TrashContentQueryReader.swift) | 在同一 Session、requestID、options、Batch 中装配主模型、父属性、标签与保护资料；无独立旧 Batch 拼接。习惯只调用原 readFacts 的当前观察和有界记录证据。 |
| [TrashContentQueryCapture](../AreaChain/Services/TrashContentQueryCapture.swift) | 复用 ImageContentQueryCapture.retain 的物理行集合及字段校验，在枚举依赖调用之前建立基线，之后与生命周期核验时重新枚举，拒绝重入变化、漏行的 complete 和跨上下文实体。 |
| [DiaryContentQueryReader.readTrashBodies](../AreaChain/Services/DiaryContentQueryBodies.swift) | 独立于旧 live-only 路径，复用 ContentQueryBodyReads.readContent → DiaryContent.read、DiaryPrivacy 与对象级 DiaryImageProtectionFacts。没有 snapshot 捷径或失败时 entry.text 回退。 |
| [ContentQueryReadSession.prepareTrash](../AreaChain/Services/ContentQueryReadSession.swift) | 当前宿主内部签发许可，内部创建并独占 ReadOwner，返回不可拼装句柄和脱敏读取状态；外部 prepare 仍拒绝任何可读手记快照与 imagePrivacy 事实，包括墓碑。 |
| [TrashTombstoneInput / Index / Projection](../AreaChain/Domain/TrashTombstoneInput.swift) | 无父子任务以 unconvertedSubtaskIDs 继续参与类型化身份核验；图片公开使用本批对象级保护事实。级联、分组、恢复条件和查询仍由 2H 单一规则负责。 |

唯一运行链路为：隔离模型 → 受控 Batch → TrashTombstoneReader → TrashQueryProvider / Fields / Temporal → BatchReader → Sorter → Presenter → DisplayBuilder → Pagination → ReadSession 发布。当前实际消费者只有 TrashContentQuery 的隔离服务测试，无 handler 或操作执行资格输出。没有清空 deletedAt 伪装活内容，也没有把 TaskFamily 的活准备路径当墓碑读取器。

#### 实际读取与覆盖

- 根据既有 trashInputTypes 计划读取实际所需类型；非标签墓碑组需要图片及三类拥有者参与安全核验，todo/subtask/image 请求独立枚举 SubtaskItem。标签型请求只读全标签目录。所需类型使用无删除筛选、无条数上限的完整表读取，包含活行、墓碑与重复业务 ID；相关父项即使存活仍参与核验。SwiftData 可物化整行，不声称列级裁剪。
- TodoSnapshot 手工投影自身字段，不访问其活子项视图；子任务唯一权威来源是独立平面表。无法形成快照的无父行保留 ID 与 missingSubtaskParent；与可转换行同 ID 时仍产生 duplicateIdentity。投影 partial 与 Details 中原始枚举 complete 分开，所有父组的成员覆盖保持 partial，不能用可见子项数冒充完整。
- 同类型活/删碰撞不 first-wins；跨类型同 UUID 不冲突，拥有者由类型＋UUID 核对。子任务父物理行不符不重挂；父类型未读、部分、缺失、歧义、非法墓碑时间仍由原 Reader 区分。不近似同一天或时间容差，只复用 SoftDelete 精确同戳判据。
- `Details.sources` 是六类枚举状态；Batch 源与 `trashCoverage.types` 是可投影输入范围；`objects` 支持完整子任务表中已核验身份；`members` 仍沿领域覆盖语义，不提高局部范围；图片身份以完整 AttachmentItem 表核验；`trashTagNamesCoverage` 独立描述关联名字；`diaryPrivacy.objects` 只声明本批实际检查的手记。没有手记保护类型级 complete。
- complete([])、notProvided、partial 与 failed 分开。源失败在 Details 和 Batch limitation 保留 failed；无值的领域输入仍是 notProvided，不能当空结果。错误只输出封闭类别，许可复查的数据库异常也映射 readFailed，无数据库错误正文。图片诊断不带隐藏行下标、身份、文件名或数量。
- 同批全标签目录包含标签墓碑和私密标志。关联名字复用 ContentQueryTagNames，只提供唯一且允许公开的名字；缺失/私密关联名字保持部分覆盖。保留逐对象可用资料，避免一个私密关联清掉其他普通手记的保护资料；重复标签目录不能建立普通正文的完整保护证明。真实标签使用统计仍未提供。

#### 正文与图片保护

先核对宿主、查询、许可、同 context、唯一身份、墓碑状态和同批目录。已知受保护记录直接登记 protected，不调用正文 API，即使 vault 已解锁也不解密。候选普通墓碑沿既有正文 API 读取，再检查旧密码标记、私密标签及名称语法；资料不足、读取失败、非法标签或旧敏感明文保留 unknown / hidden，不转换、擦除或加密。只有确认公开且确需手记结果的墓碑才写入 Batch 的可读正文分支；空串占位保持 isContentAvailable=false。受保护墓碑正文搜索仍未开放，不能称为全部回收站正文能力完成。

图片元数据仍仅含 id、ownerKind、ownerID、filename、createdAt、deletedAt、protection，不读取定位字段、URL 或二进制，不调用 AttachmentStore。普通 live 图片规则不变；墓碑安全投影独立消费当前手记拥有者的对象级保护事实。普通已删拥有者可提供公开图片及级联关系；只为图片检查正文时，辅助 DiarySnapshot 仍无可读正文。隐藏拥有者、旧格式不明、保护或混合身份碰撞继续隐藏整个受影响图片投影。零/一/多张隐藏图片不会进入组计数、逐图诊断、未知列表或命中提升；完整枚举不等于完整披露。

#### 生命周期、只读与回退

模型只在 MainActor 的注入上下文安全域使用。实体/物理身份只留在内部许可校验闭包，冻结 Batch 与输出均为值。依赖调用前后、正文检查前后、冻结前、求值前后、发布和展示/分页/浏览消费前核对资格；身份、墓碑、标签、保护或已读取正文变化拒绝旧证据。willLock 同步撤权并清查询；失焦撤显示资格；转交后旧宿主失效；重新解锁/聚焦不恢复旧票据。同 requestID 也创建新来源代次，重入旧任务不能清掉新准备。普通 cancel 释放来源/展示但保留查询，与隐私失效不同。

读取不 save/rollback、不发 BoardEvents、不补标签或修模型，不持有恢复/删除/文件接口。回退只关闭 prepareTrash 并 detach / 撤去冻结结果，恢复未提供与未知，不改存储数据。冻结的已返回值不随后续实体变化更新；撤引用仍不保证 String/Data、SwiftData 或外部副本内存零化。

采用全表读取和保守的重复全表复查，正文逐条检查还会触发累计事实校验；领域预算与展示分页不限制 fetch。没有大库性能基线，也不承诺跨 context / 进程事务原子性。生产接线前仍需数据变化合并/宿主通知、性能预算和指定复核证据。习惯删除前历史不重建；date/on/status 缺证据仍未知，has:image 墓碑语义仍为 imageAssociationUnavailable，不能用活关联替代。

恢复执行、永久删除/清空、真实标签统计、受保护墓碑正文、生产接线及历史原生/认证验收仍未完成。本轮停在 2K-7，不进入下一阶段，不提交、推送、安装或启动生产应用。

#### 本轮验证状态

验证使用原全 schema 内存 ModelContainer、禁用自动保存与 FakeSystemVaultKeys；所有手记、密钥和图片元数据均为合成资料。

- 新增四套 TrashContentQuery 服务测试共 **30 项定义、49 次参数化执行**。涵盖六类枚举与活父项、平面子任务/孤立行/活删碰撞、跨类型 UUID、精确同戳/提前独立删除、六源失败及四种覆盖、普通墓碑正文、受保护墓碑零正文 API 调用、旧敏感/私密标签/重复目录/资料不足、占位排除条件、删除拥有者图片、隐藏图片零/一/多/跨拥有者碰撞、读取中墓碑/标签/保护变更、初始依赖回调变更、同 requestID 旧句柄、重入/取消/锁定/失焦/转交、冻结副本、父子计数与提升、排序片段/分页/键盘选择及上下文不可选。只读测试保留未保存改动并用第二个隔离 ModelContext 核对未落盘，附件定位字段不进入结果。
- 最终使用架构文档的隔离 xcodebuild 入口，`PRODUCT_BUNDLE_IDENTIFIER=com.areachain.trash-metadata-qa`、`-derivedDataPath build/TrashMetadataQA`、local 临时签名、串行执行并移除六个真实钥匙串授权变量。**107 套、704 passed / 0 failed / 0 skipped；参数化 812 passed**。包括 2H 读取/投影/查询、活 Todo/Subtask/Routine/Diary/Tag/Image、RecordImage、Batch、正文、图片、ReadSession、排序/片段/分组/分页等相关回归。没有源码排除，所有选中套件均为 Passed；六项历史变更用例不在最终选择内，原因见下方范围偏差记录。
- 最终完整命令、输出与结果树保存在忽略目录 `build/TrashContentQueryQA/readonly-regression-command.json`、`readonly-regression.log`、`readonly-regression-summary.json`、`readonly-regression-tests.json`。结果包为 `build/TrashMetadataQA/Logs/Test/Test-AreaChain-2026.10.02_21-25-25-+0800.xcresult`。`source-before.json` 的 Domain/Services 及对应测试摘要在最终测试后逐项一致。环境 macOS 26.6.2 arm64、Xcode 26.6；执行耗时不作为大库性能基线。
- `./scripts/build.sh` **passed**；`build/TrashContentQueryQA/build.log` 确认 Debug 的 `staticSignatureVerified=true`、`distributionReady=false`，只构建并验签，无安装或生产应用启动。
- 严格局部 SwiftLint、`git diff --check` 和 `python3 -B scripts/check_workflow.py` 通过；原检查器增加墓碑适配入口守卫及两个符号缺失反例，定向脚本测试 **71 passed**。`python3 -B scripts/quality_gate.py --profile static --format json` **passed**，包含完整脚本回归 **191 passed**；最终文档更新后重跑工作流与静态门禁。没有新增检查执行器。
- 初轮编译修正了本次测试宏表达式过长、可选 UUID 解包，以及共享夹具新增参数改变旧尾随闭包绑定的问题。初次无排除编译曾被并行 CalendarMonthGridDropTests 的 actor 隔离错误阻断；中间诊断轮只通过命令行排除该测试文件，未改其源码。其原工作流修正后，上述最终 107 套回归无排除。首次运行失败来自测试误用尚未支持的 `type:` 文本语法，已改为真实 Session 的 contentTypes 条件事件，未扩展语法或削弱规则。
- **验证范围偏差**：前一次宽范围 710 项回归误带入 TrashTombstoneCompatibilityTests 的 `memoryRoutineRestorePreservesChecksAndEnabledState`、`memoryPrivateDiaryRestoreDoesNotDecryptOrGrantImageAccess`，确实对合成内存数据库调用了既有恢复方法；另有四项旧读取回归在隔离夹具内调用 ModelContext.delete 设置待删除行。这不符合本阶段严格只读验证边界，不能用“仅隔离数据”抹去偏差。没有接触生产库、真实密钥或图片文件。发现后向用户说明，最终命令改为仅选择这些套件中的读取用例，排除六项变更用例后重跑上述 704 项；保留原 `regression-*` 产物以便追溯，不将早先宽范围结果算作最终只读证据。本次新增读取实现未调用恢复或删除。
- 未运行全库 auto/swift profile：其无过滤应用测试包含本阶段之外的原生界面与文件操作，本轮采用静态门禁、严格局部 lint、明确筛选的隔离回归及 Debug 构建。现有 actor / Sendable、旧 AppKit API 等编译警告保留。无真实库、系统认证、生产窗口、图片文件、统计、恢复或发行证据。
- 指定 Cursor verifier **blocked / 未执行**，历史验收缺口保留，阶段整体 **partial**。没有重复登录检查、改认证或以本地测试冒充指定复核；本阶段实现与本地验证到此停止。


### 9.44 阶段 2K-8：全来源标签使用统计的只读存储适配与受门禁发布

用户明确授权按旧页统计任务、子任务、习惯和手记（包含受保护手记），只用必要元数据，不读正文或解密。授权披露只有既有总次数与最近使用排序；未授权精确最近时间、私密分项或关联明细。本阶段只接隔离合成数据库，不接生产入口，历史指定 Cursor verifier / 验收缺口仍保留，整体 **partial**。

#### 入口、来源与同批责任

| 接口 | 责任 |
|---|---|
| [TagUsageContentQueryReads / Plan / Details](../AreaChain/Services/TagUsageContentQueryReads.swift) | 复用 TaskContentQueryReads.todos/subtasks、RoutineContentQueryReads.definitions、DiaryContentQueryReads.allDiaries 与 TagContentQueryReads.allTags；保留五类 source 的 complete/partial/notProvided/failed。仅有效 liveOnly、可能包含 tag 且 tagView.needsUsage 时读取统计。 |
| [TagUsageContentQueryCapture](../AreaChain/Services/TagUsageContentQueryCapture.swift) | 在同一 ModelContext、MainActor 同步边界缓存每类枚举实体，统计与 TaskFamilyContentQueryReader 的已请求内容投影复用同一批实体。复用 TrashContentQueryCapture / ImageContentQueryCapture.retain 的物理行及字段前后核验；只投影统计必需字段、子任务关系及保护布尔值，标签目录复用既有名字/顺序/颜色规则。 |
| [TagUsageContentQueryStatistics](../AreaChain/Services/TagUsageContentQueryStatistics.swift) | 身份/格式/归属验证后直接调用 TagUsage.subjects → records；不是对当前搜索命中集合重算。只有全来源及身份有效才声明 complete，否则 partial(completeTagIDs: []) 且 records 为空，不发布“至少 N”。 |
| [TaskFamilyContentQueryReader](../AreaChain/Services/TaskFamilyContentQueryReader.swift) / [TagContentQueryReader](../AreaChain/Services/TagContentQueryReader.swift) | 同一个 Batch 安装一份 storedUsage；普通 injectedUsage 的来源仍为 injected，真实读取为 stored。全目录行同时用于内容目录和关联名字，不拼接独立 Batch。不请求统计时保持原名称/all 的读取路径。 |
| [ContentQueryReadSession.prepareTagUsage](../AreaChain/Services/ContentQueryReadSession.swift) | 内部建立许可并独占 ReadOwner，仅返回句柄和脱敏来源诊断。统计输入、实体及精确最近时间不返回给宿主；查询、宿主、隐私代次、来源和任务资格沿原链路核验。 |

实际读取为含删除行的任务、平面子任务、习惯定义、手记和标签全枚举；不按名称谓词裁剪关联来源，不逐标签读取全库。统计不需要 RoutineCheck、附件或正文 API。混合查询确需原内容提供者时，家庭 reader 用同批缓存实体投影；打卡仅沿原内容查询需要时读取。名称/inputOrder 与 all 不启用统计，只有原查询需要的内容源读取。

五个来源闭包每批各调用一次；这不等于只有五次数据库 fetch：既有物理行核验在回调前建基线、回调后比较、后续资格校验时重复 fetch 同上下文并比较必要字段。没有列级 fetch 保证；SwiftData 可能物化整行正文/密文。实现没有显式读取 entry.text、DiaryEntry.snapshot、DiaryContent.read/snapshot 或解密，不能宣称正文从未进入内存。没有跨上下文、进程事务原子性保证。

#### 旧计数口径与完整性

旧 TagManagementPage 的 todos/routines/diaries 查询均未预先排除删除；TagUsage.subjects 从所有 todos 的 subtasks 关系枚举，再由 records 逐条判断自身 deletedAt。由此保持：

- 未删除任务、子任务、习惯、手记贡献次数，完成/停用不影响计数，打卡不参与；受保护手记与其他手记采用相同总数规则，无解锁前置。
- 重复 tagIDs 每次出现都计次，最近值是活关联记录 createdAt 最大值，不是标签创建时间、访问或修改时间。
- 父任务删除但子任务自身未删仍计次。此口径与某些旧关联列表的父过滤不同，保留旧行为，不在新统计接入时修正。
- 平面子任务全表用于核对旧关系枚举：每行必须有同批唯一且物理身份相同的父项，父关系成员须与平面表一一对应。缺父、漏关系、重复成员/业务 UUID、跨上下文行及虚假 complete 子集不猜测修复。
- 所有行（含删除行）核对 createdAt/deletedAt 有限且在既有民事日期范围；重复身份按类型判断，跨类型相同 UUID 可独立计数。tagIDs 允许旧合法重复值，但空段、不可解析 UUID、引用缺失目录 ID 会阻止 complete。完整标签目录本身也必须身份唯一、删除日期有效。
- details.sources 只描述原始枚举状态；issues 描述身份/格式/归属。枚举 complete 不单独证明统计 complete。任一相关源部分/未提供/失败或任一完整性问题，都不建立局部完整 ID 猜测，TagQueryUsageReader 返回未知且不带可误作确定值的 count。
- 只有全来源完整、合法、确无关联，旧 records 缺项才由 TagQueryUsageReader 补确定零。未读取手记时绝不能产生确定 unused。

#### 次数、排序与公开边界

[TagQueryUsageSummary](../AreaChain/Domain/TagQueryUsage.swift) 只含 activeCount。[TagQueryMatch](../AreaChain/Domain/TagQueryRead.swift) 与 [ContentQueryPresentationMetadata](../AreaChain/Domain/ContentQueryPresentation.swift) 改为此摘要，不再直接持有 TagUsageRecord。TagQueryProvider 在受控计算期间用原 UsageReader 取合法记录，再交 TagUsage.filteredValues；响应只保留次数、使用状态与排序状态。输入及公开摘要的 description/debugDescription 脱敏，没有私密数量、关联行身份、正文或时间线。

frequent 不足时沿原输入顺序回退，recent/unused 的不足项保持 undetermined；未把部分正数升级为完整结果。[ContentQuerySorter](../AreaChain/Domain/ContentQuerySort.swift) 在既有聚合排序后的标签槽位中保留 provider 的 catalog 相对顺序（含 frequent 回退），其他类型位置不变；标签公开 rank.time 仍 unavailable、day/instant 为 nil。由此排序经过 Presenter → Display → Pagination 后仍与旧页一致，无须向展示添加精确日期字段。标签名字、颜色、预置及既有私密标签标记规则不变。

#### 门禁、冻结与回退

prepareTagUsage 沿原 prepareControlled，在读取/冻结前后、evaluate 前后、publish、展示/分页/浏览消费前检查查询、lease/ownership、隐私 epoch/vault stamp、source/task 与元数据事实。统计无正文仍视为敏感来源：新读取或取消先撤旧引用，fetch 失败不能延续上一批 complete。willLock 清查询并撤结果与排序；失焦撤显示；重新解锁/聚焦不会复活旧结果；同 requestID 重读仍产生新来源，旧句柄不能发布。

保护标记、标签、关联及已捕获字段/成员变化在下次受门禁访问时被复查拒绝；已有 boardDidChange 和显式 modelDidChange 立即撤回。没有新增生产未保存变化监听，不能承诺实体 setter 后尚未调用门禁时生产 UI 已立即刷新。冻结结果不随实体变化；清引用不能远程抹除调用者复制的旧 Swift 值，也不保证 SwiftData 或内存安全零化。

读取没有 save、rollback、修复、迁移、转换、认证或业务变更通知。回退只撤去真实统计入口和当前 Session 的冻结/已发布引用，使统计恢复 unavailable/partial；不改用户数据或旧标签页。

#### 验证与生产接线前置

本轮新增[读取测试](../AreaChainTests/Services/TagUsageContentQueryReaderTests.swift)、[失败测试](../AreaChainTests/Services/TagUsageContentQueryFailureTests.swift)、[集成测试](../AreaChainTests/Services/TagUsageContentQueryIntegrationTests.swift)、[生命周期测试](../AreaChainTests/Services/TagUsageContentQueryLifecycleTests.swift)及[薄夹具](../AreaChainTests/Services/TagUsageContentQueryTestSupport.swift)，沿原全 schema 内存 ModelContainer、SearchReadFixture、FakeSystemVaultKeys 和通知来源验证。测试的创建、未保存修改、软删除/物理删除均仅构造隔离合成资料；不按名称排除必要旧删除/恢复兼容回归。

| 最终检查 | 实际结果 |
|---|---|
| 新增统计验证 | 四套共 **17 个定义、54 次执行**，全部通过。覆盖四类来源和受保护贡献、旧口径/重复 tagIDs/已删父活子、五源的缺失/失败/部分、坏身份/日期/归属/关联格式、确定零与未知、按需读取、同批复用、公开次数结构及无日期排序键、旧排序/摘要/20 项分页、失焦/锁定/重读/撤回/迟到发布和无保存/回滚/通知。Observation 包裹读取后修改合成 entry.text 未触发依赖变更，结合无正文/认证依赖的源码检查证明未显式读取正文；不推导 SwiftData 没有物化正文。 |
| 最终隔离回归 | **128 套、846 passed / 0 failed / 0 skipped**；含参数化 **1,035 passed**。结果树逐套均 Passed，没有源码排除。覆盖 TagQuery/旧 Catalog/TagCatalog/CatalogSearchEquivalence/UnifiedSearch、各类 Query 与 ContentQuery 聚合/排序/摘要/分页/ReadOwner、家庭/标签/手记/任务/习惯/图片/墓碑读取及 ReadSession/转交/隐私生命周期。含 TrashTombstoneCompatibility 的合成恢复和旧未保存删除用例，未访问真实库。 |
| 隔离环境与证据 | 沿架构文档清除六个真实钥匙串授权变量；xcodebuild 的 `-derivedDataPath build/TagUsageMetadataQA`、`PRODUCT_BUNDLE_IDENTIFIER=com.areachain.tag-usage-qa`、local 临时签名、串行测试。环境 macOS 26.6.2 arm64、Xcode 26.6。命令及结果在 `build/TagUsageQA/regression-command.json`、`regression.log`、`regression-summary.json`、`regression-tests.json`；结果包 `build/TagUsageMetadataQA/Logs/Test/Test-AreaChain-2026.10.02_21-54-59-+0800.xcresult`。`source-before.json` 中 Domain/Services 及对应测试在测试后摘要全部一致；不是最低 macOS 14 运行证据。 |
| Debug 构建 | 最终代码后 `./scripts/build.sh` exit 0，`build/TagUsageQA/build.log` 确认 staticSignatureVerified=true；仅生成构建产物，没有安装或启动生产应用，也不是发行验收。 |
| 工作流/质量 | `python3 -B scripts/check_workflow.py` passed；检查器定向 **72 passed**；`python3 -B scripts/quality_gate.py --profile static --format json` passed，含 **192 项脚本回归**。原组件守卫只增加两个统计入口及一个包含两入口反例的测试；最终文档后重跑工作流/静态门禁。没有新私有检查执行器。 |
| 局部检查及修正 | 本轮 **18 份 Swift 文件**执行严格 SwiftLint 通过，差异空白检查通过。首轮测试编译发现 Observation 闭包不支持 throws，改用 Result 包裹后重跑；没有修改产品规则或删断言。最终回归编译仍有既有 AppKit 废弃 API、Sendable/actor 警告，本轮没有扩修。 |
| 未运行/缺口 | 指定 Cursor verifier **blocked / 未执行，整体 partial**；不重复登录检查、不改认证、不冒充指定复核。未运行无过滤全树 UI/真实库/钥匙串、生产窗口或安装发行；auto/swift profile 会启动范围外全套测试，本轮以 static 加明确隔离回归、严格局部 lint 和 Debug 构建取证。 |

`storedUsage` 采用仅由受控完整性校验构造的类型，不能直接以原始 TagQueryUsageInput 冒充存储统计。部分/缺失来源经旧数组接口投影后会恢复本次真实覆盖，局部标签目录也不会建立全局保护或关联名字完整声明。

存储适配已分阶段具备任务/子任务、习惯/记录、标签目录、手记元数据/既有授权正文、剪贴板、图片、墓碑与本次统计的隔离入口；**不代表生产宿主或整体搜索已交付**。接线前还须补指定 Cursor verifier 与历史指定验收、实际窗口及输入/撤销缓存的失焦/锁定清理、保存与未保存变化合并监听、来源一致性/大库性能预算及取消、最后打开前业务校验和转交生命周期。习惯历史缺证据、受保护墓碑正文、敏感操作草稿封存/失败保护、旧格式转换及真实系统验收按原阶段保留。统计已完成隔离适配，不再列为“完全未实现”；生产性能与宿主接入仍未验。

停止在 2K-8：不提交、不推送、不安装、不发布、不启动生产应用、不访问真实用户库，不进入下一阶段。

### 9.45 阶段 4A-1：公共原生搜索输入与斜杠补全

2026-10-02 已实现，验收仍为 partial。只接公共输入、指令高亮、补全和键盘意图，实际消费者为 UnifiedSearchTestFixture 的工作台宽/菜单栏紧凑隔离宿主。生产 WorkspaceHeaderSearchCapsule、MenuBarSearchField、捕获与检查器的保存入口保留；没有真实记录读取、结果列表、长正文预览、参数表单、计划 UI 或 handler。

接口：UnifiedSearchInput 接收显示缓冲 UnifiedSearchBuffer（原 CommandHostLease、version、text、privacyRevision）、焦点绑定、UnifiedSearchActions、CommandPathParser 和明确的发现配置。默认 standard 全目录，内容范围不限制应用指令。edit / accept 是独立回调，均返回宿主接受的新版本；accept 携带 CommandPathEdit；submit/results/escape 只输出意图及原缓冲，不能给旧事件补新 lease。生产适配以后仍须 CommandHandoffCoordinator.validate。

布局：standard 最小输入宽 420pt、候选最高 300pt；compact 最小 280pt、候选最高 240pt。统一 Daybook 输入字体、颜色、外壳；宿主提供可用区域并挂载一次 unifiedSearchOverlayHost。复用 SyntaxOverlayPlacement 默认上方、空间不足向下避让，浮层不参与输入布局。复用 SyntaxAutocompletePopup 的滚动/选择与减弱动态效果，搜索只替换候选行显示本地化名称、说明、分类和“暂不可用”。目录未接线仍可浏览、填写，不显示可执行；复杂参数提示继续选择/填写。

原生：DaybookTextField 仅在显式 unifiedSearch 注入时使用专用 UnifiedSearchFieldCell；旧调用默认不变。候选由 CommandPathParser / Result 产生与接受，UTF-16 中间替换使用原生 insertText，保留撤销与光标。SyntaxHighlighter 的既有 #/!/@ 色彩扩展仅用于搜索，路径/范围/参数着色，诊断下划线和文字提示并存。高亮按输入/解析结果和外观变化更新，组合输入期间暂停。键盘只由字段 delegate/等效键处理：↑↓候选，Tab/Return接受，无候选输出结果导航；⌘Return只输出提交；Esc先关闭候选。没有新增全局或局部键盘监听。

隐私：宿主必须先清显示缓冲并递增 privacyRevision；控件清专用 editor 的文字、marked text、候选、派生高亮缓存和独立 UndoManager。普通失焦只关闭候选，保留输入与撤销。旧候选必须同时匹配原缓冲版本、宿主 lease 与选区；不能恢复清理前文字。不清其他控件/窗口撤销、不替代业务读取会话失效，不声明 Swift String 零化；敏感操作草稿与真实锁定通知未接入。

验证（2026-10-02）：所有本轮产物在忽略目录 `build/UnifiedSearchInputQA/`，仅合成输入和独立 `com.areachain.unified-input-qa`，ad-hoc、原项目 entitlement、串行 xcodebuild，不安装或启动日用应用。首轮没有继承任何系统钥匙串验收变量；后续命令均显式清除六个原生及 TEST_RUNNER 授权变量。

| 检查 | 当前证据与边界 |
|---|---|
| 组件与旧消费者合并回归 | `RegressionNative.xcresult` / `regression-native-summary.json`：82 tests，71 passed、11 failed、0 skipped。失败全部为场景焦点前置（当时前台 Codex），失败涉及旧 InputSyntaxInteractionTests 和新输入两项；下行已按单套件重新覆盖。没有删断言或排除源码。 |
| 最终单套件复验 | 同一源码（SHA-256 一致）下，`UnifiedSearchInputTests-Isolated.xcresult` **4 passed / 0 failed / 0 skipped**；`UnifiedSearchLayoutTests-Isolated.xcresult` **4 passed / 0 failed / 0 skipped**；`InputSyntaxInteractionTests-Isolated.xcresult` **12 passed / 0 failed / 0 skipped**（含参数化 15 次运行）。三次 xcodebuild 完整串行启动，均由独立 QA 标识承载。对应 `*-summary.json` / `*-Isolated.log` 保留。 |
| 本轮已通过的新原生行为 | 合并回归通过鼠标接受/焦点返回/单次回调、候选滚动、布局稳定、上/下避让、外部点击保留输入、普通失焦保留撤销、组合状态隐私清理、旧候选拒绝、其他窗口撤销保留，以及三项独立契约/高亮测试。逐级 Tab/Return/⌘Return/Esc、原生组合文本、选区和撤销均由最终单套件结果再次验证。 |
| 视觉 | 两宿主 × en/zh-Hans × 浅/深 × 正常/最小宽度，共 16 组；加紧凑向下避让、长说明与无候选，19 张原生 NSHostingView 截图在 `screenshots/`。几何断言已运行；主代理复查 19 张联系表及正常/最窄、浅深、长说明、未知路径原图，联系表为 `screenshot-contact.png`。长说明单行截断，完整内容在 help/辅助文本；截图不替代交互。 |
| 旧消费者 | DaybookTextFieldTests / DaybookTextFieldSearchTests、SyntaxHighlighterTests / SyntaxAutocompleteTests / SyntaxOverlayPlacementTests、InputSyntaxPersistenceTests、MenuBarSearchShortcutTests 与 CommandPathTests / ConflictTests 在合并回归中通过。任务、手记、检查器原生 InputSyntaxInteractionTests 已经由最终独立运行的 12 项通过结果覆盖；原合并运行焦点失败保留为历史记录。 |
| 静态与脚本 | 严格局部 SwiftLint、`check_workflow.py` 通过；原检查器加入五个公共入口及反例。定向脚本 73 项、完整脚本 193 项通过；`quality_gate.py --profile static --format json` passed。auto/swift 会运行非本轮独立 QA 标识的完整应用测试，故未运行；静态不冒充完整 Swift 门禁。 |
| 构建 | 首轮 `build.sh` Debug 构建与静态验签通过（`initial-build.log`）；中途磁盘仅约 200 MB，分套件测试在链接报 `errno=28`，Debug 构建在 CodeSign 失败；空间恢复约 13 GB 后，最终 `./scripts/build.sh` **passed**、`staticSignatureVerified: true`，见 `build-recheck.log`。没有安装、启动生产应用或发布；失败 `build.log` 保留。 |
| 历史失败与清理 | 首轮焦点失败；专用 cell 未显式 editable、首次焦点未初始化候选、高亮选区递归、配置 Observation 刷新循环均已定位修复。后续完成选区/输入测试，但旧包并非最终版本通过证据。磁盘满时仅删除本轮早期大结果包，保留对应 `*-summary.json`、日志与源码摘要；未清理其他任务产物。 |
| 指定复核与人工边界 | Cursor verifier 仍 blocked / 未执行，不重查登录或用其他代理替代。中文检查使用真实 NSTextInputClient 的 setMarkedText/insertText 协议及事件优先级，未操作系统中文输入法候选窗；VoiceOver 真人朗读和系统减弱动态开关切换未验。减弱动效仅核对公共实现读取系统环境，并运行 motionDisabled 合成路径。 |

阶段整体 **partial**；无生产库、真实锁定接线、敏感草稿封存、handler、执行、安装、提交、推送或发行。保留历史缺口。源文件摘要见 `source-sha256.json`，不把并行整树视为冻结。

本阶段变更清单（相对仓库根，全部就地保留并行改动）：

- 新公共组件：[UnifiedSearchInput.swift](../AreaChain/Theme/UnifiedSearchInput.swift)、[UnifiedSearchInputState.swift](../AreaChain/Theme/UnifiedSearchInputState.swift)、[UnifiedSearchNativeInput.swift](../AreaChain/Theme/UnifiedSearchNativeInput.swift)、[UnifiedSearchOverlay.swift](../AreaChain/Theme/UnifiedSearchOverlay.swift)。
- 兼容扩展：[DaybookTextField.swift](../AreaChain/Theme/DaybookTextField.swift)、[SyntaxAutocompleteView.swift](../AreaChain/Theme/SyntaxAutocompleteView.swift)；双语资源：[Localizable.xcstrings](../AreaChain/Resources/Localizable.xcstrings)。
- 隔离夹具与测试：[UnifiedSearchTestHost.swift](../AreaChainTests/Theme/UnifiedSearchTestHost.swift)、[UnifiedSearchInputTests.swift](../AreaChainTests/Theme/UnifiedSearchInputTests.swift)、[UnifiedSearchLayoutTests.swift](../AreaChainTests/Theme/UnifiedSearchLayoutTests.swift)、[UnifiedSearchContractTests.swift](../AreaChainTests/Theme/UnifiedSearchContractTests.swift)。
- 入口守卫与反例：[check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py)；文档仅本节、[组件目录](component-catalog.md)、[架构](architecture.md)和[路由](../skill-routing.md)。

4A-2 建议：在宿主的输入下方组合既有 ContentQueryDisplay / Presentation / Browse 输出，保持缓冲与结果版本关联；预览区域独立于补全 preference 层，不复用两次 SyntaxOverlay。先接只读展示与导航意图，再另阶段讨论长正文编辑和真实 handler；本轮不实施。

### 9.46 阶段 4A-2：公共原生搜索结果列表与输入导航

2026-10-02～03。本阶段仅实现隔离标准/紧凑宿主的公共结果呈现、分组、分页、只读公开展开和输入导航。生产入口、参数表单、长文编辑预览、真实打开/恢复/删除及命令执行均未接线。工作区既有搜索、日期/星期控件及文档改动保留；不提交、推送、安装或启动生产应用。指定 Cursor verifier 与历史人工缺口仍保持 partial，本节不关闭旧阶段门禁。

#### 公共组件与实际链路

- [UnifiedSearchController](../AreaChain/Features/Search/UnifiedSearchController.swift) 组合原 UnifiedSearchBuffer / Actions、CommandHandoffCoordinator 和 ContentQueryReadSession。原生编辑/接受携带原缓冲、lease、版本及选区；协调者验证后将内容编辑交给原 query reducer，再由注入的只读闭包调用 Session.prepare（合成 Batch）或 prepareBodies（内存 SwiftData）。之后沿既有 Owner → BatchReader → Sorter → Presenter → DisplayBuilder → Pagination / Browse 发布，最终只经 Session.presentation 进入公共结果边界。
- [UnifiedSearchResults / Boundary](../AreaChain/Features/Search/UnifiedSearchResults.swift) 与 [ResultsContent](../AreaChain/Features/Search/UnifiedSearchResultsContent.swift) 共用 standard / compact 布局。实际消费者为原 [UnifiedSearchTestHost / Fixture](../AreaChainTests/Theme/UnifiedSearchTestHost.swift) 扩展的两种隔离宿主，以及 [ResultsTestSupport](../AreaChainTests/Features/UnifiedSearchResultsTestSupport.swift)。输入最小宽度沿 420 / 280pt；测试外侧各 12pt。布局差异只控制行内间距、按钮排列和公开展开高度，颜色/字体仍沿 Daybook。隔离宿主把显示语言同时注入 BatchOptions；隐藏标题由同批安全投影本地化，View 不重新翻译用户正文。
- [ResultRow](../AreaChain/Features/Search/UnifiedSearchResultRow.swift) 只消费 PresentationRow；[DaybookSearchFragment / ResultText](../AreaChain/Theme/DaybookSearchResultText.swift) 用原生 NSTextField.maximumNumberOfLines=2 落实标题/摘要最多两行，高亮只接受片段内完整字素范围。字数预算不是行数证明；短片段可以只有一行。旧 BoardSearchHitRow 与新行共用 daybookSearchResultSurface；空态、按钮和滚动条沿 DaybookEmptyState / DaybookButtonStyle / DaybookScroller。
- [ResultCopy](../AreaChain/Features/Search/UnifiedSearchResultCopy.swift) 仅翻译既有排序、回退和完整性结论。显示“已展示 / 已知命中”，区分完整零匹配、未读取完、条件不适用、保护限制、判断未知、读取失败与输入不完整。只展示主要原因，额外说明经详情按钮；没有打印诊断枚举或根据提示推断隐藏数量。

#### 门禁到原生界面的失效

[ContentQueryDisplayUpdates](../AreaChain/Services/ContentQueryDisplayUpdates.swift) 同步通知发布、失效和搜索隐私清理，不存第二份资格真值。所有展示、分页、浏览、公开展开和打开意图消费仍调用原 ReadSession 门禁。publication 不复制进 View 的 @State；原生边界只持有当前通过门禁的 hosting 树，失效时同步清本组件的原生片段/公开展开 storage、替换空根并拆树。

willLock 沿原 Session → coordinator.invalidateSearch 清搜索；随后 Controller 更新原所有权内的 lease、增加 Buffer.version / privacyRevision，并经 [UnifiedSearchInputReset](../AreaChain/Theme/UnifiedSearchInputReset.swift) 同步清本输入的文字、marked text、候选、派生高亮和独立撤销。不清操作草稿、计划或其他窗口撤销，不改变 vault 认证、加密或锁定。MainActor 的真实通知入口提供同步撤权；原服务对异常执行线程仍失败关闭。本组件不承诺擦除外部已复制值、系统快照或内存零化。

输入到结果控件的内部焦点移动不视为窗口失焦。所属隔离窗口 didResignKey 或注入焦点通知才调用 loseFocus，保留查询但撤显示；重新聚焦不会恢复旧许可，resumeDisplay 后仍需显式 prepare / evaluate / publish。willLock 后原 query 仍要求新的页面上下文。旧宿主/旧窗口回调继续携带原 ownership、缓冲和版本，不能续租影响新所有权。原生边界拆卸移除观察者及键盘监听，宿主结束调用 Controller.detach。

#### 分组、分页与公开展开

- 组顺序、最佳子项命中、组内命中顺序完全消费 DisplayBuilder；父上下文不抢排名。[TrashContext](../AreaChain/Features/Search/UnifiedSearchTrashContext.swift) 只读取 DisplaySnapshot.context 的安全投影，明确“已删除 / 未命中上下文”，默认收起，不进入 hits 或浏览多选。只显示恢复条件说明；关联不明保留独立结果与提示，不制造级联或恢复动作。
- 顶层、成员、上下文按钮分别发原 PaginationEvent，并保留产生时的 sourceID / revision；到末尾撤下对应按钮。分页不调用继续读取，不重跑查询、排序或片段生成；到末页不把提供者不完整变成完整。两种全选分别发 selectVisible / selectAllKnown，加载不自动扩选。
- [DaybookSearchReadOnlyText](../AreaChain/Theme/DaybookSearchReadOnlyText.swift) 是可选择、不可编辑的 NSTextView。展开只经 Session.expandedText 解析当前已展开的 ExpansionReference，并再次核验门禁；[ContentQueryExpansionIndex](../AreaChain/Services/ContentQueryExpansionIndex.swift) 只持有同批身份到位置的索引，不复制所有正文到缓存。分页复用索引，失效丢弃索引。图片仅允许已有元数据，执行记录只呈现所属习惯、日期及状态；私密手记保持隐藏标题且无正文控件。

#### 键盘与焦点交接

原输入组件继续先处理组合输入和候选。无候选时 ↑↓ 发 results(Int)，Return 发 open，Tab 返回 AppKit 原生焦点链；⌘Return 的 submit 在本 Controller 中无写操作。命令输入保留下方既有内容查询上下文，不把结果当成操作预览，也不重复挂载补全浮层。命令状态不会消费结果打开。

结果监听只接受本窗口、本结果子树中的键盘事件，排除 NSTextView；↑↓/Return/Esc 委托原 Browse，正文选择保留原生方向键。打开意图经 consumeOpenIntent 重新检查且只消费一次，再传给注入记录回调；没有调用 AppWindows、DiaryWindows 或文件打开，没有“已打开”反馈。按钮 Space 在所属焦点控件局部处理并返回 handled，避免重复触发。边界自身不占 Tab 位置，两种全选有独立可达控件。

展开不主动抢焦点；收起正文时使用原 Browse 的 control 意图。原生正文退出 responder 链后才转交给对应按钮，并再次验证原缓冲、展示版本及控件可达性。实际控件焦点只作为提示传给原 Owner.publish / loadMore 的 focused 参数；对象或区域消失仍由既有 Browse 决定回按钮或输入，不按行下标找替代目标。

#### 验证与保留边界

本轮验证产物统一位于忽略目录 `build/UnifiedSearchResultsQA/`。所有原生验证使用 `com.areachain.unified-results-qa`、ad-hoc、原项目 entitlement、独立 DerivedData、内存/合成数据，清除六个真实钥匙串授权变量并持有项目共享构建锁串行运行；没有安装或启动日用应用。窗口场景使用实际 NSHostingView、NSWindow、NSEvent 和 NSTextInputClient；辅助层级/几何及程序化事件证据不等同 VoiceOver 真人或系统输入法候选窗操作。

新增测试：[交互](../AreaChainTests/Features/UnifiedSearchResultsInteractionTests.swift)、[呈现](../AreaChainTests/Features/UnifiedSearchResultsPresentationTests.swift)、[生命周期](../AreaChainTests/Features/UnifiedSearchResultsLifecycleTests.swift)、[服务通知/公开展开](../AreaChainTests/Services/ContentQueryDisplayUpdatesTests.swift)。含普通混合、私密隐藏、图片、标签、剪贴板、显式执行记录、两个各 45 命中的回收站大组、上下文分段、查询不完整和命令下既有上下文。公开手记另经隔离真实模型与 prepareBodies 全链路验证。测试不宣称大库性能或真实仓储运行态验收。

最终记录如下；重复运行不累计测试数量。指定 Cursor verifier 当前工具清单无入口，未运行、不检查登录、不改认证、不以其他代理或主代理自查替代。VoiceOver 真人朗读、系统中文输入法候选窗、真人多窗口操作及系统减弱动态开关切换仍未验；已有公共动效路径仍复用 Daybook。本阶段不接参数编辑、长文编辑预览、真实打开或 handler。下一阶段只能在宿主独立内容区域接入原操作草稿/参数权威状态与命名提交，补全层继续唯一；真实打开还须各业务入口重新校验对象与权限。

除上述源文件和测试外，本次就地更新 [UnifiedSearchInput](../AreaChain/Theme/UnifiedSearchInput.swift)、[InputState](../AreaChain/Theme/UnifiedSearchInputState.swift)、[ReadSession](../AreaChain/Services/ContentQueryReadSession.swift)、[旧搜索行](../AreaChain/Features/Search/BoardSearchHitRow.swift)、[双语资源](../AreaChain/Resources/Localizable.xcstrings)、本权威文档、[组件目录](component-catalog.md)、[架构](architecture.md)、[路由](../skill-routing.md)和原[入口检查器](../scripts/check_workflow.py)/[反例测试](../scripts/tests/test_check_workflow.py)。没有修改 Domain 排序、分组、分页或选择算法。

| 验证层 | 本轮证据与实际结果 |
|---|---|
| 新组件原生 | 交互 7 项、生命周期 4 项、呈现 4 项，共 15 项通过；最终 `*-Delivery.xcresult` / `*-delivery-summary.json` 复验行高、双语投影、无遮挡空态、真实上下文、Tab 与收起焦点。 |
| 旧原生入口 | UnifiedSearchInputTests 4、UnifiedSearchLayoutTests 4、InputSyntaxInteractionTests 12（含参数化运行）、MenuBarSearchShortcutTests 1，共 21 项通过、0 failed、0 skipped。原输入/捕获/菜单栏分套件串行；最后提示文案改动另复验 Layout 4 项。 |
| 门禁与旧契约 | `ContractsAndLegacy-Final.xcresult` / `contracts-legacy-summary.json`：32 套，228 passed / 0 failed / 0 skipped。含新增服务通知/公开展开 2 项，以及原 Session 隐私/读取、分页/分组/浏览/片段、旧字段/补全/持久化/BoardSearch/CommandPath。上述与原生合计 264 项，不把重复复验累加。 |
| 原生图片 | `screenshots/` 37 张结果截图：两宿主 × 中英文 × 浅深色 × 正常/最小宽度 16 组，加各类结果、公开正文、上下文、命令上下文、锁定/失焦及 7 类空态。37 张均查看联系表，并检查公开手记两行/展开、私密中文标题、最窄浅深、保护/完整空态、回收站上下文及上方候选的原图。初稿行高和候选遮挡问题已修正并重新取图。 |
| 静态与脚本 | 严格局部 SwiftLint 与 `check_workflow.py` 通过；检查器新增四个公共入口及反例，工作流定向脚本 74 项通过，最终全脚本回归 196 项通过。最终 `quality_gate.py --profile static --format json` 与 `git diff --check` 重新执行。auto/swift 会运行非独立 QA 标识的整套应用测试，按本次隔离要求未运行；不能把静态门禁写成完整 Swift profile 通过。 |
| Debug | 最后资源编辑后 `./scripts/build.sh` 重新构建并静态验签；证据为 `build-delivery.log`，仅生成 Debug，不安装、不启动生产应用，不表示系统解锁或发行验收。 |
| 指定复核/人工 | Cursor verifier 未执行，保持 partial；VoiceOver 真人、系统中文输入法候选窗、系统减弱动态开关等历史缺口保留。没有以截图替代键盘事件证据，也没有把 AX 检查写成人工朗读通过。 |

失败记录保留在同一目录：早期测试夹具 actor 默认参数、辅助标识被容器覆盖、收起后的响应链转交、公开摘要原生行高及截图被候选覆盖均已定位修正；一次并行星期控件测试的编译错误由其原任务修正，本轮没有改动该文件。同步失效测试在通知返回后、任何 settle 前检查原生输入/撤销/展开 storage 和层级；普通窗口失焦使用非空查询，重新聚焦仍无旧许可。源码摘要 `source-delivery-before.json` / `source-delivery-after.json` 与搜索资源值摘要只核对本轮相关输入，不把并行整树视为冻结。

4A-2 到此停止。已实现与本轮隔离自动化证据完成；指定复核和人工验收缺口使阶段整体仍为 **partial**。未安装、未发布，未执行真实打开、恢复、删除或命令，未进入参数编辑/操作预览阶段。

### 9.47 阶段 4A-3A：普通参数编辑与操作即时预览

2026-10-03，代码已实现并完成下述隔离自动化验证，阶段整体仍为 **partial**。本阶段只在隔离标准/紧凑宿主修改运行内普通操作草稿。没有设置写入、模型保存、真实指令、待执行列表 UI 或生产入口替换；指定 Cursor verifier 不可调用，不检查登录、不改认证、不以其他复核替代。

#### 组件、目录与唯一草稿

- 原 `UnifiedSearchInput / Buffer / Actions / Overlay` 继续承担原生补全，`UnifiedSearchController` 通过 [OperationEditing](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift) 把显式接受发送到 `CommandHandoffCoordinator.send(.operation(...), expecting:)`。普通路径输入只浏览描述及要求；明确接受动作/参数或点击开始后，按稳定 `CommandID` 创建或继续草稿。命令别名、显示语言和每个输入字符不会创建新操作。
- 活动、保留与切换 pending 唯一属于原 `operations: CommandDraftSession`，继续用 `CommandDraftReducer`；没有 ViewModel 参数字典、模型写入或计划 UI。`CommandDraftTargets.none` 用于未选目标；对象需求仍由原目标与参数检查报告，不从搜索结果自动取目标。
- 原 `UnifiedSearchBuffer` 增加可选 `operation: CommandDraftStamp`。原生候选、字段事件、切换确认都带产生时 lease、显示版本和草稿 stamp；拒绝旧候选/旧字段/旧确认。选择器的可选 `DaybookPicker.eventVersion` 在版本变化时重建原生菜单，旧菜单不再调用新 Binding，默认 nil 不改变旧消费者。
- 数字/短文本沿原 `UnifiedSearchInputState`、`DaybookTextField` 和专用 field editor 编辑。原生状态只能消费同步接受返回的新缓冲；外部旧回调不能续租。`parameterText` 保存拼写与产生 stamp，只有匹配现有草稿字段时才用于重新挂载，不是可独立提交的 `CommandValue`。数字无效时发送缺值参数、保留原文与校验提示，不能留下旧合法值冒充本次输入；组合文本结束前不提交参数。
- 选择“在上方输入框填写”只切换当前字段上下文，补全从该字段 `CommandChoice`/布尔元数据派生，双语别名复用原 `CommandPathArguments`。接受更新同一字段；不重拼所有已填参数，也不重写通用查询解析器。普通短文本保留原文，不翻译、不解析为另一条命令。

#### 支持矩阵与预览

| 类型 | 本阶段原生输入与校验 |
|---|---|
| choice | DaybookPicker + 原 CommandChoice / 双语别名；选项来自目录 |
| boolean | 明确“开 / 关 / 尚未填写”，nil 与 false 分开 |
| number | 原生单行拼写缓冲，复用目录上下限、整数/小数及 finite 校验 |
| day | DaybookDatePicker、DayKey 民事日字符串与规范往返校验，不转业务 UTC 时间戳 |
| time | DaybookTimePicker / 原生 NSDatePicker，保留 0…1439 分钟与提醒操作语义 |
| weekdays | DaybookWeekdayPicker 的 allowsEmpty 编辑模式；空集合进入缺值校验，不补成每天 |
| shortText | 独立原生编辑器；空白/换行非法，正文原文保留 |
| longText、object/objects、tags、nativeFile、nativeShortcut | 只显示对应的后续编辑器/选择器/原生交互需求，不提供替代控件 |
| secureInput / authentication / freshAuthentication | 整个指令不给普通参数输入，说明独立安全交互要求；不认证、不降格 |

字段修改方式来自 `CommandParameter.operations`；未指定、赋值、清空、设置/取消提醒各自表达。静态合法仍不代表业务可执行。`CommandDraft.check` 负责参数和固定目标校验；未支持字段、缺必填与目标问题继续显示。

[OperationPanel](../AreaChain/Features/Search/UnifiedSearchOperationPanel.swift) 在主输入下方承载 [OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)；结果区仍由原 `UnifiedSearchResults` 独立负责。只挂一个补全层，预览展开仅增加区域内滚动，不移动主输入锚点。预览显示操作名、说明、状态、已填摘要、修改方式、拟修改值与校验；参数可收起恢复。候选优先使用上方可用空间缩小滚动高度，补全区域不拦截下方参数点击。

基线只来自 `CommandDraftBaseline` 显式注入：缺项显示“当前值尚未读取”，已知无值和 mixed 分别显示“当前无值”“多个不同值”；有合成基线时明确标记来源，再显示当前→拟修改值。目录默认值从不被当作真实设置。没有读取真实偏好、正文或业务库来填预览。

#### 键盘、保护与后续边界

候选活动时 ↑↓、Tab/Return 仍优先补全；参数 Return 只确认当前要素，⌘Return 只反馈“暂不可执行，参数仍保留”。组件没有执行闭包、偏好 setter、仓储保存、入计划入口或“已保存/已切换”反馈。Esc 先关候选/日期局部层，参数输入再回主输入；不丢草稿。展开不请求焦点，收起回对应控制。没有新增全局快捷键。

切换沿原 retain/discard/cancel；保留项在面板可见且可恢复，恢复推进原草稿版本。待决时继续编辑会让旧确认失效。切页、清查询和收起只改变查询或展示。运行内拼写可跟随保留的普通草稿恢复，放弃后清对应拼写引用。

面板通过 `ContentQueryReadSession.validateDisplayHost` 复用既有门禁；失焦/锁定同步清原生编辑器、marked text、独立撤销并卸载参数树，协调者中的普通草稿不删除。没有敏感草稿封存/解封、String 零化或系统快照清除承诺；此阶段隐藏 UI 不代表安全封存。QA 只用合成普通资料与既有 fake vault，不启用真实认证。

4A-3B 接入对象选择时必须显式固化类型化目标，通过原 `selectTargets` 与 stamp 校验，不能把结果高亮/浏览多选直接变成操作目标。待执行列表须通过原 HostSession/Plan 的唯一所有权转移、依赖与版本协议，不能把 retained 当作队列；未支持输入、安全保护与真实执行仍需各自后续授权、实现及验证。本轮不实施 4A-3B。

时间编辑补充：`DaybookTimePicker.eventVersion` 默认 nil；操作参数显式提供显示版本。外部字段修改令旧时分暂存失效，后续失焦 action 不得提交到新草稿版本；下一次真实鼠标/键盘输入才重新读取当前显示值。本次有效 time action 的回声单独识别，保留原生连续输入。该行为不修改提醒排程、通知或真实偏好。

#### 最终验证、实际缺口与停止点

产物在忽略目录 `build/UnifiedSearchOperationsQA/`。每次串行 xcodebuild 都使用 `com.areachain.unified-operations-qa`、独立 DerivedData、ad-hoc、原项目 entitlement、`-parallel-testing-enabled NO`，清除六个真实钥匙串 QA 授权变量并持有项目 `build/.build.lock`。每次精确命令见对应 `*-command.json`，运行日志、摘要与 xcresult 同目录。环境 Xcode 26.6 / Swift 6.3.3 / macOS 26.6.2 arm64；不代表最低 macOS 14 真机通过。

| 验证层 | 本轮最终证据 |
|---|---|
| 新普通参数与操作预览 | `DeliveryOperations.xcresult`：四套新增测试 **16 passed / 0 failed / 0 skipped**。包括目录接受/别名/旧候选、每种普通参数、必填/非法数字/闰日/时分边界、原文与组合文本、选区/撤销/重做、Tab/Return/⌘Return/Esc、切换/保留/恢复/旧确认、锁定/遮罩/真实窗口失焦、无设置/计划/执行写入及所有权转交后拒绝旧事件。最后补周一＋周三多选演示，`WeekdayCombination.xcresult` 对受影响单项再次通过，不累计数量。 |
| 目录/草稿/查询与原输入契约 | `DeliveryContracts.xcresult`：26 套、**177 passed / 0 failed / 0 skipped**；含参数化 218 次运行。涵盖 Catalog/Parameter/Path、Draft/Protection/Host/Handoff、Session/PrivacyReset/DisplayUpdates、旧文本/高亮/补全/浮层及输入持久化合成回归。 |
| 4A-1 / 4A-2 原生 | `LegacyInput.xcresult` 8 项、`LegacyResults.xcresult` 15 项通过；`InputSyntaxIsolated.xcresult` 原输入消费者 12 项通过；MenuBarSearchShortcutTests 在 `LegacyInputConsumers.xcresult` 的结果树单项 Passed。 |
| 共享 Picker / TimePicker 与既有消费者 | `PickerIsolated.xcresult` 5 项、`SharedTime.xcresult` 8 项通过；`SharedConsumers.xcresult` 10 passed、1 expected failure。既有 SettingsPickerConsumerTests 的 dark→system 环境仍深色问题由原 withKnownIssue 登记，未修复、未冒充通过。 |
| 合计口径 | 去除复验重复后 **253 个测试定义：252 passed、1 既有 expected failure、0 unexpected failed、0 skipped**；含参数化 **325 次执行**。测试成功退出不抹掉上项既有问题。 |
| 原生图片 | `screenshots/` **35 张**；16 组标准/紧凑 × en/zh-Hans × 浅深 × 正常/最小宽度（输入 420/280pt，宿主各加 24pt 边距），其余包含补全与预览同显、日期展开/收起、星期组合/时间、原文、非法数字、多参数折叠、未支持/安全参数、切换及遮罩/锁定。全部联系表已检查，并逐张放大核对最窄英文、中文安全需求、日期展开和最终星期/时间原图。最窄英文菜单长项使用原生省略与完整 tooltip；列表明细在固定区域滚动，不冒充全部明细同屏。 |
| 静态/脚本 | 相关 Swift 严格局部 SwiftLint、`check_workflow.py` 与 `git diff --check` 通过；工作流定向 **78 项**、全脚本 **198 项**通过。最终 `quality_gate.py --profile static --format json` passed。auto/swift profile 会启动非本轮独立 QA 标识的整套宿主，依本次隔离要求未运行；以以上显式隔离 Swift 检查补充，不能写成完整 Swift profile 通过。 |
| Debug 构建 | 最后应用源码修改后的 `./scripts/build.sh` passed，`build-final.log` 的 `staticSignatureVerified: true`。只构建/静态验签，没有安装、启动生产应用或发行。 |

失败与修正保留原日志：首轮测试宏/可选值编译问题；上方避让漏算间隔；测试宿主误选参数文本框；原生菜单辅助框含标签导致未点中菜单，改用既有 formRow；数字撤销场景采用已填草稿作为初始值，验证单次选区替换的 undo/redo；时间字段旧暂存跨版本补交由事件版本阻止。旧目录测试原先扫描整篇文档，误计后续交接的 D1–D3，现只核对权威第 8 节，48 项断言未放宽；旧控件展示增长后按钮位于屏外，时间展示测试先实际滚动再点击，未跳过焦点/几何断言。两次旧消费者运行被前台 Codex 夺去焦点，按单套件重新运行通过，历史失败不删除。

`source-final-before.json` / `source-final-after.json` 和资源值摘要只核对本轮相关源码与文案；后续仅增强一个星期组合测试并单项重跑，其最终指纹单独记录，不把并行整树视为冻结。调用链不引用 AppPreferences setter、ModelChanges 或执行器；无真实执行测试同时核对 QA 偏好不变、plan 为空、execution 为 nil 和打开记录为空。

指定 **Cursor verifier 未执行**；VoiceOver 真人朗读、系统中文输入法候选窗、系统减弱动态开关切换、最低系统与真实用户多窗口使用未验。组合输入证据来自 NSTextInputClient 的真实 setMarkedText/insertText 协议，不等于系统输入法候选窗人工验收。敏感草稿封存/失败保护、生产入口和真实指令执行仍未实现。上述缺口及既有外观预期失败保留，不能宣布阶段完整验收。

本轮到 **4A-3A 停止**。不提交、不推送、不安装、不发布、不启动生产应用，不进入对象选择或待执行列表阶段。

#### 本轮文件清单

- 控制器与操作： [UnifiedSearchController.swift](../AreaChain/Features/Search/UnifiedSearchController.swift)、[UnifiedSearchOperationEditing.swift](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift)、[UnifiedSearchOperationCopy.swift](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift)、[UnifiedSearchOperationPanel.swift](../AreaChain/Features/Search/UnifiedSearchOperationPanel.swift)、[UnifiedSearchOperationPreview.swift](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[UnifiedSearchParameterField.swift](../AreaChain/Features/Search/UnifiedSearchParameterField.swift)、[UnifiedSearchParameterText.swift](../AreaChain/Features/Search/UnifiedSearchParameterText.swift)。
- 输入与共享控件：[UnifiedSearchInput.swift](../AreaChain/Theme/UnifiedSearchInput.swift)、[UnifiedSearchInputState.swift](../AreaChain/Theme/UnifiedSearchInputState.swift)、[UnifiedSearchOverlay.swift](../AreaChain/Theme/UnifiedSearchOverlay.swift)、[UnifiedSearchParameterContext.swift](../AreaChain/Theme/UnifiedSearchParameterContext.swift)、[DaybookPicker.swift](../AreaChain/Theme/DaybookPicker.swift)、[DaybookTimePicker.swift](../AreaChain/Theme/DaybookTimePicker.swift)、[DaybookNativeTimePicker.swift](../AreaChain/Theme/DaybookNativeTimePicker.swift)。
- 门禁与文案：[ContentQueryReadSession.swift](../AreaChain/Services/ContentQueryReadSession.swift)、[Localizable.xcstrings](../AreaChain/Resources/Localizable.xcstrings)。
- 新增隔离测试：[ContractTests](../AreaChainTests/Features/UnifiedSearchOperationContractTests.swift)、[InteractionTests](../AreaChainTests/Features/UnifiedSearchOperationInteractionTests.swift)、[LifecycleTests](../AreaChainTests/Features/UnifiedSearchOperationLifecycleTests.swift)、[PresentationTests](../AreaChainTests/Features/UnifiedSearchOperationPresentationTests.swift)、[TestSupport](../AreaChainTests/Features/UnifiedSearchOperationTestSupport.swift)；增量维护原 [UnifiedSearchTestHost](../AreaChainTests/Theme/UnifiedSearchTestHost.swift)、[CommandCatalogTests](../AreaChainTests/Domain/CommandCatalogTests.swift)、[DaybookTimePickerLifecycleTests](../AreaChainTests/Theme/DaybookTimePickerLifecycleTests.swift)。
- 文档和入口守卫：本文、[组件目录](component-catalog.md)、[架构](architecture.md)、[技能路由](../skill-routing.md)、[check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py)。已有并行改动保留；没有改动指令目录定义、领域草稿 reducer、生产入口或业务保存路径。

### 9.48 阶段 4A-3B1：对象参数选择与操作固定目标的原生接线

2026-10-03。本阶段只在标准/紧凑隔离宿主、普通合成资料上更新运行内草稿；没有真实指令、仓储写入、待执行列表、长正文、标签集合或原生文件选择。保留已有并行修改、指定 Cursor verifier 缺口、§9.47 的外观预期失败和人工验收缺口；整体仍为 **partial**，不因本轮自动化结果关闭历史阶段。

#### 权威状态与候选来源

- [UnifiedSearchController / ObjectSelection 扩展](../AreaChain/Features/Search/UnifiedSearchObjectSelection.swift) 复用原 OperationEditing.sendOperation，发送 `CommandHandoffCoordinator.send(.operation(...), expecting: 原 lease)`。操作对象经原 `selectTargets` 写入 `CommandDraft.targets`；新建子任务 parent 等普通 `.object/.objects` 经 `.edit` 写入同一草稿的 `arguments`。两类值互不代写；没有新的对象身份或可提交目标数组。
- `UnifiedSearchObjectSelection` 只在选择器打开期间持有独立的 `ContentQueryBrowseState`，用于活动行、临时多选及加载进度；它没有提交能力，取消释放引用，不改变原固定目标。重新选择从空的临时选择开始，界面明确要求接受后才替换。原全局 Browse 及查询状态不被覆盖。
- 候选读取沿原注入 read 闭包、`ContentQueryReadSession.prepare/evaluate/publish/presentation`。本轮不另加名称搜索框，直接使用外层完整查询的当前确定命中；要改查询先取消选择再编辑公共输入，草稿保留。选择器不会把操作路径写入查询，不在 View 中做名称匹配，不从实体补标题或跨批 UUID 补明细。
- [ContentQueryReadSession.objectCandidate](../AreaChain/Services/ContentQueryObjectCandidates.swift) 同时核验当前许可、sourceID、known 成员、完整 CommandObjectReference 与同批活提供者种类。身份仍是 type＋UUID，执行记录另含 dayKey；子任务保留自身身份和同批 parentTask 定位。未知、review 和非命中上下文不进入 known；墓碑即使 type 相同也不能伪装成活操作对象。

| 输入/来源 | 本阶段支持与限制 |
|---|---|
| 操作 targets | 任务、子任务、习惯定义、指定日执行记录的安全活命中；单个、明确多个及显式全部已知命中。数量遵守 CommandDescriptor.batch，类型遵守 targetTypes。 |
| 普通 object | 当前目录的 subtask.create / subtask.order 的 parent 使用任务候选；其他参数也从其类型声明校验，不写 targets。 |
| 普通 objects | 同一选择→CommandValue.objects→原 edit 路径；当前目录没有非 target 的 objects 字段，合成描述符覆盖数组编码，不宣称存在生产目录消费者。 |
| 未适配来源 | 手记（包括公开手记）、图片、标签对象、剪贴板条目、墓碑、窗口、草稿/计划项等均在此不可用。其他类型的安全搜索结果仍可正常显示，选择器会说明来源/类型限制；全局搜索能力不变。 |
| 后续输入 | 未来步骤输出引用、tags 集合、longText、nativeFile/nativeShortcut、私密对象授权均未接线。普通参数原有的 choice/boolean/number/day/time/weekdays/shortText 继续走 §9.47。未填的范围外参数不冒充完整操作，所有操作仍不可执行。 |

#### 版本、固定集合与基线

`UnifiedSearchObjectSelectionStamp` 绑定选择器会话 ID、原 UnifiedSearchBuffer（原 lease、显示版本、草稿 ID/版本）、目标/参数位置和候选可见版本。确认重新经过 ReadSession 与协调者资格校验；任意旧来源、旧可见性、旧草稿、取消重开或转交后的事件被拒绝，不用当前 lease 替换旧事件。异步读取另有请求身份，取消后的迟到结果不能复活选择器。

“选择已展示命中”调用原 Browse.selectVisible；“选择全部已知命中”调用 selectAllKnown，只包括当前已读出的确定命中，不能称全部数据。未适配或不符合目录类型的成员仍留在临时选择并明确报错，用户主动移除或改选；不静默筛成可用子集。加载更多经原 Pagination，推进候选版本且保留已选身份，旧确认拒绝；接受后 targets 固定具体集合，后续读取、排序及查询不会扩选。

选择不是完整基线读取。原 `selectTargets` 增加可选 baseline 证据，仍只由原 reducer 调用 `CommandDraft.select`；具体目标集合变化而没有新证据时清除旧 baseline，arguments 不丢失。隔离宿主可显式注入 `syntheticBaselines`，按对象/字段索引派生原值；缺项、absent 和 mixed 分别显示“当前值尚未读取”“当前无值”“多个不同值”。不把安全摘要当正文或字段原值。更换目标不沿用上一对象的基线。

接受或已固定对象草稿的参数编辑后，新草稿 lease 使旧读取许可失效，预览先标记待核验，再经原读取链获取当前安全明细；不保留另一份标题/正文缓存。对象删除、离开当前可确认命中或新门禁不足时，保留原固定身份并显示“需要重新核验”，不替换为同名对象。该状态不是最终存活/权限结论，真实执行前仍需独立核验。

#### 原生交互、预览与生命周期

- [UnifiedSearchObjectField](../AreaChain/Features/Search/UnifiedSearchObjectField.swift) 在 ParameterField 的对象分支提供计数、展开列表、单项移除及重新选择；[UnifiedSearchObjectPicker](../AreaChain/Features/Search/UnifiedSearchObjectPicker.swift) 在原 OperationPanel 内切换选择模式，候选独立滚动、确认/取消保持可达。两者共用 [UnifiedSearchResultRow](../AreaChain/Features/Search/UnifiedSearchResultRow.swift) 的安全标题、类型、关系和必要日期，不复制完整正文。限制原因与未接线执行说明显式可见。
- 公共输入在选择模式暂停路径补全，但补全仍唯一挂载；↑↓ 复用 Browse 移动、空格切换临时选择、Return/Tab 接受临时选择（没有已选项时接受活动行）。⌘Return 仍只有 submitBlocked 提示。Esc/取消退出选择器，返回发起控件；展开不主动请求输入焦点。选择模式内输入不覆盖外层查询或草稿，取消后继续原输入。
- 普通结果面板在选择模式暂撤显示，结束后仍沿原 ReadSession 显示；切页、清查询、面板收起不改变已固定 targets。只有明确重新选择或移除发送新的草稿事件。
- 锁定、窗口失焦与既有门禁失效清临时候选引用、原生字段/候选显示，原 OperationBoundary 同步卸载目标明细。协调者的 `ownershipRevision` 在两端转交完成后才通知现有 ReadSession Observation 链，旧宿主立即撤显示并拒绝旧回调。没有直接删除普通操作草稿；敏感草稿封存仍未完成，遮罩不是加密或内存零化。

#### 4A-3B2 应复用的接口与停止边界

后续计划 UI 复用 `UnifiedSearchObjectLocation / SelectionStamp` 的编辑位置与事件绑定、`beginObjectSelection / browseObjects / acceptObjects / removeObject`、`ContentQueryReadSession.objectCandidate` 的安全行入口，以及原 `CommandDraftTargets / Baseline / Stamp / Session`。真正入计划须走原 HostSession.enqueue 与 CommandPlan 的所有权转移、版本和依赖协议，不能复制 targets、把 retained 当队列或沿用选择器临时 Browse 作为业务真值。未来输出引用 UI、未适配对象来源、敏感草稿保护及最终执行前核验仍需后续实施。

#### 本轮验证记录

产物统一在忽略目录 `build/UnifiedSearchTargetsQA/`；精确 xcodebuild 命令随各次运行保存。独立 `com.areachain.unified-targets-qa`、独立 DerivedData、ad-hoc、原 entitlement、串行测试并持有原 build/.build.lock；清除六个真实钥匙串授权变量。只用合成快照与 fake vault，没有生产应用启动或真实指令。

初轮 Contracts 编译发现测试误用 plan.steps（正确字段为 items），修正后重跑。Targets.xcresult 为 14 passed / 2 failed：确认与取消落在长参数区屏外，辅助树找不到对应控件；保留失败记录，调整为原面板内独立选择布局后重验，未删除事件、焦点或几何断言。LayoutRetest 的截图进一步证明按钮可见，但父级辅助标识传播覆盖子按钮；增加显式 accessibility container 后恢复独立按钮标识。焦点失败先纠正 BOOL getter 的读取方式，再补发起按钮 focusable；实际空格激活仍失败，最终沿公共 Toggle 的按下/释放模式处理，保留按下时的原事件闭包。KeyboardRemoval.xcresult 的五项原生交互全部通过，包括辅助焦点、空格重新打开、Tab 到移除按钮并释放空格移除。两个单方法过滤尝试实际为 0 用例，不作为通过证据。最终组合结果见下表。

| 验证层 | 本轮证据与范围 |
|---|---|
| 主组合回归 | `Final.xcresult`：42 套、243 个测试定义，**242 passed / 1 既有 expected failure / 0 unexpected failed / 0 skipped**；参数化合计 295 次运行。包含 4A-1（11 项）、4A-2（15 项）、4A-3A（16 项），以及草稿/转交/Plan、目录/参数、Browse/Display/Pagination、ReadSession、记录提供者、旧 UnifiedSearch/InputSyntax/MenuBar 搜索入口。 |
| 最后界面修正 | 图片检查发现 ObjectField 未直接观察读取修订，控制器已可读而原生标题仍停留在待核验分支；补 `controller.revision` 依赖及“4 个原生安全标题均更新”断言。`PreviewRefresh.xcresult`：四套对象测试与 4A-3A 展示 **24 passed / 0 failed / 0 skipped**。其源码前后指纹一致。 |
| 加载态收尾 | 加载候选时 Return/Tab/方向意图不重新开始草稿，Esc 仍取消，⌘Return 仍受执行边界阻止。`Loading.xcresult`：对象契约/生命周期/原生交互与公共输入契约/输入 **26 passed / 0 failed / 0 skipped**。其中新增一项加载态测试；与主组合去重后共 244 个定义（243 passed、1 既有 expected failure）。此后没有应用源码修改。 |
| 原生截图 | 最后展示修正后生成 `screenshots/` **41 张原图**：标准/紧凑 × en/zh-Hans × 浅深 × 正常/最小宽度的选择与固定预览共 32 张，另含键盘临选/确认、parent、子任务父定位、两天执行记录、混合原值、移除保参、锁定和失焦。已检查全部六张联系表，放大核对最窄英文深色与混合原值原图。窄宿主限制说明和候选独立滚动，确认/取消可达；多对象明细在原面板内滚动，不宣称全列表同屏。后续加载态保护不改变这些布局，原生交互在 Loading 中再验。 |
| 构建与本地门禁 | 最后应用源码的 `./scripts/build.sh` 通过，`build-delivery.log` 的 staticSignatureVerified 为 true、distributionReady 为 false。相关 Swift 严格局部 lint、工作流与静态质量门禁通过；最终工作流定向 81 项、全脚本 201 项通过。精确结果以 `final-lint.log`、`final-workflow.log`、`final-static-gate.json` 为准。auto/swift profile 会启动本轮隔离标识之外的整套宿主，依隔离约束未运行，以以上显式 QA 定向补充，不声称完整 Swift profile 通过。 |
| 证据边界 | Final 与 PreviewRefresh 的相关源码前后指纹一致；加载态收尾另存当前源码指纹。仓库并行修改持续存在，没有把整棵工作树当作冻结版本。原生事件来自可见隔离 NSWindow 的 AppKit/SwiftUI 事件派发，截图不是事件身份或真实业务验证的替代。 |

所有历史失败原包保留。§9.47 的 SettingsPickerConsumerTests dark→system 外观问题在主组合仍为 expected failure，没有修复或抹除；本阶段没有更改该偏好/主题路径。没有安装、真实系统认证、业务执行或发布。

指定 Cursor verifier 当前无可调用入口，未重新认证，也不以其他代理替代。真人 VoiceOver、系统中文输入法候选窗、系统减弱动态开关切换、最低 macOS 和真实用户多窗口均仍未验。§9.47 SettingsPickerConsumerTests dark→system 的历史外观预期失败保留，本阶段不修改该偏好/外观路径。

本轮停止于 **4A-3B1**；不提交、不推送、不安装、不发布、不启动生产应用、不执行真实指令，也不进入 4A-3B2。

#### 本轮修改文件与核心接口

| 层 | 文件与接口 |
|---|---|
| 权威草稿 | [CommandDraft.swift](../AreaChain/Domain/CommandDraft.swift) 的 select 基线失效；[CommandDraftSession.swift](../AreaChain/Domain/CommandDraftSession.swift) 的 selectTargets 可选基线；[CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift) 的 ownershipRevision。 |
| 候选门禁 | [ContentQueryObjectCandidates.swift](../AreaChain/Services/ContentQueryObjectCandidates.swift) 的 objectCandidate；[ContentQueryReadSession.swift](../AreaChain/Services/ContentQueryReadSession.swift) 的所有权观察。 |
| 选择接线 | [UnifiedSearchObjectSelection.swift](../AreaChain/Features/Search/UnifiedSearchObjectSelection.swift) 的 SelectionStamp / beginObjectSelection / browseObjects / acceptObjects / loadObjectCandidates / removeObject；[ObjectField](../AreaChain/Features/Search/UnifiedSearchObjectField.swift)、[ObjectPicker](../AreaChain/Features/Search/UnifiedSearchObjectPicker.swift)。 |
| 原组合入口 | [Controller](../AreaChain/Features/Search/UnifiedSearchController.swift)、[OperationEditing](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift)、[OperationPanel](../AreaChain/Features/Search/UnifiedSearchOperationPanel.swift)、[OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[ParameterField](../AreaChain/Features/Search/UnifiedSearchParameterField.swift)、[OperationCopy](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift)、[ResultRow](../AreaChain/Features/Search/UnifiedSearchResultRow.swift)、[Results](../AreaChain/Features/Search/UnifiedSearchResults.swift)。 |
| 原生输入 | [UnifiedSearchInput](../AreaChain/Theme/UnifiedSearchInput.swift)、[InputState](../AreaChain/Theme/UnifiedSearchInputState.swift)、[NativeInput](../AreaChain/Theme/UnifiedSearchNativeInput.swift) 的选择模式、Tab/Return/空格与唯一补全；[Localizable.xcstrings](../AreaChain/Resources/Localizable.xcstrings) 的 en/zh-Hans 文案。 |
| 隔离测试 | [ObjectTestSupport](../AreaChainTests/Features/UnifiedSearchObjectTestSupport.swift)、[ObjectContractTests](../AreaChainTests/Features/UnifiedSearchObjectContractTests.swift)、[ObjectLifecycleTests](../AreaChainTests/Features/UnifiedSearchObjectLifecycleTests.swift)、[ObjectInteractionTests](../AreaChainTests/Features/UnifiedSearchObjectInteractionTests.swift)、[ObjectPresentationTests](../AreaChainTests/Features/UnifiedSearchObjectPresentationTests.swift)。 |
| 文档与守卫 | 本文、[组件目录](component-catalog.md)、[架构](architecture.md)、[技能路由](../skill-routing.md)、[check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py)。 |

### 9.49 阶段 4A-3B2：待执行计划与就地编辑

2026-10-03。本阶段仅在标准/紧凑隔离宿主、普通合成资料中更新运行内 CommandPlan。原工作区已有 4A-3A/3B1、Domain、Theme 和文档等并行修改；接续已有 plan/item stamp 草稿改动并保留全部并行差异。没有替换生产入口、提交、推送、安装、生产应用启动或真实指令。指定 Cursor verifier 不可调用，未重复登录检查、未改认证、未以其他代理冒充，阶段整体保持 **partial**。

#### 唯一计划与原生组合

| 入口 | 本轮责任 |
|---|---|
| [UnifiedSearchPlanEditing](../AreaChain/Features/Search/UnifiedSearchPlanEditing.swift) | Controller.plan 从协调者派生原 HostSession.plan；editingPlanItem / editingDraft 只选择当前编辑位置，没有待执行镜像数组。enqueue / sendPlan / removePlanItem 全部发送原 CommandHostEvent。 |
| [UnifiedSearchPlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift) | 原 OperationPreview 的固定滚动区内显示计划；单次计算整图检查、稳定项身份、名称/目标计数/安全核验提醒/紧凑参数/缺参及依赖诊断、编辑/移出/上移/下移/合并入口。 |
| [UnifiedSearchPlanButton](../AreaChain/Features/Search/UnifiedSearchPlanButton.swift) | 沿已有对象按钮的按下/释放约定，保留按下时的原回调；键盘焦点和回到编辑按钮仅为展示状态。 |
| [OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[OperationCopy](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift)、[ParameterField](../AreaChain/Features/Search/UnifiedSearchParameterField.swift) | 活动草稿、retained 保留草稿和待执行列表分别命名。参数摘要共用格式化；计划内直接复用普通参数和对象字段。失败/入列/移出提示固定在面板上方，长列表不遮住反馈。 |
| [PlanLinks](../AreaChain/Features/Search/UnifiedSearchPlanLinks.swift)、[PlanDependencies](../AreaChain/Features/Search/UnifiedSearchPlanDependencies.swift)、[PlanCopy](../AreaChain/Features/Search/UnifiedSearchPlanCopy.swift) | 声明输出候选、依赖展示/解除/刷新和类型化诊断；不创建表达式编辑器，不输出原始错误、正文或私密元数据。 |

列表默认紧凑，只有选中的计划项展开字段，长列表在原 450pt QA 面板内滚动，不推开输入框；标准/紧凑使用同一实现。对象选择仍切换原 OperationPanel 的内容，补全仍只有原 unifiedSearchOverlayHost；计划不是另一层补全或独立浮窗。没有新增生产宿主。

#### 所有权、编辑位置与版本

- 明确“加入待执行列表”捕获原 lease、draft stamp 和 plan stamp，经协调者 `.enqueue` 调用 HostSession.enqueue。成功后 active/retained 移出、计划唯一持有同一 draft ID；失败保留原草稿。重复点击、旧显示版本、旧计划或旧草稿事件不能重入。资格直接由 CommandPlan.add 检查，导航、退出、安全及排除操作没有开放。
- 未完成计划项可以入列，CommandPlanCheck 的缺参、目标、结构问题照常展示；没有将其视为可提交。参数原文/无效拼写仍只由原 parameterText 保存显示接续信息，不具有独立提交能力。
- UnifiedSearchBuffer 增加可选 plan / planItem；原 lease、display version、privacy revision、draft ID/version 继续保留。OperationEditing / ObjectSelection 共用 editingDraft，并由 sendPlanDraft 将原 edit / selectTargets 翻译为原计划事件。没有把计划草稿复制到 operations.active。
- beginEditing / edit / selectTargets / endEditing 直接作用于原计划项；切换先同步结束旧项再开始原先指定的新项。旧控件/参数补全/对象选择票据在切换、计划修订或转交后拒绝，不能补发当前 lease。原 SelectionStamp 自动包含完整 buffer，候选确认仍经 ReadSession.objectCandidate。
- `cancelKeepingChanges` 对应“收起 · 保留修改”，不声称撤销。真正回退编辑仍是后续能力，没有创建第二份可提交副本。计划内对象更换不把候选摘要当完整 baseline；原领域 select 使旧基线失效，普通参数继续保留。
- 移出调用 removeFromPlan，退回 retained 并推进草稿版本；依赖者、正在编辑和原子组的领域拒绝原样保留。恢复 retained 改为显式 draft stamp，避免多个同命令草稿总恢复第一项；命令浏览的继续入口仍按原协议。

#### 顺序、合并、依赖与输出

- 上移/下移发送 reorder；不合法逆序或组结构保持原顺序并显示原因，没有拖放专用通道或自动解依赖。
- 合并按钮只请求 CommandPlanSemantics.mergeConflict 对相邻项的既有判断。提议只保存 source/earlier/later stamp，在原列表展示最终字段和值；明确“接受合并”才发送 merge。未知基线、顺序语义、目标不一致、不同业务字段、依赖和原子组继续保留各项。没有在 View 复制等价判断，也不覆盖追加正文或部分重叠目标。
- 显示显式前置名称和结果参数、前置操作及输出类型；缺失、过期、逆序和无效类型沿领域诊断。显式前置可以逐项解除，本阶段未增加任意前置选择或工作流图。
- 创建引用只列当前计划里排在前面的真实项，且必须有目录 createdObjectType 并通过原 CommandPlanValidation.acceptsReference。该函数仅从 private 调整为模块内复用，算法未改。当前目录唯一声明是 `todo.create → todo`，可接 subtask 的 parent、兼容操作的 target 等已声明 object/objects 参数；不生成尚未存在的业务 UUID。
- 引用与直接值互斥；已绑定字段显示说明，须先明确解除引用再填直接值。生产者修改后的旧引用可重新选择生产者逐项刷新，沿原 CommandPlan.link 的既有修复门禁，不放宽整图校验。没有新增其他输出类型。
- 可呈现合成原子组及诊断，不能在 UI 创建“所有设置保证一起成功”选项；未接真实设置事务。

#### 不执行与保护边界

所有目录指令仍 unwired。⌘Return/提交意图仅说明暂不可执行；计划形状与依赖有效不代表最新存活、权限、冲突或业务检查完成。UI 不调用 sealPlanForProtocol / beginNextProtocolStep，不生成成功回执、不清空计划、不显示已保存。

清查询、切页、收起、失焦与锁定不删除 operations/plan；失焦/锁定沿原 ReadSession 和 OperationBoundary 撤原生字段与计划明细。转交后旧所有权事件失效。这里仅用普通合成目标和内容，敏感草稿封存仍未实现，隐藏面板不是安全封存。

#### 原生验证与剩余项

产物在忽略目录 `build/UnifiedSearchPlanQA/`，每次实际 xcodebuild 参数保存为 `*-command.json`。独立 `com.areachain.unified-plan-qa`、独立 DerivedData、ad-hoc、原 entitlement、清除六项真实钥匙串授权变量并持有原 build/.build.lock，测试串行。没有安装、生产启动或真实业务运行。

新增 [PlanContractTests](../AreaChainTests/Features/UnifiedSearchPlanContractTests.swift)、[PlanDependencyTests](../AreaChainTests/Features/UnifiedSearchPlanDependencyTests.swift)、[PlanLifecycleTests](../AreaChainTests/Features/UnifiedSearchPlanLifecycleTests.swift)、[PlanInteractionTests](../AreaChainTests/Features/UnifiedSearchPlanInteractionTests.swift)、[PlanPresentationTests](../AreaChainTests/Features/UnifiedSearchPlanPresentationTests.swift)，夹具复用 [ResultsFixture](../AreaChainTests/Features/UnifiedSearchResultsTestSupport.swift) / [ObjectTestSupport](../AreaChainTests/Features/UnifiedSearchObjectTestSupport.swift) / [TestHost](../AreaChainTests/Theme/UnifiedSearchTestHost.swift)，最小计划辅助放在 [PlanTestSupport](../AreaChainTests/Features/UnifiedSearchPlanTestSupport.swift)。

首轮 Contracts 编译发现 Observable 控制器的初始化顺序问题，修正为先构造局部 initial buffer；Native.xcresult **15 passed / 0 failed / 0 skipped**。随后图片检查推动固定反馈、空摘要紧凑化、整图检查复用和按钮空格接续补强，并增加同命令 retained 恢复与键盘重排测试；Keyboard 编译发现测试宏内缺少显式 try，已修正。工作流反例曾因合成目录缺少三个新符号失败，补齐夹具后 83 项定向、203 项脚本回归通过。历史失败日志均保留，Native 结果不能替代补强后的最终验证。

| 检查 | 实际结果与边界 |
|---|---|
| 最终领域与计划接线 | `Domain.xcresult`：**119 passed / 0 failed / 0 skipped**，包含全部 Command 领域测试及本轮 PlanContract / PlanDependency；最终增加计划 parent 候选确认与 target 创建输出引用反例。没有执行真实 handler。 |
| 44 套组合回归 | `Regression.xcresult`：246 个测试定义，**185 passed / 61 failed / 0 skipped**（含参数化 220 passed / 70 failed）。全部失败停在 NativeSyntaxUI.prepareFocus：`active=false, key=false, foreground=com.apple.loginwindow`。这些失败没有进入各自交互，不能据此判定产品回归通过；已保留原包、摘要与前后相同源码指纹，未删或跳过焦点断言。已请求用户回到可用桌面，最终原生重验仍待完成。 |
| 首轮原生证据 | `Native.xcresult` 的 15 项包含可见隔离 NSWindow 中的补全→入列→原生标题/对象编辑→收起→移除恢复、合并确认、引用选择、锁定与提交保护。`screenshots/` 的 **38 张原图、5 张联系表已实际查看**，含标准/紧凑×en/zh-Hans×浅深×正常/最小宽度的列表与展开 32 张。后续按钮/固定反馈修改使对应最终截图和键盘证据仍缺失，不能沿用首轮图宣称最终验收。 |
| Debug 与静态验签 | 最终应用源码 `./scripts/build.sh` **passed**；`build-delivery.log`：`staticSignatureVerified: true`、`distributionReady: false`。只构建与验签，没有安装、启动生产应用或发布。 |
| 静态门禁与脚本 | 最终相关 Swift 严格局部 lint 无输出/通过；工作流检查、静态质量门禁、`git diff --check` 通过。工作流定向 **83**、脚本回归 **203** 项通过。auto/swift profile 会启动非本轮独立标识的整套宿主，依隔离约束未运行；以上显式 QA 定向不冒充完整 Swift profile。 |
| 指定复核与历史外观 | Cursor verifier **不可调用/未执行**，没有重新登录或替代复核。SettingsPickerConsumerTests dark→system 历史外观预期失败继续保留；本轮组合在焦点准备即失败，未触达该外观断言，不能写成已重验通过或归因已解决。 |

最终本轮共 19 项新测试定义：11 项无窗口计划接线随 Domain 通过，8 项原生测试仍须在最终界面代码上复验。领域验证时指纹在 `source-final.json`，交付指纹在 `source-delivery.json`；其间仅 OperationPreview 给 retained 恢复按钮增加共用参数摘要，区分同命令的不同草稿，没有改状态或事件。该显示收尾重新通过构建和严格局部 lint，仍待原生截图重验。结果摘要在对应 `*-summary.json`；并行工作树未冻结。前述首次已通过的链路与最终未完成验收分别记录，不合并成一个通过数字。

VoiceOver 真人、系统输入法候选窗、系统减弱动态开关、最低 macOS 和真实用户多窗口未验。§9.47 / §9.48 的 SettingsPickerConsumerTests dark→system 历史外观预期失败不关闭；本轮仅展示合成计划设置意图，没有改偏好应用或系统外观切换路径。

#### 最终原生重验接续（2026-10-03，Asia/Shanghai）

本次仅重验与交接，**原生重验 blocked，阶段仍 partial**。工作区已有 15 个已跟踪修改文件和 12 个未跟踪文件全部保留；本次没有修改 Swift、测试、资源或其他并行实现，仅追加本节记录。逐文件 SHA-256 核对 `source-delivery.json` 的 44 个源码/测试/资源文件，当前全部一致，记录为 `build/UnifiedSearchPlanQA/source-native-recheck.json`。已读取 Domain / Native / Regression 的原结果摘要，确认分别为 119/0/0、15/0/0、185/61/0（passed/failed/skipped）；这些仍是历史结果，不计为本轮重验。

一次只读桌面预检（2026-10-03T10:04:44Z）返回 `foregroundBundleID=com.openai.codex`、`sessionOnConsole=true`、`sessionLoginDone=true`；锁屏字段未提供，不能据此断言 QA 已获得焦点。未发现正在运行的 xcodebuild/xctest。随后按原 QA 参数准备先执行现有 `UnifiedSearchPlanInteractionTests/keyboardReorderAndDependentRejectionKeepOriginalOrder()`，但对原 `build/.build.lock` 的非阻塞独占申请返回 `BlockingIOError: [Errno 35] Resource temporarily unavailable`。只读 lsof 未返回持有者，锁文件为空，故锁占用来源未确认；没有将其归因于 loginwindow、产品或测试预期。

测试在申请锁处停止，**未启动 xcodebuild、QA 应用或任何 XCTest**。`FocusRecheck-command.json` 仅保存拟执行参数，不是执行证据；没有产生 FocusRecheck.xcresult 或测试日志。没有删除/重建/解锁原锁文件，没有终止其他任务或关闭用户应用，也没有解锁系统、输入凭据或更改安全设置。无法确认独占测试条件，因此不启动组合回归、不重复焦点失败。

| 最终交接项 | 本次状态 |
|---|---|
| 最终原生结果 | 未运行。计划键盘、入列/移除/重排/合并/依赖、参数/对象接续、标准/紧凑布局及相关旧输入消费者均待补；不排除必需用例，不放松焦点或输入法断言。 |
| 最终截图 | 本次新增与实际检查均为 0 张；最终代码的语言、主题、宽度、关键状态均未取得新视觉证据。首轮 en/zh-Hans、浅深色、标准/紧凑、正常/最小宽度的 38 张只保留历史身份。 |
| 实际修复 | 无。仅更新本文 §9.49；未获得产品问题证据，不改变代码或主题规则。 |
| 环境恢复条件 | 当前前台已不是 loginwindow，但独占测试锁不可得，QA 焦点尚未验证。需其他构建/验收任务正常结束并释放锁，保留已登录、可交互桌面，测试期间不切换窗口或操作键鼠；锁来源不明时先定位，不绕过锁。 |
| 剩余缺口 | Cursor 指定 verifier 不可调用/未执行，未重复登录检查或替代复核；VoiceOver 真人、系统输入法候选窗、系统减弱动态开关、最低 macOS、真实多窗口仍未验。旧 dark→system 外观预期失败继续保留，本次未触达该断言。 |
| 下一阶段依据 | 尚不具备最终原生验收完成的本地依据；不进入下一阶段或长正文阶段。既有领域/构建证据不替代本次缺失的原生与指定复核证据。 |

本次文档验证：`python3 -B scripts/check_workflow.py`、`git diff --check`、`python3 -B scripts/quality_gate.py --profile static --format json` 均 passed；静态入口按现有工作区差异同时运行的 203 项隔离脚本回归通过。未运行 Swift 构建或原生测试。检查期间另有并行的 `DaybookScrollContractTests.swift` / `DaybookScrollNativeTests.swift` 差异出现，未修改或纳入本阶段实现；工作区并非冻结快照，续验前须重新核对相关源码与测试范围。

长正文、标签集合、nativeFile/nativeShortcut、未适配对象来源、敏感草稿封存、真正撤销计划编辑、更多创建输出与 handler 接线仍是后续项。本轮到 **4A-3B2 停止**，不进入执行接线阶段。

### 9.50 阶段 4A-3C0：长正文与敏感操作草稿的只读核验及接线方案

2026-10-03（Asia/Shanghai）。本阶段仅阅读当前工作树并更新本文，**没有实施长正文或封存，没有修改产品 Swift/测试/资源，没有申请测试锁或启动 XCTest**。§9.49 的 Errno 35 独占锁阻塞、最终原生重验未启动、指定 Cursor verifier 不可调用、人工和历史验收缺口全部保留。本次授权允许继续只读设计，不改变前阶段 partial 状态；本文以下拟议类型、方法和阶段均不是已实现能力或实施授权。

已读取 AGENTS、技能路由、组件目录、项目架构/质量门禁，按 areachain-workflow、areachain-ui、areachain-verify 及通用架构/可靠性规范组织。UI/UX 的 SwiftUI 聚焦检索支持 Binding 和稳定视图身份；其 iOS 的“避免手工 first responder”建议不替代本项目 AppKit 焦点契约。两项并行只读探索分别核验隐私/封存和命令所有权，主代理沿源码抽查；它们不是指定 Cursor verifier，未重复登录检查。原有 4A-3B2、滚动测试、规则与文档等并行修改全部保留，仅在本文追加交接，不另建方案或修改路由/组件实现。

#### 推荐结论与最小影响/复用表

**不能把现有 DiaryEditorSession 整体搬入搜索，也不能在 CommandDraft.arguments 外罩一层隐藏视图便开放敏感编辑。** 推荐先在原标准/紧凑 QA 宿主用合成普通正文完成原生接线；真实自由正文、敏感计划及转交，须先完成下述独立授权的保护契约。优先验证“每个已接受的内容修订已有同版本密文恢复点”，让真正锁定只撤销访问并释放明文引用，避免把第一次可能失败的加密留到密钥清除之前。若不能覆盖 marked text（输入法组合文本）等全部入口，该路径保持关闭，不用较旧密文冒充保住最新稿。

| 需求 | 已有入口与实际消费者 | 推荐复用/扩展及必须保持的边界 |
|---|---|---|
| 下方多行正文 | DaybookTextEditor；DiaryWindowView、DiaryCardComponents、DiaryQuickComposerView 经 SyntaxTextEditor 消费 | 复用 NSTextView/NSScrollView、DaybookInputShell.editor、字体与滚动条；为命令场景增加可选版本/生命周期桥接，旧消费者默认行为兼容。不能直接采用 SyntaxTextEditor 的全量 @Query 标签作为安全候选来源。 |
| active / planItem 编辑 | Controller.editingDraft、OperationEditing.sendOperation、PlanEditing.sendPlanDraft | 共用同一正文适配，直接编辑当前位置；不复制计划正文到 active，不另建可提交 @State String。 |
| 草稿保留与转交 | DraftSession、HostSession、Plan、HandoffCoordinator | 保持原身份、版本、原子入列/移出、失败保留及目标接管/源撤权；保护载荷须覆盖 retained 和 pending，而非只覆盖可见项。 |
| 密文与访问 | SealedDiaryDraft → VaultKeyAccess → VaultCrypto；PrivacyAccess | 复用同一 vault/key access/加密实现；新建命令载荷封装与受控读取边界，不复制算法、不增加另一套密钥、认证或磁盘存储。 |
| 搜索锁定 | ContentQueryReadSession、InputReset、OperationBoundary | D3 的立即撤权、清搜索与旧票据失效继续独立执行；草稿保护不得等待搜索恢复，也不得把查询清理事件改成删稿。 |

#### 核实的封存、密钥与敏感性事实

以下行号对应本轮读取的工作树，可按符号定位；源码变化后需重核。引文仅保留决定方案的语句。

| 问题 | 实际代码与结论 |
|---|---|
| 1. 现有会话封存哪些内容 | [SealedDiaryDraft.swift:3–23](../AreaChain/Services/Privacy/SealedDiaryDraft.swift)：`DiaryDraftText` 只有 `text`、`baseline`；外层是 data/vaultID/id/isDirty，`JSONEncoder().encode(DiaryDraftText(...))` 后调用 keys.seal。**包含正文基线，不含** Session.baselineTags、initialTagIDs、privacyTags、record/source、日期、窗口状态、选区、marked range、撤销栈或附件选择。不能用它直接承载完整 CommandDraft/计划。 |
| 2. 封存依赖什么密钥 | [PrivacyVault.swift:104–113](../AreaChain/Services/Privacy/PrivacyVault.swift)：`post(name: .privacyWillLock...)` → generation 增长 → systemKeys.cancel → `keys.clear()` → 状态更新/changed。[VaultKeyAccess.swift:28–52](../AreaChain/Services/Privacy/VaultKeyAccess.swift) 前后检查 key/vaultID/generation；[VaultCrypto.swift:29–43](../AreaChain/Services/Privacy/VaultCrypto.swift) 唯一 AES.GCM 实现以 context 作认证附加数据。封存依赖这把即将清除的会话密钥，不能锁后另行补做或从配置推断仍可用。 |
| 3. willLock 是否须同步封存 | [DiaryEditorSession.swift:194–218](../AreaChain/Features/Diary/DiaryEditorSession.swift) 主队列观察回调直接 `sealForLock()`，没有 await。当前 lock 在 MainActor 同步发通知，seal 必须在通知返回、keys.clear 前完成；把它包入稍后 Task 不等价。多个观察者之间的注册/回调顺序不是未来正文恢复的保证。 |
| 4. 失败能否阻止锁定 | lock 返回 Void，无投票、错误返回或延期接口。sealForLock 先 mask；成功才 `text = ""; baseline = ""`，catch 只设 privacyUnavailable/issue.failed，**唯一最新稿仍在原会话明文 text/baseline**。这避免直接丢稿，但不是成功封存，也不是满足新路径安全要求的长期兜底。不能虚构“返回 false 阻止锁定”。 |
| 5. 未配置时普通草稿 | Session.needsUnlock 为 false 时 sealForLock 的 guard 直接返回，普通 text/baseline 随会话留在内存；SealedDiaryDraft.seal 无 configuration 会抛 notConfigured。Command 层目前也是内存明文保留。没有默认落盘或跨进程恢复承诺；未配置状态不能宣称任意敏感输入受加密保护。 |
| 6. 何时知道新内容需要保护 | [DiaryPrivacy.swift:11–23、38–55](../AreaChain/Domain/DiaryPrivacy.swift)：isSensitive 看 isPrivate、`#密码/#password` 和关联密码/私密标签；requiresProtection 用 TagSyntax/DiaryMemoTags 提取的名字及关联 UUID 匹配 `tag.isPrivateDiary`。Session.isSensitive/needsUnlock 在 [82–96 行](../AreaChain/Features/Diary/DiaryEditorSession.swift) 读取当前文字/目录/原记录，并非统一的写入前保护门禁。新文本、标签选择、目标或基线/标签目录变化均需重新判断；不能等保存再判断。 |
| 7. 普通记录与任意敏感输入 | isSensitive 与 requiresProtection **不等价**：旧密码标记可触发遮罩但不一定触发加密；缺目录不能当空目录，移除当前标记也不证明基线/撤销内容不敏感。记录公开只说明已核实的来源；用户后续自由文字、未完成拼写和 IME 都可能敏感。沿 D3，搜索输入无无内容证明即按敏感清理；操作草稿不能套用“清掉即可”，也不能用无关键词证明安全。建议配置可用后的新自由正文一律进入受保护载荷，不等待标签才升级。 |
| 8. 解锁是否自动恢复 | Session 的 privacyDidChange 调用 refresh；[114–118 行](../AreaChain/Features/Diary/DiaryEditorSession.swift) 在 vault.isUnlocked 时自动 open 密文并回填 text/baseline，isMasked 仍为 true，显式 reveal 才显示。**自动解密与自动显示须区分**。新命令方案更窄：保持密文，明确“恢复此草稿”且当前宿主通过访问校验后才解封，不复制旧 refresh 的自动解密行为。 |
| 9. retained/计划能否直接复用 | 可复用低层 keys.seal/open 与密文保留模式，不能原样复用 DiaryEditorSession：它持 ModelContext、读真实记录和标签、保存经 ModelChanges/DiaryRepository，身份不是命令宿主/项 stamp。SealedDiaryDraft 的二字符串格式不包含参数操作、基线主体及 absent/mixed、未完成拼写、计划所有权等，须独立命令载荷契约。 |
| 10. 已封存执行快照是什么 | [CommandPlan.swift:203–210、247–252](../AreaChain/Domain/CommandPlan.swift) 的 seal 仅 `CommandPlanSnapshot(stamp: stamp, items: items)` 后清 items；[CommandExecutionRun.swift:3–14、183–204](../AreaChain/Domain/CommandExecutionRun.swift) 持不可编辑 snapshot，resolvedInput 还能派生 arguments 值副本。**协议冻结不是加密封存**。失败/未知结果须保留原运行身份，不得退回成可重放创建。推荐在进入 sealPlanForProtocol 之前拒绝受保护/保护未知载荷；本阶段及上述后续 UI 均不接 seal/beginNext/handler。 |

[PrivacyAccess.withDiary/perform:127–164](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift) 可复用显式认证后的访问与记录存活复查思路，但 perform 在需要解锁时会创建认证 Task；搜索渲染、预览、自动恢复不得调用它触发认证。未来显式恢复还要在 await 后核对**原** ownership、draft/payload revision、privacy epoch 与访问资格；原 PrivacyAccess 本身不认识命令 stamp，不能单独证明迟到恢复安全。

现有失败标志也不能充当新隔离协议：[DiaryEditorSession.refresh:112–113](../AreaChain/Features/Diary/DiaryEditorSession.swift) 读取标签成功便把 privacyUnavailable 设回 false；它不是持久的“封存失败待修复”状态。[PrivacyRenderingTests:96–118](../AreaChainTests/Features/PrivacyRenderingTests.swift) 直接赋值后测试成功封存和自动解封但仍遮罩，未覆盖 seal 失败；同文件锁后等待 settle 再检查当前原生树，不证明锁返回时旧 storage/marked/undo 已全部撤除。

[DiaryCardDrafts.swift:8–26](../AreaChain/Features/Diary/DiaryCardDrafts.swift) 让列表持有会话、过滤卸载卡片不丢稿；[DiaryWindows.swift:22–30](../AreaChain/Features/Diary/DiaryWindows.swift) 是窗口先接收 BoardComposerDraft 再回调清源。该回调没有 CommandHandoffTicket 或双端版本，不能直接作为敏感命令转交。其 canClose（136–141）复用真实 session.save，搜索未接 handler 时不能借这个按钮宣称保存完成。附件资料和异步选择另属原 composer/附件链，本阶段不承接附件选择或真实窗口转交。

#### 正文及敏感参数持有清单

“唯一正文”指**一个被授权编辑的真值**；Swift 值拷贝、只读基线、密文恢复点和原生瞬时缓冲仍需逐项管理。下表“锁定现状”不是未来能力；拟议清理必须以唯一最新内容已被可靠保全为前提。任何仅清 String 引用的动作均不承诺内存零化。

| 持有点与源码 | 当前所有者、生命周期、可编辑性 | 锁定现状、失败时唯一内容及旧回调风险 | 后续要求 |
|---|---|---|---|
| 活动草稿 arguments；[CommandDraft:21–40、72–76](../AreaChain/Domain/CommandDraft.swift) | Coordinator.hosts → HostSession.operations.active；edit 推进版本；shortText/longText 均为 String。 | lock 不改它；编辑/入列失败仍在源草稿。旧 stamp 拒写不等于旧值不可读。 | 受保护路径从首次接收即用受控载荷引用，不先输出明文快照再事后遮罩。 |
| retained；[DraftSession:44–46、60–80](../AreaChain/Domain/CommandDraftSession.swift) | 完整草稿保留集合；恢复才活动编辑，退列进入此处。 | lock 不改；恢复/转移失败保留源。隐形项目也含正文和基线。 | 同一载荷/草稿 ID 转移；密文项目只显无内容状态，显式恢复。 |
| **pending 新草稿**；[DraftSession:5–14、147–155](../AreaChain/Domain/CommandDraftSession.swift) | destination.start 持整份新草稿；decision 同时可在 intent 和按钮闭包中存活。 | lock 不改；当前 active 与待接收正文都可能是唯一内容。旧确认被版本拒绝仍可能持值。 | 目的地只携受控引用；锁时撤确认资格但保留两侧载荷，不能清 pending 顺带丢新稿。 |
| 计划项/编辑位置；[Plan:26–39、112–126](../AreaChain/Domain/CommandPlan.swift) | item.draft 持值；editing 仅项 UUID；cancelKeepingChanges 不回滚。 | lock 保留整个 plan；计划编辑失败保持原项。UI let item/draft 可留旧副本。 | active/retained/item 中一个逻辑所有者；入列/退列原子迁移引用和版本；非活动项优先仅持密文。 |
| 编辑基线；[DraftTargets:56–71](../AreaChain/Domain/CommandDraftTargets.swift)、Session.baseline | immutable 比较证据，可含多个对象的 uniform(CommandValue)；显式 reload 或换目标替换。 | Command 无封存；Diary 只封正文 baseline，标签资料留会话。当前稿保护不能保护被漏掉的原文。 | 基线和当前稿同一保护单元内分别存储，保留未提供/absent/mixed 区别；失效与解封失败都不得当空值。 |
| 执行协议 snapshot / resolvedInput；[ExecutionRun:3、183–204](../AreaChain/Domain/CommandExecutionRun.swift) | snapshot 至显式成功释放；resolvedInput 是调用方持有的参数副本，不可编辑运行稿。 | lock 不改；失败、冲突、未知均留快照。取消 Task 不撤回已导出值。 | 敏感/未知载荷前置拒绝进运行；未来执行保护另审，不能锁时删运行稿或允许重新创建。 |
| 参数拼写 parameterText / syntheticBaselines；[Controller:23–25](../AreaChain/Features/Search/UnifiedSearchController.swift)、[OperationEditing:38–51、140–153](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift) | Controller 按 draft/parameter 持字符串及 stamp；可能重复合法值，也可能是 value=nil 的唯一未完成输入；合成基线另持整份证据。 | changed(.privacyInvalidated):215–224 不清这两个字典；parameterBuffer 可按解析值相同重新展示旧拼写。 | 长正文不写 parameterText，也不写主查询 buffer；其它内容型未完成拼写进入同一保护载荷。syntheticBaselines 只准 QA，不作真实原值缓存。 |
| InputState/事件/候选/高亮；[UnifiedSearchInputState:5–20、42–66、87–105](../AreaChain/Theme/UnifiedSearchInputState.swift) | buffer、deferredBuffer、completion、pendingAcceptance 和 request.source/text；控件/闭包持到更新或释放。 | clearNative:241–255 清控件、候选等，**不直接清 state.buffer**；end:120–126 也非全值清理。只清 NSTextView 不等于这些值均消失。 | 新正文事件携身份而非旧整份正文；明确清派生显示值及 deferred/接受回声，旧事件不可补当前版本。 |
| NSTextView/textStorage；[DaybookTextEditor:33–59、85–114](../AreaChain/Theme/DaybookTextEditor.swift) | 原生编辑器持实际文字和属性；delegate.textDidChange 把 editor.string 写回。 | 多行无同步撤销/销毁清理桥；OperationBoundary:70–84 目前只识别搜索 NSTextField 与 SearchFragmentLabel，不覆盖将来多行编辑器。清唯一 native 文本前须确认已保全。 | 增加可同步冻结/清理的窄适配，清 storage、选择及回调，禁止先卸载再读取唯一内容。 |
| marked text / 替换范围 | NSTextInputClient/NSTextView；组合期间可变，不是已确定词；[InputState:129–146](../AreaChain/Theme/UnifiedSearchInputState.swift) 普通参数暂不写草稿。 | 当前参数锁定会 unmark/清控件，未证明保留仅存在于 native 的组词；多行 synchronizeText:85–91 有 marked 时拒绝更新。 | 保存可恢复的显示全文及组合范围/选区/必要替换信息，标成未完成输入；不得强制提交为手记或把拼音当最终词。恢复为普通待编辑文字，不自动重建系统候选窗。 |
| UndoManager | 单行 [UnifiedSearchFieldEditor:14–29](../AreaChain/Theme/UnifiedSearchNativeInput.swift) 有独立 searchUndo；多行仅 allowsUndo=true，未声明专属 undo manager。 | 旧多行栈可能仍持历史字符串/操作；窗口共享栈不能整窗清空。 | 命令多行使用独立 undo；本次正常编辑保留撤销/重做，锁定/转交清本控件栈，不序列化历史。恢复不重建旧撤销；基线独立保全。 |
| 预览/摘要/标签辅助值；[OperationCopy:5–12、27–49](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift)、[OperationPreview:153–170](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift) | View 派生摘要，retained 按钮也显示两行；longText 目前仅 later，shortText 原样格式化；候选可持用户标签名。 | 卸载树不是撤销外部副本；当前尚无长文摘要保护实现。 | 公共查询继续隐藏敏感正文；操作草稿仅明确恢复且有当前显示资格时生成摘要，不缓存完整正文/摘要，锁时清辅助与可访问性值。 |
| Task/闭包捕获；[Controller:86–101](../AreaChain/Features/Search/UnifiedSearchController.swift)、[DaybookTextEditor:70–81](../AreaChain/Theme/DaybookTextEditor.swift) | refresh 捕获含 text 的 source；多行异步焦点捕获 editor/window/旧 focused，delegate.parent 也持 Binding。 | cancel 是合作式取消；已捕获值可存活，旧焦点块目前无命令版本。 | 异步只捕获 ID/stamp 与弱 owner；返回核对 epoch，不保留正文到 await；detach/lock 清闭包，焦点请求核对挂载代次及当前可显示性。 |
| 加解密临时 Data/快照；[SealedDiaryDraft:16、22](../AreaChain/Services/Privacy/SealedDiaryDraft.swift)、[DiaryEditorSession:54、83、167](../AreaChain/Features/Diary/DiaryEditorSession.swift) | 同步编码/解码的完整 JSON 明文 Data、初始化文本、判定用 DiarySnapshot 和裁剪文本；均不是可编辑权威。 | 同步作用域结束仅释放引用；锁定无法追溯清除任意值副本，不能据此承诺物理擦除。 | 保持同步且不逃逸、不缓存/记录；失败保留原源/密文，不把临时编码数据当恢复库。 |
| 转交准备、旧宿主值；[HandoffCoordinator:29–31、61–114](../AreaChain/Domain/CommandHandoffCoordinator.swift) | ticket 仅 lease/要求，不含正文；prepare/commit 局部值和 host() 调用方可持完整旧 Session。 | commit 单次 hosts=next 保证写所有权；旧 Swift 值不会被清零，可能继续被读取。失败源仍完整。 | 受保护草稿从一开始只向旧宿主快照暴露不透明引用；目标接管后旧引用不可读，准备期间源保持唯一恢复点。 |
| mergedOrigins；[Plan:190–200](../AreaChain/Domain/CommandPlan.swift) | 只含被合并草稿 stamp，非正文历史。 | 不需正文封存；不可被用作恢复旧草稿能力。 | 保持出处及防重放；敏感正文/未知基线仍不合并，不扩大既有窄白名单。 |

#### 推荐长正文原生接线（拟议，尚未实施）

1. 在 `UnifiedSearchParameterField` 的 longText 分支组合 **DaybookInputShell.editor + DaybookTextEditor**，新增 Feature 内 `UnifiedSearchLongTextEditor` 窄适配。不把长文放回 `UnifiedSearchInput` 的命令解析/参数拼写模式。`SyntaxTextEditor` 是已核实的外壳参考，但其 @Query 读取全部未删标签；新适配应显式注入允许的候选，复用 SyntaxAutocompleteState 的 tags/diaryCapture 语义，不自行 fetch、不创建标签。`/`、`#`、引号、多行粘贴保持正文；# 可沿手记既有标签语法提示，路径样式文字绝不调用 CommandPathParser 的执行意图。
2. 编辑位置显式携 `active(draftStamp)` 或 `planItem(planStamp,itemStamp,draftStamp)`，共同经过 Controller/原协调者；active 调原 edit，planItem 调 sendPlanDraft 的原计划 edit。retained 先显式恢复再编辑，计划就地编辑不移回 active。普通合成阶段参数真值仍为 arguments.longText；预览仅派生。受保护阶段改为下节载荷中的唯一 currentText，Domain 仅持引用，不能保留另一份 editable String。
3. 原生桥接关联 `ownership + lease revision + draftStamp + plan/item stamp + parameterID + privacy epoch + editor mountID + native revision`；选区用 UTF-16。普通输入、粘贴、补全、撤销/重做均带原版本。仅同步成功的本次输入回声可接续新版本，拒绝旧参数/确认/候选。不能使用只比较 text 相等或 saved.version<=draft.version 的旧拼写恢复作为敏感准入依据。
4. 多行 bridge 需要在**原生接受内容之前**取得候选修订及保全成功回执，覆盖 insertText/setMarkedText、删除/替换、补全、粘贴和 undo/redo。现有 textDidChange 是事后通知，不能证明此能力；须先在隔离宿主验证 NSTextInputClient 与 delegate 的完整顺序。组合期间不做语义提交、不弹命令补全、不强改 marked range；可恢复的组合状态归同一编辑所有者，仅 native 为短暂可写缓冲。非敏感 QA 也要证明组词内容在宿主卸载时不消失。
5. 用户收起/切页/切 active-plan/转交前同步完成编辑所有者接收；marked 尚在时，优先保持 native 会话等待用户结束组词，或在已经保全完整组词显示值后结束显示，**不**调用真实保存。若本次切换的保全失败，可拒绝这个用户切换、保留原会话并反馈；这不意味着可以拒绝系统 lock。搜索 clearUserQuery 与操作编辑隔离：清查询不能顺带删正文或其组合恢复内容。
6. 真正锁定由同步保护入口先关闭编辑/读取/焦点回调资格，再使用已存在的同版本密文，最后清 native storage、marked 状态、专属 undo、候选、摘要及事件缓冲。原 Search ReadSession 的 willLock 仍立即清查询、结果和票据；**不依赖**它与正文观察者谁先收到通知。若 OperationBoundary 先卸载正文，正文最新修订也必须早已保全，因此不能依赖“锁通知时再从 editor 抢读”。
7. 日常展开/收起保持同一草稿与正文；只持无内容的展开、选区、滚动位置元数据，焦点回到触发的展开/计划编辑按钮。重新展开不得自动恢复敏感内容；明确恢复后才可焦点进入正文。正文 NSScrollView 有界滚动、外围仍复用原操作面板有界滚动，不推开顶部搜索；键盘光标/选择滚动属于文本视图，列表滚动属于面板。正常/最小宽度、滚轮边界与焦点可达性留给原生验收，不凭代码宣称体验已通过。
8. Return 仍为换行，组词优先由输入法处理；⌘Return/保存按钮只说明“尚未执行”，Esc 优先关闭标签候选，再返回发起控件并保留草稿。不调用 DiaryEditorSession.save、repository、sealPlanForProtocol 或 handler；失败反馈不得写“已保存”。普通长文与敏感长文分阶段，未支持的内容入口在读取/粘贴/恢复**之前**拒绝，并给明确限制，不接收后再丢弃。

#### 保护载荷、失败处理与授权边界

**2026-10-03 / 4A-3C2A 已确认决定（优先于下文 C0 历史建议）**：用户授权本阶段公共草稿/计划契约及敏感数据处理实现，仅隔离合成验证。普通备注/手记在未配置私密锁时允许运行内明文编辑，不承诺加密、不自动落盘；明确受保护的记录/操作不得降级。普通转保护必须先成功建立恢复点再切换，失败保留普通稿并明确尚未保护、不执行私密操作。关键词缺失不是安全证明。下文关于未配置真实自由正文仍待决定的推荐保留为 C0 历史意见，已由本决定取代。

C2A 仅实现应用接受修订的密文恢复点与显式恢复，不实现 NSTextView/IME 接受前门禁、原生撤销、生产敏感编辑、完整敏感转交、执行中保护、真实 handler、认证、迁移或磁盘草稿；不修改密钥生命周期及 PrivacyVault.lock 顺序。解锁不自动解封。原生缓冲与应用接受修订分别取证，缺失的原生保证继续关闭相关入口。

推荐对**公共 CommandDraft 载荷契约**作显式扩展，而非仅给 View 加管理器。拟将当前 arguments+baseline 包为内容状态：普通合成路径为 plain，受保护路径为 `protected(reference)`；reference 只有不可复用载荷 ID/修订及所需形状，不携正文、密钥或权限。`CommandValue` 继续表达内层业务值，**不推荐把密文塞成 .longText(String)，也不必为每个值加入可任意解密的 sealed case**。Domain 的空值/缺项仍是业务语义；外层 sealed/masked/unavailable 与它们分开。具体名称是设计占位，尚未新增文件或类型。

拟在 Services/Privacy 新建 `CommandDraftContentSession` 与 `SealedCommandDraft`：前者受注入的同一 Coordinator 所有权、vault 及编辑代次约束，独占可编辑 payload；后者只做命令格式编码与既有 VaultKeyAccess.seal/open 调用。载荷包括参数及 field operation、按 subject/parameter 编码的基线、未完成拼写、组词恢复数据、必要的敏感性来源与内容修订。固定目标/初始目标、计划图仍归原 Domain；若其中元数据被判敏感，只向普通展示投放允许投影。密文认证 context 区分命令草稿与既有 `draft:<id>`，绑定稳定载荷 ID/格式/修订；host lease 由所有权门禁核验，不把密文可复制当接管权限。旧 DiaryDraftText 编码与恢复兼容保持，不让新格式冒充旧格式。

服务保存当前可编辑载荷和其**同一修订的不可编辑密文恢复点**，不是两份可提交正文。普通 Domain host()/plan()/decision 仅得到引用及无内容状态，无法通过旧值快照直接读取 protected payload；敏感 current/baseline 不通过普通 arguments/baseline getter 导出。读取返回的 String 仍会复制，必须限定在同步渲染/原生借用窗口并登记清理责任，禁止捕获进异步工作或正文日志；Swift 不提供这里所需的绝对内存零化保证。

受保护编辑不能直接调用旧 `.edit(stamp, CommandArgument)` 再事后封存。拟由内容会话在原生接受前准备新 payload/密文，返回仅含候选 ID、原 owner/location、旧/新 payload revision 的一次性准备凭据；新增受保护内容提交事件由 Coordinator 同步核验当前引用、draft/plan/item stamp 及准备凭据后更新引用和版本。准备凭据不携正文，也不是解锁许可；候选失败或事件过期保持原 payload。plain 合成分支继续原 edit。计划和普通草稿共用这条提交路径，不能在新服务内绕过原 reducer 自行推进 owner。实现还必须验证候选资源发布与原生接受失败时的回退顺序；未证明这个原子性前保持敏感路径禁用。

推荐失败协议如下，必须先验证再开放：

| 时点 | 保全/失败处理 | 唯一内容位置及不能宣称的结果 |
|---|---|---|
| 首次接收/读取敏感或未知正文前 | 验证 vault 已配置且可用、当前访问与保护格式，完成初始密文后才允许原生编辑/普通投影。读取权限不从搜索 lease 获得。 | 初次 seal 失败不得把内容接入普通展示；原来源保持所有权。没有原来源/无法保全的入口保持禁用，不能把失败输入写临时文件。 |
| 每次接受正文/组词修订 | 同步准备候选 → 同版本密文成功 → 原子发布载荷修订及接受原生更新；中途失败不推进成功状态。不得异步 debounce 后再补密文。 | **已接受的最新修订**仍在原 payload 及匹配密文；拒绝的新候选明确标“本次输入未接受”，不能声称它已保留。若平台已把唯一新内容写入 native 后才允许拦截，此方案前提失败，必须阻止该敏感路径开放。 |
| 用户切换/收起时保全失败 | 拒绝该次可取消的用户切换、保留原编辑者，给无内容错误和重试入口；不更新目标版本或清源。 | 唯一稿留源；不能给旧 native 回调补新 stamp。转交失败同理。 |
| willLock / 密钥即将清除 | 不再首度加密；立即撤访问，转换为仅持**最新已接受修订**密文，原 lock 按时清 keys。 | 锁定后唯一恢复材料是内存密文，含最新组词恢复内容与基线；没有自动落盘或进程崩溃恢复。旧密文落后一字也不能算保全。 |
| 解封/格式/vault 不匹配失败 | 保留密文原件与身份，继续 masked/unavailable，显示固定错误；不覆盖成空稿、不自动认证/换钥/重试保存。 | 唯一可恢复内容仍为原密文；不能宣称已恢复。原 vault 永久不可用、退出进程等恢复能力未建立。 |
| 发现无同版本密文却已接受明文 | 这是保护不变量破坏，**现有机制没有同时满足“立即锁定、不留明文、不丢唯一稿”的通用兜底**。 | 原 Session 的明文保留只能如实登记为安全缺口，不是新机制的成功分支。不得采用直接清稿、永久明文隔离、取消自动锁或新建密钥系统解决；实现/验收阶段保持入口关闭，另行提交具体修订方案。 |

未配置私密锁的**已存在普通草稿**继续归原运行内所有者，收起/切页/清查询不丢，关闭保留原未保存处理；没有可用 key 时不强行调用 seal，也不自动配置。用户要求的“普通长文保留”与“任意自由输入都受保护”不能在未配置状态被混称为已实现。推荐首批普通长文只用合成资料；真实未配置自由输入暂不开放新的安全承诺或新路径。未来若要开放，需明确其非加密草稿产品边界及已知敏感/保护未知入口的阻断；只检测 #密码 不足以证明任意输入非敏感。配置/标签外部变化同样须使当前证明失效，不能延用旧 public 分类。

配置可用后的推荐路径从首个自由正文修订就建立密文恢复点，覆盖短文字中用户内容、原值和未完成输入，避免由普通转敏感时已遗留无法撤回的明文 host 副本。锁定/不可用/busy 时不新建或解封这类载荷，明确提示原因；已封存内容保留原件。解锁本身不显示、不解封，显式“恢复此草稿”后才重新校验资格。保护成本为每次可恢复原生修订的编码/加密；需按合成长文规模测主线程延迟与内存，不先承诺无限长度、性能预算或用异步窗口削弱不变量。

#### 所有权、计划及转交的具体变化

- 原子入列/移出继续沿 HostSession.enqueue/removeFromPlan：只迁移同一 payload 引用与 owner location；失败不动源，retained 不是执行队列。pending 的目标载荷也参加保全和未保存枚举。封存/恢复推进保护 epoch 和编辑资格，业务目标与 baseline 不隐式重载；旧确认、候选、原生/焦点回调一律失效。
- 修改、形状检查与显示资格分开：protected 状态不能把缺少可读正文解释为空或无修改。`CommandDraft.check/changesOriginal`、`CommandDraftBaseline.original` 需返回受保护/待校验状态或使用同修订的无内容检查证据，保守保留未保存标记；不能依据 opaque reference 相等推断正文等价。`CommandPlanValidation` 不因为有密文便判可执行；正文合并仍拒绝。原 mergedOrigins 只保存 stamp，继续保留。
- 转交前源先停止当前编辑、保全同版本完整载荷（含组词）、撤掉显示/undo，并保留源所有权；完成此步后才按**新当前版本** prepare。准备不冻结后续普通操作，任何新编辑或锁定都使 ticket 过期，须重新准备，不能在 commit 内临时解密或强制结束旧组词。
- confirm 只接受目标宿主已准备好处理该 protected 格式/密文引用的明确结果，不包含解锁许可、读取票据、认证结果或显示资格。commit 保留 MainActor 无 await、无外部回调、单次发布的结构；载荷 owner 元数据须和双方 hosts 一次发布，不能先改服务表再改 hosts 造成两套权威。不把加密搬进这个提交段；所有可失败准备在之前完成。
- 最小集成建议：载荷资源寿命由注入的命令内容会话持有，**owner 的唯一权威仍由 Coordinator 登记**，服务每次读取都核对它，不另维护可独立授予资格的 owner 表。commit 移动引用并推进双端 ownership/generation、draft/item/plan 版本；密文以稳定载荷 ID 可在同 vault 内接续，旧宿主引用无当前 lease 即不可读。不同 vault/格式不兼容直接拒绝，不迁移密钥。
- prepare/confirm/cancel/fail 均不删除源密文；失败或目标关闭仍由源恢复。成功后源只留防重放身份，目标保持封存，用户明确恢复才读取。锁定先发生：搜索撤权且 ticket 旧 lease 失效；commit 先发生：锁事件对协调者当前实际 owner 的全部载荷执行保护，而非只找已销毁源 Controller；编辑先发生：先完成新修订恢复点并使旧 ticket/确认失效。三者都串行核验，不跨 await 续租。
- 任意未释放 execution 仍禁止转交；敏感/未知载荷在 `sealPlanForProtocol` 前拒绝进入 snapshot。未来真实 handler 的执行中/结果未知保护、不可撤回的已提交状态、异步参数借用及失败恢复需独立阶段，不能以当前 UI 的 submitBlocked 代替 Domain 防绕过门禁。

公共契约的真实影响消费者如下；不是只改一个新服务就能交付：

| 拟改文件/符号 | 影响及后续回归 |
|---|---|
| CommandDraft、CommandDraftTargets、CommandDraftSession、CommandArgumentValidation | plain/protected 读取、修改判断、baseline 三态、pending/恢复/显式重载及事件形状；CommandParameterTests、CommandDraftTests、CommandDraftProtectionTests。普通值入口兼容，受保护值不能被默认为合法普通参数。 |
| CommandPlan、CommandPlanSemantics、CommandPlanValidation、CommandHostSession | 入列/退列/就地编辑、依赖/引用版本、未保存及执行前阻断；CommandPlanOwnership/Dependency/Merge、CommandAtomicPlan、CommandHostSession 测试。 |
| CommandExecutionRun、CommandExecutionContract | snapshot/resolvedInput 不导出受保护明文、未知结果保留/不重放；CommandExecutionTests、CommandExecutionIntegrationTests。不接真实执行。 |
| CommandHandoffCoordinator、CommandHandoffContract、HostSession.handoffStates | protected 引用接管、资格、双端原子性、旧值读取失效；CommandHandoff、Identity、Boundary、Integration 测试。 |
| Controller、OperationEditing/Copy/Preview/ParameterField、PlanEditing/List/Links/Dependencies、ObjectSelection | 正文位置/预览/原值、无内容投影、同版本候选、旧回调清理；已有 Operation/Plan/Object 的 Contract/Lifecycle/Interaction/Presentation 及新长文用例。 |
| DaybookTextEditor、UnifiedSearchInputState/InputReset/OperationBoundary；拟增 Feature 长文适配 | 可选生命周期桥、原生入口版本/专属 undo/同步清理，旧手记卡片/小窗/快速输入与任务备注、输入语法及搜索消费者回归；不顺带迁移原保存行为。 |
| Services/Privacy 拟增命令内容会话/密文载荷；SealedDiaryDraft/VaultKeyAccess 的复用点 | 故障注入、格式/关联身份、锁前最新恢复点、显式解封。优先直接复用 keys API，必要抽取共有封装时须保持原 DiaryDraftText 兼容及原隐私测试；不得复制 VaultCrypto 算法。 |
| ContentQueryReadSession / ReadLifecycle / 显示通知 | 保持 D3 同步清查询、许可隔离及旧票据拒绝；ReadSessionLock/Observation/Interaction、BodyLifecycle/Boundary 回归。新增草稿保护不能延长旧搜索许可。 |

#### 后续实施拆分及必要授权

以下是可审阅的推荐顺序，本阶段结束即停止，不据此自动进入任何一步。

| 阶段 | 拟改范围、复用 | 新边界、失败/回退与隔离验收 | 授权 |
|---|---|---|---|
| 4A-3C1：合成普通长文原生接线 | 原 ParameterField/OperationEditing/PlanEditing/Preview；拟增 LongTextEditor，DaybookTextEditor 的可选版本/生命周期桥；双语文案 | 仅原 QA 标准/紧凑宿主与合成正文；active/retained/plan、组词、撤销、收起、切页、清查询/关闭保留。受保护或来源未知输入在导入前拒绝；失败保留源或拒绝切换，回退关闭 longText 分支。无 handler、真实对象/正文读取或生产入口。 | 需要后续明确实施请求；本轮无实施授权。普通原生接线不自行扩大隐私边界。 |
| 4A-3C2：命令保护载荷与故障契约 | 上表 Domain 契约、Services 密文/内容会话，复用现有 vault.keys；原生 pre-accept 能力的隔离验证 | 明确改变敏感数据存活期/公共读值边界及编辑接受时机。先证明所有已接受修订有精确恢复点，故障时不丢稿、不保留普通展示明文、不延缓 lock。含 IME、baseline/pending、解封失败与性能；若任一入口无法证明，停止开放，不能保留未保护实现继续下一步。 | **必须明确授权高风险的公共草稿/计划及敏感数据处理契约变化**；范围含内存加密载荷、显式恢复、原生接受门禁和失败注入。授权不含密钥生命周期/认证/自动锁策略、磁盘持久化或真实数据。 |
| 4A-3C3：受保护编辑、计划和同 vault 转交接线 | C2 载荷接原 Controller/OperationBoundary/Handoff；所有内容持有点按表回归 | retained/plan 仅密文、显式恢复、目标初始封存、锁/编辑/转交竞态、旧 callbacks/票据、无敏感快照执行。任何准备/接管失败源保留，回退禁入口并保留既有密文格式读取；不能回退到普通明文表示。 | 独立实施授权，并以前阶段证据/指定复核为前提；先隔离合成，真实读取、生产入口、真实认证和 handler 另列门禁。 |

以下两项是 C0 当时待决定事项，现已由上方 4A-3C2A 授权及普通编辑边界取代；保留历史，不再请求确认：

1. **是否授权 C2 的 protected payload + 同版本密文恢复点 + 显式恢复方案**。推荐授权后先做隔离契约/原生可行性验证；失败即维持敏感入口禁用。该方案复用现有密钥，不改 lock 顺序，不引入磁盘，也不承诺字符串零化。
2. **未来未配置私密锁时真实自由正文的产品范围**。推荐本轮后续首批仍限合成 QA，真实未配置自由输入暂不开放；若要普通明文运行内编辑，必须明确接受其不具备任意敏感输入加密能力，并重新审定已知敏感/未知来源阻断及配置变化保护。不能把“普通手记”名称当安全证明，也不能先开放敏感路径再补保护。本项未决定不阻断 C0 文档交付或 C1 合成验证。

指定 Cursor verifier 仍是后续公共契约/高风险实现的只读复核入口；本轮仅保留既有不可调用状态，不重复登录、不以本次两项探索/主代理自查冒充。未来代码完成、相关检查完成后向该入口交付原需求、实际差异和证据；不可用则继续登记 partial。本阶段没有要求修改 PrivacyVault.lock 使其可取消，任何这类方案也不在推荐授权范围内。

#### 后续隔离验证计划（本阶段不执行）

| 场景 | 必须检查的证据 |
|---|---|
| 原生长文 | 长中文/emoji/组合字符、多行粘贴、选区替换、Return、⌘Return、Esc、undo/redo；/ 与 # 不执行指令、不创建标签、不保存。标准/紧凑、en/zh-Hans、浅深色、正常/最小窗口及两层滚动。 |
| 位置与未保存 | active→retain→恢复→入 plan→就地编辑→移出，pending 双侧正文；草稿/项/计划身份及版本、基线缺项/absent/mixed、取消保留修改；失败不改变唯一 owner。 |
| IME 时序 | 在 setMarkedText、replacementRange、选区更新、候选确认、native/delegate 回声及卸载之间逐点注入锁/切换；验证每个已接受显示修订有同版本恢复点，不用“最后一个已提交词”冒充完整草稿。程序化 marked API 与真人中文输入法候选窗分别取证。 |
| 封存成功/失败 | 合成 fake vault/内存配置，初次 seal、编辑 checkpoint、基线编码、解封、格式/vault/context 不匹配逐点故障注入；保存密文原件和最新修订，错误反馈无正文。无恢复点的反例必须拒绝准入，不能改断言接受丢字或长留明文。 |
| 隐私状态 | unconfigured、locked、unlocked、unavailable、authenticating/methods changing；legacy 标记、新私密标签、目录缺失/更改、已去标记但基线仍敏感；不自动认证、不延缓自动锁，显式恢复前无明文读/显示。 |
| 生命周期与转交 | 关闭面板/切页/清查询/收起/失焦后唯一稿仍在；锁定立即清搜索；准备前/confirm 前/commit 前后交错锁定和编辑，目标失败源保留、成功源旧值不可读、目标不自动解封。任何 execution（含未知/成功未释放）阻止转交。 |
| 迟到与泄露 | 旧 lease/stamp/epoch、旧 confirm、deferred buffer、undo、失焦/焦点 Task、旧 host()/resolvedInput、候选和迟到查询结果均不得重新发布正文；检查原生 storage、摘要、可访问性、日志与故障产物。测试只含合成标记，不记录真实正文。 |
| 无副作用 | fake repository/handler 调用计数为 0；无 UserDefaults/临时文件正文写入、无真实钥匙串/日历/生产库、无自动认证；不把密文 checkpoint 或协议 seal 表述为保存成功。 |
| 性能与历史回归 | 测量指定长度/中文比例、每修订编码/加密延迟、cold/warm、主线程及内存；无数据不承诺预算。共享多行控件扩大到原手记/备注消费者，维持旧行为；§9.49 最终原生、旧 dark→system、VoiceOver/减弱动态/最低系统/真实多窗口缺口分别保留。 |

后续原生验证沿架构文档既有 PrivacyQA 独立标识、独立 DerivedData、内存/临时合成资料、清除真实钥匙串授权变量和串行入口执行；须先由其他任务正常释放测试锁，不能删锁、抢锁或停止其他任务。C0 没有检查锁持有者或申请锁，没有启动 Swift 构建、应用或 XCTest。已阅读的 DiaryEditorSessionTests、PrivacyRenderingTests、InputSyntaxInteractionTests、Command/Operation/Plan/ReadSession 生命周期测试只作为覆盖线索，不能计成本轮通过。

#### 本轮文档检查与停止交接

本阶段仅追加本文；只读核验与方案已写入，**整体验证暂为 partial**。实际检查如下，后续并行变更不反向改变这些运行的历史身份：

| 检查 | 本轮实际结果 |
|---|---|
| `python3 -B scripts/check_workflow.py` | 首轮 failed；project-links 通过，新增 §9.50 未报告坏引用。component-catalog 的 5 条错误来自并行滚动入口：daybookScroll、daybookScrollAssembly、DaybookScrollIndicators 当时未完成目录登记，后两项符号尚未在 DaybookScroller 中出现。未修改相关文件或绕过规则。 |
| `python3 -B scripts/quality_gate.py --profile static --format json` | 首轮 failed；workflow-contract 同上，204 项脚本回归有 3 项失败。diff-whitespace、performance-contract、shell-syntax、security-static、comment-contract 均 passed；静态扫描无高置信秘密/敏感日志候选，不等于内存安全或完整审计。 |
| 脚本失败定位 | 额外运行 `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v`：84 项，81 passed / 3 failed。失败为 test_cli_json_and_failure_exit_code、test_default_checks_pass_in_isolated_repository、test_default_run_never_enumerates_personal_documents；报告均指向合成组件目录尚未登记上述三个并行滚动符号。仅定位，不修该任务的夹具。 |
| `git diff --check` | 已运行 passed。原检查命令与工作流使用 && 时因前者失败未运行 diff，因此另行单独执行并确认结果，未把未执行写成通过。 |
| 工作区与未执行 | 初始及定稿时都有并行差异；期间 DaybookColor/DaybookScroller、目录及脚本又在变化，整树未冻结。本任务写入仅本文 §9.50，不把他人修改纳入产品交付。不运行 auto/swift profile、Swift 构建、XCTest、原生截图、系统认证或应用；不申请/删除/争抢测试锁。 |

记录定稿后的第二轮 `check_workflow.py` / static 仍 failed：并行组件的三项符号/目录检查已通过，但 `docs/component-catalog.md:545` 新引用的 `engineering.md#第八阶段-b公共滚动装配去重` 尚无对应锚点；204 项脚本回归仍有上述 3 项失败，其余静态项通过。首轮与第二轮的错误不混为同一次快照，也不等待/修改他人工作来凑绿。额外直接调用原检查器的 `check_links(root, [本文], "authoritative-document-links")`，本文完整内联链接检查 passed；这只是本文件范围，不替代失败的仓库门禁。`git diff --check` 单独运行 passed。追加前本文的 704048 字节前缀 SHA-256 与追加后对应前缀一致，既有 §9.49 及更早内容未被改写；新 §9.50 只有一份。

显式 static 避免当前并行 Swift 差异使 auto 启动原生测试；脚本隔离回归不申请原生锁。没有提交、推送、安装或发布。C0 文档交付不表示敏感封存、普通长文运行或前阶段原生验收通过；§9.49 的 Errno 35 锁阻塞、最终原生未运行、指定 Cursor/人工/历史外观缺口继续保留。完成本节文档交付后停止，后续实施须按上述范围单独授权。


### 9.51 阶段 4A-3C2A：命令保护载荷与显式恢复

2026-10-03。用户明确授权公共草稿/计划与敏感数据处理实现，仅隔离合成验证。§9.50 的 C0 待决定建议保留为历史；普通备注/手记未配置时允许内存明文编辑，不承诺加密、不落盘。required/unknown 不降级，转换失败保留原普通稿并返回 notProtected，私密执行关闭。已配置也不自动读取、认证或恢复。

#### 载荷、修订与访问

`CommandDraftPayload` v1 只编码格式、稳定 payloadID、应用内容 revision UUID、draftID、commandID、arguments（含 operation）、按 subject/parameter 的 absent/uniform/mixed baseline、未完成拼写及 UTF-16 选区。拒绝重复字段、非法选区、未知格式和 nativeSelection/shortcut；不序列化整个宿主、窗口、执行闭包、认证或文件能力。`SealedCommandDraft` 经现有 VaultKeyAccess / VaultCrypto AES-GCM，认证上下文绑定命令格式、vault、草稿、命令、载荷及内容修订；错关联、替换及损坏拒绝。旧 DiaryDraftText / draft:<id> 格式未修改。

内容 revision 与宿主 lease / draft.version 分开：前者标识精确正文、基线、编辑状态恢复点；后者还会在普通移动/恢复激活时推进，不表示正文改变。每个应用接受内容修订先同步编码并加密，在服务资源表存候选后，Coordinator 核验当前 lease/stamp 并一次提交引用；提交失败恢复原密文。无公开 checkpoint 构造器，没有可填授权布尔值，没有独立 owner 表。服务表只保存恢复材料；当前访问每次回查唯一 Coordinator。

公开 CommandDraft.arguments 不返回受保护值；baseline.isReadable=false，original 返回未提供值而非 absent，调用者必须同时看不可读标志；check.parameterCompleteness=protectedUnknown，dirty 保守 modified，引用相等不证明未修改。旧普通副本仍是转换前明文，Swift 值复制不能追溯擦除；本阶段无真实敏感入口，不将这点宣称为零化保证。

`explicitlyRestore` 是唯一服务解密入口，恢复前后核验宿主 lease、草稿 stamp、载荷/修订、vault 和隐私代次/服务 epoch；不发起认证。返回不透明访问凭据，`withRestoredContents` 同步借用且前后复核；String 可被不遵守约定的进程内调用者复制，因此借用方禁止缓存、异步捕获、普通预览或日志。原生安全接线未完成，服务只在合成测试装配。锁定/隐私通知清受控明文引用并使凭据过期；willLock 当代次尚未递增时也禁止重新恢复。解锁通知只撤权，绝不自动解密。恢复失败保留密文。

#### 失败与消费者边界

- 初次转换：原普通稿完整保留到加密成功和协调者接受；失败 notProtected，无新引用、无版本推进、不执行私密操作。
- 已保护编辑：必须先显式恢复；保持原基线，候选先封存，成功才替换引用与修订，失败 revisionNotAccepted，旧稿及密文不变。没有接受失败的新输入；不承诺尚未接入的 marked text 保全。
- active/retained/plan 复用同一提交路径。pending 两侧纳入未保存枚举；存在 pending 时拒绝保护提交，不取消决策、不丢稿。计划入列/退出只移动引用；普通 edit/select/reload 不能覆盖 protected。计划就地保护编辑推进 item/plan/draft 版本，旧依赖自然过期。
- CommandPlanValidation / Semantics / ExecutionRun：保护或未知内容不可合并/链接为普通参数；协议 seal 前拒绝保护/未知与自由长文导出，resolvedInput 也有拒绝检查。普通长文转交与旧追加合并错误继续兼容；明确保护/未知转交在 Coordinator 与 HostSession/Plan 边界拒绝，源所有权与密文不变。没有真实执行。
- 两个原 Search 文案适配仅补无内容的 protectedContent 错误及 en/zh-Hans 文案，没有新增编辑或恢复按钮；不以 UI 禁用替代领域拒绝。

#### 原生缺口、回退与交接

只读核对 UnifiedSearchInputState 的 buffer / deferredBuffer / pendingAcceptance / lastSelection 及 NSTextView.hasMarkedText 分支；这些没有接入新服务。NSTextView/IME 接受前门禁、UndoManager、真实长正文、执行中敏感命令、完整跨宿主敏感转交继续关闭。应用修订合成事件不是系统输入法保证。下一步仅登记原生接受前候选拒绝、组合文本全部阶段、撤销缓冲与锁通知交错可行性，需单独阶段，不自动实施。

回退关闭新保护入口，但保留当前内容服务及 v1 解码/显式恢复路径直至已持有密文处理完毕；不得卸掉唯一运行内服务/解码器、将密文降成公开明文或用旧代码读取新载荷。无磁盘草稿，不承诺进程退出/崩溃恢复；不改变用户数据格式、认证、密钥生命周期或 PrivacyVault.lock 顺序。

#### 实际验证（持续更新至本阶段停止）

首轮正常完整 PrivacyQA 目标沿 build/.build.lock 非阻塞取得锁，独立标识/目录、临时签名、六项真实钥匙串变量清除，测试仅内存配置、fake keys、合成载荷。79 项测试，74 通过、5 失败、0 跳过；含动态参数共 114 次运行，109 通过。失败是普通长文转交被扩大拒绝（4 项）及普通追加合并错误变更（1 项），已收窄转交/合并门禁，未放宽测试断言。首轮包曾为 `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.03_22-22-59-+0800.xcresult`，结果已读取；后续正常 Xcode 日志保留策略已移除该旧包，失败日志仍在 `build/CommandC2A-tests.log`，不将路径当作仍可访问的证据；重验结果另列。首次 Debug 编译漏两处新枚举分支失败，补齐后构建及静态验签通过，但后续相关编辑需重建。

指定 Cursor verifier 当前无可调用入口，未执行、不重复登录、不改认证、不以主代理检查或其他代理替代；保持 partial。4A-3B2 最终原生重验缺失、历史测试锁阻塞及人工/旧阶段缺口全部保留。本次取得锁不等于补齐任何历史验收。未提交、推送、安装、启动生产应用或开放敏感编辑，停在 C2A。


公共消费者的最终准入补充：明确 required/unknown 的普通种子由 CommandDraftReducer.validSeed 拒绝，直接 CommandPlan.add 同样拒绝；没有受控来源读取实现时不能先进入普通编辑再声称受保护。已有普通稿仍可显式 protect。protect 传入已保护稿报 unsupported，不误称旧稿“尚未保护”。

第二轮完整定向结果：96 项测试、含参数化 131 次运行，零失败、零跳过；正常完整 PrivacyQA 应用/测试目标，结果包当时为 `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.03_22-31-42-+0800.xcresult`，日志 `build/CommandC2A-final-tests.log`。此轮后增加上述 required/unknown 准入拒绝与一项回归，最终结果另列，不把第二轮证据外推到新增改动。

性能样本在 macOS 26.6.2 (25G83)、arm64 MacBook Pro、Xcode 26.6 (17F113)、Debug、MainActor、既有 AES-GCM 强度下测得。每档 6 次，正文为重复“中a🙂”（UTF-8 每单元 8 字节），基线与正文同大小；计时覆盖 DTO 构造/校验、JSON 编码、加密，不含解密、Coordinator 提交、原生接受或绘制。首样本是本测试该规模首轮，**不是冷进程**；热值取余下 5 次。每次随后解密比对内容，附件仅记录规模与时间、不记录正文。

| 正文 / 基线各 UTF-8 字节 | 密文字节 | 首轮 ms | 热均值 ms | 热最大 ms |
|---:|---:|---:|---:|---:|
| 1,024 | 2,448 | 0.0348 | 0.0235 | 0.0260 |
| 65,536 | 131,472 | 0.2598 | 0.2431 | 0.2465 |
| 1,048,576 | 2,097,552 | 3.7208 | 3.5911 | 3.7905 |

原始样本已从结果包导出到 `build/CommandC2A-metrics/`（含 manifest）；这不是逐键/组词延迟验收，没有内存峰值/输入时限预算，不降低密码学强度。

工作流脚本新增四个稳定入口登记及缺符号反例。首次反例集三项失败来自合成组件目录未登记四项，补齐夹具后 86 项定向检查通过；静态 strict 门禁及 206 项 scripts/tests 通过，安全扫描 0 高风险、0 敏感日志候选；20 个本次 Swift 文件严格局部 SwiftLint 通过。后续只追加交接文档仍重跑工作流与 static。Debug 最终构建首次尝试因其他任务持锁退出 3，未删锁/抢锁/终止任务；不将前一构建当最终代码通过。


**最终代码证据**：新增准入拒绝后的第三轮，97 项测试、含参数化 132 次运行，全部通过、0 跳过、0 预期失败。结果包 `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.03_22-43-29-+0800.xcresult`；日志 `build/CommandC2A-admission-tests.log`。正常完整目标串行运行上述 16 套：CommandProtectedDraftTests、SealedCommandDraftTests、CommandDraftTests、CommandDraftProtectionTests、CommandPlanOwnershipTests、CommandPlanDependencyTests、CommandPlanMergeTests、CommandAtomicPlanTests、CommandHostSessionTests、CommandHandoffTests、CommandHandoffIdentityTests、CommandHandoffBoundaryTests、CommandHandoffIntegrationTests、CommandExecutionTests、CommandExecutionIntegrationTests、CommandParameterTests。最终 Debug 构建再次经 `./scripts/build.sh --no-wait` 成功取得原锁，构建及静态验签通过，日志 `build/CommandC2A-final-build.log`；仅构建，不安装或启动。保留已发生的持锁阻塞记录。旧密文兼容由合成 SealedDiaryDraft 回归验证，不运行含真实钥匙串探测的完整 PrivacyVaultTests。

本次实现和隔离单测/构建完成，但**阶段整体仍 partial**：指定 Cursor verifier 无可调用工具、未执行；原生长文接受前、IME、撤销、真人与历史验收未补齐。性能仅支持上表同步检查点测量，不支持系统输入保证。最终主代理检查确认原 SealedDiaryDraft / VaultKeyAccess / VaultCrypto / PrivacyVault 无差异，未接生产/handler、未提交、未推送、未安装、未启动生产应用；在 C2A 停止。

本次文件清单（同文件内并行差异不算本阶段实现）：

| 范围 | 文件与核心接口 |
|---|---|
| 新载荷/服务 | [CommandDraftPayload.swift](../AreaChain/Services/Privacy/CommandDraftPayload.swift) / CommandDraftContents、CommandDraftEditingState；[SealedCommandDraft.swift](../AreaChain/Services/Privacy/SealedCommandDraft.swift) / seal、open；[CommandDraftContentSession.swift](../AreaChain/Services/Privacy/CommandDraftContentSession.swift) / protect、acceptRevision、explicitlyRestore、withRestoredContents、CommandDraftCheckpoint |
| 草稿领域 | [CommandDraftProtection.swift](../AreaChain/Domain/CommandDraftProtection.swift)、[CommandDraft.swift](../AreaChain/Domain/CommandDraft.swift)、[CommandDraftTargets.swift](../AreaChain/Domain/CommandDraftTargets.swift)、[CommandDraftSession.swift](../AreaChain/Domain/CommandDraftSession.swift)、[CommandArgumentValidation.swift](../AreaChain/Domain/CommandArgumentValidation.swift) |
| 计划/所有权/导出 | [CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift)、[CommandPlanValidation.swift](../AreaChain/Domain/CommandPlanValidation.swift)、[CommandPlanSemantics.swift](../AreaChain/Domain/CommandPlanSemantics.swift)、[CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift)、[CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift)、[CommandHandoffContract.swift](../AreaChain/Domain/CommandHandoffContract.swift)、[CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift) |
| 无内容错误投影 | [UnifiedSearchOperationCopy.swift](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift)、[UnifiedSearchPlanCopy.swift](../AreaChain/Features/Search/UnifiedSearchPlanCopy.swift)、[Localizable.xcstrings](../AreaChain/Resources/Localizable.xcstrings) 的 unified.operation.protected |
| 合成回归/性能 | [CommandProtectedDraftTestSupport.swift](../AreaChainTests/Services/CommandProtectedDraftTestSupport.swift)、[CommandProtectedDraftTests.swift](../AreaChainTests/Services/CommandProtectedDraftTests.swift)、[SealedCommandDraftTests.swift](../AreaChainTests/Services/SealedCommandDraftTests.swift) |
| 原有文档与检查器 | 本文 §9.50/§9.51、[组件目录](component-catalog.md)、[架构](architecture.md)、[技能路由](../skill-routing.md)、[check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py) |

### 9.52 阶段 4A-3C2B：原生接受与锁定交错的隔离可行性

2026-10-03 开始，跨日续验。仅合成 PrivacyQA；不接生产、handler、完整敏感转交、真实认证或磁盘草稿。§9.50 为设计来源，§9.51 的 C2A 载荷/保护拒绝继续有效。本节区分应用接受、原生暂存和密文；最终状态与实际结果在本节末尾登记。

#### 三种状态与受控持有

- **应用修订 A**：唯一 Coordinator 的 active 草稿 stamp、lease 和 protectedReference。先沿原 SealedCommandDraft / CommandDraftPayload / VaultKeyAccess 建立密文，再经原 acceptProtection 提交。普通 acceptRevision 接口与基线不变校验保留。
- **原生状态 N**：专用 CommandProtectedTextView 的 textStorage 与 UTF-16 单选区。仅 ContentSession 在同步 `attachNative` / `presentNative` 窗口可调用 `installProtectedContents`；外部直接调用安装方法被拒绝。不是任意 `withRestoredContents` 回调可缓存正文的新许可。
- **恢复点 C(A)**：同一应用修订的完整 arguments、baseline、CommandDraftEditingState。原生接受成功后，字段 spelling / selection 与 N 一致。检查点成功但锁定先于原生更新时，A 与 C 已前进，N 被清空；这是“已保全但未显示”，不是原生接受成功。候选失败则 A/C/N 保留前一已接受状态；锁定时 N 清空，恢复仍只取 C。

明文基线和其他参数只在原 ContentSession.restored，专用原生 owner 只取得 notes 字段。临时候选只存在 MainActor 同步栈；不放入 Task、异步闭包、日志、摘要或生产预览。undo/redo 闭包只捕获 SealedCommandDraft 密文，并归本控件独立 UndoManager；不使用/清除整个窗口的历史。撤销旧文字须在当前访问下解密旧点，经过相同基线核验、重新加密、Coordinator 提交，再显示为新修订。撤权清当前正文、选区、marked 状态和本控件撤销密文；重新显式恢复后历史为空，不承诺恢复系统 undo 栈，也不承诺进程内所有 String 已零化。

#### 生命周期与最小契约变化

`explicitlyRestore` 仍是用户恢复动作入口；成功恢复切换服务 epoch，避免恢复重入让旧候选继续提交。解锁通知只撤权。`attachNative(owner, using:)` 必须验证 C2A access、当前 active 位置、宿主与版本，且一次只有一个原生 owner。`acceptNative` / `undoNative` 共用原 acceptRevision 的校验/封存实现；只有该次验证通过的同步原生提交能把暂持关系移交到新 access，旧 access 不续期。协议没有每次编辑调用 explicitlyRestore。

DaybookAppKitTextView 仅解除 final 供隔离子类继承，旧 DaybookTextEditor / SyntaxTextEditor 的默认构造、系统撤销、组词、delegate、保存/提交均未改。原生字段的 string 直接赋值拒绝；程序化同步必须携当前 access，旧回声不能补领新资格。重入撤销当前会话，旧候选不能再通过 epoch/lease 检查。失焦、卸载、宿主切换须调用 end；下次编辑必须重新显式恢复。独立窗口失焦与外部 Coordinator 修改的完整自动接线以实际实现/测试为准，不因每次操作有验证便宣称所有未触发回调的显示都已清理。

active 是本阶段唯一原生接线位置；planItem 的 attach 明确 unsupported，不把正文复制到 active。原 C2A 的 plan/retained/pending 保护、执行与转交拒绝保持，plan 原生接线单独留后续。未配置普通输入仍是运行内明文，不自动落盘；转换失败不降级保护记录，沿原 notProtected 规则保留普通稿。

#### 原生入口可行性矩阵

下表“程序化”指正常 QA 应用内真实 AppKit 方法调用，不等同真人键盘、中文候选窗或 VoiceOver。最终运行结果见末尾；未通过项不得按此设计表算支持。

| 原生入口 | 拦截点 | 恢复点 | 失败处理 | 证据类别 / 开放状态 |
|---|---|---|---|---|
| insertText、明确 replacementRange | 专用 override 在调用原生写入前构造完整替换文本；校验 Unicode/UTF-16 范围 | 同步 acceptNative 完整 payload | 保护失败保持旧 A/C/N；失效清 N | 程序化原生测试；仅隔离子集 |
| 普通前删/后删、单选区替换、换行/Tab | 显式纯文本事务；删除按 composed character range | 同上，每次接受独立修订 | 拒绝非法范围，不拆 surrogate | 程序化原生测试；词/段删除等未列入口不开放 |
| 多行粘贴 | readSelection 仅接 string，测试用 unique pasteboard | 插入前同步完整检查点 | 不接受富文本/附件；失败不标成功 | 程序化 AppKit 方法；真实系统剪贴板未读 |
| 选区变化 | 单选区 override；多选区拒绝 | 同修订 editing selection | 校验失败保留旧选区 | 程序化验证；拖选连续时序未覆盖 |
| undo/redo | 本控件 UndoManager → undoNative | 旧密文在当前资格下重封为新修订 | 锁定清本历史；不从旧 access 恢复 | 程序化原生测试；系统菜单/事件链另需验证 |
| 程序化同步 / delegate 回声 | synchronize 要求原 access；didChangeText 不提交 | 只有明确同步可产生新点 | 旧版本拒绝，无文本变化回声不重复加密 | 程序化测试 |
| setMarkedText / unmarkText | 在 super 前拒绝，不强制结束组词 | 不产生检查点，不谎称旧 C 包含 IME 暂存 | 保留旧 A/C/N；返回固定 compositionUnsupported | **不可安全开放**；普通 AppKit 对照验证更新/确认/取消 |
| 失焦 / 卸载 | end 撤服务 owner 并同步清本控件 | 锁前已有 C，无末刻补加密 | 不续租；显式恢复才能再显示 | 原生焦点及程序化卸载分别记结果 |
| 外部 mutable textStorage 写入 | didProcessEditing 才能检测，已是事后 | 没有该外部输入的检查点 | 撤权清 N，保留原 C；明确未保全外部输入 | **不可安全开放**，具体反例下述 |
| 系统服务/拖放/替换/辅助功能写入 | shouldChangeText 未获本次内部安装许可即拒绝 | 无 | 拒绝；绕过 delegate 的路径不在支持集合 | 部分拒绝测试；各系统实现未覆盖 |

最小反例一：`setMarkedText("zhong", …)` 的输入法可能仍持候选/拼写；应用拒绝后没有接受新修订，旧密文只有之前正文，无法承诺 zhong 已保全。程序化 setMarkedText 不观察真实系统 IME 私有存储，因此真实中文候选窗仍未覆盖。

最小反例二：持有 `editor.textStorage` 的调用者直接 `replaceCharacters`；可绕过 insertText/shouldChangeText。检测在字符变更后，撤权清理不能把它变成接受前保护，新增字符串没有密文恢复点。此故障是“不受支持的输入可能丢失”，不冒充已接受修订无损。当前探针不能作为通用受保护 NSTextView 开放。

#### 逐点失败注入的判据

| 注入 | 最后应用修订 / 原生 / 可恢复内容 | 资格与损失判定 |
|---|---|---|
| 初次恢复的 open 后锁定 | 原 A/C 保留，N 从未安装 | 无 access；未接受新输入 |
| 候选编码/加密失败 | 原 A/C/N 保持 | 原资格仍合法时保留；失败候选未接受、未保全 |
| 建点前锁定 | 原 A/C；N 清空 | 撤权；旧已接受内容可恢复，新候选未接受 |
| 建点后、原生接受前锁定 | 新 A/C；N 清空 | 撤权；新内容可恢复，但不算已原生显示 |
| 原生回调重入 | 外层候选因 epoch 过期失败，旧 A/C | 撤权清 N；内外候选均未接受 |
| 接受后旧回声 | 新 A/C/N 不变 | 旧 access 拒绝；不发布旧内容 |
| 组词更新期间锁定 / 带候选请求卸载 | 原 A/C，N 清空 | 受保护 marked 从未接受；系统候选未保全不能算无损 |
| undo/redo 封存期间失效 | 撤销前的 A/C 保留，N 清空 | 无资格/本控件历史；不得显示旧正文 |
| 失焦 / 卸载 / 旧宿主回调 | 最后 C 保留，N 清空 | 旧回调拒绝；不自动续租 |

每项实际断言位于 CommandNativeEditingTests / CommandNativeFailureTests，比较 Coordinator 状态、控件文本/marked/选区、可解密载荷、access 和本控件 undo；仅使用合成值。测试和探针存在不等于测试已通过。

#### 验证与停止边界

性能测试按正文 UTF-8 1 KiB / 64 KiB / 1 MiB，每档先装入，再逐次插入六个汉字；每次单独建立检查点，计时涵盖候选构造、payload 编码/加密、Coordinator 提交、新 access、textStorage/选区安装及 undo 注册，不含后续绘制和系统 IME。基线固定为合成短文本；首样本不是冷进程，后续五次为本档热样本；不把 C2A 加密微基准当逐键结果。只输出长度、时间和检查点次数，不输出正文。没有性能预算/内存峰值/真实逐键时限保证。

指定 Cursor verifier 在本会话无可调用工具，未执行；不重复登录、不改认证、不以主代理检查替代。4A-3B2 最终原生重验、真人中文候选窗、VoiceOver、减弱动态、最低支持系统和历史外观/多窗口缺口保留。正常/最小尺寸、中英文/主题的产品长文面板未接线，不能由本探针外推。下一阶段最多继续隔离的 active notes、明确版本纯文本事务研究；**不允许据此开放敏感生产编辑、通用 IME、planItem 或完整转交**。本阶段结束即停止，不进入 C3。

#### 上轮实际证据与续验前 partial 状态

**2026-10-04 续验前快照：实现已写入，最终原生与编译验证未完成，不具备开放条件。以下保留上轮历史，最新状态以本节末的“编译续验与停止交接”为准。** 本节前述状态机/处理表是实现意图与测试判据，不是全部已通过的结果。不能将旧版某条通过外推到最后的修正。

| 检查 / 版本 | 实际结果与限制 |
|---|---|
| 初次正常 PrivacyQA 编译 | 成功取得原 build/.build.lock；编译失败于 NSTextStorage 类型名及 epoch 局部遮蔽，随后修正。未修改目标、排除源码或绕过正常入口。 |
| 第二次完整 QA 目标 + 五套定向测试 | `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.03_23-53-55-+0800.xcresult`：44 项，29 passed / 15 failed / 0 skipped（含参数运行口径 32 passed / 15 failed）。新子类错误使用便利初始化，触发未实现 init(frame:textContainer:)；旧 InputSyntaxInteractionTests 一项窗口焦点未就绪，foreground 为 Codex。没有修改旧测试或降低断言。此时 C2A 两套回归通过，但后续服务有编辑，不能当最终回归。 |
| 第三次完整 QA 目标 + 新原生两套 | `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.04_00-01-43-+0800.xcresult`，读取最终汇总为 11 项，3 passed / 8 failed / 0 skipped；部分参数未完成，测试取消。nil textContainer 未建立文本系统，原生正文为空，应用检查点却前进；这是实测不一致，不能允许丢字。undo 回调内 removeAllActions 触发 `_endUndoGroupRemovingIfEmpty` 异常，runner 长时间停滞。仅对本任务 runner 发送正常中断（退出 75），未停止其他任务、未删除锁。 |
| 已写入但未重验的修正 | 显式创建 NSTextStorage → NSLayoutManager → NSTextContainer；安装后校验文本/选区，失败关闭会话；独立 UndoManager 撤权先禁止 undo/redo，当前调用退栈后清密文历史，避免破坏运行中分组；窗口失去 key/关闭同步 end；安装期间再次核验受控 owner。这些修改尚未获得新的 Swift 编译或运行证据。 |
| 下一次正常非阻塞申请测试锁 | 退出 3，`C2B: test lock unavailable; native execution stopped`。按用户指令停止原生执行，未再尝试测试/构建，没有抢锁、删锁或停止持锁任务。最终 Debug 构建/验签未运行；之前测试目标的编译不能覆盖最终源码。 |
| 性能 | 新 `nativeAcceptLatencySamplesIncludeCheckpointAndStorageUpdate` 未完成，没有任何有效的 C2B 原生逐键样本或检查点性能数据。上方 1 KiB/64 KiB/1 MiB、六次插入是测试方法，不是测量结果；不得引用 C2A 数字替代。 |
| 严格局部 SwiftLint | 最终 6 个 Swift 文件实际运行通过；仅语法风格检查，不证明类型、AppKit 行为或保全。 |
| 工作流定向反例 / scripts 回归 | `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v`：87 项通过；完整 `scripts/tests`：207 项通过。新增 NativeOwner/TextView 登记沿原检查器、合成目录和缺符号反例；没有新增检查执行器。 |
| 仓库工作流 / static strict | 检查时 failed：并行主题入口 `DaybookSurface.swift` 缺少已登记的 smallBackground。project-links、Domain、技能、文件大小与本次两个符号登记通过；diff-whitespace、performance-contract、script-tests、shell-syntax、security-static、comment-contract passed。未改他人主题实现、删除检查或等待其工作来凑通过。最后一次命令结果以日志为准。 |
| 指定复核 / 历史原生 / 人工 | Cursor verifier 无工具，未执行、不重查登录、不以其他代理代替。4A-3B2 最终原生重验仍缺失。真实中文候选窗、VoiceOver、真实键盘/系统菜单的完整链路、最低系统/减弱动态、长文面板的语言/主题/尺寸矩阵均未覆盖。 |

原命令均是正常完整 PrivacyQA scheme/app/test target、独立 Bundle ID / DerivedData、临时本地签名、移除六项真实钥匙串授权、串行与 only-testing 筛选。五套为 CommandNativeEditingTests、CommandNativeFailureTests、CommandProtectedDraftTests、SealedCommandDraftTests、InputSyntaxInteractionTests；第三轮只缩小测试方法选择，未排除编译源码。日志 `build/CommandC2B-tests.log`；失败诊断 `build/CommandC2B-diagnostics/`；停滞只读采样 `build/CommandC2B-hang.sample`；中断汇总 `build/CommandC2B-interrupted-summary.json`；静态/脚本日志 `build/CommandC2B-static-final.json`、`build/CommandC2B-workflow-final.log`、`build/CommandC2B-workflow-tests.log`、`build/CommandC2B-script-tests.log`。构建目录未提交，Xcode 可能按保留策略移除旧结果包；这些运行历史不等于包永久可用。

最终可行性分类：**已验证支持：无（最终源码缺运行证据）；仅程序化验证：早一版初次恢复失败、锁定两时点和焦点撤权的部分案例，不能计最终通过；未覆盖：最后修正的所有原生路径、性能及 planItem；不可安全开放：IME 暂存、任意 mutable textStorage/系统绕过路径以及当前整个敏感生产入口。** directMutableStorage 的最小反例目前是架构/API 层反例；该测试在无文本系统版本失败，修正后的真实变更/检测顺序未重验，不把失败测试描述成已证明的安全检测能力。

下一阶段准确范围不是产品接线许可：只能在锁正常可得后，独立请求中续验本阶段 active notes 合成探针及旧消费者；先证明最终 A/N/C 一致、undo 退栈清理、回调和宿主生命周期，再讨论任何进一步接线。planItem、真实 IME、生产参数入口、执行、retained/pending 转交与完整敏感转交没有新增许可。本次停止在 C2B。

本次变更清单（并行的同文件其他差异不算本阶段交付）：

| 文件 | 本次接口或责任 |
|---|---|
| [CommandDraftContentSession.swift](../AreaChain/Services/Privacy/CommandDraftContentSession.swift) | C2A 保护/借用保留；attachNative / validateNative / detachNative / acceptNative / undoNative / presentNative；显式恢复 epoch 修正 |
| [CommandDraftNativeOwner.swift](../AreaChain/Services/Privacy/CommandDraftNativeOwner.swift) | 窄字段暂持/安装/同步清理协议，不给任意借用缓存许可 |
| [CommandProtectedTextView.swift](../AreaChain/Features/Search/CommandProtectedTextView.swift) | 隔离 active notes 原生事务、拒绝路径、专属密文撤销及生命周期 |
| [DaybookTextEditor.swift](../AreaChain/Theme/DaybookTextEditor.swift) | 仅 DaybookAppKitTextView 解除 final；旧默认行为原样保留 |
| [CommandNativeEditingTests.swift](../AreaChainTests/Features/CommandNativeEditingTests.swift)、[CommandNativeFailureTests.swift](../AreaChainTests/Features/CommandNativeFailureTests.swift) | 真实 AppKit API、Unicode、独立撤销、回声/身份、失败、组词拒绝、性能及合成 QA 夹具 |
| [组件目录](component-catalog.md)、[架构](architecture.md)、[技能路由](../skill-routing.md)、本文 | 本次边界与单一权威交接 |
| [check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py) | 新接口登记、合成目录与缺符号反例 |

主代理最终只读核对原 PrivacyVault / VaultKeyAccess / VaultCrypto / SealedDiaryDraft 无差异；没有改认证、锁顺序、密钥生命周期或磁盘格式，没有连接生产/handler、提交、推送、安装、发布或启动生产应用。保留全部既有并行修改。

**最终文档后复跑**：并行主题任务随后补齐 smallBackground，主代理未修改该实现。重新运行 check_workflow.py、quality_gate.py --profile static --strict --format json、六文件严格 SwiftLint 与 git diff --check，均 passed；前述失败作为历史保留。最终静态通过不改变原生/构建未验证、无性能样本及指定复核缺失的 partial 结论。

#### 2026-10-04 编译续验与停止交接

**当前结论仍为 partial：最终应用源码已通过 Debug 编译和静态验签；原生最小复现申请锁失败，未调用测试命令，原 8 项失败均未复验，性能无样本。C2B 未完成，暂不允许增加隔离接线。** 本轮只修编译歧义并维护本 §9.52；没有修改测试成功定义、断言、保护服务或生产入口。

**实际修改与编译**：`CommandProtectedTextView.swift:25` 将文本容器高度从 `.greatestFiniteMagnitude` 明确为 `CGFloat.greatestFiniteMagnitude`。本轮第一次 `./scripts/build.sh --no-wait` 退出 65，编译器在这一行同时找到 CGFloat / Double 候选；修正后相同命令退出 0，Debug 构建及 `staticSignatureVerified: true` 通过。日志分别为 `build/CommandC2B-resume-build.log`、`build/CommandC2B-resume-build-typed.log`。沿现有 development 签名配置与 `build/development-DerivedData`，没有改变个人配置、联网申请签名资源、安装或启动产物。环境为 macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113）、Swift 6.3.3。构建的最后相关 Swift 变更就是本行；之后仅编辑本文。正常应用目标成功不表示完整测试目标已重新编译。

本次六个相关文件的 SHA-256 前缀用于辨认源码：TextView `fa268897830f1336`，ContentSession `eb648a2d6c5353b7`，NativeOwner `c68b2c93fcfb5985`，DaybookTextEditor `282252740c466724`，CommandNativeEditingTests `623a65b86fd19157`，CommandNativeFailureTests `6934b549fcab04c7`。后五个文件本轮没有编辑；不将前轮初始化、撤销和检测修正算作本轮新修复。

**锁与桌面**：两次构建各通过原锁执行；随后原生最小复现的非阻塞 `flock(LOCK_EX | LOCK_NB)` 返回不可用，退出 3，日志 `build/CommandC2B-resume-minimal.log` 只有 `C2B: test lock unavailable; native execution stopped`。未启动 xcodebuild test、未生成本轮 xcresult、未重复申请、抢锁、删锁、等待或终止持锁任务；交接不推断锁后来已释放。准备命令保留正常完整 scheme、`build/PrivacyQA`、独立 QA Bundle ID、本地临时签名、生产 entitlement、`LSUIElement=NO`、六项真实钥匙串变量清除和串行选项；选择插入一致性与 undo/redo 失效两个原方法，没有排除编译源码。只读系统状态报告控制台会话，但没有完成本轮 QA key window / first responder 断言，所以桌面可交互条件尚未充分验证。未解锁系统、输入凭据或更改安全设置。

**原失败逐项核对**：本轮重新读取原 `00-01-43` 结果包的 `test-results tests` / `test-details`，与中断汇总一致：11 项中 3 通过、8 失败，参数口径为 4 次通过、8 次失败。下表位置是当前源码定位；原始包部分条目只返回符号或 runner 诊断，不臆造旧包行号。`E` 指 [CommandNativeEditingTests.swift](../AreaChainTests/Features/CommandNativeEditingTests.swift)，`F` 指 [CommandNativeFailureTests.swift](../AreaChainTests/Features/CommandNativeFailureTests.swift)。

| 原失败方法 / 分类 | 原始失败位置与证据 | 最后相关修正及本轮复验 |
|---|---|---|
| `insertionReplacementDeletionPasteAndSelectionHaveExactCheckpoints`；初始化 / 实际编辑 | E:13 → `expectCurrent` E:160：显示为空；E:168 选区 0 与检查点 10 不同，后续编辑还出现载荷/拼写不一致 | 前轮已显式连接 storage/layout/container，并在安装后核对正文和选区；本轮补 CGFloat 编译歧义。**应用编译通过，原生未运行**。 |
| `ownedUndoRedoReprotectAndLockCannotRestoreText`；编辑 / undo / 恢复 | E:43、46、56 → E:160：显示为空；redo/恢复仍读到 A 而预期 AB，不能无证据归为纯环境或只归为分组问题 | 文本系统和安装核对、独立 manager 退栈清理已写入；仍需分别验证编辑、undo、redo、锁定后恢复。**未复验**。 |
| `staleSyncLeaseHostAndUninstallationCannotEditLaterRevision`；身份 / 生命周期 | E:66、68 → E:160/168：新修订应显示 new，但显示空、选区 0/3 不一致 | 文本初始化/安装核对，以及前轮窗口撤权与旧 owner 不撤销新 owner 的逻辑。**未复验**，不能将后半段卸载断言存在当作通过。 |
| `protectedMarkedUpdatesConfirmCancelStayRejectedAndOrdinaryAppKitComposes`；组词拒绝 / runner | 方法 E:83；原包只报 runner 在完成测试前以 0 退出，未给出失败语句；涉及 E:93 的 cancel 和 E:96 后普通 AppKit 对照，具体退出点未定位 | 受保护初始化修正已编译；组词测试/普通对照未改。**未复验，提前退出原因未证实已修复**。 |
| `directMutableStorageIsAnExplicitAfterMutationCounterexample`；旁路 / 清理 | E:117 issue 为 nil；E:118 正文空但 access 仍存在；旧 nil storage 的可选调用没有证明实际写入或检测 | 前轮已建立文本系统，当前 didProcessEditing 先标 unsupportedMutation，再 end。**未复验**，未证明真实回调内清理可稳定完成。 |
| `sealAndEncodingFailureKeepVisibleAcceptedRevision`；失败完整性 | F:27、34 → E:160：旧已接受正文应仍可见但为空 | 初始化与安装核对已编译；原失败注入/负选区拒绝断言保留。**未复验**；不得写成真实加密故障全路径已通过。 |
| `nativeReentryRevokesOuterCandidateAndOldEchoCannotPublish`；重入 / 旧事件 / 重复恢复 | F:68 → E:160：重新恢复后显示空 | 前轮显式恢复 epoch、owner 核验和文本初始化修正已编译。**未复验**。 |
| `undoAndRedoInvalidationNeverRevealHistory(redo:)`；undo 分组 / 清理 / 中断 | F:72；原包只有 `redo=false` 的 canceled 记录，F:80 对应撤销调用；`redo=true` 没有运行结果。前轮另记录 `_endUndoGroupRemovingIfEmpty` 异常/停滞 | `CommandNativeUndoManager.revoke` 先禁用，等 `super.undo/redo` 返回再 removeAllActions（TextView:264、269、275）。**仅编译通过，两个参数均未复验**；没有绕过撤销或锁定检查。 |

原包其余三项是 `focusedNativeLifecycleRevokesOnBlur`、`initialRestoreFailureNeverInstallsNativeText`、`lockBeforeCheckpointOrAfterCheckpointBeforeNativeAcceptance`（false/true 均有旧通过）。它们也没有最终源码复验。更早五套运行的 InputSyntaxInteractionTests 焦点失败仅能证明当时窗口未就绪、前台为 Codex，不能推断唯一原因；本轮保留 `NativeSyntaxUI.prepareFocus` 和原断言，未重跑旧编辑器测试。原包没有 `markedUpdateLockAndUnmountNeverPretendIMEWasPreserved`、`planLocationIsExplicitlyClosedWithoutCopyingToActive`、性能方法或 undo 的 true 参数结果；这些是**未完成执行**，不是 skipped，更不是拒绝验证通过。本轮不进入 planItem 开发。

**最终边界矩阵**：A 为应用修订，N 为原生显示，C 为密文恢复点。下列“恢复点覆盖”是源码路径与待验证判据；全部原生行都缺最终运行证据。“编译是”仅指完整应用目标，测试目标本轮未重新编译。

| 原生路径 | 最终应用代码编译 | 实际测试结果 | 恢复点覆盖 | 剩余限制 | 允许继续隔离接线 |
|---|---|---|---|---|---|
| 普通插入、前后删除、单选区替换、多行纯文本粘贴 | 是 | 原失败；本轮未运行 | 代码先 seal C、acceptProtection 更新 A，再 presentNative 更新 N | A/C/N 及 Unicode/选区一致性尚未复验 | 否，先修验现探针 |
| 编码/封存失败 | 是 | 原失败；本轮未运行 | 候选失败应保留旧 C/A/N；失败候选无恢复点 | 当前注入为 seal 前抛错和无效载荷，不能冒充底层加密全部故障 | 否 |
| 建点前锁定、建点后原生接受前锁定 | 是 | 原版两参数通过；本轮未运行 | 前者只留旧 C；后者新 C/A 可保留、N 应清空 | 后者不算原生接受；还需明确核对失败 issue/回执，不能凭 checkpointCount 判成功 | 否 |
| 锁定清 textStorage / selection / undo / access | 是 | 原版部分通过且 undo 中断；本轮未运行 | 没有末刻补加密，恢复只取最后 C | 清理退栈与旧 access 拒绝未复验；不承诺所有内存副本零化 | 否 |
| 独立 undo/redo | 是 | 原失败；本轮未运行 | 旧密文用当前资格重封为新修订 | 分组稳定性未证；现有“其他历史”对照是独立 UndoManager，还不能覆盖另一真实控件的系统菜单链 | 否 |
| 初始化、失焦、卸载、关闭、重复恢复 | 是 | 初始化/重复恢复旧失败，失焦旧通过；本轮未运行 | 恢复安装既有 C；end 撤权清 N | 真实 key window、反复挂卸与外部 Coordinator 无回调清理缺口保留 | 否 |
| 旧版本、旧宿主、重入、迟到回声 | 是 | 原失败；本轮未运行 | epoch/lease/owner 校验应拒绝，不能借旧事件恢复 | 代码校验存在不等于完整事件时序已通过 | 否 |
| setMarkedText / unmarkText | 是 | 原 runner 退出；锁定/卸载组词项未完成 | 不建立候选输入恢复点，代码在 super 前明确拒绝 | **拒绝策略已实现，拒绝后完整性未复验；IME/产品中文输入支持未完成** | 否 |
| 外部 mutable textStorage.replaceCharacters | 是 | 原 nil storage 版本失败；本轮未运行 | **没有外部最新输入的 C**；仅旧 C 可恢复 | **事后检测，不能保证新增内容不进入原生缓冲或不丢失，明确不支持**；清理是否成功也未实测 | 否 |
| 其他系统服务、拖放、替换、辅助功能底层写入 | 是 | 本轮未运行，各系统链未覆盖 | 仅 shouldChangeText 路径显式拒绝；绕过它没有保护保证 | 不将覆盖少量 override 当作覆盖全部 AppKit 输入 | 否 |

旁路的当前检测顺序经源码核对为：外部字符变更 → `didProcessEditing` → 判断非内部安装且 editedCharacters → issue → end → 撤服务资格/清正文与选区/撤销历史。没有写入前拦截，也没有给这次外部输入加密。恢复旧 C 只能找回之前内容，不能宣称最新输入没有丢失。此轮未尝试为任意底层写入重写 AppKit 文本系统。

**性能与回归**：原生链路尚未重新正确运行，因此没有采集性能，也没有用 C2A 微基准代替。现有性能方法指定 UTF-8 1,024 / 65,536 / 1,048,576 字节初值，每档六次各插入 1 个汉字，每次 1 个检查点；计时只覆盖同步完整编辑链路，不含绘制/系统 IME。当前测试尚未提供相同载荷的纯加密独立计时，后续先通过正确性再补分项数据；保留原加密强度与每次修订。CommandProtectedDraftTests、SealedCommandDraftTests 和受影响的 InputSyntaxInteractionTests 本轮均未重跑。没有连接真实库、真实钥匙串或生产应用。

**本轮静态证据**：`python3 -B scripts/quality_gate.py --profile static --strict --format json`、`python3 -B scripts/check_workflow.py`、六文件严格 SwiftLint 和差异空白检查通过；静态门禁内实际运行 207 项 scripts/tests，通过。显式 static 避免 auto/swift profile 启动普通测试宿主。日志为 `build/CommandC2B-resume-static.json`、`build/CommandC2B-resume-workflow.log`、`build/CommandC2B-resume-lint.log`。原包只读提取在 `build/CommandC2B-resume-original-tests.json` / `build/CommandC2B-resume-original-details.json`，不是本轮测试结果。构建产物和日志不提交。

**后续最小方案与停止点**：推荐继续修验现有 C2B 探针。之后独立续验先确认可交互桌面并正常取锁，先运行插入一致性与 undo/redo 失效最小复现，逐个定位组词 runner 提前退出及旁路清理；保留全部焦点、撤销和锁定断言。关键路径稳定后再跑本阶段正常隔离回归及旧编辑器相关方法，最后测完整链路/纯加密两类性能。现有证据只够证明编译修正，尚不足以认定初始化/undo 已稳定解决，也不足以选择扩大设计或有限接线。

最终分类：**已验证可用的有限原生路径：无；明确拒绝的实现路径：组合文本、无版本赋值、非许可 delegate 编辑，但最终拒绝完整性未复验；尚未验证：最终原生链路、测试目标编译、回归和性能；当前设计无法保证：IME 自有暂存、任意 mutable storage 最新写入保全和完整系统旁路。** 指定 Cursor verifier 本轮未执行，未重查登录，也没有其他代理替代；4A-3B2 最终原生、真人中文候选窗、真实键盘/系统撤销菜单、VoiceOver、最低系统/减弱动态及历史外观/多窗口缺口继续保留。PrivacyVault 认证、密钥与 lock 顺序无差异。保留并行主题和计划列表修改；未提交、推送、安装、发布或启动生产应用，未进入长文 UI、planItem、敏感转交或下一阶段。

### 9.53 阶段 3A-0：普通本地设置执行接线的只读核验与最小方案

2026-10-04（Asia/Shanghai）。**本阶段仅核验源码并增补本文；真实设置执行仍未实现。推荐先单项，阻断尚无共同保存能力的多项提交。** 下文“事实”来自本次工作树静态阅读；“建议”均未实施、未获运行验证，拟议符号不是现有 API。不重复修改第 2～4 节已确认的键盘、预览和队列基本规则。

范围仅语言、外观、四象限标题省略和捕获来源标记。开机启动、系统通知、日历同步、隐私、快捷键注册、文件、删除恢复、正文与敏感草稿均不接线；沿通知追踪排除能力，只为核实副作用边界。未调用任何设置方法，包括初始化 AppPreferences；未修改 Swift、handler、路由、组件目录或并行文件。C2B 以 §9.52 末次交接为准：最终应用编译通过，8 项原生失败未复验；IME 拒绝、mutable textStorage 只能事后检测，敏感输入不开放。指定 Cursor verifier、4A-3B2 最终原生和其他历史缺口继续保留，本次只读探索不替代指定复核。

#### 当前写入事实与最小复用表

以下行号为本轮读取时定位，后续以同表稳定符号复核。

| 命令 ID / 路径 | 参数 → 现有类型 | 原设置页写入与权威副作用入口 | 实际消费者与保持项 |
|---|---|---|---|
| `setting.language` / `/setting/language` | 必填 `value`，choice `system/chinese/english` → `AppLanguage` | [SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift):16 的 `$prefs.language` → [AppPreferences.swift](../AreaChain/Services/AppPreferences.swift):75 `language.didSet` → `defaults.set(rawValue, languageKey)` → `notifyChange` | `AppChrome.body`:177 注入 locale；`AppLanguage.resolvedCode`:13。保留存储值 `system`，不冻结为当前 `en/zh-Hans`；system 按首选语言首项判断中文，否则英文。 |
| `setting.appearance` / `/setting/appearance` | 必填 `value`，choice `system/light/dark` → `AppAppearance` | SettingsSections:23 的 `$prefs.appearance` → AppPreferences:83 `appearance.didSet`，依次写 defaults、`applyAppAppearance`、通知 | AppPreferences:143 分别设置 `NSApp.appearance = nil / aqua / darkAqua`；AppChrome 同时使用 `resolvedColorScheme`。存储 `system` 不等于当前视觉为浅色。 |
| `setting.truncation` / `/setting/title-truncation` | 必填 `value`，choice `tail/middle` → `QuadrantTitleTruncation` | SettingsSections:30 的 `$prefs.quadrantTitleTruncation` → AppPreferences:92 的 didSet，写 defaults、通知 | [QuadrantPage.swift](../AreaChain/Features/Quadrant/QuadrantPage.swift):312、377 的 `QuadrantSingleLineTitle` 消费 `textTruncation`；:337 的标题气泡仍从开头预览，不修改标题正文。 |
| `setting.captureSource` / `/setting/capture-source` | 必填 `enabled`，boolean → `Bool` | SettingsSections:66 的 `$prefs.stampCaptureApp` → AppPreferences:100 的 didSet，写 defaults、通知 | [ClipboardCapture.swift](../AreaChain/Services/ClipboardCapture.swift):55 `ingest`、[DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift):109 `addTodo`、[DayBoardMutations+Capture.swift](../AreaChain/Features/Tasks/DayBoardMutations+Capture.swift):21 `addCapturedTodo` 在创建待办时决定 `sourceBundleID`；不追溯改现有记录，也不是显示开关。 |

目录原文在 [CommandCatalog+Settings.swift](../AreaChain/Domain/CommandCatalog+Settings.swift):6～17；参数默认规则在 [CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift) 的初始化声明。四项均仅 `.assign`，无参数默认值、无对象目标；缺值、`.unspecified`、`.clear`、多余/重复参数、错类型必须拒绝。布尔路径尾参是 `true/false`（[CommandPathArguments.swift](../AreaChain/Domain/CommandPathArguments.swift):21），界面“开/关”不另造存储词。choice 别名由原解析器规范化，未知 rawValue 不得在执行时回退 `.system` 冒充有效输入。

四个持久键为 `areachain.prefs.language`、`areachain.prefs.appearance`、`areachain.prefs.quadrantTitleTruncation`、`areachain.prefs.stampCaptureApp`（AppPreferences:64～67）。除初始化装载外，本次检索到的生产交互写入者只有上述四个 Binding；未发现其他生产直接写这四键。AppPreferences 是现有 `@MainActor @Observable` 权威对象，不需第二份设置状态或完整设置服务框架。默认值为 system/system/tail/false；非法枚举存储读取时回退默认，但不修复原始存储。初始化 `init(defaults:)`:128、140 本身会应用进程外观；[AreaChainApp.swift](../AreaChain/App/AreaChainApp.swift):29 还在正常启动时重应用。

#### 通知并非只有界面重绘：真实接线前置

**事实**：AppPreferences:164 `notifyChange()` 无条件通过 `NotificationCenter.default` 发布 `.appPreferencesDidChange`，`object: nil`，不携带字段、来源实例或版本。同值赋值也写存储和发通知，外观还重应用 NSApp；[SettingsPickerConsumerTests.swift](../AreaChainTests/Features/SettingsPickerConsumerTests.swift):52～54 明确期待选择原值增加一次通知。因此现有 setter 只有最终值上的重复赋值等价，没有副作用幂等保证。

| 原通知的生产观察者 | 实际响应及对本阶段的含义 |
|---|---|
| [AppWindows.swift](../AreaChain/Services/AppWindows.swift):105 偏好通知观察、:148 `refreshChrome` | 主执行器刷新窗口 chrome，目前清空/隐藏标题。 |
| [StatusItemController.swift](../AreaChain/Services/StatusItemController.swift):60、183 `refreshCount` | 读取任务/习惯/打卡并更新菜单栏计数、语言及辅助文字，不是持久化回执。 |
| [DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift):171 `observeChanges` | 原通知同时调用 `session.refresh()` 和 `refreshChrome()`；[DiaryEditorSession.swift](../AreaChain/Features/Diary/DiaryEditorSession.swift):110 `refresh` 可读取正文、恢复已封存编辑内容。普通设置不应借此进入正文路径。 |
| [CalendarSync.swift](../AreaChain/Services/CalendarSync.swift):22 `start`、39 `applyPreference` | 已启动且同步偏好为 true 时请求 coordinator 同步；否则停止。请求不等于必然发生日历写入，但可能继续进入同步引擎，不能声称四项 setter 无外部能力。 |

**建议 N（待决定）**：在原 [BoardEvents.swift](../AreaChain/Services/BoardEvents.swift) / AppPreferences 拆出仅四项使用的普通偏好变化事件，包含字段集合、偏好实例/存储身份及修订号。旧四个 Binding 和指令共用该事件；只由需要的展示消费者接收。语言变化让菜单栏刷新本地化、手记窗口仅 `refreshChrome`，不调用 `DiaryEditorSession.refresh`；AppChrome/Observation 继续传播 locale、主题和截断；来源标记仍在后续创建时读取。原日历偏好及其他偏好保留原事件，CalendarSync、正文服务、认证和日历引擎不改。

这会有意改变“四项普通设置广播引起无关刷新”的既有行为，不能包装成等价提取。若不批准该窄通知变更，严格排除日历/正文副作用的真实普通设置接线继续阻断；不能仅在命令通道静默禁通知，让设置页和命令有两套最终业务。这里的进程内事件不等于系统用户通知，不接 NotificationScheduler 或任何通知权限。

#### 目录声明、真实适配与最后执行检查

**事实**：[CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift):68、94 的 binding 只有 `.unwired`，:119 的 `isExecutable` 恒 false；`ordinary()` 只声明未来队列资格。[CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift):74 允许满足声明的草稿入内存计划；[CommandPlanValidation.swift](../AreaChain/Domain/CommandPlanValidation.swift):25 `canSealProtocol` 只证明静态形状。它与 [CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift):26 的 `isExecutable` 均不证明真实业务可执行；`beginNext`:43 也没有偏好核验。

**事实**：[UnifiedSearchOperationEditing.swift](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift):90 仅取 `syntheticBaselines` 或空基线；:194 `requestOperationSubmit` 只显示阻断提示。[UnifiedSearchController.swift](../AreaChain/Features/Search/UnifiedSearchController.swift):104 将提交意图转到该入口；当前构造调用只在测试夹具，生产搜索未装配该 Controller。[UnifiedSearchPlanEditing.swift](../AreaChain/Features/Search/UnifiedSearchPlanEditing.swift) 只经 Coordinator 编辑/入列；没有真实提交服务。§9.47/§9.49 的 UI 禁用不能充当执行门禁。

**建议**：Domain 目录继续表达“无自带执行能力”，不批量把 `isExecutable` 改 true 或给全部目录加 handler。新增一个具体的 `LocalSettingCommandAdapter`（拟名，Services）只映射四个实际 ID，显式注入同一个 AppPreferences；其只读 readiness 给 UI 显示“未装配/缺基线/冲突/可单项提交”等原因，默认没有适配器时保持关闭。所谓真实适配资格，必须同时证明四 ID 的类型映射、共享写入口、存储和副作用依赖就绪、当前宿主/版本有效、单项范围有效；合成目录、布尔开关或 UI 可点击都不能提供这份资格。

运行时绑定视图由目录元数据与该具体适配器组合，明确标记“目录未自带接线 / 本宿主已装配普通设置适配”；其身份绑定当前注入存储，不持久化到目录，也不将协议层的 false 改成授权。没有该绑定时始终 unwired；不能只凭命令 ID 在任意宿主调用 setter。

最终执行函数独立重查上述条件，不接受 UI 传入的 `canExecute=true`。它从 Coordinator 的当前运行快照取输入，拒绝调用者另传一份参数、伪造 attempt、脱离所有权的快照、保护/未知内容、长文/对象/原生选择及本范围之外的任何命令。只读 readiness 与实际 execute 复用同一窄校验函数；即便直接调用 execute，也必须在最后写入前通过。不新增通用注册器、插件执行器、完整 handler 框架或第二套队列。

#### 共享入口、真实基线与单项流程（建议，未实施）

1. 在 AppPreferences 内最小提取四项的 `applyLocalSetting` / `readLocalSetting`（拟名），由原四个属性 setter 和适配器共同使用。属性可保留可写兼容外壳及原 Binding，内部权威值只保留一份；不能“setter 的 didSet 再调用 setter”产生递归或重复通知。原设置页仍即时生效、不进 CommandPlan；命令先预览，只有显式提交才调用同一写入口。保留旧页面同值选择的即时行为，命令的重复提交在适配器入口提前识别，不全局静默改变旧契约。
2. 为该入口注入具体存储读写、普通事件发布与外观应用/核验闭包；生产仍使用原四键与现有枚举，不引入通用存储框架。初始化的外观应用也必须经过注入，不能只替换 setter。AppPreferences 增加运行内存储身份和逐字段修订，用来记录所有经过此入口的写入；不把四个属性复制为另一份可写配置。旧 Binding 的有效写入也推进受影响字段修订，无关字段不制造冲突。
3. 新草稿由适配器读取实际偏好生成 `.ambient + .value/.enabled` 的 `CommandDraftBaseline`，并附来源身份、受影响字段修订及原始键状态的证据。沿原 draft → retained/plan → snapshot 保留证据，不能只在 Controller 另存一个可丢失字典。目录缺省值和 `syntheticBaselines` 不能成为生产事实；没有可靠基线则不可执行。未知/非法存储、无法确认来源和内存值/存储分歧显示诊断，禁止静默修复。缺失键的有效默认与“基线未读取”必须区分；system 保留策略值，不把随系统变化的解析结果当用户编辑。
4. `requestOperationSubmit` 先核对产生事件时的完整 buffer/lease、draft stamp、plan/item stamp、编辑位置和当前展示许可。按原提交范围一次检查全部待提交意图；首阶段只接受恰好一个普通设置，且没有未结束编辑、pending 切换、依赖、结果引用、原子组或未释放 execution。多项/混合/缺参整体拒绝，不选择其中一个执行，也不自动合并成单项。显式 active 单项且计划为空时，通过原 enqueue 转移同一草稿，再沿原 `.sealPlan` / `.beginStep`；不另建临时队列或复制参数。
5. 预检通过后封存仅移动所有权，不产生设置副作用。执行前从同一 `CommandExecutionStamp` / `CommandAttemptStamp` 重新取 resolvedInput，严格映射类型；同时重读该偏好当前值、原始键状态与逐字段修订，比较基线、当前和拟提交值。整个核验→本地写入保持 MainActor 同步临界段、无 await，并设窄重入保护；注入回调不得重入第二次提交。普通页面经过同一入口写入，运行中的另一设置提交不能穿插；这不承诺跨进程 UserDefaults 比较交换。
6. 在存储调用前完成全部可失败的参数/基线检查；写后读回匹配才更新权威可观察值、登记结果及推进字段修订，再应用外观/发布普通事件。副作用前先登记本次运行的本地提交事实，避免同步观察者或迟到回调再次写入。结果通过原 `.result(receipt)` 回到唯一 execution；不由 View 生成成功。保存完成与显示完成分开，不能因原计划在 seal 时清空就显示“已保存”。

现有 [CommandDraftTargets.swift](../AreaChain/Domain/CommandDraftTargets.swift):56 的 Baseline 只有值与可读性，没有存储身份或字段修订。建议只增加普通设置的纯值证据；Domain 不引用 AppLanguage/AppAppearance 等带平台依赖的类型。Draft/Plan 的版本保护参数编辑，不替代偏好修订。基线证据变化必须推进原草稿/项版本，并进入合并等价检查：相同显示值、不同存储身份/修订的两项不得合并。普通转交可以携带证据，接收者重新核验同一存储身份；不能转交成另一个 suite 的执行权限。

#### 单项结果、冲突、重复与回退（建议）

| 情况 | 要求与结果边界 |
|---|---|
| 新提交的当前值与基线一致 | 有效映射且字段修订/原始键证据一致才允许写入。只核对受影响字段；别的偏好变化不造成冲突。 |
| 当前值或来源修订变了 | 同字段冲突；即使 A→B→A 回到原值也不能只凭值相同覆盖。显示原基线/当前/拟提交三者，提供采用当前、明确确认自己的修改、继续编辑；确认必须绑定此次当前值和版本，再校验，不能永久“强制覆盖”。首次发现尽量留在未封存计划中。 |
| 当前值已等于拟提交值 | 来源可靠且无未处理冲突时返回“无需更改”，不写键、不重发事件、不重应用外观；不得把未知写入结果仅凭当前值相等就归给本操作。来源修订变化时先呈现冲突/已由别处满足，再显式接受。 |
| 相同运行/项/尝试重复调用 | 在窄适配器记录本地写入事实与 receipt，重入返回已有结果，不再调用共享入口。原 ExecutionRun.receive:61 只去重回执，不能防止回执之前重复调用 setter；两层都需要。冲突回执、旧版本、旧尝试拒绝，不给旧用户事件换领新 lease。 |
| 存储调用前失败 | 原状态未变才可报告 `failedWithoutCommit`；唯一草稿/运行保留。只有验证没有写入、且下一次仍通过基线/资格检查，才提供 safeLocalReplay。 |
| 调用了 UserDefaults.set 后不能确认读回 | 报 `commitUnknown`，保留运行和原值证据，阻止自动重试/撤销。set 的 Void 返回、同一实例缓存回读都不是磁盘持久确认；不能用“没有抛错”证明永久保存。 |
| 本地读回一致，但外观应用/普通事件派发失败 | 保留“本地已提交、应用反馈失败/待核验”，不再写一次偏好，不倒退为未提交失败。恢复只处理尚未完成的应用步骤，且当前字段仍对应本次提交；后来被改则终止旧应用步骤并报告已被后续修改替代。发布事件只证明派发调用完成，不证明所有异步窗口刷新成功。 |
| 关闭、失焦、转交及迟到完成 | 提交前许可失效拒绝；提交后收起不撤销。原 HostSession 有 execution 时禁止转交。结果归属 run/attempt 和原 ownership generation；展示过期不能销毁运行或把旧 receipt 写给新草稿。协调层处理可信完成时重新证明运行归属，不把它变成旧 UI 事件续租。 |

**成功口径需决定**：保留 UserDefaults 的单项阶段最多证明“该设置已应用，偏好存储当前读回一致”，不声称 fsync、进程崩溃/断电耐久或跨进程原子性。UI 使用该实际口径；外观的 `system` 核验 NSApp 的 nil 策略与 AppChrome 派生值，不以它证明窗口最终像素已经恢复。dark→system 历史视觉缺口仍在。

当前执行协议仅有 notification/calendar 两种副作用，`.committed(outputs: [:], external: [])` 会立即成功（ExecutionRun:86）。若真实适配需要表达上表应用失败，建议只加一个具体 `preferencePresentation` 应用阶段，复用既有 pending/failed/unknown 与重试身份；不要借用“系统通知成功”，也不要把应用失败伪造成存储未提交。单项 local receipt 先登记 committed，再报告应用阶段结果；没有实际步骤的命令可直接完成。另以窄 `noChange` 结果表示目标已满足：成功结束该项、local 保留 notSubmitted，无输出/应用步骤，不允许重试或撤销，不能报“再次写入成功”。这些最小扩展及原结果消费者需定向回归。

封存后的冲突仍属于原 execution；`resolveValidation(.readyForProtocol)`（ExecutionRun:245）不会改基线，不能当作覆盖授权。拟在窄适配器保留绑定 run/attempt、当前字段证据和用户解决意图的一次性确认；继续编辑/采用当前须通过原协调者增加受限的“未提交冲突项返回计划”转移，保持 operation 身份、推进版本、关闭旧尝试。仅限 local.notSubmitted 且无副作用的单项；committed/unknown 永不退回可重放草稿。不要直接拼一个新 draft 绕开原运行。

**执行后撤销暂不开放**。未来最少需要：写前有效值及原始键是否存在/类型、写后值与字段修订、存储身份、run/operation、已完成的应用步骤；撤销前检查当前仍是本次写后版本，检测同字段后续写入及 ABA，不能覆盖旧设置页或其他命令后来修改。没有任何可证明后续写入检测时不给“安全撤销”。缺失旧键不能简单写默认值代替删除键语义。外部直接改 defaults/其他进程目前不受逐字段修订控制，需比对实际存储并保守失效；仅相同值不能证明未被动过。撤销也须经同一业务入口形成新结果，不撤回已发通知、已读正文或日历效果。no-change 无撤销项；命令编辑器的文本撤销不属于此功能。

#### 多项共同保存：当前不满足，不能改成部分成功

**事实**：AppPreferences 没有批量 save、错误返回、共同快照或回滚方法。四个 setter 是四次独立写入/通知，`isLoading` 只用于装载，不能充当事务开关；ModelChanges 管 SwiftData，不包办 UserDefaults/NSApp。原 Plan 支持四项组成原子组（[CommandPlanSemantics.swift](../AreaChain/Domain/CommandPlanSemantics.swift):9），但只约束纯协议结果。ExecutionRun 的原子组拒绝 external effects；目前组中重复同一设置也未在结构层禁止。这些都不是现成多项业务能力。

**推荐分期**：下一阶段只开放单项。最终 execute 必须阻断任何多项设置提交，无论 UI 是否标 atomicGroup；保留全部草稿并明确“共同保存尚不可用”。不得循环单项适配器、静默拆组、部分返回成功，或以失败后逐键设回旧值称原子事务。这是实现依赖尚未满足，不撤销第 4 节的组内一致性目标。

**具体后续方案（独立存储改造，未批准）**：让四项成为同一份版本化普通偏好记录，由 AppPreferences 作为唯一访问入口，在具备可报告提交失败及回滚能力的本地存储中一次提交。例如沿现有 SwiftData 持久层增加一个普通偏好聚合记录，以一次 context 事务写整份值与 revision；提交前完成所有组员映射和冲突检查，失败不发布任何新值，成功后一次发布整份可观察快照。不得继续把四个旧 defaults 键作为并行权威源，也不以成功后逐键镜像写入冒充兼容。schema、初始化次序、旧四键一次导入、版本标记、旧应用回退和迁移失败保留原值都必须单独设计并取得迁移授权；不用现有 ModelChanges 通知广播无关业务。这不是下一单项阶段的隐含工作。

只把四值编码为一个 UserDefaults 字典/数据键可减少逐键中间态，但仍没有真实提交错误/耐久确认，也引入旧键兼容变化，不能据此宣布满足完整共同保存。若要求抗崩溃/重开一致性，后续必须用事务后端及中断/重开证据核验，不能用延迟通知或 `synchronize()` 补造保证。本阶段未选定/实测新后端。

在聚合方案中，组内同一字段重复项须先显式合并或拒绝整组，不能默默取最后一项；整组冲突整组暂停。保存前失败整组无变更；提交不明整组待核验；保存成功则所有设置值同属一个 revision。外观/窗口传播在提交后进行，不能与磁盘承诺为跨系统事务；若应用失败，反馈“整组已保存，展示应用未完成”，只恢复应用步骤，不报某设置未保存。届时需将原子组结果协议窄化扩展为允许整组的 preferencePresentation 阶段，仍禁止逐成员半成功和日历/系统通知效果。提交后回退若要撤回整组，必须验证整组后续修订并以新的整份事务提交；不能撤销已经发生的观察者效果。若用户要求磁盘与所有窗口视觉也同时全成全败，当前平台链路不能给出此保证，保持阻断并重新明确该更强要求。

#### 下一实施阶段的拟改文件与验证范围

下表是实施提示词的最小候选清单，不是本次修改清单；同文件并行变更须重新读取。只有确实需要结果分支或纯值证据时才扩展 Domain，不为一个适配器建立通用框架。

| 拟改文件 / 符号 | 最小责任 |
|---|---|
| AppPreferences.swift：四属性、init、notifyChange、applyAppAppearance | 共享 read/apply 入口、原四键兼容、单份权威值、逐字段版本、存储/事件/外观注入、真实结果；旧页面即时写入。 |
| 拟新增 `AreaChain/Services/LocalSettingCommandAdapter.swift` | 仅四 ID 类型映射、真实基线读取、readiness/最终门禁、单项提交事实与重复调用保护；不持有第二份可编辑参数。 |
| CommandDraftTargets.swift：CommandDraftBaseline；CommandDraft/Session、CommandPlan/Semantics、CommandHostSession/HandoffContract/Coordinator | 最小普通偏好基线证据随原所有权移动；证据参与合并；未提交冲突项的受限返回/重新确认，保护拒绝不变。 |
| CommandExecutionContract.swift / CommandExecutionRun.swift | 单项 no-change 呈现与具体 preferencePresentation 结果映射、真实提交确定性；保持旧 attempt/receipt、未知不重放规则，多项仍在适配入口阻断。 |
| UnifiedSearchController.swift / UnifiedSearchOperationEditing.swift / UnifiedSearchPlanEditing.swift / UnifiedSearchOperationPreview.swift / UnifiedSearchOperationCopy.swift / UnifiedSearchPlanCopy.swift / Localizable.xcstrings | 显式注入适配器与真实基线来源、复用原提交意图、待校验/冲突/应用结果和失败保留；默认未装配继续禁用；中英同步。ParameterField 沿现有 choice/boolean，无须新增编辑控件。 |
| BoardEvents.swift / AppWindows.swift / StatusItemController.swift / DiaryWindows.swift；SettingsSections.swift 仅必要兼容与失败反馈 | 经决定 N 后拆普通偏好事件及最小展示消费者，原四个 Binding 保持即时语义；新事件不进入 session.refresh/CalendarSync。不改正文或日历实现，不替换生产搜索入口。 |
| 现有 AppPreferencesTests、SettingsPickerConsumerTests、SettingsToggleConsumerTests、SettingsButtonTestSupport、SystemPageHost；新增窄适配测试 | 复用随机 suite、原页面、原 QA 宿主，补副作用注入、失败/冲突/重入/重复回执等证据。实际新增公共入口时同步组件目录、路由及相关原文档，不在 3A-0 先登记成已实现。 |

**后续隔离验证（本阶段全未执行）**：

- 存储测试只用随机 suite，清理只限测试 suite；从构造起注入假的外观执行器、私有 NotificationCenter/记录闭包，不接 `.standard`、`.shared`、真实 NSApp、NSWorkspace、日历/正文观察者。存储掉写、读回不匹配、写前失败、写后未知与应用失败分别注入。注入失败只证明处理分支，不冒充 UserDefaults 提供了原生错误回调或磁盘故障实测。
- 覆盖四 ID 全部合法/非法/缺失参数、稳定 rawValue、缺失键与非法存储、真实而非合成基线、同字段/无关字段修改、ABA、其他实例/直接 defaults 改动、旧 lease/draft/plan/item/attempt、重入及重复调用、应用失败不重复本地写入、未知结果阻断、冲突重确认与未提交返回计划。所有多项/重复字段/atomic/mixed 提交都应零写入地拒绝；不能只测按钮不可点。
- 回归原 CommandParameter/CommandDraft/CommandPlan/CommandExecution/CommandHandoff 相关套件，尤其 `CommandAtomicPlanTests.atomicResultRejectsObjectsAndExternalEffectsAndConfirmsWholeGroup`，不要为单项适配放宽原子组。普通设置证据在转交/合并后仍匹配；保护/未知/长文依然不可导出执行。
- 旧页面仍直接挂 GeneralSettingsSection，回归即时保存、菜单取消、同值选择、禁用、重建、四键外键不变、逐项事件次数与失败反馈；不挂启动真实服务的完整 SettingsView。新普通事件用 spy 证明不触发日历请求、不调用手记 refresh，只刷新所需 chrome；其余旧事件消费者行为保留。
- UI 允许执行的后续任务才运行隔离正常 PrivacyQA，标准/紧凑命令宿主及原设置分节，中英、浅深色、正常/最小窗口；AppChrome、实际四象限标题与气泡、失败不丢稿分别取证。测试用窗口级外观或注入探针，真实 NSApp 适配器仅在独立 QA 进程另列证据，不改变日用应用。捕获来源只用纯 `CaptureStamp.bundleID` 合成输入验证，不实际捕获/创建记录。
- 既有 AppPreferencesTests:61 同时写 `syncCalendarEvents`，原 Toggle 套件也含日历/登录方法；后续仅取相关方法或拆分本地四项测试，不因测试名有 AppPreferences 就整套执行被排除设置。现有套件读取不等于此次运行；dark→system 的 `withKnownIssue`（SettingsPickerConsumerTests:124）、真实四象限视觉及捕获消费者注入缺口分别保留。新注入路径可测映射，不能声称三个捕获业务已端到端验证。

#### 两项待决定与准确交接

1. **普通偏好通知是否按建议 N 拆分？推荐批准窄拆分**：仅四项共用入口及必要 chrome 观察者，避免触发日历/正文；保留其他原事件和旧设置页即时行为。这是后续跨消费者行为变更，需要明确纳入实施范围。若维持当前广播，严格排除边界下不能接真实执行。
2. **下一阶段是否接受先单项及 UserDefaults 的有限成功口径？推荐先单项**：以“已应用、当前存储读回一致”为准，不声称崩溃耐久；多项/安全撤销继续关闭，聚合事务与旧键迁移另行定界。若要求本轮后续立即满足多项耐久共同保存，应先开展并批准上述独立存储/迁移阶段，不能将循环 setter 当替代。

下一实施提示词应命名为“3A-1 四类普通本地设置的共享入口、单项真实适配与隔离验证”，明确记录上面两项决定，覆盖映射表、注入副作用、普通事件拆分、真实基线/字段版本、最后门禁、原 Plan/Run 唯一所有权、真实结果/冲突/重复调用/失败保留及旧设置页回归。先在现有隔离 Controller 宿主装配，生产搜索入口未装配是单独前置，不能顺手替换工作台/菜单栏。不得写入用户偏好、迁移存储、执行多项、开放撤销或敏感输入；C2B 与指定 Cursor 复核缺口不豁免。后续测试/构建/取锁权限必须在新任务中明确，本次不启动。

#### 本阶段检查与停止记录

仅修改本 §9.53。执行前核对了 [quality_gate.py](../scripts/quality_gate.py) 的 `PROFILES` / `run_profile`：默认 auto 会受并行 Swift 变更影响；显式 docs 只做工作流、差异、性能清单和注释静态检查，不走 Swift、脚本回归、构建或锁。实际运行 `python3 -B scripts/quality_gate.py --profile docs --strict --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check -- docs/unified-search-commands.md`，均通过；最终文档编辑后复跑同一组检查。docs 门禁识别到 67 个工作树变更路径，属于包含并行改动的静态扫描，不是本阶段改了 67 个文件。没有改检查器或并行文件来消除失败。

追加前后本文旧内容 SHA-256 均为 `4a4565e14b28dc8a58bb6ac78e89e4b9b5eb354e161efb5153b10d3d9abf0a80`，用于确认 §9.52 及更早记录原样保留。本次两项只读探索提供设置消费者和执行协议出处，主代理沿关键写入/通知/基线/提交路径核对；这不是指定 Cursor verifier 的复核或运行验收。

未执行设置方法、AppPreferences 初始化、Swift 测试、原生测试、构建、测试锁申请、登录检查、应用启动、提交、推送、安装或发布；没有 handler 补丁或下一阶段实施。文档/静态通过只证明本次设计记录的引用与规则检查，不证明方案可运行。完成 3A-0 文档交接后停止。

### 9.54 阶段 3A-1A：普通偏好共享读写与事件拆分

2026-10-04（Asia/Shanghai）。本次用户明确批准 §9.53 建议 N：语言、外观、标题省略和捕获来源标记共用窄事件，不再借普通偏好广播请求日历同步或刷新手记正文。已实施生产共享入口和展示消费者接线；本阶段不实现 handler、不接生产搜索、不改用户设置、不进入 3A-1B。§9.53 保留为当时只读事实/建议，下列实际接口取代其中同名拟议接口的未实施描述。

#### 实际接口与唯一权威

| 文件 / 接口 | 责任与证据边界 |
|---|---|
| [AppPreferences.swift](../AreaChain/Services/AppPreferences.swift) `readLocalSetting(_:)` | 同步返回 `LocalPreferenceSnapshot`：source、field、字段 revision、内存权威 value、当前注入存储 raw；每次重读存储，不修复非法值。`storedValue` 是严格规范类型解析，缺失键返回有效默认，非法/不支持/读失败返回 nil。 |
| 同文件 `applyLocalSetting(_:)` | 唯一四项写入路径，接 `LocalPreferenceValue`，返回 `LocalPreferenceWriteResult`。旧可写属性及四 Binding 即时调用；没有入列、封存、重试、撤销、多项事务或通用 handler。 |
| [LocalPreference.swift](../AreaChain/Services/LocalPreference.swift) `LocalPreferenceField / Value` | field 为 language / appearance / quadrantTitleTruncation / stampCaptureApp；Value 分别携带原 AppLanguage、AppAppearance、QuadrantTitleTruncation、Bool，不能表达错配类型或非法枚举。命令 ID/字符串参数校验仍待 3A-1B，禁止用 initialValue 的默认回退校验执行参数。 |
| 同文件 `LocalPreferenceSource / Snapshot / Change` | source 同时有每个 AppPreferences 独立 UUID 和底层 UserDefaults 句柄 ObjectIdentifier；同对象能共享存储句柄但实例不同，事件仍不能跨实例消费。新建同 suite 的另一个句柄不承诺相同身份，身份只在当前运行有效。Change 仅 source、field、revision，无正文、值字典或其他设置。 |
| [LocalPreferenceDependencies.swift](../AreaChain/Services/LocalPreferenceDependencies.swift) `LocalPreferenceStorage / Effects` | 窄同步 read/write、applyAppearance/post 可注入。默认四键读写、NSApp 外观及 NotificationCenter 行为；隔离测试从构造起显式传随机 suite、私有中心/记录闭包和假外观，不靠事后恢复用户设置。其他偏好仍由原 defaults 路径维护。 |
| [PreferenceObservation.swift](../AreaChain/Services/PreferenceObservation.swift) | 四个真实消费者共用订阅、身份/字段筛选和取消。沿原主执行器异步刷新；事件发送返回不代表这些回调已完成。取消或释放后，已排队回调不再执行。 |

`raw` 区分 missing、string、bool、number、unsupported、unavailable。它是 UserDefaults.object 当前搜索域可见值，包含注册默认值等查找语义；missing 仅表示此次查找无值，不是物理持久域/磁盘文件的证明。不复制未知复合负载，不支持用 unsupported/unavailable 作为可重放或安全撤销的可靠原值。初始化仍按旧枚举默认 system/system/tail 和 UserDefaults 布尔转换装载，不自动写回非法存储；初始化没有事件，外观应用经过注入。readLocalSetting 不刷新权威内存：外部直接改 defaults 后，value 与 raw/storedValue 可以不同，供后续适配保守拒绝。

#### 旧设置页与消费者

四个稳定键仍是 `areachain.prefs.language`、`areachain.prefs.appearance`、`areachain.prefs.quadrantTitleTruncation`、`areachain.prefs.stampCaptureApp`；存储值仍为 system/chinese/english、system/light/dark、tail/middle 和 Bool。system 保留策略值；语言按当前首选语言解析，外观仍以 nil 应用跟随系统。没有存储迁移、新偏好数据库或新磁盘格式。

[SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift) 的 `$prefs.language`、`$prefs.appearance`、`$prefs.quadrantTitleTruncation`、`$prefs.stampCaptureApp` 原样保留。共享路径读回一致时立即更新原权威可观察值并调用展示副作用。**旧同值选择仍调用一次写入、一次普通事件；外观仍重应用一次，并推进该字段修订**。旧 Picker 测试只将事件名称/来源观察调整为窄事件，原同值通知次数断言不改。原 AppPreferences 混合测试改为只验证四项和注入外观；其他事件由私有中心中的独立 `isTagsExpanded` 回归核对，不调用日历设置或其他真实能力。

| 实际观察者 | 普通事件 | 其他偏好/数据原路径 |
|---|---|---|
| AppChrome、QuadrantSingleLineTitle | 继续从同一 AppPreferences 的 Observation 读取 locale、scheme、textTruncation，无新通知状态副本 | 原视图/气泡/输入保持，未改标题正文 |
| [AppWindows.swift](../AreaChain/Services/AppWindows.swift) `PanelWindowController` | `.windowChrome` 只接同源语言/外观，调用原 refreshChrome | 原广域偏好仍刷新 chrome |
| [StatusItemController.swift](../AreaChain/Services/StatusItemController.swift) | `.statusItem` 接同源语言/外观，refreshPresentation 用最后已呈现计数重绘本地化/辅助文字，不重查任务库 | board、日期、计时器及旧偏好仍 refreshCount |
| [DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift) `observeChanges` | `.diaryWindow` 仅同源语言 → refreshChrome；主题由 AppChrome/外观应用传播；绝不调用 session.refresh | 旧偏好和 board 仍 refresh + chrome，失活仍 mask，关闭取消订阅。DiaryEditorSession.refresh 正文实现未改 |
| [CalendarSync.swift](../AreaChain/Services/CalendarSync.swift) `start` | `.calendar` 不注册普通事件，四项不能到 applyPreference | 原 appPreferencesDidChange → applyPreference；引擎、认证、事件存储及同步偏好实现未改 |

[BoardEvents.swift](../AreaChain/Services/BoardEvents.swift) 新增 `.localPreferenceDidChange`，Notification.object 为 LocalPreferenceChange；四个旧 Binding 和未来适配同用这个发送端。其他偏好继续 `.appPreferencesDidChange`、nil object 及原业务路径，没有为所有旧事件追补字段/身份。测试其他偏好时必须用私有事件中心；普通事件即使误发到共享中心，观察者仍须匹配完整 source，不能触发生产单例或另一个实例。

捕获来源的三个读取点 ClipboardCapture.ingest、DayBoardMutations.addTodo、addCapturedTodo 保持只在后续创建时读取标记。没有追溯修改记录、真实捕获、创建或文件操作；本轮未作这三个业务入口的端到端验收。

#### 调用、读回、修订与失败保证

- 写前读失败返回 rejection.unreadableStorage；同步重入返回 rejection.reentrant；两者 write.notCalled、readback.notRead，不调用写入。类型化入口本身不接命令字符串，未实现命令预检/冲突裁决。
- write.returned 仅表示写闭包返回；write.threw 仅表示注入调用抛错，不能说未写入。调用后同实例读回严格匹配规范 raw 才标 readback.matches；不匹配是 differs，读失败是 unavailable。后两种均属写入归属/效果不确定，不能映射为 failedWithoutCommit。没有 fsync、崩溃/断电耐久、跨进程原子性或 compare-and-swap 承诺。
- matches 时更新权威值、调用需要的外观、再派发普通事件；appearance/event 各自返回 notCalled/returned/threw。外观抛错不阻止独立事件尝试，不回滚本地值、不重写。returned 不证明 NSApp 之外的窗口最终像素、异步回调或全部消费者成功。注入写入抛错但读回一致也分别保留 threw/matches，不能仅凭最终相等就归因到本操作。
- 写后不匹配/不可读时保留原可观察值，不发布目标展示事件或外观；after 明确保存此时内存值与读回 raw 的分歧。这是新增故障注入路径的保守行为，不是自动恢复。原 Binding 无结果展示能力，若未来要呈现存储异常须另行接反馈；本轮不虚报已保存或吞掉结果后伪装事务。
- 修订按字段计每次已调用写入（包括旧同值写入和注入抛错），不按全部字段共用一个版本；写前拒绝不推进。修订先于 Observation 新值及展示调用登记，重入写入被拒绝。初始化和 read 不增修订，不用 isLoading 延迟通知构造事务。
- A→B→A 经本入口会留下字段修订；外部直接 defaults、另一对象/进程变化不会自动增此实例修订。后续必须比较 source、revision、value、raw/storedValue；仍不能检测所有外部 ABA，同值不能证明无外部写入。没有完整安全撤销证据。

#### 3A-1B 已确认要求与未实施项

已确认且留待 3A-1B：四命令仅开放单项；来源可靠且无冲突、目标已满足时不重写、不重发事件、不重应用外观；同字段变化报冲突；写入未知禁止自动重试；多项共同提交整体阻断并保留计划；安全撤销不开放。多项事务仍是最终交付项，独立设计聚合存储与迁移，不以本阶段共享入口、逐键回滚或延迟通知冒充共同提交。

可复用准确调用是 `readLocalSetting(LocalPreferenceField)` 与 `applyLocalSetting(LocalPreferenceValue)`，并消费 LocalPreferenceSnapshot / LocalPreferenceWriteResult；原四属性继续作为旧页兼容入口。3A-1B 尚须落实四 ID 严格参数映射、真实来源/字段证据随原草稿与计划所有权保存、readiness 和写前最终校验、no-change/冲突/未知与展示调用结果到原 ExecutionRun 的映射、重复 attempt 去重和单项门禁。不能只检查 revision，不能把 Value.initialValue 的初始化回退用于非法命令，也不能把 write.returned 自动映射为持久化成功。生产搜索接入、完整 ABA/撤销、磁盘耐久与多项后端均未获得本阶段实现。

#### 验证、并行范围与停止

初始工作树干净，实施期间出现第八阶段 E 的 Theme、UI 测试、架构/路由/组件目录及检查器改动，均保留。本轮只在共享文档及 COMPONENT_ENTRIES/对应反例追加本阶段条目，没有改动那些并行 UI 实现或补写其历史证据。

实际结果：**实现和隔离回归已验证，整体部分完成**，指定复核和下述原生/历史缺口仍在。

- 初期两次隔离测试非等待取锁退出 3，未启动测试；锁后来可用后正常取得同一 `build/.build.lock` 执行，没有删锁、抢锁或绕过。最终生产配置 Debug 复跑再次因锁忙退出 3，保留该次未运行记录。
- `./scripts/build.sh --no-wait` 的首次 Debug 构建/验签通过，未安装或启动产物。该轮发现的本次 `LocalPreferenceEffects.live` 主执行器默认参数警告已修正；最终代码在下面完整 QA Debug 构建与测试中通过，无本次接口编译警告。正常生产配置的修正后复跑锁忙，因此不把首次产物当作最终代码产物。完整测试 target 编译仍有原有辅助 API 废弃及其他套件 Swift 6 隔离警告，未修改无关文件。
- 最终隔离命令以架构中的完整正常 PrivacyQA 为基础：六项真实钥匙串环境变量均清除，`-derivedDataPath build/PreferenceQA-3A1A`，`PRODUCT_BUNDLE_IDENTIFIER=com.areachain.preference-qa`，`AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements INFOPLIST_KEY_LSUIElement=NO`，`-destination platform=macOS,arch=arm64 -parallel-testing-enabled NO test`；Python 非等待 flock 在整个 xcodebuild 生命周期持锁。没有排除测试源码或改 QA 工程。
- `-only-testing:AreaChainTests/` 后分别选 AppPreferencesTests、LocalPreferenceTests、LocalPreferenceFailureTests、PreferenceObservationTests、SettingsPickerConsumerTests、SettingsLocalPreferenceConsumerTests、MenuBarStatusTests、MenuBarStatusImageTests；显式 `-skip-testing:AreaChainTests/SettingsPickerConsumerTests/appearanceUsesProcessAndHostEnvironment()`，只排除本轮禁止真实进程外观副作用的历史测试，没有跳过焦点断言。xcresult 测试树确认该方法未执行，37 个测试定义、参数化合计 47 次执行全部通过，0 失败/0 预期失败（该排除方法未列入所选计数）。结果：`build/PreferenceQA-3A1A/Logs/Test/Test-AreaChain-2026.10.04_14-39-08-+0800.xcresult`。
- 旧设置页四 Binding：原三个 Picker 和新增捕获 Toggle 直接挂 GeneralSettingsSection，随机 suite 和私有中心；中英文、浅深色，420×560 Picker 和 420×720 捕获宿主，菜单取消/同值、禁用、语言动态传播、重建及四键独立性通过。原 mixed Toggle 套件只调整窄通知观察以保持未来计数，不执行其日历/登录测试。程序化菜单 action、合成键盘/鼠标和绑定断言不是人工操作；尚未覆盖正常/最小生产窗口的全部展示组合。
- 已查看本次 QA 导出的英文浅色、中文深色及动态语言切换三张原设置页截图；设置行及中文长说明保持原布局。没有查看/操作日用应用。四象限真实标题/气泡、实际手记窗口 chrome、真实工作台 chrome 的完整原生矩阵未运行；路由副作用使用与生产相同的 PreferenceObservation 和注入计数断言，不冒充实际 DiaryEditorSession 正文读取或日历引擎运行。
- 严格局部 SwiftLint 覆盖本次 18 个 Swift 文件通过；`python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` 89 项通过；`python3 -B scripts/quality_gate.py --profile static --strict --format json` 通过（含脚本完整回归 209 项）；`python3 -B scripts/check_workflow.py` 与 `git diff --check` 通过。采用 static + 明确定向 QA 替代 swift profile 的无过滤全量测试，因为后者包含本轮排除的真实进程外观及其他设置测试。静态、编译和运行证据分开报告。
- 首轮静态失败来自并行第八阶段 E 尚未完成的三个工程锚点，随后由该任务补齐；新增接口初次使检查器测试夹具缺五个符号，补齐夹具后 89 项及完整 209 项通过。失败没有被隐藏或通过改业务断言消除。

指定 Cursor verifier 沿既有不可用缺口保留，本轮不重查登录、不改认证、不以主代理自查或其他代理冒充指定复核。C2B 的 8 项原生失败未复验、IME 拒绝和 mutable textStorage 事后检测限制、4A-3B2 最终原生、dark→system 历史预期视觉失败及真人/VoiceOver 等缺口均保留。注入外观只证明调用映射，不能宣布 dark→system 修复。

没有修改用户设置、运行完整 SettingsView、启动日用应用、执行用户捕获/正文/同步、接生产搜索或实现 handler；不提交、不推送、不安装、不发布，止于 3A-1A。

### 9.55 阶段 3A-1B：普通设置单项真实适配与隔离验证

2026-10-04（Asia/Shanghai）。本阶段按用户明确决定实现四项普通设置的**单项**适配，只在注入的隔离存储与可控展示副作用下运行。成功限于已执行应用步骤及当前可见存储读回一致；不承诺磁盘耐久、所有窗口像素或异步消费者最终刷新。§9.53 是历史方案，§9.54 的共享偏好与窄事件继续作为唯一业务入口。生产搜索仍未接线；多项事务、迁移、执行后撤销与排除的系统/敏感能力不开放。

#### 实际装配与接口

| 入口 | 责任 |
|---|---|
| [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) `init(coordinator:preferences:)` | 明确注入同一个 Coordinator 和 AppPreferences；preferences 默认 nil，未装配调用拒绝。没有 `.shared`、生产依赖初始化、通用 handler 注册表或可编辑偏好副本。 |
| 同文件 `prepare(_:expecting:)` | 只读原 active/plan 草稿和真实偏好，成功后将基线装入原草稿并推进草稿、项及宿主版本；已有关联证据时只校验，不静默刷新冲突。 |
| 同文件 `readiness(plan:expecting:)` / `submit(plan:expecting:)` | 资格覆盖完整计划和活动草稿；仅恰好一项、无未决编辑/运行才封存。提交使用原 sealPlan / beginStep / run / operation / attempt，不复制参数。 |
| 同文件 `execute(_:)` | 从 Coordinator 当前运行重新取得参数，独立检查装配、四项白名单、参数/目标、基线、完整提交范围、来源和身份；实际写入仅调用 AppPreferences.applyLocalSetting。 |
| 同文件 `rereadConflict` / `resolveConflict` / `returnUnsubmittedToPlan` | 受控重读、采用当前、继续编辑、一次覆盖确认，以及确实未提交单项返回原计划；没有完整冲突 UI。 |
| 同文件 `retryPresentation` | 显式重试原运行中失败的展示步骤；不再写偏好，只重做尚未成功的外观/普通事件调用。 |
| [LocalSettingCommandMapping](../AreaChain/Services/LocalSettingCommandMapping.swift) | 先复用 CommandCatalog / CommandArgumentValidation / Targets，再做实际枚举转换。没有初始化回退或类型强转。 |
| [CommandPreferenceEvidence](../AreaChain/Domain/CommandPreferenceEvidence.swift) | CommandPreferenceBaseline、写入调用/读回事实和具体展示结果；只含普通标量，无 AppKit/SwiftUI 导入或偏好对象。 |
| [CommandHandoffCoordinator](../AreaChain/Domain/CommandHandoffCoordinator.swift) | claimPreferenceInvocation 在 IO 前登记同一操作/尝试；validatePreferenceInvocation 做最后身份核验；completePreferenceInvocation 只把可信事实归入原运行。 |
| [AppPreferences](../AreaChain/Services/AppPreferences.swift) | applyLocalSetting 新增默认兼容的 expected 快照与写前校验；共享入口自身重读原始键后再核验。retryLocalSettingPresentation 复用同一外观/事件依赖且不调用存储写入。 |
| [CommandDraftTargets](../AreaChain/Domain/CommandDraftTargets.swift)、[CommandPlan](../AreaChain/Domain/CommandPlan.swift)、[CommandHostSession](../AreaChain/Domain/CommandHostSession.swift) | 原基线增加 preference；原计划增加 returnedAttempts 与受限的单项返回；原宿主原子移交基线/计划/执行所有权。 |
| [CommandExecutionContract](../AreaChain/Domain/CommandExecutionContract.swift)、[CommandExecutionRun](../AreaChain/Domain/CommandExecutionRun.swift)、[LocalPreference](../AreaChain/Services/LocalPreference.swift) | 原协议增加 noChange、preferenceWrite / preferencePresentation 及对应状态转换；原共享结果保留 Readback 类型别名，增加 snapshotChanged / executionInvalidated 写前拒绝。 |

四 ID 的严格映射为 language → `.value/.choice(system|chinese|english)`；appearance → `.value/.choice(system|light|dark)`；truncation → `.value/.choice(tail|middle)`；captureSource → `.enabled/.boolean(Bool)`。全部只接受 assign。缺值、重复、多余参数、非法 choice、boolean 的字符串/数值替身、unknown/clear/unspecified、对象目标及非四项命令均拒绝。system 是实际策略值，不能用作未知输入的回退。

当前服务提交入口接完整 CommandPlan。active 草稿需先经 prepare，再通过原 Coordinator.enqueue 显式入列；没有新建活动草稿自动提交或 UI 按钮接线。CommandCatalog / DraftCheck / PlanCheck / ExecutionRun 的原 isExecutable 仍为 false；纯协议测试和手工回执不提供运行时装配资格。

#### 真实基线、冲突与所有权

- 基线挂在原 CommandDraftBaseline.preference，携带 captureID、draftID/采集版本、commandID（唯一映射字段）、AppPreferences 实例/存储句柄身份、字段修订、原始键状态及内存/存储值。值投影仍为 ambient/value 或 ambient/enabled。签发登记是适配器私有只读事实，不是另一份可编辑设置；合成 baseline 及复制到其他草稿的证据不能执行。
- missing 与未提供基线不同：缺失键按原 system/system/tail/false 解释为可靠有效值，且保留 missing 原状；非法类型、不支持值、unavailable 和内存/存储分歧不得自动覆盖。读取不会修复原键，也不从存储更新可观察内存。现有 lookup 的注册默认域语义继续遵守 §9.54。
- prepare 推进原草稿/项版本；执行身份绑定当前 plan/item/draft/run/attempt。后续参数编辑保留原始字段证据，执行仍核对当前操作版本。原普通转交可携带证据并继续使用同一适配器；新适配实例没有旧签发登记，须显式重新核验/解决。来源改变报告冲突。不同采集身份的真实基线保守拒绝合并，不能通过合并隐藏多项范围。
- 执行前重新读取，比较完整来源、同字段 revision、raw、内存值与 storedValue。字段 A→B→A 经共享入口可被修订检测；其他字段变化不制造冲突。不承诺检测另一个句柄/进程的全部 ABA，也不提供跨进程比较交换。
- `rereadConflict` 生成一次性确认，绑定当时 lease、草稿版本、旧证据及新快照；`resolveConflict(.confirmOverwrite/.adoptCurrent)` 再读并比对后才更新基线。继续编辑不刷新证据、不授予覆盖；采用当前只改原草稿参数，后续可得到 noChange。确认后任何同字段变化仍被执行前检查阻断；readyForProtocol 不能代替确认。
- 已封存冲突先保留在原运行。returnUnsubmittedToPlan 只接受适配实际记录为拒绝/冲突或 write.notCalled 的单项，并由 Host/Plan 再检查 local.notSubmitted、无展示效果、无输出/依赖、无组及目标计划为空。保持原 item/draft ID、推进版本、记录 returnedAttempts，usedRunIDs 保留；旧 run/attempt 不能复活。committed/unknown/noChange 不能返回可重放草稿。

#### 一次调用、完整提交与完成事实

Coordinator 在任何可重入 IO 前占用 operation/attempt；登记跨适配实例共享，重复请求和同次重入无法取得第二次调用。适配器自身还对 prepare/readiness/execute/resolve/retry 的同步路径设重入守卫。原回执完全相同仍按协议幂等接受，但这不替代调用前占用。

执行路径是资格核对 → 原运行占用 → 真实快照重读 → AppPreferences 再读且比对 expected → 最后 lease/运行核验 → 一次共享写入 → 原运行回执；整段 MainActor 同步、无 await。存储读回调使 lease 失效时 write.notCalled；写入已经开始后的展示失效不撤销事实。占用期间仅查询事件可推进宿主展示修订，其他执行/操作事件拒绝；完成凭内部 invocation 重新核对同一 ownership、run、operation 和 attempt 后入账，不给旧 UI 事件续租。

多项、同字段重复项、混合项、有活动草稿的计划、atomicGroup、依赖和创建输出均在适配边界阻断。submit 拒绝前不封存、不写设置、保留全部计划；绕过提交直接把纯协议多项运行交给 execute，也保留原运行快照并零写入。不会循环单项、拆组或逐键回填伪装事务。

#### 结果映射

| 真实事实 | 原运行结果与承诺 |
|---|---|
| 来源/修订/raw/内存/存储均可靠一致，目标已满足 | `.noChange`；state.succeeded、local.notSubmitted、无输出/展示效果；不调用 applyLocalSetting、不写存储、不重应用外观、不发事件，不生成撤销。 |
| 尚未调用写入；资格/原值不可读或 lease 失效 | rejected / failedWithoutCommit，或 `.preferenceWrite(write.notCalled, readback.notRead)`；保留未提交事实，可经受限返回后重新核验。 |
| 同字段原值/修订或来源改变；共享入口第二次读取不一致 | `.conflict`，local.notSubmitted；保留旧基线和当前证据，阻止静默覆盖。 |
| write.returned + readback.matches，所需应用调用均返回 | `.preferenceWrite`，local.committed、state.succeeded；仅当前可见存储和已执行应用步骤。 |
| write.returned + matches，外观或普通事件 threw | local.committed、state.failed，effects.preferencePresentation.failed；分别保留 appearance/event 事实，绝不回滚或重复写偏好。外观失败不阻止独立事件尝试。 |
| write.threw + matches | local.unknown、state.verificationRequired；保留已经读回的值及实际外观/事件调用事实，即使都返回也不把写入确定归因于本操作。禁止写入/展示自动重试、返回计划和撤销。 |
| write.returned 或 threw + differs / unavailable | local.unknown、state.verificationRequired；不展示成功、不发布目标展示步骤，禁止自动重试或逐键回滚。 |
| 显式展示重试 | 原 external attempt、`.preferencePresentation(.applied(...))`；只重试先前 threw 的步骤，成功步骤不再调用。local 始终 committed。 |
| 展示重试前同字段已变化，包括经共享入口 ABA | `.preferencePresentation(.superseded)`；零偏好写入、零旧展示调用，保留 local.committed；展示为 notExecuted，不给本次展示重试成功或安全撤销结论。 |

write 抛错不等于写前失败；event 抛错也不证明没有派发。窄事件是读取当前展示状态的进程内刷新，显式重试可能再次派发曾抛错的调用；其返回不证明异步消费者已完成。未知写入没有自动核实/重放功能；未来需要单独定义人工核实与运行释放。superseded 保留未解决运行事实，不自动改成新草稿或宣布全部成功。

#### 旧页面、验证与停止

SettingsSections 的四 Binding 不变；旧同值赋值仍调用一次共享写入、外观（适用时）和窄事件，并推进字段修订。PreferenceObservation、CalendarSync 与 DiaryWindows 的 3A-1A 拆分不改：命令只发 localPreferenceDidChange，不触发日历或手记正文刷新。测试直接计数实际注入存储、外观和私有 NotificationCenter / 原订阅路由；不启动日历引擎、正文会话或真实捕获业务。

新增验证文件为 [基本链路](../AreaChainTests/Services/LocalSettingCommandTests.swift)、[边界](../AreaChainTests/Services/LocalSettingCommandBoundaryTests.swift)、[冲突](../AreaChainTests/Services/LocalSettingCommandConflictTests.swift)、[故障](../AreaChainTests/Services/LocalSettingCommandFailureTests.swift)、[身份](../AreaChainTests/Services/LocalSettingCommandIdentityTests.swift) 及 [共用夹具](../AreaChainTests/Services/LocalSettingCommandTestSupport.swift)。文档同步本节、架构、组件目录与技能路由；原 check_workflow 的 COMPONENT_ENTRIES 及反例增加三个稳定入口，不新增验证执行器。

**已实现并通过所列隔离验证；整体部分完成**，指定复核、生产配置构建及历史缺口仍保留。

| 最终检查 | 实际结果 |
|---|---|
| 完整正常 QA 目标构建及定向测试 | `build/PreferenceQA-3A1B/Logs/Test/Test-AreaChain-2026.10.04_16-05-17-+0800.xcresult`：181 个测试定义、229 次执行全部通过，0 失败/0 跳过/0 预期失败；其中新增五套 36 个定义、38 次执行。最终源码包含伪造来源证据的拒绝反例。 |
| 隔离条件与所选范围 | 按架构正常 PrivacyQA 命令，六项真实钥匙串环境变量清除；`-derivedDataPath build/PreferenceQA-3A1B`、`PRODUCT_BUNDLE_IDENTIFIER=com.areachain.preference-command-qa`、`AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements INFOPLIST_KEY_LSUIElement=NO`，macOS arm64、Debug、`-parallel-testing-enabled NO test`。Python 非等待 flock 全程持有原 `build/.build.lock`，没有排除测试源码、替换工程或改签名配置。 |
| 原协议/偏好回归 | 原 Catalog / Parameter / Path / Draft / Protection / Host / PlanOwnership / PlanDependency / PlanMerge / AtomicPlan / Execution / Handoff 及语言与执行集成；AppPreferences、LocalPreference、Failure、PreferenceObservation；均纳入最终结果，纯协议测试仍不代表真实装配。 |
| 旧设置页及消费者 | SettingsPickerConsumerTests、SettingsLocalPreferenceConsumerTests、MenuBarStatusTests / ImageTests 纳入最终结果；四 Binding、同值、取消/禁用、重建、语言传播及窄事件兼容通过。旧页中英文/浅深色隔离分节、原生菜单/鼠标/键盘沿原宿主执行；没有完整 SettingsView 或生产搜索接线，没有新增像素验收结论。 |
| 明确排除 | `-skip-testing:AreaChainTests/SettingsPickerConsumerTests/appearanceUsesProcessAndHostEnvironment()` 未执行，xcresult 树确认不含该方法；它使用真实进程外观，本阶段只允许替身。所选 181/229 不包含此排除项，不把 0 跳过解释为它通过。日历/登录 mixed Toggle 与无关原生/敏感套件不执行，不删除或放宽原 dark→system 断言。 |
| 严格静态与脚本 | 本次 17 个 Swift 文件严格局部 SwiftLint、`python3 -B scripts/check_workflow.py`、`git diff --check` 通过；检查器定向回归 90 项、`quality_gate.py --profile static --strict --format json` 的完整脚本回归 210 项通过。static 配合上述明确选择的 QA 替代会启动排除能力的无过滤 auto/swift profile；不称为全库运行通过。 |
| 生产配置 Debug 构建 | `./scripts/build.sh --no-wait` 退出 3：其他任务持锁，未执行构建；记录在 `build/PreferenceQA-3A1B/debug-build.log`。最终 QA Debug 构建/测试通过不替代正常生产配置构建或验签，该缺口保留，不抢锁。 |

首轮 Optional.none 与 CommandDraftTargets.none 的歧义造成 19 个定义失败、其余 136 个定义通过；显式修正类型后五套新增测试 32/34 通过，再增补边界后旧消费者共同回归 180/228 通过。主代理自查收紧伪造来源证据的校验顺序，最终复跑得到上表 181/229；中间结果不冒充最终结果。期间一次测试非等待取锁退出 3，未启动测试，后续正常取得原锁，没有删锁、抢锁或跳过焦点断言。最后 QA 日志只有既有原生测试辅助 API 的废弃警告，无本次接口/测试新增警告。

指定 Cursor verifier 的既有不可用缺口保留，不重查登录、改认证或用其他代理替代；主代理核对不冒充该复核。C2B 的 8 项原生失败未复验、IME 拒绝/mutable textStorage 事后检测、4A-3B2 最终原生、dark→system 视觉预期失败及真人/VoiceOver 等历史缺口仍保留。

生产 UI 提交接线前仍需：由真实宿主显式装配适配器和真实基线；绑定当前 buffer/lease/draft/plan/item；展示本节有限成功、冲突和未知语义；明确未知/被后来修改替代运行的人工核实与释放；完成指定复核及相关原生验收。多项共同提交仍需独立事务存储、旧键迁移、整组冲突/失败/恢复与展示协议；本阶段不批准或实现这些工作。安全撤销继续关闭，不能将“设回旧值”包装成安全撤销。

保留起始 3A-1A 和并行第八阶段 E 修改；本阶段只增量修改共享文档/检查器，不改并行界面实现。不修改用户设置、不启用生产搜索、不提交、不推送、不安装、不发布；完成 3A-1B 后停止。

### 9.56 阶段 3A-2：四类普通设置的原生提交、冲突和反馈

**当前结论：3A-2R 本阶段本地验收已完成；指定 Cursor 复核缺失，整体治理验收仍为 partial。** 最后两项的实际证据见本节末“最后两项收口”。下文历次失败、锁忙和未运行记录保留历史身份，不改写为当时已通过。

2026-10-04（Asia/Shanghai）。本轮只在原标准/紧凑 QA 宿主显式装配普通设置适配器，允许 UI 调用隔离 UserDefaults 与注入展示副作用。生产搜索入口保持原实现，用户偏好及其他命令不接线；多项共同事务和执行后安全撤销关闭。§9.53～§9.55 保留历史身份，本节记录 UI 增量。

#### 显式装配与实际接口

| 入口 | 责任和边界 |
|---|---|
| [UnifiedSearchController](../AreaChain/Features/Search/UnifiedSearchController.swift) `localSettings:` | 可选显式注入同一 Coordinator 的 LocalSettingCommandAdapter；缺省 nil，未装配继续暂不可执行。仅 language / appearance / truncation / captureSource 四 ID，目录 isExecutable 不变。 |
| [UnifiedSearchSettingEditing](../AreaChain/Features/Search/UnifiedSearchSettingEditing.swift) `prepareSettingDraft` / `requestOperationSubmit` | 从原 editingDraft 采集一次缺失真实基线并发布新 buffer；原生点击与 ⌘Return 共用提交入口。参数、plan、run、attempt 的真值仍从 Coordinator 读取。 |
| [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) `prepare` / `readiness(draft:)` | prepare 按严格白名单确定字段，允许尚未填写参数时读取真实原值；value(for:) 仍负责最终参数校验。已有证据不随刷新而更新；活动单草稿预检不移交所有权。 |
| 同适配器 `report(for:expecting:)` / `canReturnToPlan` / `canRetryPresentation` | 只给出实际登记且仍匹配原运行/尝试的回执和受控资格；返回计划复用原值转移的校验，重试复用原 Run.retryAssessment。没有通用执行闭包。 |
| [UnifiedSearchSettingSubmission](../AreaChain/Features/Search/UnifiedSearchSettingSubmission.swift) / [SettingCopy](../AreaChain/Features/Search/UnifiedSearchSettingCopy.swift) | 在原 OperationPreview 中显示实际结果及受控按钮。ParameterField 与 PlanList 共用真实当前/拟设置值；system 明确为跟随系统。文案在原 xcstrings 同时覆盖 en / zh-Hans。 |

本轮其他修改文件：[OperationEditing](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift)、[OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[ParameterField](../AreaChain/Features/Search/UnifiedSearchParameterField.swift)、[PlanEditing](../AreaChain/Features/Search/UnifiedSearchPlanEditing.swift)、[PlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift)、[PlanButton](../AreaChain/Features/Search/UnifiedSearchPlanButton.swift)、[LocalSettingCommandMapping](../AreaChain/Services/LocalSettingCommandMapping.swift)、[双语资源](../AreaChain/Resources/Localizable.xcstrings)。测试为 [SettingTestSupport](../AreaChainTests/Features/UnifiedSearchSettingTestSupport.swift)、[Contract](../AreaChainTests/Features/UnifiedSearchSettingContractTests.swift)、[Lifecycle](../AreaChainTests/Features/UnifiedSearchSettingLifecycleTests.swift)、[Interaction](../AreaChainTests/Features/UnifiedSearchSettingInteractionTests.swift)、[Presentation](../AreaChainTests/Features/UnifiedSearchSettingPresentationTests.swift)及原 [ResultsTestSupport](../AreaChainTests/Features/UnifiedSearchResultsTestSupport.swift)。文档/守卫增量在本文、[架构](architecture.md)、[组件目录](component-catalog.md)、[路由](../skill-routing.md)、[check_workflow.py](../scripts/check_workflow.py)和[反例测试](../scripts/tests/test_check_workflow.py)；没有改旧设置页 setter、生产搜索入口或并行菜单栏/主题实现。

装配能力、参数/计划形状、当前适配器 readiness 和写前最后核验各自独立。UI 禁用不是授权；submit 及 execute 继续重查原运行输入、偏好来源/修订/原始键证据，并在最后写入前核对显式传入的同一 ReadSession。外观和事件来自注入依赖，不调用 UI setter。

#### 基线、提交范围与结果

开始/恢复普通设置时经 prepare 读取真实偏好，即使参数尚未填写。基线附着原 draft，参数编辑、入列和封存沿原版本协议迁移；prepare 引起修订后 publishOperation 返回新 buffer。重绘和预览不重新 prepare，不给旧原生回调换 lease；实际适配草稿忽略 syntheticBaselines。读取不可靠时显示无法确认当前值，可明确重新读取缺失基线，不用默认值伪装成功。

只接受两种范围：一个活动草稿且计划为空，或没有活动草稿且计划恰好一项。前者明确提交后经原 `.enqueue` 原子移交同一草稿，再提交整份单项计划；后者直接提交该计划。活动加计划、多项、原子组、依赖/创建输出引用、未完成参数/计划编辑、pending 选择、未释放运行及非四项命令均拒绝，零部分写入。Return 仍补全/处理当前控件；⌘Return 与具体动作按钮共用 requestOperationSubmit，同步占用防重复和回调重入。

- noChange：当前已是此设置，零存储写入、零外观/事件调用。
- 真实本地提交且展示调用完成：已应用，说明提交时读回一致，不承诺断电/崩溃耐久或所有窗口像素完成。
- 写前拒绝：保留内容与原因；封存后的确实未提交项只经 returnUnsubmittedToPlan 返回原计划，保留 item/draft ID 和旧 attempt 出处。
- conflict：原值、当前值、拟设置值并列；核对当前值取得适配器一次确认，采用当前 / 确认用我的值覆盖 / 继续编辑只调用受控接口。确认覆盖不会自动提交；同字段再改仍使原确认失效。
- unknown：结果待核实，保留原运行，没有普通重试、释放或撤销入口。
- 本地 committed、展示失败：明确已写入与展示未完成；仅在适配器允许时提供“仅重试展示应用”，不重写偏好。
- 展示 superseded：说明旧展示步骤被后续修改替代，不再重放；运行事实仍保留，不能宣称新设置由旧操作完成。

成功/noChange 后用户明确点击“完成”，只走原 releaseExecution；失败/未知不能借该入口清除。关闭/失焦/锁定仍沿 ReadSession 撤显示，不改变已写入事实、原 run/attempt 或未释放运行的转交阻断。显式重新显示不自动重试。敏感正文、C2B、系统认证和真实系统能力不在本节。

#### 隔离验证与停止交接

验证实现复用 PreferenceCommandIO、LocalPreferenceTestSupport、原 UnifiedSearchTestHost / ResultsFixture、GeneralSettingsSection 四 Binding 和 fake 隐私依赖；标准/紧凑矩阵分别使用 workspace / menubar 原宿主身份。正常完整 QA 目标编译，原 build/.build.lock 非等待持锁，六项钥匙串授权变量清除，测试串行。所有测试状态仍以本节随后记录的实际命令结果为准，源码存在不是运行通过。

**整体部分完成：UI 实现与测试代码已写入；原生 UI 到隔离写入尚未完成验收。** 本轮实际证据如下，不能把中间测试结果当作最终源码的完整通过。

| 检查 | 实际结果与限制 |
|---|---|
| 完整 QA 编译首轮 | `build/SettingUIQA-3A2/Initial.xcresult` / `initial.log`：新增测试夹具的 `#require` 展开缺少可抛错调用处理，退出 65，未运行测试。将调用先单独求值后继续；没有排除编译源码。 |
| QA 契约与服务运行 | `build/SettingUIQA-3A2/Contracts.xcresult` / `contracts.log`：49 个测试定义，**47 passed / 2 failed / 0 skipped / 0 expected failure**；参数化共 61 次执行，59 passed / 2 failed。完整正常 QA 目标已编译，四套新增测试均纳入编译，但此轮只运行新增 Contract / Lifecycle 两套和原 LocalSettingCommand 五套服务测试。 |
| 新控制器契约证据 | 上轮 13 个新定义全部通过：四字段在空参数时读取真实基线、版本发布、唯一所有权、单项/混合拒绝、三类冲突选择/过期确认、unknown 保留、展示重试/后来覆盖、写前与写后撤显示、旧 buffer/lease 拒绝。它们是直接 Controller/Adapter 调用及注入事件，不是鼠标/键盘驱动的原生 UI 通过。 |
| 两处回归与最终修正 | 旧 `unsupportedProtectedUnknownAndExtraArgumentsAreRejectedAtPreparation` 发现 prepare 错误放宽了非空非法参数；现仅允许空参数预读取，非空仍走原严格 value 校验。旧 `laterPreferenceWriteSupersedesOldPresentationEvenAfterABA` 发现新增只读资格把不可重试错误类型改成了 LocalSettingCommandIssue；已恢复原 CommandExecutionError.notRetryable。两处断言未改，但**修正后 Swift 运行未复验**。 |
| 原生取锁与停止 | 准备 `Native.xcresult` 时，原 `build/.build.lock` 非等待独占申请失败，退出 3；`native.log` 仅记录停止。没有启动该轮 xcodebuild/XCTest，没有生成 Native.xcresult，未删锁、抢锁、等待或终止持锁任务；此后停止所有原生执行。`native-command.json` 未生成，不伪造执行命令/结果。 |
| 本轮原生截图与交互 | **0 张新增、0 张实际检查**。四项补全→参数→点击/⌘Return→隔离读回、Return 不提交、按钮焦点/空格、旧 GeneralSettingsSection Binding、双语/浅深色/两宿主/最小宽度、长反馈及窗口失焦/锁定/关闭的原生用例已编译，尚未运行。没有用历史截图、离屏占位或服务测试替代。 |
| 旧设置与 4A 回归 | 已运行服务套件中的旧 Binding 同值写入与普通事件路由断言；没有运行本轮原生 SettingsPickerConsumerTests / SettingsLocalPreferenceConsumerTests，也没有最终 4A 参数/计划/对象/输入回归。明确不运行真实外观 `appearanceUsesProcessAndHostEnvironment()`、日历/登录 mixed Toggle 及两项读取 UserDefaults.standard 的旧 Operation/Plan 生命周期方法；后两项身份/无写入断言由新的独立 suite 场景承接，仍需原生补验。 |
| 最终生产配置 Debug 构建 | `./scripts/build.sh --no-wait` **退出 0**，`build/SettingUIQA-3A2/debug-build.log` 的 `staticSignatureVerified: true`。沿现有 development 配置生成 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`；没有修改个人配置、申请签名资源、安装或启动。此构建发生在两处最终修正后，补齐当前应用源码的正常配置编译/验签；不替代最终 QA 测试目标或原生运行。 |
| 静态与脚本 | 严格局部 SwiftLint、工作流检查、检查器 91 项回归、`quality_gate.py --profile static --strict --format json`（含 211 项脚本回归）及差异检查通过；最终相关编辑后重跑受影响静态项。static 配合明确隔离定向，不运行会启动未隔离/排除套件的 auto/swift profile。 |

实际命令保存在 `initial-command.json` / `contracts-command.json`，正常完整 AreaChain scheme、Debug、macOS arm64；QA 标识 `com.areachain.setting-ui-qa`、独立 DerivedData `build/SettingUIQA-3A2`、local/ad-hoc、原生产 entitlement、LSUIElement=NO、串行，六项真实钥匙串授权环境变量均清除，flock 覆盖整个子进程生命周期。环境为 Xcode 26.6（17F113）、Swift 6.3.3、macOS 26.6.2（25G83）arm64。日志只含合成普通标量及测试诊断，不含用户设置/正文/凭据。

指定 Cursor verifier 既有不可用缺口保留，不重复登录检查，不以测试设施探索或主代理自查冒充复核。C2B 的 8 项原生失败、IME 拒绝 / mutable textStorage 事后检测限制、4A-3B2 最终原生、dark→system 历史视觉问题继续保留；本轮只有当前正常配置 Debug 构建取得新证据。人工 VoiceOver、系统输入法候选窗、最低系统/减弱动态和真实用户多窗口分别未验。没有通过本轮注入外观宣布历史视觉问题修复。工作树仍有并行菜单栏/主题测试及工程记录变化，全部保留；本轮构建证据不覆盖之后出现的并行修改。

续验优先顺序：正常取得原锁后，先重跑 Contract / Lifecycle 和 LocalSettingCommand 五套（确认上述两处回归），再运行 Interaction / Presentation 的原生测试，实际检查截图，最后补相关 3A 协议、4A 参数/计划和隔离旧设置分节回归。仍需指定复核和人工证据；本轮不继续申请原生执行。

下一步仅建议：多项共同提交须先确定事务存储、旧键兼容/迁移、整组冲突及失败恢复协议，不能循环本单项入口；其他命令须各自核实领域入口、输入/结果与副作用，再显式装配，不能因普通设置可执行而批量开放目录。本轮不实施这些建议。不提交、不推送、不安装、不发布、不修改用户设置、不替换生产入口；完成 3A-2 后停止。

#### 3A-2R 验收收口：运行记录与未完成项

2026-10-04（Asia/Shanghai）。**本次收口仍为 partial / 运行验收 blocked**。先核对当前 AGENTS、技能路由、areachain-verify 及其 checks、原生隔离规范、当前修正与原 `Contracts.xcresult`；以下为本次新增证据，上面的 3A-2 记录保持历史身份。只更新本节，保留工作区并行修改，没有新增设置、其他 handler 或多项事务。

**两项原失败与修正核对。** 只读执行 `xcrun xcresulttool get test-results tests --path build/SettingUIQA-3A2/Contracts.xcresult --compact` 并提取失败节点；原结果仍为 47 passed / 2 failed（49 个定义），不是本轮复跑。

| 原失败用例 | 原始断言与原因 | 已有修正文件与当前代码 | 本次结果及仍缺证据 |
|---|---|---|---|
| `LocalSettingCommandBoundaryTests.unsupportedProtectedUnknownAndExtraArgumentsAreRejectedAtPreparation()` | 原测试第 20 行有 4 条“应抛错但未抛错”：language 多余参数、appearance 的 unknown、truncation 的 system、captureSource 的字符串 choice 均错误返回基线快照。prepare 为支持空参数预读而放宽了非空非法参数。 | [LocalSettingCommandAdapter.swift](../AreaChain/Services/LocalSettingCommandAdapter.swift) 的 `prepare` 第 240 行保留 `if !draft.arguments.isEmpty { _ = try LocalSettingCommandMapping.value(for: draft) }`；[原边界测试](../AreaChainTests/Services/LocalSettingCommandBoundaryTests.swift) 的拒绝及零写入/零事件断言仍在。 | **修正已核对，运行未复验**。缺本方法在最终源码下通过，以及空参数真实基线、严格映射和直接契约回归通过的运行证据。 |
| `LocalSettingCommandFailureTests.laterPreferenceWriteSupersedesOldPresentationEvenAfterABA()` | 原测试第 132 行期望 `CommandExecutionError.notRetryable`，实际抛出 `LocalSettingCommandIssue.notRetryable`；新增展示资格检查改变了后续修改使旧展示失效后的错误类型。 | 同一 [适配器](../AreaChain/Services/LocalSettingCommandAdapter.swift) 的 `presentationWrite` 第 362 行恢复 `CommandExecutionError.notRetryable`；[原失败测试](../AreaChainTests/Services/LocalSettingCommandFailureTests.swift) 仍核对 superseded、已提交事实、零写入/零展示副作用和精确错误类型。 | **修正已核对，运行未复验**。缺本方法及展示失败/重试/后续覆盖直接回归在最终源码下通过的运行证据。 |

**一次有界只读锁诊断。** 17:35:18 +08:00，约 0.16 秒完成；以 `O_RDONLY | O_NOFOLLOW` 打开既有 `build/.build.lock`（inode `234750977`），仅一次 `LOCK_EX | LOCK_NB` 探测返回 EAGAIN / Errno 35。该结果为**实际占用**，不是读取失败或把任意 IOError 当作锁忙。锁文件内容为空，不能从中取得持有 PID。

同次 `lsof -nP -Fpcfal` 查询成功：唯一观测到的打开者为 Python **63610**，fd 3、写方式打开；`ps` 确认存活，状态 `Ss`、已运行 `00:46`。其子进程 **63611** 为存活 `xcodebuild`，状态 `S`、已运行 `00:46`，另有存活 DTServiceHub / SWBBuildService。只读取必要进程字段和筛选后的构建参数，没有输出环境变量、凭据或完整命令行。

关联任务为第八阶段 E 修复二的 `AreaChain` / Debug 串行测试：DerivedData `build/PrivacyQA-Surface8E-Fix2`，QA 标识 `com.areachain.privacy-qa`，目标为 `MenuBarHelpSurfaceTests/helpMonitorStopsAfterUnmountAndDoesNotConsumeModifiedEscape()` 与 `MenuBarHelpSurfaceTests/helpEscapePreservesEditorAndPresentation(search:locale:)`，结果目标 `build/SurfaceStageE-fix2-keyboard-final.xcresult`。`lsof` 的锁类型字段为空，故 PID 归属依据为唯一打开者与父子测试链，不能冒充内核直接返回的持锁 PID；进程存活也不等于测试已通过。锁忙和存活测试链足以执行用户要求的停止分支。

本轮诊断后**停止所有测试/构建申请**，没有等待、重复探测、删锁、抢锁、终止持有任务或绕过脚本锁；没有启动 xcodebuild/XCTest，也没有新建 QA 运行产物或截图。桌面可交互检查尚未执行，不能凭其他测试存活推断本轮可交互。此处只记录上述时刻的状态，不推断交接时锁已释放。

**四项原生提交链路。** 已读取原 `UnifiedSearchSettingInteractionTests.completionBaselineParameterAndExplicitSubmission(index:)` 及原夹具入口；源码包含原生输入/参数、基线、明确提交、适配器及隔离读回断言，但本次全部未运行，不作为原生验收通过。

| 字段 | 本轮原生 UI → 实际隔离写入 → 反馈 |
|---|---|
| 语言 `setting.language` | 未运行；待原生输入/参数到隔离存储读回及准确反馈的证据。 |
| 外观 `setting.appearance` | 未运行；待注入外观/事件下的同一完整链路证据。 |
| 标题省略 `setting.truncation` | 未运行；待原生参数选择、明确提交、隔离读回及反馈证据。 |
| 捕获来源 `setting.captureSource` | 未运行；待 Bool 参数、明确提交、隔离读回及反馈证据。 |

点击与 ⌘Return 同入口、Return 不写入、noChange 零写入/零副作用、单草稿入计划唯一所有权、多项零部分写入、同字段冲突三选/过期确认、unknown 无普通重试、展示重试不重写偏好/后续修改使旧展示失效、失焦/锁定仅撤显示及其他命令/未装配拒绝，**均无本轮新增运行证据**。旧 Controller/Adapter 调用结果不替代这些原生链路。

**截图与旧入口。** 本轮新增截图 0、实际检查 0。中英文、浅深色、标准/紧凑、正常/最小宽度及成功/noChange/冲突/unknown/展示失败/多项阻断矩阵未运行；旧设置页四 Binding 与受影响的 4A 参数/计划/输入回归未运行。没有获得最终代码对应的截图证据。dark→system 原历史视觉失败没有本轮定位或运行证据，继续保留，不能用注入外观验证关闭。

**本轮改动与门禁。** 没有修改 Swift 或测试断言；两处代码修正属于原轮。本次仅在同一 §9.56 追加事实与恢复条件。`swiftlint lint --strict --quiet` 指定 `LocalSettingCommandAdapter.swift`、`LocalSettingCommandBoundaryTests.swift`、`LocalSettingCommandFailureTests.swift` 三文件，退出 0、无诊断；`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json` 及 `git diff --check -- docs/unified-search-commands.md` 均通过，最终文档编辑后重跑后面三项。docs 门禁识别的 73 个工作树变更路径包含并行工作，不代表本轮修改 73 文件。显式 docs profile 避免工作区并行 Swift 改动触发未隔离测试，不重跑无关领域或整套脚本测试。正常配置构建与验签本次未申请；上轮通过仅保留历史身份，不视为本次最终源码验证。

**未完成项与恢复条件。** 指定 Cursor verifier 继续缺失；未重复登录检查、未使用自查/测试/其他代理替代。VoiceOver 真人、系统输入法候选窗、最低系统/减弱动态及真实用户多窗口未验；C2B 的 8 项原生失败、IME 拒绝/mutable textStorage 事后检测限制、4A-3B2 最终原生及上述 dark→system 历史缺口保留。

需等待关联测试正常结束并自然释放原锁。后续续验先重新核对工作区与最终修正，在正常取得原锁、确认桌面可交互后，按完整隔离 QA、独立偏好/外观/事件及 fake 隐私依赖，先复验上述两项和直接相关回归；通过后才串行运行四项原生链路、矩阵及真实受影响旧入口，实际检查截图，最后完成最终定向、正常配置构建验签和适用静态门禁。已有来源与修正代码足以界定后续本地续验，但**尚不具备 3A-2 验收通过或进入下一阶段的依据**。本轮到此停止；未提交、推送、安装、发布、启用生产搜索或修改用户设置。

**17:49 续验记录（2026-10-04，Asia/Shanghai）。** 用户再次要求继续后，重新检查工作区、当前两处修正和原锁；不沿用 17:35 的 PID。工作区并行改动保留，无暂存变更，本次只补充本节。结果仍为 **partial / 运行验收 blocked**。

| 本次检查 | 实际证据与结果 |
|---|---|
| 当前锁 | 17:49:21 +08:00，以只读 fd 对既有原锁做一次非等待独占探测，EAGAIN / Errno 35 确认实际占用；诊断约 0.17 秒。锁文件无 PID；不是检测失败。 |
| 当前关联任务 | 本次 `lsof` 唯一打开者 Python **85312**（fd 3，存活 `Ss`，`01:30`），其子进程 xcodebuild **85313**（存活 `S`，`01:30`）。AreaChain / Debug、`build/PrivacyQA-Surface8E-Fix2`、`com.areachain.privacy-qa`、串行 `MenuBarHelpSurfaceTests`；结果目标 `build/SurfaceStageE-fix2-final-help.xcresult`。锁类型字段仍空，归属依据是本次唯一打开者与存活父子测试链，未获得内核直接持锁 PID。未读取环境变量或输出完整命令行。 |
| 两项原失败 | 当前 `prepare` 非空参数严格校验和 `CommandExecutionError.notRetryable` 修正仍在；**两项均未运行复验**，原 47 passed / 2 failed 不变。 |
| 原生、旧入口及构建 | 桌面交互确认、语言/外观/标题省略/捕获来源四条原生提交链路、布局矩阵、旧设置页、4A 回归和正常配置构建/验签均未启动；新增及检查截图均为 0。没有新增运行失败，也没有新增运行通过。 |
| 停止与缺口 | 确认占用后停止测试/构建申请；不等待、不轮询、不删锁、不终止任务、不绕过锁。指定 Cursor、人工及历史缺口沿上文保留。本次未改代码/断言、未修改用户设置、未启用生产搜索、未提交/推送/安装；等待关联任务自然结束及锁释放后，仍从两项失败的定向复验开始。 |

本次文档修改后，`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json` 和 `git diff --check -- docs/unified-search-commands.md` 均退出 0；最终补记后重跑同一组检查。门禁识别的 73 个变更路径包含既有及并行改动；本次只改本文。不因文档补记申请测试锁或重复无关回归。

**17:53～18:25 续验（2026-10-04，Asia/Shanghai）。** 本次取得运行证据，**整体仍 partial：完整矩阵、旧入口回归和最终构建未完成**。17:53:36 的一次只读非等待锁探测成功；桌面预检得到 consoleSession=1、loginComplete=1、screenLocked=false、screenCount=1。随后各次正常 QA 执行在整个 xcodebuild 生命周期持有原锁、结束后释放，没有使用旧 PID 或绕过锁。窗口测试仍保留真实 key-window 断言。

| 本次运行（均在 `build/SettingUIQA-3A2`） | 实际结果与对应源码阶段 |
|---|---|
| `Recheck-3A2R.xcresult` / `recheck-3a2r.log` | **49 个定义、61 次执行全部通过**，0 失败/跳过/预期失败。Contract / Lifecycle 及原五套 LocalSettingCommand 服务测试；两项原失败 `unsupportedProtectedUnknownAndExtraArgumentsAreRejectedAtPreparation()`、`laterPreferenceWriteSupersedesOldPresentationEvenAfterABA()` 均明确 Passed。原 `Contracts.xcresult` 的 47/2 不改写，新的运行补齐其两处修正证据。 |
| `Native-3A2R.xcresult` | 9 个定义中 8 通过、1 失败；19 次执行中 18 通过、1 失败。语言链路 index=0 在 `UnifiedSearchTestHost.key` 的 `window.isKeyWindow` 断言失败；没有足够证据定位外部失焦原因，不归为已修复环境问题。其他三字段链路及 noChange、冲突按钮、旧语言 Binding、展示重试/替代、失焦/锁定撤显示等所选场景通过。此轮参数选择仍含真实菜单 action 派发。 |
| `Native-Diagnostics-3A2R.xcresult` | 增加按键阶段诊断后，四字段原链路与初步面板边界检查共 2 个定义、6 次执行全部通过。没有自动抢回焦点、重试失败按键或放宽焦点断言；该次通过不能解释首轮失焦原因。 |
| `Layout-Diagnostics-3A2R.xcresult` | 新增跨区域断言后，1 个定义的两宿主执行均失败。compact 的结果标题 `(12,158.91015625,185,16)` 与提交按钮 `(24,158,119.5,20)` 相交，结果边界仅 `(12,12,280,138)`；standard 结果标题也超出结果边界。确认是 QA 布局给结果区空间不足，不能把“按钮在窗口内”视为布局通过。 |
| `Native-Controls-3A2R.xcresult` | 修正 QA 布局并把参数选择改为系统菜单键盘事件后，2 个定义、**10 次执行全部通过**：四字段分别点击/⌘Return 的 8 条完整链路，以及 standard/compact 两项区域不重叠断言。此轮完成时间 18:20:33；具体 command/source SHA-256 清单同名保存。 |
| `Native-Matrix-3A2R` 申请 | 新增六结果状态矩阵及原生阻断用例后，正常非等待取锁返回 `LOCK_BUSY`、退出 3，**未启动 xcodebuild/XCTest，未生成同名 xcresult/command/source 清单**。停止后续申请。 |

所有实际测试沿原完整 AreaChain scheme、Debug、macOS arm64、独立 QA 标识 `com.areachain.setting-ui-qa`、原隔离 DerivedData、local/ad-hoc、生产 entitlement、LSUIElement=NO、串行执行，清除六项真实钥匙串授权变量。`PreferenceCommandIO` / `LocalPreferenceTestSupport` 的随机 UserDefaults suite 承担实际写入与读回，外观/事件可注入，隐私仍为内存配置及 FakeSystemVaultKeys。没有改工程或排除源码，没有修改用户偏好；完整测试 target 编译仍有既有辅助 API 废弃及并行菜单栏测试 Sendable 警告。

**两项原失败的最终已运行结果：均通过。** 本次未修改适配器或这两项原测试；它们分别验证非空非法参数仍拒绝且零写入，以及旧展示 superseded 后返回精确 `CommandExecutionError.notRetryable`。这与后续尚未编译的新 UI 测试范围分开。

| 四项原生链路（`Native-Controls-3A2R`） | 点击 / ⌘Return | 实际隔离结果 |
|---|---|---|
| language | 两者通过 | 真实基线为 system，原生参数设为 chinese；单次 `.language(.chinese)` 写入，存储读回一致，显示 Applied。 |
| appearance | 两者通过 | 真实基线为 system，原生参数设为 dark；单次 `.appearance(.dark)` 写入，存储读回一致，显示 Applied；不证明系统 dark→system 像素问题已修复。 |
| truncation | 两者通过 | 真实基线为 tail，原生参数设为 middle；单次 `.quadrantTitleTruncation(.middle)` 写入，存储读回一致，显示 Applied。 |
| captureSource | 两者通过 | 真实基线为 false，原生参数设为 true；单次 `.stampCaptureApp(true)` 写入，存储读回一致，显示 Applied。 |

8 个场景均从原生输入 `/set`、Tab 接受候选、空参数真实基线开始；原生菜单经合成鼠标打开，方向键/Return 由系统追踪循环选择参数，随后原生点击或 ⌘Return 经原 Controller → Adapter 完成提交。均核对普通 Return 零写入、旧候选拒绝、同一 draft ID 移入运行、active/plan 无重复所有者、重复旧回调不再写入及明确“完成”释放。它们不是手工调用适配器的替代证明，也不等于真人键盘/输入法/VoiceOver 验收。当前未编译的新方法不改变这 8 个已运行场景的正文，但完整最终测试 target 仍需重编和续验。

**实际修改与范围。** 只修改四份测试/QA 支持源码：

- [UnifiedSearchOperationTestSupport](../AreaChainTests/Features/UnifiedSearchOperationTestSupport.swift)：960pt QA 窗口中操作滚动面板由 450pt 改为 320pt，为下方结果固定页头留空间。原 4A-3B2 的 450pt 是历史 QA 配置，不是生产布局契约；应用组件和提交语义未改。此共享 QA 宿主变化仍需旧 4A 消费者回归。
- [SettingInteractionTests](../AreaChainTests/Features/UnifiedSearchSettingInteractionTests.swift) / [SettingTestSupport](../AreaChainTests/Features/UnifiedSearchSettingTestSupport.swift)：保留并细化焦点诊断，四字段各覆盖点击与 ⌘Return；参数选择复用 PickerNativeTestSupport，去掉这条链路中的菜单项 action 直派。补充真实入列、混合/多项及未装配/其他命令原生阻断场景。
- [SettingPresentationTests](../AreaChainTests/Features/UnifiedSearchSettingPresentationTests.swift)：增加提交/结果区域不重叠及所属边界断言；补充成功、noChange、冲突、unknown、展示失败、多项阻断 × 中英文 × 浅深色 × 两宿主 × 正常/最小宽度的 96 个场景。

**新增而未运行的范围。** 最后新增的 `resultStatesAcrossHostMatrix(layout:locale:)`、`nativeEnqueueOwnsDraftAndMultipleSubmissionWritesNothing()`、`unsupportedAndUnassembledNativeSubmissionRemainBlocked(assembled:)` 及对应 helper **未编译、未运行**；不能因严格 lint 通过就宣布其可运行。完整旧 SettingsPickerConsumerTests / SettingsLocalPreferenceConsumerTests、4A 参数/计划/输入及该共享 QA 宿主的相关对象界面回归未运行。首轮已通过的旧语言 Binding 是一个实际场景，不能代表整个旧设置页回归。三种冲突选择/过期确认、unknown、展示重试/后来覆盖、noChange、撤显示等首轮证据基于旧 QA 布局，仍需在最终 320pt 宿主复跑；未知和多项的服务/Controller 证据不冒充新增原生阻断测试通过。

**截图实际检查。** 首轮保留 32 张于 `Native-3A2R-images`，其中实际检查 compact 深色最小宽度与展示失败两张，前者暴露重叠。修正后保留并实际检查 `Native-Controls-3A2R-images` 的 10 张：8 张 `setting-applied-{0…3}-{false,true}.png` 和两张 `setting-submit-boundary-{standard,compact}.png`；`native-controls-contact.png` 是这 10 张的索引。修正后提交动作与结果页头已分开，反馈可读。以上是已挂载原生窗口 `cacheDisplay` 内容图，截图查看在交互结束后；不是系统合成桌面截图。没有本轮最终六状态完整视觉矩阵，不能将早期 16 张 pending 矩阵图或新增测试源码冒充最终验收。后续新增测试尚未运行，10 张图对应 `Native-Controls-3A2R-sources.json` 记录的已运行代码。

**本次停止时的锁事实。** `Native-Matrix-3A2R` 正常申请时原锁不可得，包装器没有截断、写入或删除未取得的锁。18:25:26 对该次失败仅做一次有界归属查询（约 0.14 秒，未再次 flock）：`lsof` 退出 1、没有打开者，因而**无法确认申请瞬间的持有 PID/任务**，也不能断言现在可取锁。未沿用之前 PID、未输出环境变量或完整命令行；随后不轮询、不重试、不等待、不干预。正常配置构建/验签本次未申请，原历史成功不替代本次最终构建。

**最终静态与后续。** 四份修改测试源码的严格局部 SwiftLint 已退出 0、无诊断；`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json` 和 `git diff --check` 均通过，最终文档编辑后复跑。门禁识别 76 个工作树变更路径，包含并行工作，不代表本轮修改量。源码指纹核对确认两次已运行清单内的应用源码和两项原失败测试均未改变；相较 `Native-Controls-3A2R-sources.json`，已列源码中仅后三份 Setting 测试/支持文件有未运行增量。并行菜单栏变化及新增 RowBubble 测试全部保留，不认领其验收，清单外新增测试也不能假定已编译。

指定 Cursor verifier 不可用继续保留，不查登录或换代理；VoiceOver 真人、系统候选窗、减弱动态/最低系统/真实多窗口，以及 C2B 8 项失败、4A-3B2 最终原生、dark→system 历史缺口仍未关闭。已有两项失败修正与四条原生提交链路的新证据，可作为继续本地验收的依据；**不构成整个 3A-2R 收口通过或进入下一阶段的依据**。续验先取得原锁、确认交互桌面，编译运行上述新增矩阵/阻断及最终布局回归，再补旧设置页/4A 与正常构建验签。本轮不新增功能，不提交、推送、安装、发布或启用生产搜索。

**19:44 起的剩余验收（2026-10-04，Asia/Shanghai）。** 本轮结论：**六状态矩阵、阻断、旧设置页与大部分 4A 回归已通过；本阶段仍待一项测试定位修正复验及正常 Debug 构建/验签**。指定复核、人工和其他历史缺口在下方单列，不把它们与这些实际结果合并成一个状态。

开始时仅一次只读锁探测：19:44:24 可正常取得并立即释放；桌面 console=1、loggedIn=1、locked=false、screens=1。对照 `recheck-3a2r-sources.json` 与 `Native-Controls-3A2R-sources.json`：适配器、两项原失败测试和八条设置提交路径未改变；后续应用变化是并行 RowBubble 外壳及 DaybookSurface 的 rowBubble 分支，原设置/候选分支保持语义，故不机械复跑两项修复及八条链路。其原截图和首轮语言焦点失败、根因未明记录均保留。

**单次仓库入口。** `Remaining-3A2R-command.json` 记录一次 `./scripts/build.sh test --no-wait` 合并 31 个类/方法选择器，覆盖已登记的剩余 Setting 场景、隔离 SettingsPicker/SettingsLocalPreference 消费者、4A 参数/计划/对象界面及 UnifiedSearchInput。没有手工持锁；脚本管理原锁、串行执行和六项钥匙串授权清除。原脚本没有 QA 参数透传，故仅该子进程使用 Xcode 支持的 `XCODE_XCCONFIG_FILE`，指向未入库的 `build/SettingUIQA-3A2/remaining-qa.xcconfig`。执行前 `-showBuildSettings` 确认 QA 标识 `com.areachain.setting-ui-qa`、local/ad-hoc、无 Team、生产 entitlement、sandbox=YES、LSUIElement=NO；SYMROOT/OBJROOT 指向原隔离 QA 产物目录。未改 build.sh、个人签名或工程。测试日志/xcresult 使用脚本的 `build/local-DerivedData/Logs/Test`；正常构建不得继承这份进程级覆盖。

| 本轮证据 | 结果 |
|---|---|
| 完整测试目标编译与合并运行 | 19:52:16 启动，20:00:45 完成，退出 65。`build/local-DerivedData/Logs/Test/Test-AreaChain-2026.10.04_19-52-17-+0800.xcresult`：**57 个定义中 56 通过、1 失败；77 次执行中 76 通过、1 失败**。未跳过或预期失败；四类旧边界外能力没有纳入选择器，不能把未选择称为通过。 |
| 六状态矩阵 | `resultStatesAcrossHostMatrix(layout:locale:)` 四组参数运行全部通过；每组内部覆盖 24 个场景，实际完成 **96 个状态/语言/主题/宿主/宽度组合**。96 是内部场景数，不冒充 96 个 XCTest 测试。另有 16 个 pending 布局组合在最终 320pt QA 宿主通过。最小宽度仍是 compact 304 / standard 444（包含原 24pt 外边距），正常宽度 380 / 620；未放宽窗口/面板边界或遮挡断言。 |
| 原生阻断及生命周期 | 新增原生入列唯一所有权、活动+计划/多项零部分写入、未装配/其他命令拒绝通过；noChange、三类冲突按钮及过期确认、unknown 无普通重试、仅展示重试/后续替代、失焦/锁定保留提交事实、焦点按钮空格/⌘Return 均在最终 QA 宿主通过。 |
| 旧设置页 | 已选的 groupedFormSelectionAndCancellation、languageChangesThroughAppChromeWithoutFallback、persistenceReopenRebuildAndTruncationKeepTitle、disabledExternalUpdatesAndLongDescription，以及 captureToggleUsesSameAuthorityWithoutOtherSettings 均通过；覆盖四项普通偏好、双语/浅深色、共享读写/事件、重开和同字段冲突。真实进程外观方法未选，dark→system 缺口不变；未触发日历、登录或其他真实系统写入。 |
| 4A 回归 | 所选 Operation Contract/Interaction/Presentation/Lifecycle、Plan Contract/Interaction/Presentation/Lifecycle、Object Presentation 和 Input 均通过。Object Interaction 仅 `cancelReturnsFocusAndNativeRemovalPreservesOtherParameters()` 失败，其余通过。两项读取 UserDefaults.standard 的旧生命周期方法仍未选，以已有隔离阻断用例承接本阶段要求。 |
| 一项失败及最小修正 | 原第 152 行 `draft.targets == .none` 失败。源码和 `objects-removed-keeps-title.png` 显示，整窗按 `unified.select.<objectID>` 找到的是下方搜索结果按钮，空格改变搜索选择而非移除固定目标；两个区域复用同一行标识。只修改 [UnifiedSearchObjectInteractionTests.swift](../AreaChainTests/Features/UnifiedSearchObjectInteractionTests.swift)：查找限定原 OperationBoundary，先滚动到该按钮并检查其框在面板内，再保留原焦点、空格、目标为空及标题不变断言。应用代码和 QA 尺寸未改，也未新增无关场景。 |
| 修正后定向复验 | `ObjectRemoval-3A2R-command.json` 仅选择上述一个方法；原 `build.sh test --no-wait` **锁忙退出 3，未编译、未运行、无新 xcresult**。`ObjectRemoval-3A2R.log` 与 result.json 保留该事实，不将原失败改写为通过。 |

完整正常测试 target 保留原未使用变量、辅助 API 废弃及其他现存警告，没有排除源码来编译。全部新设置实际读写仍是随机隔离偏好及注入副作用；未启用生产搜索或接触用户设置。

**最终截图检查。** 本次运行生成的 257 张窗口内容图按时间筛选后保存在 `build/SettingUIQA-3A2/Remaining-3A2R-images`，不是全部都已逐张验收。已通过 `Remaining-3A2R-contact` 的 12 张对照图逐一检查 96 个六状态反馈区域：成功/noChange、原值/当前/拟改值、unknown 限制、仅重试展示、多项阻断均可读；对照图裁切只用于查看，原完整 PNG 保留。另直接查看 compact 英文深色最小宽度冲突、standard 英文深色最小宽度多项、compact 中文深色最小宽度 pending 的完整窗口图，以及旧设置页 en/zh-Hans × light/dark 四张完整图。未见提交区域与结果页头重叠；必要反馈未被省略。复用未受影响的上一轮八条提交结果与两宿主区域图，不把未查看的其余图片计为通过。证据仍是已挂载原生窗口 cacheDisplay，不冒充系统桌面合成截图或真人操作。

**停止事实与剩余门禁。** 定向复验被脚本锁拒绝后，不再申请测试或正常构建。20:17:59 仅做一次有界归属查询，lsof 退出 1、无打开者，无法确认申请瞬间的持有任务，也不推断现在锁已可用；未再次 flock、轮询、等待或干预。**本阶段仅剩上述一项定位修正的编译/运行复验，以及不带 QA 覆盖的正常配置 Debug 构建/验签。** 已通过矩阵及旧入口不因该测试文件的局部定位修改失效，后续无需重跑整组。修改后 `swiftlint lint --strict --quiet AreaChainTests/Features/UnifiedSearchObjectInteractionTests.swift`、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json` 与 `git diff --check` 均退出 0；最终文档补记后复跑受影响门禁，不能替代待运行方法。源码指纹对照本次合并运行清单，除该用例文件外，仅并行 MenuBarHelpKeyboardTests、RowBubbleInteractionTests 变化，设置矩阵及应用路径未变。

**分开保留的缺口。** 指定 Cursor verifier：未执行，不查登录、不替换；人工：VoiceOver、系统输入法候选窗、减弱动态/最低系统及真实多窗口未验；历史：首轮语言焦点失败根因仍未明，C2B 八项原失败、IME/mutable textStorage 限制及 dark→system 未关闭。此次通过的 4A 所选回归是新证据，但不据此清空其他阶段整体验收记录。本阶段尚未收口通过，已有结果可支持继续本地验收；不进入下一阶段，不提交、推送、安装或发布。

**最后两项收口（2026-10-04，Asia/Shanghai）。** 核对暂存区与工作区后，确认对象移除测试与 `ObjectRemoval-3A2R-source.json` 指纹一致：仅把同标识按钮的查找限定至 OperationBoundary，并滚动/检查面板边界；原焦点、空格操作、目标为空及标题不变断言未改。既有暂存和并行修改全部保留，本次没有再改 Swift、QA 布局或新增测试。桌面预检仍为已登录、未锁定、有显示器。

| 最后验收项 | 实际结果 |
|---|---|
| 单用例编译/复验 | 21:27:50 通过原 `build.sh test --no-wait --only-testing AreaChainTests/UnifiedSearchObjectInteractionTests/cancelReturnsFocusAndNativeRemovalPreservesOtherParameters()` 启动；仍仅对子进程应用原 `remaining-qa.xcconfig`。完整测试 target 编译，**1 个定义、1 次执行 Passed，0 失败/跳过/预期失败**，21:28:20 完成、退出 0。结果为 `build/local-DerivedData/Logs/Test/Test-AreaChain-2026.10.04_21-27-52-+0800.xcresult`；命令、日志、指纹与返回值保存为 `build/SettingUIQA-3A2/ObjectRemoval-Closure-3A2R-*` 及同名前缀 `.log`。原误定位失败记录不删除。 |
| 正常 Debug 构建/静态验签 | 确认该 xcresult 仅含上述 Passed 方法后，21:51:18 清除 `XCODE_XCCONFIG_FILE`，运行原 `./scripts/build.sh --no-wait`，**退出 0**。实际为既有 development 配置，产物 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`，`staticSignatureVerified: true`、`hardenedRuntime: true`。证据为 `build/SettingUIQA-3A2/Debug-Closure-3A2R.log`、command/result/sources 清单。没有改个人签名、安装或启动产物；不把验签中的配置状态当作真实系统解锁验证。 |
| 锁与范围 | 两次操作均由原脚本管理原锁并在退出时释放，没有手工持锁、抢锁或绕过；本轮未遇锁忙，不追加全局空闲探测。未机械复跑未受影响的两项修复、八条原生链路、96 场景矩阵、截图及其他回归。 |
| 本阶段本地验收 | **已完成。** 两项原失败修复、四类设置八条原生提交链路、六状态矩阵、已登记阻断/生命周期、旧设置页及所选 4A 回归、截图检查和最终正常构建/验签均已有对应证据。不同轮次结果按源码及影响核对复用，不把 96 个内部场景混算为 XCTest 定义数，不冒充一次全量套件通过。 |

单用例源码严格 SwiftLint 退出 0；`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json` 及 `git diff --check` 均通过，最终补记后复跑受影响门禁；机器结果保存在 `build/SettingUIQA-3A2/Closure-3A2R-doc-gates.json`。两次运行的源码指纹与收口时一致。构建仍提示 macOS 的 arm64/x86_64 候选目的地多选；测试目标已有辅助 API/Swift 并发等警告保留，不作为本次新增缺陷或无警告声明。

**本地完成之外的状态分别保留：** 指定 Cursor verifier 未执行，缺失使**整体治理验收仍为 partial**；没有重复登录或用自查/测试替代。真人 VoiceOver、系统输入法候选窗、减弱动态/最低系统及真实用户多窗口仍未验。首轮语言链路焦点失败及根因未明、C2B 八项历史失败、IME/mutable textStorage 限制、dark→system 等历史记录不因本阶段完成而关闭。这里只完成已授权的 3A-2R 本地验收，不表示全体系、生产入口或发布验收通过。完成后停止；不进入下一阶段，不提交、推送、安装、启用生产搜索或修改用户偏好。

### 9.57 阶段 3A-3A：四类普通设置共同保存、兼容与恢复方案定稿

2026-10-04（Asia/Shanghai）。**3A-3A 设计已获用户确认；3A-3B1 仅实现显式临时目录的聚合文件后端与提交恢复，实际证据见 §9.58。隔离迁移与重开判定现见 §9.59；AppPreferences 整份发布和生产接线尚未实现。四项共用独立版本化聚合文件，以单次整份替换作为偏好提交点。** 使用项目已有 Foundation 文件存储方式，不增加数据库或第三方依赖。下文保留设计阶段【事实】【候选】【推荐】【待授权】的历史身份；已确认决定见 G，实际 API 以 §9.58 为准。本节取代 §9.53 中尚未选定的多项存储建议，不改写 §9.54～§9.56 的实施历史。

已确认目标保持：仅语言、外观、标题省略、捕获来源标记；提交前统一校验，组内全成或保持原状态，未知整组待核实，提交后才发布和处理展示；展示失败不否认保存，旧设置页仍即时提交且共用后端。不要求磁盘提交与全部窗口像素形成一个事务，不循环单项接口、不逐键回滚。不扩展日历、权限、隐私、正文、其他设置或通用 Saga。3A-2R 本地验收已完成，指定 Cursor、人工及其他历史缺口保留；C2B 未完成，敏感编辑规则和生产搜索接线均不放宽。

#### A. 3A-1A/1B 实施后的事实与复用影响

行号为本次工作树定位，以符号为稳定出处；没有初始化 AppPreferences 或 Persistence 来取证。

| 【事实】来源 | 当前行为 | 【推荐】复用或最小扩展 |
|---|---|---|
| [AppPreferences.swift](../AreaChain/Services/AppPreferences.swift):64、85、125、159，四属性 / init / applyLocalSetting | 四个私有可观察标量，四属性 setter 共用逐字段入口；初始化逐项读取，四次读取不构成组快照。apply 先读、比 expected、查执行资格、写一键、增该字段修订、读回，匹配才更新内存及调用展示。 | 保留四属性与旧 Binding，底层改为一个不可变聚合状态的唯一替换入口；单项是该入口的单字段请求，不能由批量入口循环单项。 |
| [LocalPreference.swift](../AreaChain/Services/LocalPreference.swift):6、42、89 与 [LocalPreferenceDependencies.swift](../AreaChain/Services/LocalPreferenceDependencies.swift):6 | Field.key 映射旧四键；Storage.read 用 object(forKey:)，write 用 set。source 是实例 UUID＋句柄 ObjectIdentifier；revision 只存在运行内。raw 区分缺失/类型/不可读。 | 保留类型化四值和严格解析；增加整记录快照、持久 storeID/epoch、记录修订与字段修订，运行内实例身份继续独立存在。 |
| [LocalSettingCommandAdapter.swift](../AreaChain/Services/LocalSettingCommandAdapter.swift):50、76、92、128、249 | readiness、submit、execute 各自只准单项；prepare 签发真实基线，原 draft/plan 保有唯一参数。reports/writes 是运行内事实，重建实例不会恢复登记。 | 沿原适配器增加窄组请求、真实整组采集与回执；不增加另一份计划或参数字典。 |
| [LocalSettingCommandMapping.swift](../AreaChain/Services/LocalSettingCommandMapping.swift):5、26、70 | 四个稳定 ID，assign、精确参数个数与 choice/Bool 转换；matches 同时比来源、字段修订、raw、memory、stored。 | 原映射逐成员用于预检；所有成员通过后才能交给一次组提交。命令非法参数不使用初始化默认回退。 |
| [CommandPreferenceEvidence.swift](../AreaChain/Domain/CommandPreferenceEvidence.swift):4、22；[CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift):87 | noChange / preferenceWrite / preferencePresentation 仅接受 isSinglePreference；returned＋matches 才记 committed，threw＋matches 仍 unknown。 | 保留原调用/读回事实；另加整组提交确定性与独立展示证据，不把新后端“提交已确认”硬塞成旧 UserDefaults 回执。 |
| [CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift) group / restoreUnsubmittedPreference；[CommandPlanSemantics.swift](../AreaChain/Domain/CommandPlanSemantics.swift):9 | 四项白名单可组成连续原子组，无组内依赖；未禁止同业务字段重复。恢复未提交运行到计划只支持非原子单项。 | 组内重复字段显式拒绝；扩展整组未提交返回、统一基线更新，保留全部 item/draft 身份及 returnedAttempts。 |
| [CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift):73 | claimPreferenceInvocation 限 snapshot.items.count == 1，并用单个 operation 标识占用。组 unitID 并不是一个 itemID，不能直接用 run.operation(attempt.unitID) 取得组身份。 | 增加明确 groupID＋有序 member stamps 的窄占用身份；仍在 IO 前去重、完成归原 ownership/run/attempt，不借第一成员代替整组。 |
| [PreferenceObservation.swift](../AreaChain/Services/PreferenceObservation.swift):6、24 | windowChrome/statusItem 接语言和外观，diaryWindow 仅语言，calendar 不订阅普通事件；异步 Task 仅查 active，不核对修订，回调重新读取当前 prefs。 | 普通事件改为一组字段及已提交修订；消费者取交集，只刷新当前展示，不保存旧值、重查正文或请求日历同步。 |

**旧键读取/写入核实。** 对 AreaChain、AreaChainTests、scripts 搜索四个常量、完整键名及 UserDefaults/AppStorage 用法：产品中仍直接读取旧键的是 LocalPreferenceStorage.read，经 Field.key 间接访问；直接写入的是同处 write。AppPreferences 的初始化、readLocalSetting、applyLocalSetting 均经此依赖，没有另一个产品四键直读者或四键 @AppStorage。SettingsSections:16/23/30/66 的 Binding 访问属性。测试中的直接 set/read/persistentDomain 是旧格式夹具、外部变更注入或旧键断言，后续必须分别保留为迁移夹具或改为新权威断言，不能全部机械删掉。

**公共消费者。** AppChrome.body 读取 locale/scheme，QuadrantPage:312 读取标题省略；ClipboardCapture:55、DayBoardMutations:109、DayBoardMutations+Capture:21 只在后续创建时读取来源开关。PanelWindowController、StatusItemController、DiaryWindowController 消费普通事件。另有 FirstLaunchSeeder:20、MutationFeedback:29、AppDelegate.quitAlert、ClipboardHistoryPanel、AttachmentPicker、PrivacyUnlockPresenter、NotificationScheduler 的文案、TaskRow 菜单和 CompletionUndo 文案读取 resolvedLocale；这些依赖仍通过 AppPreferences，不能为迁移逐个补旧键镜像。读取语言的系统消费者不因此获得重排通知、请求权限、认证或刷新正文的许可。

**启动与无数据库场景。** [AreaChainApp.swift](../AreaChain/App/AreaChainApp.swift):96 先取得 Persistence 容器，AppDelegate:29 才显式应用偏好外观；AppPreferences.shared 惰性独立初始化，不依赖数据库。FirstLaunchSeeder 也会读取偏好语言。[Persistence.swift](../AreaChain/Services/Persistence.swift):14 的测试环境直接使用内存库；磁盘打开失败回退内存，打开前还做既有维护，不能为偏好探测调用它。[Models.swift](../AreaChain/Domain/Models.swift) 的 AreaChainSchema 只有七类业务实体。将偏好放入该库会新增真实依赖：容器失败时偏好也不可写，不能把 fallback 内存 save 成功写成持久成功。独立聚合文件则只依赖本地目录与 Foundation，业务库缺失/回退时仍可独立读取和保存四项。

**现有测试能证明的范围。** LocalPreferenceTests / FailureTests 刻画缺键、坏类型不修复、同值写、逐字段修订、重入、丢写、写后读失败、先写后抛错；LocalSettingCommand 的 Tests / Boundary / Conflict / Failure / Identity 刻画真实来源、伪造证据、ABA、旧身份、unknown 不重放和展示重试；PreferenceObservationTests 计数验证窄路由。CommandAtomicPlanTests 只有纯协议原子组，不证明存储。SettingsPickerConsumerTests、SettingsLocalPreferenceConsumerTests 与 UnifiedSearchSetting 四套是旧 UI 消费者。SubtaskTagMigrationTests 用旧 schema 打开的是升级前备份，不能证明升级后的库可以降级；ModelChangesTests 主要是内存事务；LifecycleBaselineTests 的合成磁盘重开也不是四项迁移/崩溃测试。本阶段只阅读这些测试，不新增运行通过结论。

#### B. 三个适用候选及推荐依据

以下均为【候选】，当前产品仍使用旧四键。表中的后端保证是设计要求或 API 层边界，只有后续故障/重开证据才能升级为“本项目已验证”。

| 比较项 | A：一个 UserDefaults 版本化 Data 值 | B：现有 SwiftData 磁盘库中的聚合实体 | C：独立版本化聚合文件【推荐】 |
|---|---|---|---|
| 原子性覆盖 | 一个值的编码/替换和应用内整份发布，减少逐键中间态；set 没有磁盘事务回执。 | 同一持久 store、干净专用 ModelContext 内提交一个实体的四值/修订/提交标识；目标是数据库事务，不包括 UserDefaults、文件与窗口。须核实实际 save/transaction 行为。 | 一个文件路径指向的整记录替换，以及应用内整份发布；同目录临时文件避免跨卷替换。只有权威文件替换是偏好提交点，辅助恢复证据不成为第二权威。 |
| 失败/未知 | 编码前可明确失败；set 返回 Void，读回只说明当前缓存可见一致，底层丢写通常没有错误。threw 只能来自包装/注入。 | 提交前校验、编码和上下文操作失败可识别；save 抛错和重新打开失败分别记录。不能仅凭 catch/rollback 推断提交一定未发生，无法归因则 unknown。 | 编码/临时准备在替换前失败可证明未提交；进入替换调用后抛错、读回不可用或标识不符一律先 unknown。API 返回＋重新读取完整记录身份吻合，才确认当前文件提交；仍不承诺断电耐久。 |
| 内存与通知 | 先 set/核验，再一次发布；不得把暂未落盘的缓存读回夸大为耐久。 | 四值只能在专用上下文内暂存，save 后投影不可变状态；不把 @Model 直接暴露给 UI，不用主上下文夹带保存其他编辑。 | 先准备全部字节，单次替换并核验，再一次发布不可变状态；最后调用外观与窄事件。准备、替换或核验失败时不部分发布。 |
| 崩溃/重启 | 可能回到旧聚合值；本次未有守护进程缓存/掉电边界证据。synchronize 和同句柄读回不能补成事务。 | SQLite/SwiftData 的事务恢复应给完整旧/新记录，但项目未有偏好实体、迁移计划、进程中断或耐久配置证据；损坏/打不开不能读 defaults 顶替权威。 | 目标是进程中断后只读完整旧/新记录；缺失、解码失败和不支持版本进入恢复状态。Foundation 替换行为需在支持环境实测；不保证掉电后保留最后一次已应答写入。 |
| 成本/启动 | 最轻，无数据库依赖；错误可观测性最弱。 | 增 schema、数据库打开/查询和事务成本；AppPreferences、种子语言、错误提示初始化须重新装配，fallback 不能持久写偏好。 | 每次小记录全量编码/替换/重读，另有窄恢复证据 IO；比 defaults 重，比把偏好绑定业务数据库更独立。只测四项实际载荷，不虚构延迟预算。 |
| 旧键/旧版 | 仍需迁移；旧版完全不认识新聚合键，保留旧四键只供旧版读取，不能双写。 | 仍需迁移并处理旧 schema 打开新库；普通 ExportSnapshot 没有偏好，resetStoreOnDisk 会连偏好一起删除。需额外数据库回退验证。 | 仍需迁移；旧版忽略新文件、读迁移前旧四键；不改业务 schema、导入导出或 resetStoreOnDisk 的数据集边界。最新偏好不自动传回旧版。 |
| 验证 | 隔离 suite＋注入掉写/读失败只能证明分支；还需独立进程重开，不能由缓存一致证明耐久。 | 临时磁盘库/关闭后重开、旧 schema 夹具、提交故障与中断、fallback 拒写、无 BoardEvents 副作用。内存库不代替磁盘。 | 临时目录/独立进程，分别中断准备、替换、读回、发布；首次创建与已存在替换均测；原文件不丢、整组无混合、恢复标识、只读旧版夹具、并发写入序列化。 |
| 不能保证 | 磁盘提交错误、fsync、完整外部 ABA、所有窗口完成。 | 跨存储/外部效果事务、未验证的旧版降级、所有窗口完成；“SwiftData”名称本身不证明项目契约满足。 | 跨文件事务、任意外部编辑的比较交换、完整外部 ABA、掉电耐久、所有窗口完成；辅助文件与权威文件之间的中断必须由状态表处理。 |

【事实】[CalendarSyncStorage.swift](../AreaChain/Services/CalendarSyncStorage.swift):7 的 ledger 将整份 JSON 以 Data.write(.atomic) 保存；[ClipboardHistoryStore.swift](../AreaChain/Services/ClipboardHistoryStore.swift):35 使用临时文件及 replace/move，错误向上传递。它们证明项目已有这种技术路径，未提供可直接套用的普通偏好事务组件；不调用日历或剪贴板服务复用其业务。隐私写入器的同步/校验也不能直接移作普通偏好协议或证明目录耐久。

【事实】[ModelChanges.swift](../AreaChain/Services/ModelChanges.swift):78 的 transaction 是应用层延迟 commit：可能先 save 上下文已有改动，末尾固定 BoardEvents.changed()，失败会 rollback 并重新 fetch。不能原样用它保存普通偏好，否则会触及无关模型与广域通知。若选择 B，需要干净专用上下文及窄提交/事件路径，验证底层真实事务；没有“零改造可用的 ModelChanges 设置事务”。本轮未发现 VersionedSchema / SchemaMigrationPlan。

【推荐理由】C 在四项小数据范围内提供明确的整份存储边界和可传播 IO 错误，同时保留偏好与业务库独立、免业务 schema 迁移。A 的失败可观测性不足；B 虽有真实事务后端可用，但启动、fallback、旧库兼容和恢复面显著扩大。本次不默认选 §9.53 的 SwiftData 示例。C 的选择包含明确验收门槛：后续如果不能证明正常进程中断下不出现混合记录、未知不重放及旧键恢复，就保持多项关闭，回到本节调整决定，不能悄悄降成逐键保存或只用 UserDefaults 缓存读回。

#### C. 推荐存储形状、写入者与成功口径

【设计已确认；后端实施见 §9.58】Services 内的 LocalPreferenceRecord / LocalPreferenceFileStore 复用旧四项类型；AppPreferences 本阶段不改。3A-3B1 的 root 必须显式注入且处于临时目录内，不提供生产默认目录；未来生产目录另行接入。目录解析不初始化 Persistence/PrivacyVault。暂存文件用同目录唯一名称，不共用固定 tmp，不枚举或清理别的业务文件。

1. `current.json` 是唯一可编辑权威记录：schemaVersion、storeID、epoch、recordRevision、四个完整规范值、四个 fieldRevision、commitID、parentCommitID、migrationID。记录内四值必须齐全并一次解码通过；未知 schema、缺字段、坏类型和非法修订不按字段填默认。commitID 每次新提交生成，和目标完整记录摘要一起绑定运行回执；不持久化完整 CommandPlan、正文或敏感草稿。
2. `migration.plist` 是一次迁移准备的只读证据：migrationID、来源域身份、四键是否物理存在/原始 property-list 值、查找得到的有效值及来源说明、目标初始记录身份/摘要、格式版本。它不参与日常读取和编辑，不随偏好更新。只保存这四键，绝不保存整份 defaults 域；不能复制任意坏负载到普通日志或测试产物。
3. `pending-write.json` 是至多一个尚未核实提交的只读意图证据：storeID/epoch、commitID、基记录身份/摘要、目标记录摘要、成员字段和运行/尝试标识；不保存可执行命令、不成为读取值的来源。替换权威文件前先落此证据并核对；无法准备证据就不开始替换。提交核实后才能清除；清除失败是恢复整理未完成，不否定已保存，后续提交先核对此记录，不覆盖它。重启只做核验，绝不根据此文件自动重写目标。它与 current 不是跨文件事务，下面状态表处理不一致。

这是一份权威记录、一次偏好提交，外加最小迁移/中断证据；不是多份可编辑偏好或通用日志引擎。每个普通写入可能有准备证据、暂存和清理 IO，不能把“一次共同提交”描述成只发生一次文件系统调用。迁移证据永久只读保留；pending 不形成无限历史，清理不得早于明确核实。应用数据 JSON/私密备份不自动包含这些文件，也不因此修改现有备份范围。

具体文件步骤沿现有 Foundation 方式：完整编码 → 写同目录唯一临时文件并解码核验 → 准备/核对 pending → 最后身份检查 → 已存在目标用 replaceItemAt、首次建立用 moveItem → 重新打开 current 核验。临时文件上的 Data.write(.atomic) 只是准备，不是偏好提交；最终替换调用才越过提交边界。首次存在性判断必须在协作锁内，读错误不能按不存在处理。没有先删 current 再移动、没有成功后逐键镜像，也不把 replace/move 抛错自动等同“原文件还在”；后续须分别验证两条实际磁盘路径及故障。若平台行为不符合整记录替换要求，门禁失败，不以 API 名称推定满足。

**写入者约束。** AppPreferences 是应用内唯一公开入口；相同规范路径的后端共享串行所有者及重入守卫。拟为文件后端加同目录稳定锁文件上的非阻塞 advisory lock（协作式文件锁），所有新版读核验/写入者遵守，锁覆盖最终重读→替换→核验→内存发布，释放后再处理展示；不锁将被替换的 inode。锁忙返回未提交，不忙等。它是未来偏好 IO 的并发约束，不是 `build/.build.lock` 原生测试锁，本阶段不创建或申请任何锁。锁的可用性/释放/多进程互斥属于后续验证，不能仅靠 MainActor 声称跨进程一致。

外部旧版只写旧键，不会成为新版权威；不受本协议控制的编辑器、备份恢复、删除/替换文件、网络卷或伪造记录不在协作锁保证内。最终重读可发现可见身份/摘要/修订变化，发现就暂停/刷新证据；无法检测别人把完整旧字节含修订一并放回的外部 ABA。不得因此开放安全撤销。旧版本和新版不得并行做迁移或回退。

**两层修订。** recordRevision 对每次确认的整记录提交推进；fieldRevision 只对请求覆盖字段推进，包括旧页同值赋值。命令全组 noChange 不推进；命令部分无变化时仍只提交一次，保守推进该组所有请求字段，未请求字段不推进。另保留运行内 evidenceGeneration，在已经尝试写入却 unknown 时使旧基线失效；不能把未知尝试伪装为已持久提交的 fieldRevision。预览冲突比较实际受影响字段，不因无关字段的 recordRevision 变化制造冲突；最终写入从锁内最新全记录派生，保留无关字段的新值。记录身份改变/回退、来源不可读或损坏则全组失效。

**内存发布。** 拟将四个私有标量替换为一个聚合 committedState，四属性/locale/scheme 仅从它派生；候选只在局部不可变值中构造。核实提交后先登记不可重放的提交事实，再一次替换 committedState；通知/Observation 回调只能观察完整旧状态或完整新状态，不能看到两旧两新。Observation 的 willSet 通知可能读到完整旧值，不等于半提交。禁止 setter 递归、逐字段发布或延迟通知掩盖四次保存。读失败时保留最后完整内存状态并标记不可写；冷启动无可信状态才用完整安全默认作只读展示，不将它签发为执行基线。

**原单项保证保留。** 旧 readLocalSetting 从整记录快照投影字段，保留 source/raw/value/revision 可核验性；旧 applyLocalSetting 变成同后端单成员提交。UserDefaults 旧夹具的 threw＋matches 仍是 unknown，不能修改断言称成功；文件后端初始回执同样先保留替换调用与读回事实。只有成功返回且重读的 schema/storeID/epoch/commitID/全记录摘要均匹配，才记“整组已保存，当前文件核验一致”；仅值相等不能归因。进入替换后抛错即使读到目标也先 unknown，只能通过下述显式核验改变确定性。没有 synchronize/fsync/缓存读回推导的掉电耐久承诺。

#### D. 迁移、初始化、中断与旧版本回退

【政策已确认，实施留给 3A-3B2】旧四键保留、不双写，坏旧值阻断自动迁移，新记录成功后唯一权威；旧版仍见迁移前值，携最新值降级另行处理。3A-3B1 不实现迁移，不读取真实旧偏好；真实用户数据转换仍须单独授权。

**读取规则与兼容值。** 四键完整名仍为 `areachain.prefs.language`、`areachain.prefs.appearance`、`areachain.prefs.quadrantTitleTruncation`、`areachain.prefs.stampCaptureApp`。

| 旧值情况 | 读取/展示 | 初次迁移决定 |
|---|---|---|
| 缺失键，实际查找也无值 | language/appearance/truncation/capture 分别为 system/system/tail/false；保留物理缺失标记 | 可导入完整默认，旧键仍缺失，不为兼容补写四键。 |
| 合法枚举字符串或真实 CFBoolean | 原样导入 system/chinese/english、system/light/dark、tail/middle、Bool | 保留策略值；system 仍在使用时按系统解析，不冻结成 en/zh-Hans 或当前浅深色。 |
| 不支持枚举、错类型/复合值 | 只读展示沿 initialValue：枚举回退 system/system/tail；不视为合法基线 | 阻断整次自动迁移，保留全部原键；提示需单独确认规范化/恢复，不将坏字段默认化后悄悄保存另外三项。 |
| capture 是字符串/数字 | 旧初始化按 NSString.boolValue / 数字非零解释，显示值保留；canonicalValue 仍判不合法 | 同样阻断自动迁移；例如 YES 的历史显示为 true 不意味着允许无确认改成 Bool。 |
| 读取失败/无法区分不存在与不可读 | unavailable，不能当 missing | 不创建 current，不写旧键，保持恢复待处理。 |
| 注册域、全局/启动参数等覆盖 | object(forKey:) 是搜索域可见值，不能当物理旧键快照；分别记录四键的应用持久域原值与有效查找结果 | 只有能证明有效值来自目标域或本应用已声明的默认时自动导入；来源不明、受管理/临时覆盖或冲突则阻断，不冻结外部覆盖为用户选择。当前四键未发现 register 默认写入，测试仍须覆盖这类情况。 |

**具体迁移次序。** 后续获得授权后，在任何新版四项写入口可用前完成：读取新记录/迁移/pending 状态 → 检查旧版已退出及本后端独占 → 仅采集四键的原始值和来源并严格验证 → 写入且核对只读 migration 证据 → 再核对旧四键未变化 → 准备 pending → 单次建立完整 current（初始修订、commitID 和 migrationID 同记录）→ 完整重读核实 → 一次装载内存 → 标记偏好就绪并仅应用启动展示。迁移本身不伪装成用户命令、不发布 board 或日历事件。读取旧 defaults 与文件提交不存在跨进程事务；旧版/外部持续写旧键的环境不满足自动迁移前提，应停止而不是宣称已锁住 UserDefaults。

**权威来源与恢复状态表。** 不使用一个单独 UserDefaults `migrated=true` 决定权威，也不按文件时间挑“更新的一份”。

| 启动/中断后观察 | 权威与状态 | 允许的恢复 |
|---|---|---|
| current、migration、pending 全不存在且读取确证不存在 | 尚未迁移；旧四键只读兼容装载，新写入口暂不开放 | 按获准迁移流程初次建立记录；初始全缺是新装分支。 |
| 只有有效 migration，或有 pending 但 current 缺失 | 已准备/中断/文件丢失无法区分，recoveryRequired；不能自动称尚未迁移 | 保留原键与证据，核对记录是否曾成功、来源是否仍一致；仅经明确恢复确认再初始化，不能每次启动重做导入。 |
| 有完整 current，migrationID 与迁移证据匹配，无 pending | 迁移成功；current 独占权威 | 按整记录初始化。旧键后来变化也不合并、不双写。 |
| pending 目标身份/摘要与 current 完全相同 | 该提交当前可核实已成为完整权威记录；可能中断在回执/清理前 | 零偏好写入地完成核验及清理；只按当前已提交修订补展示，原运行若仍在则记录核验回执。 |
| pending 基记录与 current 完全相同，目标标识不同 | 当前仍为完整旧记录；若曾越过替换边界，不能只据此断言目标从未出现 | 标记“当前未见该提交、历史结果未确认”；不自动重试。用户核对当前状态后可关闭待核实记录并另建新意图，不能把原尝试改成 failedWithoutCommit。 |
| pending 与 current 均合法但既非目标也非基记录 | 另一次写入/恢复已替代，旧尝试归因不足 | 保留当前权威及诊断；旧展示失效，明确核实/接受当前后才释放；不强盖回目标。 |
| current 损坏、未知 schema、读取失败；或 current 存在但迁移证据缺失/身份不符 | 新来源已出现但不可可靠使用，全部四项不可写 | 运行内保留最后完整显示；冷启只读默认并提示恢复。保存原文件/四键，不回退成可编辑旧键，不自动重新迁移或删坏文件。 |
| current 已核实、pending 清理失败 | 偏好已保存，恢复整理待处理 | 下次先只读核实并重试清理；不再次提交，也不把保存回执改成失败。 |

迁移准备前失败，原始值仍在旧四键；准备完成后也在只读 migration 快照。坏类型失败不必先复制坏复合负载才能保留它，原键保持原状。后续授权的恢复可以从原键/迁移快照选择一份完整状态重新建立权威，但须保留故障文件及新身份/epoch，不能逐键补齐当前损坏记录。备份、删除或覆盖真实文件仍需对应恢复授权。

**重启边界。** 四项持久状态和最小 pending 证据可以核验；完整 CommandPlan / ExecutionRun 仍是内存所有权，不新增跨重启命令队列恢复。启动核验不能复活旧 lease、签发旧 draft 基线或自动重放命令。原运行不在时，仅显示普通偏好恢复状态及当前记录；缺少证据就保留未知，不因当前四值恰好相等宣布某历史命令成功。进程中断与掉电不同：后者可能丢失已应答的最后完整记录或证据，本方案不作零丢失保证；文件不一致时按恢复表关闭写入口。

**旧版本与回退。** 迁移成功后新版停止写旧四键；旧键保留迁移前原状，migration 为只读恢复证据。旧版不认识新文件，读取旧四键（缺键用旧默认、坏类型沿其旧回退）；因此代码回退可以得到迁移前偏好，不需要改业务数据库，但不会保留新版之后的偏好修改。旧版期间改动只影响旧四键；重新运行新版仍以 current 为准，不能自动吸收旧版改动。这是明确的兼容限制，不能同时承诺无双权威和双向即时兼容。

如用户要求降级后也使用最新四值，须另外批准一次离线数据回退：停两个版本 → 核实/保留 current、migration、pending 与四旧键的完整备份 → 解决 unknown → 将经确认的完整四值转换为旧键并逐键写入、完整读回核对 → 全部核对后才允许启动旧版。此导出不是原子共同保存；中断后继续停止应用并恢复/完成四键后再核对，不声称逐键回填构成事务。保留新版文件用于返回新版；重新升级时默认仍使用该文件，要吸收旧版后续改动须再次独立确认。下一实施阶段不自动建设此降级工具或执行真实回退。

#### E. 一次组提交与执行协议

【推荐，未实施】共同提交接受单个设置，或当前完整计划内 2～4 个不同字段的普通设置；多项在原 Plan 上显式归为一个连续 atomicGroup，整组预览说明共同保存，不能隐藏地拆成多个 unit。活动草稿＋非空计划、混合命令、多组、依赖/输出引用、对象目标、保护内容、未完成参数/编辑、pending 选择和未释放执行仍拒绝。未标组的多项也只能进入显式组准备或整体拒绝，execute 不选择一项落地。

1. **一次读取组基线。** 新组准备调用拟议 readLocalSettings，一次读取/解码完整权威记录，产生 groupCaptureID、storeID/epoch、recordRevision、各字段修订与有效值；沿原草稿/计划安装签发证据。已有单项证据不在重绘时静默刷新：比对其受影响字段与该整组快照，任一过期就保留冲突。无冲突才通过原 Coordinator 原子更新整组证据与 plan/item/draft stamps；不循环公开 prepare 导致半组换基线。最终执行前仍另取一次锁内最新整记录；“一次基线”不取消写前复核。
2. **统一验证。** 严格映射全部成员，检查白名单、参数完整性、字段唯一性、来源/签发、原 plan/group/成员身份、lease/display、run/attempt；读回 raw、内存状态、持久字段修订必须可解释。封存只移动唯一所有权；实际 IO 前 Coordinator 以整组身份占用，多个适配实例不能各得一次写许可。最终存储入口重新核对来源/字段及执行身份，核验与提交间不 await，不给 UI 传入的布尔资格授权。
3. **重复字段策略：明确拒绝整组。** 即使两个值相同也不默默取最后一项；返回重复字段及 item IDs，全部保留且零提交。用户可回到原未执行计划删除重复项，或按 §9.11 既有严格条件显式合并后重新准备组。不同签发来源/基线不能自动合并；本阶段不扩建通用合并算法。
4. **单次共同提交。** 在最新完整记录上只替换请求字段；全组目标已满足且无冲突时直接 group noChange，零权威/辅助写入、零展示。若部分已满足，已满足项只在组回执中标 unchanged，仍与其他成员同属一次完整记录提交，不能提前逐项成功。准备字节、pending 与全部预检后，再查执行资格并一次替换 current；替换前失败不发布任何候选值。替换后未知锁住该后端后续写入（包括旧页与其他命令），保留原运行/目标/证据，先核验，不能用后来写入覆盖未知线索。
5. **发布一致状态。** 确认后先记录整组 commitID/修订和本地 committed，不可因关闭/失焦撤销；再一次发布 committedState。存储/发布异常与显示许可分开：提交后 UI 失效仍把可信结果归原运行，不能返回可编辑草稿。unknown 时不发布目标，也不清除唯一执行快照。
6. **按已提交修订应用展示。** 外观成员适用时调用原 effects.applyAppearance；随后一次普通组事件，包含 source、recordRevision、commitID、成员字段及字段修订，不带正文/完整设置字典。外观失败仍可独立尝试事件。回调执行时重新核对当前相关字段版本，只从最新 committedState 重绘；不让排队的旧闭包携旧 appearance 覆盖新值。windowChrome/statusItem 取语言/外观交集，diaryWindow 取语言，calendar 仍空集；截断走 Observation，来源标记只影响未来创建。
7. **写入/展示分别回执。** 整组只有一个 local 状态；成员 changed/unchanged 是说明，不是独立提交结果。展示另记录外观与事件 notCalled/returned/threw/pending/superseded，返回仅证明调用层，异步消费者与像素完成不计作文件事务。若本地已保存但展示失败，明确“整组已保存，展示应用未完成”；不得显示某成员未保存或回滚。

**组冲突。** 无关字段更新可保持，只重查请求字段；组内任一字段冲突整组暂停，列出各字段原值/当前/拟改。采用当前、确认自己的修改、继续编辑沿原三种意图；一次确认绑定完整冲突采样、组/成员 stamps 和 lease，同字段再次变化即失效。确认不自动提交。未封存时留原计划；封存后只有可证明 local.notSubmitted 且无效果/输出的整个组能原子返回原计划，推进全部成员版本、保留旧尝试出处。不能把一部分取回、一部分继续执行，也不能用 readyForProtocol 越过真实基线校验。

**未知核验。** 不走 safeLocalReplay 或普通重试。拟增加窄 verifyPreferenceCommit：持后端协作锁重新打开权威文件，比对该组 commitID、来源、基/目标摘要及 pending。目标完整匹配可记录“该提交当前已核实”，一次更新完整内存状态，允许进入展示阶段；这是新核验回执，不篡改原 threw/readback 事实。当前仍为基记录不能证明历史从未提交，保持 unknown，用户可明确接受当前状态并关闭待核实记录后另建新意图；当前为其他记录则报告已替代/无法归因，不能报旧提交成功。核验/接受只解除阻塞，不带隐式偏好重写；缺证据、坏文件或读取失败继续待核实。

**展示重试与后来修改。** 原 run/attempt 下仅重试未完成且可幂等的展示步骤，零偏好写入；已经返回的步骤不重复。执行每一步前比较它依赖的字段修订：同字段后续写入（含同值和受控 ABA）使旧步骤 superseded；无关字段变化不阻断另一独立展示步骤。普通事件的迟到刷新只读当前状态，可合并/丢弃已替代字段，不夹带旧值。superseded 保留 local.committed，可明确确认关闭展示记录，不转换为本地成功重试/未提交；若尚有独立未完成步骤，继续保留其事实。事件抛错可能已派发，重试仍限刷新当前状态，不扩大成业务副作用。

协议分两次事实入账：新增窄 preferenceCommit 先令整个 unit.local = committed、展示为 pending；再经原 beginStep 取得 external attempt，发送真实 preferencePresentation 回执。当前 CommandPreferenceWriteFacts.isValid 在 matches 时要求 event 已调用，不能表达这个“已提交、尚未展示”时点，因此不能复用旧 facts 并伪填 event.returned。新单项文件后端也走相同两阶段；旧 UserDefaults 夹具保留旧调用/读回矩阵。展示对同字段版本的最后检查与实际同步调用不得跨 await；异步观察者只能重绘当前状态。unknown 核验另用绑定原 attempt/commitID 的窄转换，不用 resolveValidation 或改写原 receipt 伪装普通重试。

**旧设置页。** 四 Binding 保持即时赋值、不入 CommandPlan。就绪后每次赋值经同一个组后端，旧同值操作仍推进该字段修订、调用原适用展示；命令 noChange 的零写入政策只在命令适配器。迁移/读取/unknown 阻塞时四控件不能乐观改值，需要最小状态与失败提示；成功但展示失败与未保存分别提示。初始化先完成独立只读装载并暴露 health，再由根宿主显示错误，不在 init 中调用会读取 AppPreferences.shared 的 MutationFeedback，避免初始化递归。启动外观沿注入依赖，不借迁移启动完整 SettingsView 或系统服务。

**执行后撤销继续关闭。** 文件历史、迁移快照、parentCommitID 和 pending 都不等于安全撤销能力；不增加撤销按钮或“设回旧值”接口，文本撤销也不受本阶段改变。

#### F. 原子组协议的最小缺口与拟改文件

以下是【拟改清单】，本轮没有修改这些代码或公共消费者；实际实现时才同步组件目录、技能路由及对应检查器反例。

| 文件/模块 | 下一阶段最小责任及消费者 |
|---|---|
| AppPreferences.swift、LocalPreference.swift、LocalPreferenceDependencies.swift；拟新增 Services/LocalPreferenceRecord.swift、LocalPreferenceFileStore.swift、LocalPreferenceMigration.swift | 整记录读/提交/核验、独立目录、协作锁、单份可观察状态、初始化 health、迁移与只读恢复证据；保持四属性/单项外壳。新增文件按职责拆，不造通用仓储框架。 |
| LocalSettingCommandAdapter.swift、LocalSettingCommandMapping.swift | 1 或 2～4 个不同字段的完整范围、组基线、占用、一次提交、组冲突与恢复报告；拆分超过文件阈值的组辅助实现，不在 UI 复制规则。 |
| CommandPreferenceEvidence.swift、CommandDraftTargets.swift | 普通标量组证据、持久来源与运行来源分开；新增整组存储事实/核验事实，原单项调用和读回字段仍保留。Domain 不导入平台 IO。 |
| CommandPlan.swift / Semantics / Validation、CommandHostSession.swift、CommandHandoffCoordinator.swift 及原运行身份契约 | 组证据原子安装、重复字段检查、group＋member 身份占用、整组未提交返回与安全完成；未知/已提交永不返回草稿。 |
| CommandExecutionContract.swift、CommandExecutionRun.swift | group noChange；整组 preferenceCommit 与提交后 preferencePresentation；本地提交、核验、展示的独立转换。只能允许四项纯设置 unit 的窄展示，原 committed(outputs:external:) 对原子组的其他 external 拒绝保留；通知、日历、对象输出和逐成员半成功仍拒绝。 |
| PreferenceObservation.swift、BoardEvents.swift；AppWindows.swift、StatusItemController.swift、DiaryWindows.swift | 单份组事件、字段交集/修订检查及取消；保留重新读当前状态的回调。CalendarSync 只作排除回归，不新增普通订阅。 |
| SettingsSections.swift、AppPreferences 的 AppChrome；必要的 AreaChainApp.swift 装配 | 原四 Binding 兼容和不可写/恢复/展示失败提示；初始化不依赖 Persistence。生产默认后端切换属于另行启用门禁。 |
| UnifiedSearchSettingEditing / Submission / Copy、UnifiedSearchPlanEditing / List、UnifiedSearchOperationPreview、原 Controller 与 Localizable.xcstrings | 同一预览/计划/结果区域的组准备、冲突、未知核验与展示反馈，中英同步；复用原控件和 ReadSession。不新开生产搜索入口或敏感编辑能力。 |
| AreaChainTests/Services、Domain、Features 的上述偏好/命令/计划/设置测试及共用夹具 | 迁移/文件/恢复新用例配合旧单项、旧页与原子组回归；旧四键直接断言保留为旧格式兼容证据，新提交断言改读完整 current。 |

B 方案若改为最终选择，则还必须涉及 Persistence/AreaChainSchema、专用上下文、业务库兼容及备份/重置决定；不能只替换 FileStore 名称就执行。C 不要求修改业务数据库模型、快照格式、隐私实现或安装脚本。

#### G. 后续隔离验证与授权决定

【后续验证，全部未运行】存储使用临时目录/随机 suite/合成四值，从构造起注入外观与私有事件中心；不读真实偏好、数据库、正文、附件或钥匙串。运行类验证另按 areachain-verify 和原正常完整 QA 门禁授权、串行执行，不能把本节文档检查作为其通过依据。

| 场景 | 必须有的证据 |
|---|---|
| 新装、旧键迁移、部分缺键、全缺、坏类型 | 完整四值及 system 语义；旧键原状、物理缺失、Bool/string/number 区别；坏一项整次阻断，无部分 current；注册/临时覆盖来源不明拒绝。 |
| 初始化与读取失败 | 不把 EACCES/损坏/未知版本当 ENOENT；无事件/修复写入；原完整状态保留、四项不可写。无数据库/内存 fallback 仍能读文件，初始化失败不递归访问 shared。 |
| 提交前失败、替换未知 | 参数、身份、基线、编码、pending、暂存失败各点零权威提交；替换抛错但目标可读、返回但读失败/不匹配各点整组 unknown、后续写阻断，无自动逐项重试/回滚。 |
| 中断与重启 | 独立子进程在迁移快照前后、pending 前后、首次创建/替换、读回、内存发布、回执/清理各点中断；重开只有完整旧/新状态或明确 recoveryRequired；不从坏 current 偷回旧键，不复活旧 run。模拟文件操作不能替代实际临时磁盘子进程。掉电耐久仍不宣称。 |
| 字段修订/外部写入 | 同字段变更/受控 ABA 冲突，无关字段保留；另一个合法后端进程遵守协作锁；绕过锁、整份旧文件恢复、来源/epoch 变化分别拒绝或明确未能检测。锁失败不能死等或偷写。 |
| 原子组与重复字段 | 1/2/3/4 成员、组 stamp/成员错位、重复字段同值/异值、过期确认、混合/未标组/多组/依赖/输出/保护内容均有服务门禁反例；非法组零写。整组冲突及返回不丢任何成员/身份。 |
| 多项成功/部分无变化/全无变化 | 精确提交次数分别 1/1/0；全无变化辅助文件与展示也零写/零调用；任意观察回调只见完整旧/新四值；未请求字段及修订保留。 |
| 外观/普通事件失败与重试 | 保存 committed 不倒退，外观失败不阻断独立事件；仅失败展示重试、无偏好重写、已成功步骤不重放；同字段新修订/ABA 使旧展示 superseded，迟到回调不能覆盖后来设置。 |
| 旧单项/设置页兼容 | 严格参数、签发防伪、写前二次核验、unknown/readback 原矩阵；四 Binding 即时、同值、取消、禁用与重建；恢复/失败提示及组反馈 en/zh-Hans、浅深色、两宿主正常/最小宽度。后续原生才核实点击/⌘Return 与焦点，Return 不改变原契约。 |
| 旧版本回退/再次升级 | 旧读取器只见迁移前四键，新版修改不镜像；旧版修改后新版不静默合并；旧坏值/缺失保持。若另授权数据回退，测试中断后应用不启动及四键完整恢复；不借旧业务库备份测试代替。 |
| 排除副作用 | 私有中心＋真实 PreferenceObservation 路由 spy：CalendarSync 普通订阅为零、Diary 正文刷新为零、StatusItem 不重查库；三个捕获消费者只测试纯来源判定，不实际捕获/建记录；NotificationScheduler 不重新排程。 |

【2026-10-04 已由用户确认；仅授权本轮 3A-3B1，详见 §9.58】

1. **存储与保证：已确认 C。** 按独立版本化聚合文件、同路径协作锁、单次权威替换与最小恢复证据设计实施；接受“整记录提交/当前核验＋整份内存发布”的范围，掉电零丢失、任意外部 ABA 和全部窗口像素完成不在保证内。影响是四项存储及事件/执行证据变化，增加小文件 IO；验证按上表，能力不达标保持多项关闭，不换成逐键方案。
2. **迁移与旧版政策：已确认保留旧四键只读、不双写，坏值阻断自动迁移。** 迁移状态机实施留给 3A-3B2；代码回退默认使用迁移前四键，新值带回旧版须另行批准离线数据回退。影响是旧版看不到新版后续偏好；恢复材料为只读迁移证据、旧键和保留的新记录。此确认不授权接触真实用户四键或执行实际迁移/回退。
3. **范围已拆分：本轮只实施“3A-3B1 四类普通偏好版本化聚合文件后端与提交恢复”。** 仅显式临时目录、服务和隔离验证；不接 Plan/Run、指令、UI 或 AppPreferences。原建议中的迁移、聚合内存发布、旧设置页和组执行分别留待后续明确范围；本轮测试/构建只使用正常隔离门禁，不抢占原锁。生产默认后端、日用设置、生产搜索、真实迁移/回退仍不切换；同一运行环境只选一种权威后端，旧格式实现只作迁移/兼容夹具，不允许两个编辑入口分别写新旧权威。通过后仍需指定 Cursor 只读复核，缺失保留；完成后停止，生产启用另定范围。

#### H. 本阶段检查与停止记录

本次只在同一权威文档追加 §9.57；既有暂存/未暂存与并行文档原样保留。使用 areachain-workflow、架构治理/工程交付/可靠性规范；areachain-verify 仅选择文档检查。一个只读探索子代理核实数据库/启动/已有文件写法与测试出处，主代理核对关键原文；不是指定 Cursor verifier，不重新查询登录或宣称复核通过。

文档检查命令为 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile docs --strict --format json`、`git diff --check -- docs/unified-search-commands.md`，均实际运行通过；最后文档补充后重跑同三项。已读 quality_gate.run_profile：显式 docs 只运行工作流、差异、性能清单与注释静态检查，不运行脚本测试、Swift、构建或申请原生锁；避免 auto 将并行 Swift 变更纳入运行范围。首轮 docs 门禁识别 95 个变更路径，包含并行工作，不表示本任务改了 95 个文件；没有为无关任务修改门禁或其他成果。

追加前原文为 899,910 字节、4,392 行；追加后核对相同前缀的 SHA-256 仍为 `38e719190e06c3e802e4710085c7815755b90ce91a581e6cd7875fdb1c7ec0d4`，§9.56 及更早内容保持原样。文档引用/差异检查不证明推荐后端、迁移、锁或重启协议已经可运行；本节全部隔离实验仍待后续授权与实际证据。

本阶段没有修改产品 Swift、设置值、数据库、迁移/存储代码或检查器；没有写入实验、Swift/原生测试、构建、申请任何锁、应用启动、登录检查、提交、推送、安装或发布。方案定稿只表示内容可供确认，不表示已实现或运行验收通过。历史指定复核、人工及 C2B 缺口保留；交付此方案后停止，不进入 3A-3B。

### 9.58 阶段 3A-3B1：版本化聚合文件后端与提交恢复

以下保留 B1 完成时的契约和验收历史；其中迁移占位拒绝现由 §9.59 的真实隔离迁移及关系核验扩展，其余后端保证不扩大。

**当前结论：3A-3B1 后端本地验收已完成；指定 Cursor verifier 仍未执行，整体治理验收保持 partial。最终源码的测试、正常 Debug 构建及静态验签见本节“最终收口”。跨进程竞争、真实进程中断和掉电实验未执行，不属于已通过证据。**

2026-10-04（Asia/Shanghai）。本轮获准实现的范围仅是四类普通偏好的独立文件后端，所有运行数据均为显式临时目录中的合成数据。§9.57 的存储、共同提交、未知暂停、旧键保留/不双写和坏旧值阻断政策已确认；迁移留给 3A-3B2。本节不表示 AppPreferences 生产后端、指令或 UI 已启用。指定 Cursor verifier 不可调用的缺口保留，不重查登录、不改认证、不由其他复核替代；历史 C2B、人工、原生与视觉缺口不变。

#### 接口与完整格式

| 文件 / 入口 | 实际责任 |
|---|---|
| [LocalPreferenceRecord.swift](../AreaChain/Services/LocalPreferenceRecord.swift) | LocalPreferenceStoreIdentity、LocalPreferenceValues、LocalPreferenceFieldRevisions、LocalPreferenceRecord、LocalPreferencePendingWrite；复用 LocalPreferenceField / Value 与 RawValue.canonicalValue 的严格语义。 |
| [LocalPreferenceFileStore.swift](../AreaChain/Services/LocalPreferenceFileStore.swift) | `init(temporaryRoot:identity:fault:)`、`initializeNew(values:)`、`read()`、`commit(basedOn:changes:)`、`verifyPendingCommit()`；没有默认 root、生产目录解析、偏好/事件发布、CommandPlan 或展示闭包。 |
| [LocalPreferenceFileContract.swift](../AreaChain/Services/LocalPreferenceFileContract.swift) | FileRead / FileCommit / FileRecovery 三类结果及封闭错误；窄故障枚举只选择固定边界，不执行任意用户回调。 |
| [LocalPreferenceFileIO.swift](../AreaChain/Services/LocalPreferenceFileIO.swift) | 显式既存临时目录句柄；同目录候选、排他创建、一次 renameat、完整重读、协作锁与身份确认清理。 |

当前 schemaVersion = 1。`current.json` 含 identity.storeID / epoch（UUID）、recordRevision（UInt64）、四个 fieldRevisions、commitID、parentCommitID、migrationID（可空）和四个必填类型化 values。语言保留 system/chinese/english，外观 system/light/dark，截断 tail/middle，来源标记是真 Bool；system 不冻结成当前系统解析值。初始化修订均为 1，后续记录修订每次加 1，请求字段修订各加 1（包括组内无变化成员），未请求字段修订保留；溢出拒绝，不环绕。父提交只说明直接前驱，不构成撤销历史。

migrationID 是未来迁移所需的最小引用；本阶段合成新记录为空，发现非空 migrationID 或 `migration.plist` 就关闭写入口，不采集或解码旧偏好，也不实现迁移格式。旧 LocalPreferenceSource 的 ObjectIdentifier 从不序列化。记录读入先查 schema，再完整解码/验证四值与修订；缺字段、坏枚举、数字/字符串冒充 Bool 都失败，不调用 initialValue 补默认。

`pending-write.json` 只有 schemaVersion、可空基记录 evidence、目标 evidence 和 1～4 个不同字段稳定名。evidence 绑定 storeID/epoch、修订、commitID 和完整记录 sortedKeys JSON 的 SHA-256 摘要；摘要用于一致性核验，不是签名或防恶意伪造。pending 不含四值、旧命令、run、lease、正文或用户内容，不能作为可编辑权威。候选文件名由目标 UUID 生成，`candidate-<commitID>.json` 与 current 在同一目录。读取不按文件时间选最新。单文件读取上限 64 KiB，超限/非普通文件/符号链接/多硬链接视为不可读，诊断不带原始数据和底层路径。

root 必须在当前临时目录或规范化 `/tmp` 的子目录内且已存在；目录句柄和最终目录身份受检查。只有显式 `initializeNew` 能创建第一份记录，且目录必须只含本协议的空 writer.lock（或全空）。不因 current 缺失自动新建，未完成 pending、孤立候选、迁移证据及无关文件均阻止初始化。普通读取只读，首次确证全空不会创建锁。关闭未来新写入口不影响现有 schema 读取代码；本阶段不提供旧键回填、迁移或降级工具。

#### 一次提交与锁范围

输入是完整基记录和 `[LocalPreferenceValue]` 数组。先校验 1～4 项、字段唯一、完整基记录及来源；非法请求在任何文件 IO 前拒绝。锁内重读 current，旧记录版本不能超前；同修订须整份相等，较旧基线只在请求字段值/修订均未变、所有字段修订未倒退时可接受。这样保留无关字段的最新合法值，同字段 ABA 留下修订而冲突。此入口不是命令基线签发器，未来适配仍须校验原草稿/运行身份。

全部请求目标已满足时返回 noChange：不生成候选、pending 或新 commitID，不改 current、字段修订、锁内容或其他辅助文件。部分目标已满足仍生成一个完整目标，所有请求字段同属一次提交，不逐字段循环存储、不回填模拟回滚。

有变化时：获得窄锁 → 读取并核验完整 current → 校验基线/全部请求 → 完整编码目标和 pending → 排他创建同目录候选并读回 → 排他创建 pending 并核对 → 再检查目录/锁身份、current、pending 和候选 → **一次 renameat 替换 current** → 重新打开并完整核实目标及 pending → 返回提交事实并尝试清理。任何准备失败都没有到达权威替换；已产生但不能完整识别的辅助文件保留，并阻断后续写入。只读核验和清理不会再次调用替换。

与 §9.57 的 Foundation replace/move 候选相比，实际提交选用 Darwin 同目录 renameat，首次创建和已有替换共用同一命名空间提交点，避免两种替换路径或先删 current 的窗口。编码/读取仍用 Foundation，摘要用项目已有 CryptoKit；没有第三方依赖或业务 SwiftData。此选择不扩展成通用文件事务框架。

`writer.lock` 是不随 current 替换的稳定空文件，用非阻塞 flock。进程内按目录 device/inode 登记占用线程：同线程重入明确 reentrant，其他线程/进程占用返回 lockBusy，不忙等；打开锁还核验普通文件与链接数。锁保护遵守本协议的读核验/写入者，持有到完整重读及本次辅助清理结束；比较与替换之间没有 await 或任意应用回调。它不锁 UserDefaults、旧应用、任意编辑器或绕过协议的恢复器，不能检测完整旧字节连同修订被外部放回的 ABA。本阶段没有内存发布；后续发布必须额外维护提交版本/唯一所有者，不能把当前函数返回自动理解为窗口已经更新。

后端锁与 `build/.build.lock` 是两套机制；测试只在本例随机临时 root 创建 writer.lock。工程测试沿原验收锁正常非等待申请，不删除、抢占或终止其他持锁任务。

#### 结果、未知与重开

| 实际事实 | 返回与后续写入 |
|---|---|
| 全部目标满足且无基线冲突 | noChange，零权威/辅助写入。 |
| 纯输入、编码、暂存、pending 或最终资格检查失败，未进入替换边界 | notCommitted(issue)，能证明本调用没有提交；若已留下证据，后续写入口仍须关闭。它不保证准备 IO 完全没有发生。 |
| 当前基线/请求字段已变化 | conflict(current)，整组零提交；不自动改基线。 |
| 替换返回且完整 current 身份/内容和 pending 核实一致 | committed(record)，当前完整文件可核验；后端没有发布内存或展示。 |
| 上述提交已确认，辅助清理失败 | committedCleanupPending(record)，不能改称保存失败；后续仅核验/清理。 |
| 已进入替换边界而抛错，或替换后读回失败/不一致 | unknown(pending, issue)，即使稍后能看见目标也先保留调用未知；不自动重试写入。 |
| current 不可靠、pending 未解决、来源/证据不符、孤立准备或未实现迁移来源 | recoveryRequired / unavailable，关闭整组写入口，保留文件。 |

read 用 absent、record、pending、unavailable(issue) 分开表达；issue 区分 readFailed、corrupt、unsupportedSchema、sourceMismatch、inconsistentEvidence 等，不把损坏/权限错误当 ENOENT。pending 存在时即使 current 已是目标也不直接给可写基线；须显式核验。进程内未知登记额外防止辅助证据被移除后同实例继续覆盖；它不是跨重启日志。

`verifyPendingCommit()` 在相同锁内只检查当前完整记录：

- 当前身份和摘要完整等于目标，且 parent 与 pending 基身份相符：confirmed，最多清理本 pending 的辅助文件；清理失败 confirmedCleanupPending，不重写 current。
- 当前完整等于基记录，或 current 缺失：historicalUnknown。它不能证明目标历史上从未短暂生效，不自动接受基值或补写目标。
- 当前为同来源的另一合法提交：superseded，保留当前权威和 pending，不回滚、不宣称旧提交成功；接受当前/关闭证据的用户恢复操作尚未实现。
- 同 commitID 对应不同内容、来源不符、损坏、未知 schema、读失败：blocked，全部写入口保持关闭。候选、pending 或迁移证据都不被当成权威值。
- 没有待核实证据：nothingToVerify，不生成提交或修订。重复核验/清理不会再次提交。

清理只针对 pending 的确定候选名及 pending 自身，删除前重读核对身份/内容；不枚举删除无关文件、不删除锁、不尝试“修好”坏辅助文件。未决状态不会被后续提交覆盖。没有显式接受当前或重建工具，没有恢复 CommandPlan、重放命令或复活旧 lease/run。

#### 保证层级与验证记录

API 层提供完整编码、协作写入下的一次命名空间替换及完整读回归因；current 的原子替换不等于 pending/current 跨文件事务。不实施 fsync/F_FULLFSYNC 或目录耐久屏障，不承诺掉电零丢失、网络卷语义、任意外部编辑比较交换或全部窗口同时更新。进程中断与掉电必须各自取证，下面故障注入不替代真实进程终止实验。

实际测试新增 [FileStoreTests](../AreaChainTests/Services/LocalPreferenceFileStoreTests.swift)、[RecoveryTests](../AreaChainTests/Services/LocalPreferenceFileRecoveryTests.swift)、[ConcurrencyTests](../AreaChainTests/Services/LocalPreferenceFileConcurrencyTests.swift)，共用 [FileTestSupport](../AreaChainTests/Services/LocalPreferenceFileTestSupport.swift)。每例由 FileManager.temporaryDirectory 创建随机独立 root，只清理自身目录。索引维护仅追加到[组件目录](component-catalog.md)、[路由](../skill-routing.md)、[架构](architecture.md)和[工程手册](engineering.md)；稳定符号与反例沿 [check_workflow.py](../scripts/check_workflow.py)、[test_check_workflow.py](../scripts/tests/test_check_workflow.py) 原入口增量维护，保留并行修改。

本轮环境为 macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113）、Swift 6.3.3（工程语言模式 5）、Python 3.9.6；不表示最低支持系统已实测。日志与命令材料根目录为 `/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B1-k2sgwq_l`，以下简称本轮临时根。

| 检查 / 最终证据身份 | 实际结果及限制 |
|---|---|
| 首次完整 QA 编译 | 退出 65：stat 的 Swift 名称冲突及多条件 guard 缺显式 try；改用 lstat 并补 try。无测试运行，日志 tests.log。 |
| 第二次完整 QA 编译 | 应用代码编译通过，测试闭包缺错误传播导致退出 65；将测试第二实例构造移到闭包外，日志 tests-repaired.log。不改成功判据。 |
| 第三次正常完整 QA 目标、十套定向 | 通过；68 个测试定义、80 次执行，0 失败、0 跳过、0 预期失败。结果 `DerivedData/Logs/Test/Test-AreaChain-2026.10.04_23-40-55-+0800.xcresult`、tests-complete.log、summary.json / tests.json。覆盖三套新文件测试及 LocalPreferenceTests / FailureTests、原 LocalSettingCommand Tests / Boundary / Conflict / Failure / Identity。完整目标仍有原有未用变量/辅助 API 警告，不删除或排除并行源码。 |
| 通过后的最后边界补充 | 增加四成员真实提交、编码故障下 noChange、非法 root/修订、溢出、pending 重复字段/未知版本与不明候选保留；将后端无锁读取/清理辅助方法及 IO 属性收为 private。两次非等待重验均退出 3，尚未启动，因此上行通过只保留该次版本身份，不覆盖最后修改。 |
| 正常配置 Debug / 验签 | `./scripts/build.sh --no-wait` 退出 3（build.log），其他任务持有原验收锁，本轮未启动最终正常构建或验签。第三次 QA 的编译不能代替此项。 |
| 严格局部 SwiftLint | 本轮八个 Swift 文件在最后 private 边界修改后检查通过。只证明风格，不冒充编译/运行。 |
| 工作流与脚本反例 | check_workflow.py 通过；定向 test_check_workflow.py 95 项通过；quality_gate.py --profile static --strict --format json 通过，内含 scripts/tests 215 项回归。最终文档编辑后同入口复跑通过。 |
| 指定只读复核 | Cursor verifier 无可调用工具，未执行；不认证、不替代，整体治理验收保持 partial。 |
| 真实进程中断 / 掉电 | 未执行进程 SIGKILL、跨进程提交竞争、掉电或 fsync 耐久实验。只做真实临时磁盘加确定故障注入、同进程对象重开；独立文件描述符 flock 拒绝验证不冒充跨进程实测。未终止用户任务、验收持锁进程或任何测试宿主。 |

通过版本实际覆盖：初建/重开、system 与四值往返、单字段/多字段及部分 noChange、全 noChange 前后内容/inode/mtime 相同、重复字段/坏值/缺字段/旧字段修订/ABA/来源不符、编码/候选部分写/pending 部分写/最终资格/替换调用前后/读回/清理故障；明确区分替换前未提交和已进入替换边界的未知。故障后的 current 保持完整基记录或完整目标，未知挡住后续写入；重开目标只核实/清理、基记录保留历史未知、其他合法记录保持权威并报告替代、损坏/未知版本/读取失败关闭写入口。核验前后 current 内容/inode/mtime 不变，重复核验不提交；两个任务竞争只得一次成功，另一方冲突或 lockBusy，同线程重入为 reentrant。它们不证明真正进程中断或掉电的所有落点。

QA 运行沿正常完整 AreaChain scheme/app/test target（不排除编译源码），原 build/.build.lock 非阻塞 flock 覆盖完整 xcodebuild 生命周期，独立 `PRODUCT_BUNDLE_IDENTIFIER=com.areachain.preference-file-qa`、临时根下 DerivedData、`AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements INFOPLIST_KEY_LSUIElement=NO`、arm64、`-parallel-testing-enabled NO test` 及十个 `-only-testing`。六项真实钥匙串变量（含 TEST_RUNNER 形式）全部移除，只由 XCTest 启动隔离宿主。没有运行完整 SettingsView、真实系统认证、用户偏好或业务库；旧测试仅用随机 suite 与注入副作用。静态 profile 配明确 QA 取代 auto/swift 全量，以免无关并行 Swift 改动启动排除能力。

本轮来源摘要核对确认 AppPreferences.swift、LocalPreference.swift、LocalPreferenceDependencies.swift、LocalSettingCommandAdapter.swift、LocalSettingCommandMapping.swift 未被本任务改变。真实旧偏好未读取/迁移、旧键未双写，未安装、发布、提交或推送。上轮停止时状态为 **partial**：新后端已实现，已有一轮隔离通过；当时最后边界补充与 private 收口缺最终 Swift 编译/运行，正常 Debug/验签未运行，指定复核亦缺失。只读观察并行 xcodebuild 50 秒后仍在运行，未再申请或干预其锁；不拿旧通过替代最后版本证据。真实中断/跨进程及历史缺口不豁免。

#### 最终收口：后端本地验收完成

2026-10-05（Asia/Shanghai，结果包时间）。本轮只核对与复验已有最后修改，没有新增 Swift 场景、改变断言或修复产品代码；本轮仓库编辑仅在本 §9.58，之前暂存/未暂存及并行工作均保留。不进入 3B2。

**影响核对。** 最后未验增量为 FileStoreTests 的四成员真实提交、编码故障下 noChange、非法临时 root/修订及溢出，以及 RecoveryTests 的重复 pending 字段、未知版本与身份不明候选保留。FileStore 的 io/fault 属性和 readLocked/readCurrent/readPending/cleanup 收为 private；四个对外方法和构造签名未改。唯一直接受访问级别影响的消费者是 ConcurrencyTests 的重入用例，现已显式建立自己的 LocalPreferenceFileIO，再通过公开 commit 验证拒绝与释放后可写，不再访问 store.io。其余原文件后端用例继续经同一公开 API 回归，没有放宽锁或跳过失败断言。

全仓符号检索确认生产 AppPreferences、单项适配器、Domain 与 UI 不调用上述内部接口。旧五文件摘要仍与 B1 开始时相同；兼容验证仅补 LocalPreferenceTests / LocalPreferenceFailureTests，以核实复用四值、严格解析和旧初始化/失败语义。未受本次访问级别收口影响的 CommandPlan、单项指令适配器五套及 UI 不重复运行，其前轮测试继续保持历史身份，不算本轮新证据。

| 最终源码证据 | 实际结果 |
|---|---|
| 正常完整 QA 编译与五套定向测试 | 首次正常取得原 build/.build.lock，执行 LocalPreferenceFileStoreTests、LocalPreferenceFileRecoveryTests、LocalPreferenceFileConcurrencyTests、LocalPreferenceTests、LocalPreferenceFailureTests；34 个测试定义、44 次执行全部通过，0 失败、0 跳过、0 预期失败。没有排除编译源码或新增场景。 |
| 最后补充及 private 兼容 | singleAndWholeRecordCommitsPreserveTypedSystemSemantics、allNoChangeWritesNothingAndPartialNoChangeIsOneRevision、rootMustBeExplicitTemporaryChildAndMalformedRevisionsAreNotWritable、inconsistentPendingAndForeignCandidateRemainUntouched、sameThreadReentryIsRejectedAcrossInstancesAndLockReleaseAllowsCommit 均有 Passed 结果，覆盖上轮未验增量。 |
| 两实例竞争 | twoConcurrentInstancesNeverSilentlyOverwriteSameOldRevision 通过：同一测试进程中两个 Task、两个后端实例，以同一旧修订竞争；恰好一次 committed，另一方 conflict 或 lockBusy，最终修订为 2。独立文件描述符 flock 及同线程重入/释放用例也通过。**这些均不是跨进程实测。** |
| 正常配置 Debug 与静态验签 | 测试通过后执行 `./scripts/build.sh --no-wait`，正常取得原锁，退出 0；沿当前 development 配置，Debug 构建成功且 staticSignatureVerified = true、hardenedRuntime = true。产物 `/Users/as/Ai-Project/project/AreaChain/build/development-DerivedData/Build/Products/Debug/AreaChain.app`；未安装、启动或发布。静态验签不表示真实系统解锁已验收。 |
| 最终 lint / 工作流 / 静态门禁 | 对本阶段八个 Swift 文件运行 `swiftlint lint --strict --quiet`；运行 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --strict --format json` 和 `git diff --check -- docs/unified-search-commands.md`。均通过；静态门禁内 scripts/tests 215 项通过。证据为本轮 closure-lint.log / closure-workflow.log / closure-static.json；文档补记后再次通过局部 lint、工作流、docs strict 与差异检查。静态 profile 不执行全量应用验收。 |
| 指定复核及未执行实验 | Cursor verifier 未执行，缺口保留且不重查认证。跨进程竞争、真实进程 SIGKILL/中断、掉电与 fsync 耐久实验均未执行；没有新增保证或终止其他进程。 |

本轮沿前述完整 QA 配置、独立 Bundle ID、原临时根下 DerivedData、六项真实钥匙串变量清除与串行测试，只将 only-testing 缩至上述五套。实际命令为临时根的 closure-test-command.json；测试结果为 `DerivedData/Logs/Test/Test-AreaChain-2026.10.05_00-00-32-+0800.xcresult`，汇总/测试树为 closure-summary.json / closure-tests.json，编译日志 closure-tests.log；正常构建与验签记录 closure-build.log。本轮测试及构建均正常取锁，没有锁忙重试、轮询、抢锁或干预其他任务。QA 完整测试目标仍有既有 AppKit 辅助 API 废弃警告，未因此修改不相关测试。

最终相关源码 SHA-256 前缀用于绑定这次证据：FileContract `e0e4a131e2ffd8e0`、FileIO `e643c015de5267c9`、FileStore `bf8c91c470ab2855`、Record `7aabd4461c21a872`；ConcurrencyTests `06d638e74ef5ac18`、RecoveryTests `014ed04cdb81b30b`、FileStoreTests `8b5ba8afdaa30f4c`、FileTestSupport `83d3ff960329d6c1`。测试前与构建后逐文件核对一致；之后只修改本文。旧 AppPreferences、LocalPreference、LocalPreferenceDependencies、LocalSettingCommandAdapter、LocalSettingCommandMapping 也均未改变，不读取其真实存储取证。

**本地验收结论：已完成本轮要求的最终源码定向测试、受影响兼容回归、正常 Debug 构建与静态验签；整体治理仍为 partial，唯一指定复核缺口未消除。** 文件保证继续限定为 API 层一次完整替换/读回及已测故障处理；同进程重开不冒充真正进程中断恢复，flock 实现不冒充跨进程实验，不承诺 fsync 或掉电零丢失。用户设置、迁移、AppPreferences 生产后端、指令/UI、提交、推送和安装均未触及；交接后停止。

#### 3A-3B2 与后续接入要求

3A-3B2 先在合成旧四键/隔离 suite 中实现迁移证据、来源判别和初始化状态机：只采四键，坏旧值阻断，旧键原样保留、不双写，新记录成功后唯一权威；注册/临时覆盖、部分缺键、中断和旧版读取分别验证。当前 migrationID 非空/迁移文件一律关闭的门禁只能随已验证迁移适配明确演进，不能用本轮 initializeNew 绕过未完成迁移。真实用户迁移、恢复、携最新值降级都未执行。

AppPreferences 接入须先把四项可观察状态改为一次完整发布，成功事实先于展示副作用；冷启动读取失败保持不可写，不能用默认值签发基线。旧 Binding 同值赋值的推进/展示语义与命令 noChange 不同，本轮文件接口只提供 noChange 政策，后续须在共同后端显式支持已确认的旧页语义，不能悄悄改变它。组事件、迟到展示版本检查、原 Plan/Run 两阶段事实和未知核验归属分别接入；当前单项 UserDefaults 结果矩阵不改写。生产默认后端、生产搜索、UI、迁移、撤销和下一阶段实现全部保持未接线。到本阶段停止。

### 9.59 阶段 3A-3B2A：旧四键隔离迁移、重开与恢复判定

2026-10-05（Asia/Shanghai）。本轮只实施独立测试 UserDefaults suite、显式临时目录内的迁移及启动判定；以本节扩展 §9.58 的迁移占位拒绝，§9.57 政策保持。AppPreferences 生产后端、用户偏好、业务 SwiftData schema、指令/UI 与 3B2B 整份内存发布均未接入。真实用户迁移、数据恢复与携最新值降级未执行。指定 Cursor verifier 缺口保留，不重新检查登录、不改认证、不冒充复核。

#### 旧源及严格解析

[LocalPreferenceLegacySource](../AreaChain/Services/LocalPreferenceLegacySource.swift) 要求显式 `LocalPreferenceLegacyIdentity.isolatedSuiteName` 与逐字段读取闭包；没有默认 UserDefaults、生产来源工厂或 AppPreferences 初始化。`capture()` 只请求 LocalPreferenceField.allCases 四键，观察值分别包含 exists、persistent、effective、origin；来源枚举区分 persistentDomain / declaredDefault / registration / volatile / managed / unknown / conflict。有效值与物理值即使相同，外部覆盖仍不合法。空来源身份、读取失败、存在性矛盾、非法枚举、非 Bool 与未知负载全部阻断。

此处的来源标签是显式注入的受控读取器契约，**不是由值相等推断来源，也不是生产 UserDefaults 搜索域识别器**。实际测试读取器只拥有自己新建的随机 suite，四次 `CFPreferencesCopyValue` 指定该 suite、currentUser、anyHost，获取物理原值；四次该句柄 `object(forKey:)` 获取可见值。注册/临时/受管理/来源不明/冲突均为逐键注入反例；不调用 register 或 setVolatileDomain 修改进程共享搜索域。不调用 persistentDomain/dictionaryRepresentation 采集整个域，也不读取标准设置。一般 UserDefaults 的受管理、启动参数、全局、其他 suite/currentHost 来源不能仅凭上述值证明；后续生产适配必须另行提供可靠来源证据，不能复用夹具推断或用一个声明布尔值开放迁移。

复用 `LocalPreferenceRawValue.canonicalValue` 严格解析：缺键才得到 system/system/tail/false；合法 system 原样保存。`initialValue` 的旧版宽松回退与布尔转换保持原实现，迁移不调用它掩盖坏值。坏复合负载只留在原测试域；返回封闭字段/原因，不输出负载、全部域或底层错误。所有旧键操作在测试夹具中，迁移服务没有旧源写接口。

#### 迁移格式与一次权威切换

[LocalPreferenceMigrationEvidence](../AreaChain/Services/LocalPreferenceMigrationEvidence.swift) 使用二进制 `migration.plist`，schemaVersion = 1。payload 包含 migrationID、source.isolatedSuiteName、初始 target（storeID/epoch、revision、commitID、完整记录摘要）、四项固定键的 presence Bool 和完整合法 values。presence=false 表示原始键不存在、有效值为原默认；presence=true 表示原始值就是相同字段的合法 values 原值。只允许持久域和已声明默认两种成功来源，故由 presence 唯一表达成功来源，不保存未知/错误类型或额外字段负载。

证据外层 digest 为 payload 规范 sortedKeys JSON 的 SHA-256；target 摘要复用 RecordCodec，绑定完整初始记录及 migrationID。读取检查 schema、来源形状、恰好四项 presence、缺键默认一致、payload 摘要及可重构的初始目标摘要。摘要用于损坏/关系核验，不是签名或恶意篡改认证。后续记录保留 migrationID；初始记录必须完全匹配证据，第二次修订的 parent 必须指向初始提交。后续不保存全历史，不承诺验证任意外部伪造的历史链。

`LocalPreferenceFileStore.migrate(from:)` 持原非阻塞目录锁，按以下顺序工作：

1. 读取 current、migration、pending 和 candidate，只有确证不存在且目录仅空 writer.lock 时才允许开始。
2. 采集并严格验证四键及来源，生成新的 migrationID 和完整初始 target；修订和字段修订均为 1。
3. 排他创建 migration.plist 并完整读回核验；已有证据不覆盖、不更新、不复用身份迁移不同来源。
4. 再采集同一旧源四键，比较原值、有效值、存在性和来源；变化拒绝提交并保留第一次证据。第二次来源不明或失败也阻断。
5. 调用原 `perform(base:nil,target:fields:lock:)`：完整准备 candidate/pending、核验目标迁移关系及目录/锁/记录资格、一次 renameat 建立 current、完整重读 current/pending/迁移关系，再清理本 pending。
6. 返回完整权威记录或明确失败/恢复结果；没有先 initializeNew 再补 migrationID 的第二次权威提交。

锁覆盖本后端协作读写者，**不锁旧 UserDefaults、旧版或其他来源写入者**；第二次采集不是跨存储事务，也不能排除两次采集之间的外部 ABA。受控夹具用于本阶段；生产迁移前须确保旧版及其他旧源写入者已停止。migration 永久只读保留，后续偏好提交不更新它。未新增锁、提交算法、恢复引擎或独立 migrated=true 开关。

#### 重开、恢复与 3B2B 接续

`reopen(from:)` 先读新来源；current 或任何迁移/准备状态存在时不采集旧源。pending 沿原 `verifyPendingCommit` / `verifyLocked` 核验，不从辅助值重建 current、不按 mtime 选值、不恢复旧命令队列。

| 观察 | 本阶段结果及写入边界 |
|---|---|
| 全部文件确证不存在或仅空 writer.lock | `notMigrated(readOnly: Values)`；只读四值供后续兼容显示，须显式 migrate。坏旧源返回 conflict/failed，不能默认为空。 |
| 只有完整 migration、孤立准备、pending 且 current 缺失 | `recoveryRequired`；incompleteMigration / orphanedPreparation / historicalUnknown，保留原件，不重新导入。 |
| current 与 migration 完整一致且无 pending | `ready(record, cleanupPending:false)`；唯一权威来自 current。旧四键变化甚至坏值不被读取/吸收。无 migrationID 的原 B1 合成记录继续兼容。 |
| pending 目标完整等于 current | 原恢复路径 confirmed，至多清理已核对的 candidate/pending；返回 ready，不改 current 内容、inode 或时间。 |
| current 仍是 pending 基记录 | historicalUnknown；保留安全当前记录和未决证据，不断言历史未提交、不重试。 |
| current 是同来源另一合法记录 | superseded；保留当前记录、旧 pending 及诊断，后续显式恢复前关闭写入。 |
| current 损坏、未知 schema、不可读；迁移证据缺失/不符/损坏 | recoveryRequired，带封闭原因，全部文件写入关闭；不退回可编辑旧键。 |
| current 已确认但清理失败 | `ready(record, cleanupPending:true)`，提交事实保留；如 pending 仍在，普通 commit 会阻断直到再次核验/清理。 |
| 本次尚未进入替换就失败 | failed 或 conflict，证明本次未提交；已有证据不删除，下次按恢复表判断。 |
| 已进入替换调用边界但失败/读回未知 | recoveryRequired.unverifiedCommit(pending, issue)，不发布候选或伪造提交事实。 |

`LocalPreferenceMigrationResult` 是 3B2B 的最小输入。只有 ready 的完整 LocalPreferenceRecord 可作为已核实的整份发布候选；cleanupPending 必须另表征写入健康状态。notMigrated 的只读兼容值、conflict、failed、recoveryRequired 不能签发可写基线。historicalUnknown/superseded 的 current 只用于恢复说明，不等于已经解锁写入。后续内存唯一所有者还须核对版本、实现一次发布和展示；本阶段不构造 shared、不应用 NSApp 外观、不发偏好/业务事件，迁移不冒充用户命令。

`initializeNew(values:)` 保留无迁移合成新建行为，但任何迁移、pending、孤立候选或异常目录状态都阻断。原 B1 非空 migrationID/存在迁移文件的一律拒绝，替换为真正的格式、摘要、目标身份及迁移关系核验；没有仅删守卫放行任意记录。

#### 旧版兼容与限制

成功前后四旧键及物理缺失原样保留；新后端后续共同提交/noChange 不写旧域、不双向合并。旧版仍只看迁移前值；旧版后来改键，新版继续读取 current。携最新值降级须另行获准的数据回退，本阶段没有回填工具，不承诺旧版看到新版最新设置。业务 schema、旧 AppPreferences 四属性/存储依赖和单项指令适配器不改变。

#### 本轮验证与停止记录

实现及本地验收已完成，整体治理验收保持 **partial**：指定 Cursor verifier 无可调用工具，未执行；历史缺口不豁免。故障注入和同进程后端对象重开与真实进程中断分开；本阶段不新增跨进程、SIGKILL 或掉电保证。

本轮证据根目录为 `/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B2A-xd80mbtf`。环境为 macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6；不代表最低系统已实测。

| 实际执行 | 结果与证据 |
|---|---|
| 前两次完整 QA 编译 | 退出 65，Swift Testing 宏内的错误传播/闭包推断不通过；修正测试构造位置及分开断言，未改变产品规则，日志 tests.log / tests-repaired.log。此时测试未运行。 |
| 第一次运行八套 QA | 9 个测试定义失败，记录 initial-summary.json / tests-complete.log。新夹具对 NSArgumentDomain 的临时设置影响测试进程其他 suite，导致原旧偏好回归也读取到覆盖值；已移除 register / setVolatileDomain，改为逐键注入有效覆盖及来源，不保存或读取真实用户设置。原失败判据保留。 |
| 最终完整正常 QA 编译＋八套定向 | **51 个测试定义、83 次执行通过，0 失败、0 跳过、0 预期失败**。包括 MigrationTests / MigrationRecoveryTests / MigrationEvidenceTests、原 FileStoreTests / FileRecoveryTests / FileConcurrencyTests 及 LocalPreferenceTests / LocalPreferenceFailureTests。实际参数 test-command.json，日志 tests-isolated.log，结果 `DerivedData/Logs/Test/Test-AreaChain-2026.10.05_00-36-27-+0800.xcresult`，summary.json / tests.json。 |
| 正常 Debug 构建与静态验签 | `./scripts/build.sh --no-wait` 退出 0，build.log；沿现有 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false。产物 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`，未安装、启动日用应用或发布。 |
| 局部严格 lint | 本次 10 个 Swift 文件的 `swiftlint lint --strict --quiet` 通过；未把已有完整目标的 AppKit 辅助 API 弃用警告写成已修复。 |
| 工作流及质量门禁 | `python3 -B scripts/check_workflow.py` 通过；定向 `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` 的 96 项通过。`python3 -B scripts/quality_gate.py --profile static --strict --format json` 通过，包含 scripts/tests 216 项。最终文档后重跑工作流、同静态门禁、局部 lint 和 git diff --check。 |
| 指定复核与未执行实验 | Cursor verifier 未执行，缺口保留；真实进程终止、中断/掉电、跨进程竞争、生产来源识别与真实迁移未执行。锁测试只含同进程竞争、独立描述符互斥和迁移重入拒绝；不声称跨进程实测。 |

QA 保留完整正常 AreaChain scheme/app/test target，不排除编译源码；采用独立 `com.areachain.preference-migration-qa`、本轮根目录下 DerivedData、本机临时签名覆盖、原 entitlements、arm64、串行执行及八套 only-testing。六项真实钥匙串变量（含 TEST_RUNNER 形式）全部清除；原 build/.build.lock 正常非等待申请覆盖整个 xcodebuild 生命周期，各次正常获锁，无锁忙重试/抢占/终止其他任务。静态 profile 配合明确隔离 QA，避免 auto/swift 把并行改动带入无关全量运行。

最终测试逐项覆盖全缺/部分缺/完整/system、非法类型与枚举、相等覆盖也拒绝、读取失败、来源变化和存在性变化、16 个迁移/候选/pending/替换/读回/清理故障落点、current/证据缺失损坏未知版本及身份不符、初始 pending 不符、后续基/目标/其他合法记录核验；保留 current 与 migration 的内容/inode/mtime，重复重开不重新迁移。旧键前后相同，新提交不双写，旧版改键及坏旧值不被新版吸收。来源覆盖是注入证据，真实磁盘文件和四键读取是真实隔离 IO；这些层次不互相替代。

构建后逐文件校验 tested-hashes.json，与通过测试的偏好源文件/测试完全一致。AppPreferences、LocalPreference、LocalPreferenceDependencies、LocalPreferenceFileIO、LocalSettingCommandAdapter、LocalSettingCommandMapping 与本轮开始前摘要一致；原有暂存/未暂存和并行修改保留。迁移接口没有产品调用方，不读用户库/设置，不接生产后端、指令、UI 或业务事件。不提交、不推送、不安装、不发布；到 3A-3B2A 停止，不进入 3B2B。


### 9.60 阶段 3A-3B2B：AppPreferences 聚合后端、整份发布与展示事件

2026-10-05（Asia/Shanghai）。本阶段只接显式临时文件后端、隔离旧键域与注入展示副作用；沿 §9.58 的 FileStore 和 §9.59 的 migrate / reopen / MigrationResult，不复制提交、迁移或恢复算法。**生产 `AppPreferences.shared = AppPreferences()` 继续旧后端；没有自动迁移用户设置、生产默认目录、业务 Persistence 依赖、多项指令执行或新生产 UI。** 下文是本阶段新接口；§9.54～§9.59 保留各阶段历史。完成后停在 3B2B，3B3 未实施。

#### 显式装配与唯一状态

| 入口 | 责任与限制 |
|---|---|
| [AppPreferences.init(defaults:fileStore:startup:effects:)](../AreaChain/Services/AppPreferences.swift) | 四个参数均显式提供。fileStore 仍受原 temporaryRoot 约束；startup 是 LocalPreferenceMigrationResult。defaults 只用于尚未迁移的偏好；新模式的 localStorage 为 nil，四项不会读取或写入旧键。 |
| 原 init(defaults:localStorage:effects:) / shared | 保留原签名和旧后端默认，四属性即时写入、旧严格/宽松读取及旧单项回执矩阵不变。初始化四值在局部装配后一次赋值。 |
| [LocalPreferencePublishedState](../AreaChain/Services/LocalPreferencePublication.swift) | legacy / readOnly / committed 三种不可变发布值；文件模式只保存完整 LocalPreferenceRecord，不另存四个可编辑标量。所有 getter、resolvedLocale / resolvedColorScheme、AppChrome 和旧 Binding 均读取同一状态。 |
| committedLocalPreferenceRecord | 只读投影最后完整发布记录，包含 storeID/epoch、recordRevision、fieldRevisions 和 commitID。是运行内已确认快照，不声称磁盘监听或命令签发。 |
| localPreferenceBackend / canWriteLocalPreferences | 单独表达旧后端、ready、只读启动、verificationRequired、cleanupPending、unknown。完整载荷存在不等于可以写入。 |
| lastLocalPreferenceCommit / lastLocalPreferenceRecovery | 保留最近一次实际后端调用的原始结果；门禁拒绝或展示重试不覆盖原 unknown/committed 事实。核验结果不改写历史调用结果；能否发布/再写还需查询 backend。 |

本次明确采用两种同值政策：**旧后端同值 Binding 继续写键、推进旧字段修订并按原次数应用展示；新文件后端同值 Binding 与共享组入口返回 noChange，零权威/辅助写入、零发布、零多余展示。** 此条依本轮请求更新 §9.57 E / §9.58 后续建议中的“新后端旧页也强制同值推进”，不是统一修改两种后端的期望。

#### 启动、重新核验与写入门禁

| 输入/当前后端状态 | 显示与写入 |
|---|---|
| ready，schema/修订合法、身份等于注入 store、实际 read 为完全相等的 record | 一次完整装载，ready 可写。调用方拼出的枚举、仅值相等、旧修订或其他 store 身份不能直接取得资格。 |
| ready(cleanupPending:true)，实际 pending/current 与载荷相符 | 还须由原 verifyPendingCommit 确认目标；历史未知/替代不发布。confirmedCleanupPending 之后重新 read：pending 仍在则只读；cleanupAfter 已删除 pending、实际 read 为 record 时可写。 |
| notMigrated | 仅显示显式输入的只读兼容四值；不采集旧域、不 migrate、不创建 current。 |
| conflict / recoveryRequired / failed，或伪造/过期 ready | 冷启动只读默认，不签发可写基线；不会因为磁盘有一份记录就忽略调用方的未就绪状态。 |
| 运行内读取/恢复失败 | 保留最后完整发布状态，关闭写入口；不回退旧键写入，不覆盖故障文件。 |
| unknown | 原 pending/issue 单独保留，全部文件模式写入口（含 Binding）关闭；不发布候选四值。 |

startupAppearance 与 startupEvent 单独记录；初始化只调用一次注入外观，event 为 notCalled，没有用户提交事实或普通变更事件。外观初始化失败不把已经核验的文件状态改成未保存，不调用 MutationFeedback 或递归初始化 shared。

`verifyAndReloadLocalPreferences()` 是明确的后端核验请求，调用原 verifyPendingCommit，再核对实际 read 与待装载记录；没有 migrate、initializeNew 或 commit。confirmed / confirmedCleanupPending / nothingToVerify(record) 的后端事实与 AppPreferences 的发布门禁分别返回/查询。身份/epoch 变化、同源已见修订倒退、同修订异内容或无推进字段值改变都不能作为连续修订发布；失败保留原显示。pending 基记录的 historicalUnknown、其他提交的 superseded 及坏文件继续关闭，不自动接受当前、重放原命令或恢复执行队列。

#### 一次提交、一次发布

`applyLocalPreferences(basedOn:changes:) -> LocalPreferenceFileCommit` 接完整基记录与 1～4 个类型化不同字段。字段唯一性、严格类型、两层修订、无关字段保留、文件锁内最后基线核验及一次替换全部由原 `LocalPreferenceFileStore.commit` 承担；AppPreferences 不循环四个 setter，也不自己写文件。旧四个 Binding 在文件模式中将一次赋值转为一个字段的聚合调用。

按结果处理：

- noChange：保留原结果，不发布和不调用展示；如后端报告的当前记录比内存更新，标记需显式核验装载，不偷偷刷新基线。
- notCommitted：不发布候选，统一进入 verificationRequired；即使 current 仍完整可读，也须显式核验之后才重新开放。准备残留、读失败或待核验状态保持关闭，不自动重试。
- committed / committedCleanupPending：先登记完整原结果及健康状态，再单次 `localState = .committed(record)` 发布所有值及修订，然后处理展示。清理失败不否认提交。
- unknown：保留最后完整显示和原未知证据，关闭全部新后端写入。
- conflict / recoveryRequired：完整保留原结果，不发布候选、不回退旧键；显式核验之后才能重新装载/开放。

AppPreferences 的同步重入守卫覆盖后端调用、事实记录、Observation 发布、外观和事件，也覆盖显式恢复与展示重试。新后端的四项读取共同登记 committedLocalPreferenceRecord 观察，withMutation 内只赋值一次；旧后端仍按单字段 key path 登记/失效，保留无关赋值不触发该字段观察者的旧行为。Observation 的 willSet 可读到完整旧记录，后续回调读取完整新记录，不出现语言已更新而外观仍旧的组合。文件锁范围仍是 §9.58 的后端调用；返回后到内存发布无 await，但不把 MainActor 扩称为跨进程锁，不声称其他进程无法在这段时间提交。

#### 提交与展示分开

[LocalPreferencePresentationLedger](../AreaChain/Services/LocalPreferencePresentation.swift) 只保留本 AppPreferences 生命周期内的 commit 身份、事件字段/修订及调用事实，没有可编辑设置值、计划或持久执行队列。提交/核验事实先登记；整份发布后，必要时应用当前 appearance，再发送一次 `.localPreferenceDidChange` 普通组事件。字段集合来自上次完整发布与新记录的值/字段修订差异，包含本次吸收的无关字段新值；部分 noChange 组成员按后端字段修订推进规则保留。

[LocalPreferenceGroupChange](../AreaChain/Services/LocalPreferencePublication.swift) 只含运行来源、storeID/epoch、recordRevision、commitID、变化字段集合及这些字段的修订。没有完整设置字典、正文或无关内容；旧后端继续发送原 LocalPreferenceChange。

外观和事件分别记 pending / returned / threw / notCalled / superseded，外观失败仍尝试独立事件；失败不回滚完整状态，不把已保存说成未保存。`localPreferencePresentation(for:)` 查询真实登记；`retryLocalPreferencePresentation(for:)` 只处理仍未完成的展示，未知 ID 不调用任何效果，已返回步骤不重复，不读取或写入偏好文件。每一步读取当前完整发布值并核对相关字段修订，后来的同字段提交使旧步骤/字段 superseded；无关字段推进不使外观重试失效。注入外观函数是同步调用契约，延迟工作须保留 commit ID 再走该重试入口，不能在外部保留旧 appearance 后自行应用。

[PreferenceObservation](../AreaChain/Services/PreferenceObservation.swift) 增加显式 preferences 初始化，延迟到 MainActor 执行时再与当前完整记录取字段交集；失效组登记 superseded，取消后的回调不刷新。部分字段被替代时只刷新仍有效的交集，消费者继续读取当前值，不应用事件捕获值。原 source 初始化及单字段事件兼容。

- PanelWindowController / StatusItemController：语言与外观 chrome；菜单栏沿已有计数绘制，不重查业务库。
- DiaryWindowController：仅语言 chrome，正文 session.refresh 仍只属于旧/业务事件。
- CalendarSync：普通订阅字段为空，仍只消费原旧事件；普通组事件不请求日历或通知排程。
- AppChrome、标题截断继续观察同一偏好；捕获来源标记仍仅在后续创建时读取，本轮不执行真实捕获。

这些事实只保证同步效果调用与安全刷新路由，不保证全部窗口像素同时更新或异步消费者已经完成。

#### 旧接口与 3B3 接续

文件模式的 readLocalSetting 不读取旧键，raw 明确 unavailable；旧 applyLocalSetting 返回 unsupportedBackend，不拼造 LocalPreferenceWriteResult 的 write/readback。Binding 走独立的聚合调用，而非该旧证据接口。[LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) 在装配资格、能力查询和 assembledPreferences 门禁拒绝文件后端；prepare/readiness/submit/execute 不签发基线、不封存或占用文件运行。原 UserDefaults 的单项基线、防伪、冲突、unknown 和展示重试矩阵保持。

3B3 可复用完整记录读取、一次组提交、backend 健康查询、原始 FileCommit / FileRecovery 和展示查询/重试。**仍需实现**原 Coordinator 的整组基线签发与原子安装、group/member/lease 身份占用、提交与展示两阶段 Run 回执、绑定原尝试的 unknown 核验、整组冲突/未提交返回，以及双语组 UI 和恢复提示。本阶段不将新文件结果硬塞进旧 preferenceWrite，也不接多项 handler 或 UI。

外部修改目前仅在后端提交核验和显式 verifyAndReload 中发现；getter、AppChrome、普通事件和展示重试读取最后完整发布状态，没有跨进程磁盘监听。协作锁、受控修订、任意外部 ABA、真实进程中断和掉电保证继续按 §9.58/§9.59；本轮没有新增耐久承诺或恢复 UI。

#### 实际验证与停止记录

证据目录：`/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B2B-q7634_ly`。macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113）、Swift 6.3.3、Python 3.9.6；不代表最低系统实测。测试与构建沿原 `build/.build.lock` 非等待取锁，不删除或抢占；完整正常 scheme/app/test target，不排除并行源码。

- 初轮 services：退出 65，PreferenceObservation 的嵌套闭包需显式 self；修复后再编译，未运行测试。
- services-repaired：本阶段产品源码编译通过，完整测试目标被并行 `QuadrantPreviewProbe` 重名阻断（QuadrantPreviewTestSupport / QuadrantLayoutTests），测试仍未运行；不修改或排除这些并行文件来绕过检查。
- services-final：21 套服务回归通过，126 个测试定义、171 次执行，0 失败/跳过/预期失败。随后按本轮“失败须待核验”要求，将尚可读的提交前失败也关闭写入口，并补充显式核验不提交/不展示的断言；该次通过不是最后源码证据。
- **services-verified：最终源码的同 21 套全部通过，126 个定义、171 次执行，0 失败/跳过/预期失败**。其中新增 6 套、30 个测试定义；覆盖本阶段共享入口、组事件及兼容性。结果 services-verified.xcresult，汇总/测试树 services-verified-summary.json / services-verified-tests.json；参数 services-verified-command.json。最后源码摘要保存于 verified-source-hashes.json。
- 消费者初轮 consumers 的方法选择器未完整匹配，实际只运行捕获开关 1 个定义/4 次，不将命令退出 0 当成其他方法通过；已校正完整 Swift Testing 方法标识。**consumers-corrected：5 个定义、14 次全部通过，0 失败/跳过/预期失败**。包括 SettingsLocalPreferenceConsumerTests，以及 SettingsPickerConsumerTests 的分组选择/取消、AppChrome 语言传播、重开/标题截断、禁用/外部更新/长说明四方法；均从构造起注入 effects；live process appearance 方法未运行。英文/简中、浅深色及对应 420pt 表单的实际原生菜单/控件与几何断言有证据；没有另行检查像素，不宣称原生视觉全面通过。后续仅收紧文件模式失败门禁，旧后端消费者路径未变。
- 正常 Debug / 静态验签：第一次非等待申请锁退出 3；build-final.log 对应随后成功的正常 development Debug 构建（staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false）。最后文件模式失败门禁编辑后，build-verified.log 的非等待申请又退出 3，彼时并行 xcodebuild 正在运行；不以先前构建替代最终正常配置证据。随后确认并行构建结束，正常取得原锁，**closure-build.log 对应最终源码的正常 Debug 构建和静态验签通过**；模式与上述相同，产物仍为 build/development-DerivedData/Build/Products/Debug/AreaChain.app，未安装或启动。
- 局部严格 SwiftLint：本轮 16 个 Swift 文件通过，lint.log；未修改、排除完整目标中的既有 AppKit 辅助 API 弃用等警告。工作流早期因并行四象限索引锚点/装饰尚未接齐而失败，未修改其他任务来绕过。随后 **quality_gate.py --profile static --strict --format json 通过，含 219 项脚本回归与工作流**（static-verified.json）；检查器定向 99 项通过（workflow-tests.log）。本轮只在原 COMPONENT_ENTRIES / 目录夹具增加稳定接口及缺失反例，没有新执行器。
- 指定 Cursor verifier 当前无可调用入口，未执行；不重查登录、不改认证、不由其他代理冒充复核。历史原生/人工、跨进程竞争、真实中断、掉电、生产来源识别及用户迁移缺口保留；整体治理状态 partial。

新增测试只使用原 LocalPreferenceFileFixture / LocalPreferenceMigrationFixture、随机 suite、真实临时文件和注入外观/私有事件中心。覆盖 ready 真伪、只读启动、Binding、整份 Observation、同值两种政策、各提交结果、失败与重入、迟到展示、字段冲突/epoch/已知倒退、旧适配器拒绝、普通消费者隔离以及真实临时 migrate→reopen→AppPreferences→共同提交→重开。以上运行数量以实际结果包为准；不使用用例代码存在或命令退出 0 替代匹配与未跳过的执行证据。

最终文档后再次运行工作流、静态质量门禁及差异检查；closure-workflow.log / closure-static.json 通过，后者包含 219 项脚本回归。最终构建后逐文件核对 verified-source-hashes.json 一致；原 FileStore、FileIO、Record、Dependencies 与本轮开始时摘要相同。§9.59 及以前的原文前缀也与本轮开始时一致；并行四象限修复和工程记录由其原修改保留。

本轮文件范围：

| 类型 | 文件 |
|---|---|
| 核心装配/状态/展示 | [AppPreferences](../AreaChain/Services/AppPreferences.swift)、[LocalPreference](../AreaChain/Services/LocalPreference.swift)、新增 [LocalPreferencePublication](../AreaChain/Services/LocalPreferencePublication.swift) 与 [LocalPreferencePresentation](../AreaChain/Services/LocalPreferencePresentation.swift) |
| 适配器与消费者 | [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift)、[PreferenceObservation](../AreaChain/Services/PreferenceObservation.swift)、[AppWindows](../AreaChain/Services/AppWindows.swift)、[StatusItemController](../AreaChain/Services/StatusItemController.swift)、[DiaryWindows](../AreaChain/Features/Diary/DiaryWindows.swift) |
| 新增测试/夹具 | [StartupTests](../AreaChainTests/Services/AppPreferencesFileStartupTests.swift)、[CommitTests](../AreaChainTests/Services/AppPreferencesFileCommitTests.swift)、[RecoveryTests](../AreaChainTests/Services/AppPreferencesFileRecoveryTests.swift)、[PresentationTests](../AreaChainTests/Services/AppPreferencesFilePresentationTests.swift)、[CompatibilityTests](../AreaChainTests/Services/AppPreferencesFileCompatibilityTests.swift)、[GroupObservationTests](../AreaChainTests/Services/AppPreferencesGroupObservationTests.swift)、[TestSupport](../AreaChainTests/Services/AppPreferencesFileTestSupport.swift) |
| 入口与交接 | 本文、[组件目录](component-catalog.md)、[架构](architecture.md)、[工程](engineering.md)、[技能路由](../skill-routing.md)、[工作流检查](../scripts/check_workflow.py)及[反例测试](../scripts/tests/test_check_workflow.py) |

**本阶段实现与本地验收完成；整体治理保持 partial，指定 Cursor verifier 与上述历史缺口没有关闭。** 本轮没有提交、推送、安装、发布、读取用户偏好或启用生产后端；保留已有暂存/未暂存及并行修改。完成交接后停止，不进入 3B3。

### 9.61 阶段 3A-3B3A：普通设置组准备、共同执行与回执

2026-10-05（Asia/Shanghai）。本轮实施 §9.57 E 的命令接线，复用 §9.60 实际 AppPreferences / FileStore / PublishedState / PresentationLedger。**仅显式临时文件、隔离旧键域及注入展示；生产 shared 保持原后端，多项 UI 未接线。** 不做真实迁移、认证、系统权限、其他命令、敏感载荷、执行后撤销或通用事务。本节是新增接口的权威说明；先前章节保留历史，最终验证状态在本节末尾记录。

#### 显式后端与组证据

[FileLocalSettingCommandAdapter](../AreaChain/Services/FileLocalSettingCommandAdapter.swift) 的 `init(coordinator:filePreferences:)` 拒绝旧后端；原 [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) 仍拒绝文件后端。不存在自动 fallback、两个适配器同时执行同一设置或循环旧 UserDefaults 单项写入。两者共用 LocalSettingCommandMapping 严格白名单、参数和对象/保护拒绝边界。

- `prepare(_:expecting:)` 为活动或计划内单项显式采集完整记录，不 enqueue；既有证据先核对受影响字段，不自动刷新。
- 多项先通过原 Plan 的 `.atomicGroup(groupID,members:)` 明确建立连续组，再调用 `prepareGroup(plan:expecting:)`。仅接受 2～4 个不同字段的一组，或单项。未分组返回 needsExplicitGroup；重复字段（同值也拒绝）、混合/多组、依赖/输出引用、对象目标、保护/未知载荷、未完成参数/编辑、pending 草稿确认、活动草稿混合和未释放执行均拒绝。未扩展合并算法。
- `AppPreferences.readLocalPreferenceRecord()` 每次调用只读一次完整权威记录，不发布、恢复或准备。prepareGroup 由这一份记录生成 CommandPreferenceGroupBaseline：runtime instance/storage、storeID/epoch、migrationID、recordRevision/commitID/摘要、四字段修订及四值、groupID、有序成员和草稿 stamps、命令身份、issuerID/captureID。
- 实际适配器私有登记 `(evidence, record)`；仅手工构造结构、复制其他适配器证据或更换后端实例均不能取得资格。准备时发现任何旧成员受影响字段过期，整组和原 lease/plan/item/draft 均不变。无冲突才通过 Coordinator 的 replacePreferenceGroupBaselines 一次发布候选 session，plan/lease 各推进一次，各 member/draft 一致推进。
- 普通读取、report、View 重绘不会准备基线。组内编辑、重排/拆组、返回计划后必须显式重新准备或解决冲突；不存在旧签发身份自动续期。

#### 最后执行门禁、共同提交与两阶段事实

`readiness(plan:expecting:)` 只检查；`submit` 从原计划封存并取得原 beginStep attempt，`execute(FileLocalSettingCommandRequest,displaySession:)` 再验证当前 ready、完整记录连续性及请求字段、原 lease/plan/group/ordered member stamps、run/attempt、严格参数、无输出/外部依赖及唯一范围。多项 unitID 是 groupID，不能调用 `run.operation(firstMember)` 冒充组身份。新组适配仅供隔离装配，不改变目录整体 isExecutable 或原生 Controller。

Coordinator `claimPreferenceGroup` 在 AppPreferences 调用前登记整组占用，并与旧单项 invocations 共用排他/attempt 去重；同一协调者上的重入和多适配实例不能各取得一次提交许可。最后 validatePreferenceGroup / 可选 ReadSession 校验与 applyLocalPreferences 同步相邻，无 await；FileStore 原协作锁、最后完整记录/字段核验与单次替换保持。校验期间旧 UI 事件不会换取新 lease。

通过所有成员预检后只调用一次 `applyLocalPreferences`。全部目标已满足时是 group noChange，零权威/辅助写入、零发布/展示；部分目标已满足仍只整份提交一次，并保守推进所有请求字段修订。`changedFields` 只是成员差异说明，没有独立成员保存状态。未请求字段从最新记录保留，旧四键不双写。

新 [CommandPreferenceGroupCommit](../AreaChain/Domain/CommandPreferenceGroup.swift) 明确区分 noChange、notCommitted、committed（含 cleanupPending）、unknown、conflict（仅受影响成员诊断）和 recoveryRequired；[FileLocalSettingCommandReport](../AreaChain/Services/FileLocalSettingCommandContract.swift) 保留唯一 localReceipt、独立 verificationReceipt、presentationReceipt 及原 group 身份。新文件结果不写入旧 preferenceWrite / UserDefaults 调用事实。

AppPreferences 在原后端返回并登记 `lastLocalPreferenceCommit` 后，通过 `recordCommit` 将真实本地事实记入原 Run，再单次发布完整 PublishedState 和调用原展示 ledger。此期间 Coordinator 占用仍保留。提交成功先令整组 local.committed，展示为 pending；展示调用完成后由可信完成入口内部取得 external attempt，记录真实外观/事件步骤，最后释放占用。观察者只能读到完整旧值或完整新值；提交后失焦/锁定只撤显示，可信事实仍归同一 ownership 的原运行，绝不恢复旧 UI 权限。通用 `.committed(outputs:external:)` 对 atomicGroup 的限制未放宽；新增阶段只认可四类纯偏好 unit，不新增 notification/calendar 效果。

#### 冲突、未知与展示恢复

`rereadConflict(plan:expecting:)` 重新读取当前完整记录，返回仅包含 affectedFields、组成员及 plan/lease 身份的确认。完整当前记录保留在适配器私有登记，确认不外露无关值。`resolveConflict(_:choice:)` 支持 adoptCurrent / continueEditing / confirmOverwrite；确认绑定采样及全部版本，再读完整记录完全一致才一次更新证据/参数。确认不提交；正式提交仍再次核验。continueEditing 保留原内容与冲突，adoptCurrent 接受整组当前值，overwrite 保留原目标。

已封存冲突/确定未提交/recoveryRequired 且整组 local.notSubmitted、无效果/输出时，`returnUnsubmittedToPlan` 经原 Coordinator→HostSession→Plan 原子返回全部成员；保留 item/draft/group IDs、追加 returnedAttempts 并推进版本。旧 run/attempt 无效。noChange、committed、unknown 不返回新草稿；未释放运行仍不允许转交。

unknown 关闭后端全部写入，不能自动重试或走 safeLocalReplay。`verifyCommit(_:expecting:)` 保留原 attempt 和实际 FileCommit.pending，在原 Coordinator 取得核验占用后仅调用 `verifyAndReloadLocalPreferences(recordRecovery:)`；该入口继续复用原 pending/current 核验和辅助清理，不 commit。只有目标 store/epoch/revision/commitID/完整摘要及 parent 与原 pending 精确匹配，并通过 AppPreferences 连续发布门禁，才在发布前写入独立 verificationReceipt，更新同一 Run 结论，再记录展示；原 unknown localReceipt 不被改写。值碰巧相同、当前仍是基记录、记录已被替代、身份/格式错误或证据不足，原运行继续 unknown，不回滚、重新提交或生成可重放草稿。后端曾要求恢复时，UI 可明确调用现有 verifyAndReloadLocalPreferences 再查询健康；缺少成功核验不得绕过 readReady。

`retryPresentation` 只在原运行的新 external attempt 下调用现有 `retryLocalPreferencePresentation`，不会保存或重读偏好文件。已返回步骤不重做，同字段后续修订使旧步骤/字段 superseded，无关字段不阻止外观重试；失败或被替代都保留 local.committed。展示回执包含独立 appearance/event 步骤和被替代的命令集合，不把调用返回等同所有窗口像素已完成。本阶段不增加关闭 superseded 展示的完整恢复 UI。

运行、签发与确认登记只存在于内存；重启不恢复队列或旧 lease。文件锁、绕过协议的外部 ABA、跨进程/真实进程中断和掉电边界仍按 §9.58/§9.59，本轮不增加耐久承诺。

#### 3B3B 接续接口与边界

后续原生接线应消费原计划、组/成员 stamps 和 FileLocalSettingCommandReport，而不在 View 复制参数/基线或保存状态。显式组操作→prepareGroup→readiness/submit；冲突→受控返回→rereadConflict/resolveConflict；unknown→verifyCommit；展示未完成→retryPresentation；普通后端恢复→verifyAndReloadLocalPreferences。交互必须继续用原 ReadSession、旧事件 lease 和双语文案。待做：多项组预览/明确确认、中英冲突与共同保存提示、unknown/清理/展示恢复界面、被替代展示的显式结束交互，以及标准/紧凑宿主的原生键盘/焦点/尺寸验收。生产后端选择、用户迁移和安全撤销仍是独立范围。

#### 本轮验证记录

证据目录：`/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B3A-0apmm__q`。使用正常完整 AreaChain scheme/app/test target、独立 QA Bundle ID `com.areachain.preference-group-qa` 与临时 DerivedData、local/ad-hoc、原生产 entitlement、LSUIElement=NO、macOS arm64 串行测试；六项真实钥匙串变量均移除，原 build/.build.lock 非等待取得并覆盖整个 xcodebuild 生命周期。未排除并行源码或修改个人签名。

初轮 initial：产品代码编译通过，测试回调内三个取值断言未处理 throws，退出 65，测试未执行。修正回调和可选目标比较后再次运行。最终结果在后续完成时追加，不把源码存在或编译成功当共同提交实测。

指定 Cursor verifier 无可调用入口，本轮不重查登录、不修改认证、不由其他代理替代；该必需复核及历史原生/人工/跨进程/掉电缺口继续保留，整体治理为 partial。没有提交、推送、安装、发布、真实设置读取/迁移、生产后端切换或多项 UI 接线；完成后停止，不进入 3B3B。

本轮实际修改文件（其他暂存/未暂存与并行改动保留）：

| 责任 | 文件 |
|---|---|
| 显式适配与类型 | [FileLocalSettingCommandAdapter.swift](../AreaChain/Services/FileLocalSettingCommandAdapter.swift)、[FileLocalSettingCommandContract.swift](../AreaChain/Services/FileLocalSettingCommandContract.swift)、[CommandPreferenceGroup.swift](../AreaChain/Domain/CommandPreferenceGroup.swift) |
| 原证据/计划/运行 | [CommandDraftTargets.swift](../AreaChain/Domain/CommandDraftTargets.swift)、[CommandExecutionContract.swift](../AreaChain/Domain/CommandExecutionContract.swift)、[CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift)、[CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift)、[CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift)、[CommandPlan.swift](../AreaChain/Domain/CommandPlan.swift)、[CommandPlanValidation.swift](../AreaChain/Domain/CommandPlanValidation.swift) |
| 共享偏好与计数 | [AppPreferences.swift](../AreaChain/Services/AppPreferences.swift)、[LocalPreferenceFileContract.swift](../AreaChain/Services/LocalPreferenceFileContract.swift)、[LocalPreferenceFileStore.swift](../AreaChain/Services/LocalPreferenceFileStore.swift)、[LocalPreferencePresentation.swift](../AreaChain/Services/LocalPreferencePresentation.swift)、[LocalSettingCommandAdapter.swift](../AreaChain/Services/LocalSettingCommandAdapter.swift)（仅后端互斥注释） |
| 新增隔离测试 | [FileSettingCommandTests.swift](../AreaChainTests/Services/FileSettingCommandTests.swift)、[BoundaryTests](../AreaChainTests/Services/FileSettingCommandBoundaryTests.swift)、[ConflictTests](../AreaChainTests/Services/FileSettingCommandConflictTests.swift)、[RecoveryTests](../AreaChainTests/Services/FileSettingCommandRecoveryTests.swift)、[LifecycleTests](../AreaChainTests/Services/FileSettingCommandLifecycleTests.swift)、[TestSupport](../AreaChainTests/Services/FileSettingCommandTestSupport.swift) |
| 同源交接与入口守卫 | 本文、[组件目录](component-catalog.md)、[技能路由](../skill-routing.md)、[架构](architecture.md)、[工程](engineering.md)、[check_workflow.py](../scripts/check_workflow.py)、[反例测试](../scripts/tests/test_check_workflow.py) |

**最终本地证据。**

| 检查 | 实际结果 |
|---|---|
| repaired（首次运行新测试） | 22 个定义、34 次执行；21 个定义/33 次通过，1 次失败、0 跳过。唯一失败为已确认 unknown 再核验的拒绝类别（expected notRetryable、actual stale），已在适配器入口补齐最后 attempt/核验状态限制。 |
| regression | 39 套，225 个定义、317 次执行，0 失败/跳过/预期失败。随后补锁定通知参数化及旧回执撤除门禁，故不作为最终源码证据。 |
| **verified（最终源码）** | **同 39 套，226 个定义、319 次执行，全部通过，0 失败/跳过/预期失败。** 新增五套共 27 个定义、40 次执行。verified.xcresult、verified-summary.json、verified-tests.json 与 verified-command.json 保存实际结果/选择器；verified-source-hashes.json 保存相关 Command/Preference/适配器与新测试摘要。 |
| 正常 Debug 构建 / 静态验签 | build.log 首次 `./scripts/build.sh --no-wait` 退出 3，未构建。只读查询原锁打开者 PID 42689（Python），其后退出；生命周期单套申请又遇新持锁任务 PID 44897（Python），退出 3、未运行。未删除/抢锁/中断任务；观察该进程结束后，verified 正常取得原锁。随后 **build-final.log 的同一正常命令退出 0，Debug 构建及静态验签通过**，development、staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false。未安装或启动该产物，未改个人签名。 |
| 工作流 / 脚本 / SwiftLint | check_workflow 定向 **100 项通过**；静态质量门禁 **通过，含 220 项 scripts/tests 回归**。本轮 21 个 Swift 文件局部严格 SwiftLint 通过。完整正常目标仍有既有 AppKit 弃用/未使用返回值等警告，未排除源码或修改警告门禁来消除。最终文档后复跑工作流、静态质量与差异检查，日志 closure-workflow.log / closure-static.json / closure-diff.log。 |
| 指定复核 / 原生 UI | Cursor verifier 未执行，缺口保留；没有认证检查或替代代理复核。没有本轮多项 UI 或像素/人工验收，属于下一阶段。合成锁定通知与失焦由真实 ContentQueryReadSession 接收，不冒充真实认证或生产窗口实测。 |

关键断言与验收对应：

| 要求 | 最终测试中的实际证据 |
|---|---|
| 单项四命令、2/3/4 字段组、Parser→Draft→Plan→真实临时文件→Run | FileSettingCommandTests 的两个参数化链路；每次一次 FileStore.commit 入口和一次真实 replace 调用，组 ID 与第一成员 ID 不同，原 item/draft 身份保留。 |
| 严格参数/重复/未分组/混合/多组/依赖/输出/目标/保护/未知/编辑/pending/活动混合 | BoundaryTests 与 LifecycleTests；preparation/submit 拒绝时原所有权/计划保留，commit 计数为零；全部仍经过现有严格 mapping。 |
| 一次组读取、无半组安装、旧单项过期不吞掉 | explicitGroupUsesOneReadOneCommitAndOriginalIdentities、oldIndividualBaselineCannotBeSwallowedByGroupPreparation、preparationRejectsUnknownPayloadAndAtomicInstallCannotPartiallySucceed；读取计数增一，plan/lease 仅增一次，坏最后成员不发布前半组。 |
| 同字段/ABA 冲突，无关字段保留，显式确认与旧尝试失效 | ConflictTests；完整原组返回，returnedAttempts 可追溯；确认后同字段再次变化被拒绝，新确认不自动写，最终提交再次核验。 |
| 防重复、重入、多适配器竞争 | BoundaryTests 的 reentryMultipleAdaptersAndLateCompletionCannotDuplicateCommit / sharedCoordinatorOccupationPrecedesEveryAdapterCall；占用拒绝发生在 AppPreferences 调用前，实际 commit/replace 不重复。 |
| 全 noChange / 部分不变 / 一次完整发布 | noChangeWritesNothingAndPartialChangeIsOneWholeRecord、publishOnlyCompleteStatesAndLocalFactPrecedesObservationAndEffects；文件内容/inode/修改时间清单不变或只一次替换，Observation/effects 仅看完整旧/新状态，观察时原 Run 已 committed。 |
| 提交前失败、unknown、清理待处理 | RecoveryTests 的七种真实故障参数，加原 FileStore/AppPreferences 回归；unknown 不发布/重试/退回，cleanupPending 保留整组 committed。 |
| 展示失败/重试/被替代 | failedPresentationRetriesOnlyLedgerAndLaterSameFieldSupersedes、unrelatedFieldChangeDoesNotCancelPendingAppearance；重试零 commit，已返回事件不重复，同字段旧外观不覆盖新值。oldPresentationReportDisappearsOnceProtocolRetryClearsReceipt 验证协议清回执后不再显示旧报告。 |
| unknown 精确身份、非重放和无重启队列 | unknownExactIdentityVerificationUpdatesOriginalRunBeforePublication、equalValuesWithDifferentIdentityRemainUnknownAndSupersededNeverRollsBack、baseStillPresentIsHistoricalUnknownAndRestartDoesNotRestoreQueue；保留原未知回执，只精确目标更新原 Run，其他同值/基记录/替代记录保持 unknown。 |
| 生命周期与旧后端 | LifecycleTests 的失焦/锁定通知参数化：提交前拒绝零 commit，提交后撤显示但事实归原 Run；BoundaryTests 验证未释放不可转交；fileBackendAndLegacyAdapterAreMutuallyExclusive 和旧五套 LocalSettingCommand 回归证明不双执行/不双写。 |

最终验证所选 39 套还包括 LocalPreference / Failure、FileStore / Recovery / Concurrency、Migration / Recovery / Evidence、AppPreferencesFile 五套及 GroupObservation、PreferenceObservation、原 CommandAtomicPlan / Execution / ExecutionIntegration / PlanOwnership / PlanDependency / PlanMerge / Handoff / HandoffBoundary / HandoffIdentity / HandoffIntegration / HostSession / Draft / DraftProtection / Parameter。所有数据与事件均来自显式临时目录、随机 suite 和注入效果，未读真实用户资料。

**3A-3B3A 实现与本地验证已完成；整体治理仍为 partial，指定 Cursor verifier 与历史缺口未关闭。** 停在本阶段，多项原生 UI 留给 3B3B；不提交、推送、安装、发布、迁移用户设置或切换生产后端。


### 9.62 阶段 3A-3B3B：普通设置共同提交的原生接线

2026-10-05（Asia/Shanghai）。本阶段只接显式文件后端的隔离宿主，沿原计划列表和 Daybook 参数控件，不另建批量设置页面。生产 shared、旧默认装配、用户四键与生产文件均不迁移或初始化，不执行其他命令、不开放执行后撤销。已有暂存/未暂存并行修改全部保留。以下实现的最终验证状态另列，代码存在不代表原生验收完成。

#### 后端、准备和提交

- [UnifiedSearchController](../AreaChain/Features/Search/UnifiedSearchController.swift) 通过 `UnifiedSearchSettingBackend` 枚举互斥选择 unassembled / legacy / file；原 `localSettings:` 初始化兼容旧单项，不存在双适配调用或失败后回退。文件适配仅由显式临时 root、随机 suite、注入展示效果的测试宿主装配。
- [FileSettingEditing](../AreaChain/Features/Search/UnifiedSearchFileSettingEditing.swift) 只衔接版本事件和原适配器；原计划仍是唯一可编辑来源。文件模式不在接受草稿、View 重绘或计划编辑时自动准备基线。单项明确“读取当前值”；2～4 项明确“准备共同保存”。
- [PlanLinks](../AreaChain/Features/Search/UnifiedSearchPlanLinks.swift) 先核对原 source/lease/plan，复用适配器 groupingEvent 对原 Plan.apply 和严格 mapping 的候选检查，再发送原 atomicGroup 事件；随后使用更新后的合法版本 prepareGroup。无部分筛选、删除或循环提交。准备失败展示实际保留的计划；已合法准备的重复点击不建组、不刷新基线。
- 原适配器补 `preparedPlans` 签发登记：多项 readiness/execute 还核对准备后的完整 plan stamp。重排即使顺序相同也使旧证据失效；编辑、拆组/移除/合并仍遵守原 Plan 规则，重新准备必须明确操作。旧单项过期证据先报冲突，不被组准备吞掉。
- [PlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift) 在原列表显示共同保存数量、实际基线当前值、拟修改值和“无需更改”；组是否可提交来自原 readiness，部分无需更改没有成员级成功状态。计划项展开继续复用 ParameterField、PlanDependencies 和原参数事件。
- 点击及 ⌘Return 都进入原 requestOperationSubmit，文件单项与多项均调用一次 FileLocalSettingCommandAdapter.submit，并传实际 ReadSession。旧后端单项仍原行为、多项继续阻断。UI 不接文件 store / AppPreferences 写方法，不 seal/beginStep 拼回执，不先清计划。

#### 整组结果、冲突与恢复

[FileSettingSubmission](../AreaChain/Features/Search/UnifiedSearchFileSettingSubmission.swift) 与 [FileSettingCopy](../AreaChain/Features/Search/UnifiedSearchFileSettingCopy.swift) 只投影 FileLocalSettingCommandReport 的本地、独立核验与展示回执：noChange 无新保存；committed 整组保存；清理待处理作为独立说明；展示失败仍为整组已保存；conflict 整组未提交；unknown 保留运行、只提供“核验结果”；recoveryRequired 后端不可写；superseded 为旧展示已被后续修改替代。没有某成员成功、另一成员失败的保存文案。

冲突重读仍由原适配器私有完整记录签发确认，本轮仅补受影响字段的类型化 baseline/current 标量差异。部分成员尚未准备时，重读只显示已有签发成员的冲突，明确 adopt/overwrite 才通过原 install 一次准备整组；无旧证据且无冲突不借此隐式准备。确认绑定全部成员与完整当前记录，新变化使旧确认失效。continueEditing 通过原计划编辑入口，未提交返回使用 returnUnsubmittedToPlan；committed/unknown 不可返回成可重放计划。

unknown 明确调用 verifyCommit，精确原提交身份仍由适配器/文件后端核验；没有普通保存重试或自动循环。不确定继续保留原 localReceipt/run。展示重试只调用 retryPresentation，不读写文件；后续同字段修订阻止旧外观覆盖新值。成功/noChange 才经原 releaseExecution 释放，失败/未知/未处理运行不自动清除。notReady/recoveryRequired 只提示后端需核验，不提供迁移、恢复文件选择或降级工具。

失焦后的显示 invalidated 也推进原输入 buffer 版本，但不换取新 lease；重新显示后旧 UI 回调仍无效。提交后失焦/锁定只撤去显示，可信结果继续归原 run/attempt。恢复显示不会重提、重验或重新准备。敏感草稿和 C2B 边界未修改。

#### 有限验收与证据

事前固定服务/控制器→合并原生的验收清单：2/3/4 项与文件/旧单项；全 noChange/部分不变；准备、编辑、重复/混合/旧后端多项；点击/⌘Return/重复触发；冲突/过期确认、unknown、展示重试、清理；失焦/锁定/迟到事件；完整发布与无旧键双写。代表性 en/zh-Hans、浅深色、标准/紧凑与 304pt 最小宽度，结合旧设置页、3A 单项、4A 参数/计划/输入回归；不扩展笛卡尔积。

证据目录：`/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B3B-mjhmp89t`。完整正常 scheme/app/test target，独立 `com.areachain.setting-group-ui-qa`、独立 DerivedData、local/ad-hoc、原 entitlement、LSUIElement=NO、arm64 串行，移除六项真实钥匙串授权。原 build/.build.lock 非等待申请并覆盖完整进程；锁忙即停止后续申请，不抢锁、不干预持有任务。

| 轮次 | 实际结果 |
|---|---|
| contracts | 产品编译通过，新夹具 notMigrated 缺只读初值导致测试编译失败（65），用例未执行。已修正。 |
| contracts-repaired | **46 个定义、72 次执行通过，0 失败/跳过/预期失败。** 原服务五套、新控制器契约、旧单项契约/生命周期；包含重复准备、计划修订证据、混合/重复/未就绪、旧单项过期与精确冲突差异。 |
| 原生、最终回归、Debug/验签、静态、截图 | 见下方收尾记录；测试锁忙后已停止申请，阶段 partial，不能按前轮构建推定通过。 |

指定 Cursor verifier 无可调用入口，未执行、不重复登录或用其他代理冒充；整体治理保持 partial。人工 VoiceOver、系统输入法候选窗、减弱动态/最低系统、真实用户多窗口，C2B 和历史外观缺口继续保留。生产启用仍需独立后端装配/迁移/恢复策略授权与验收；其他 handler、敏感编辑和执行后撤销不在本阶段。完成后停止，不提交、推送、安装或进入下一阶段。


#### 3B3B 本地复验与停止记录

原生首轮 `native.xcresult` 共 68 个测试定义：62 passed / 5 failed / 1 既有 expected failure / 0 skipped。新 noChange 用例误把提交入口调用次数当实际写入，文件清单与零替换断言原已成立，已改为 replacements/完整清单判定。原生编辑用例误认为旧辅助方法 moveDown=false 会发送上方向键，实际只是 Return；已改为真实系统菜单追踪中的上方向键，并在提交前断言原草稿参数。其余三项 4A 回归来自本轮将普通模型重读 invalidated 也当作撤显示，现已收窄为 isMasked 时才推进 buffer 版本。

首轮 24 张组场景原图与 4 张联系表已实际查看：旧“合成原子组／尚未接事务”提示已改成“属于同一次共同保存”，准备状态放在原固定反馈位置并从 readiness 派生；组标题与底部提交分别留图。`verified.xcresult` 因 Return 处理用了不接 KeyPress 参数的 SwiftUI 重载而编译失败，用例未执行；已改为项目已有 onKeyPress(keys:)。

| 记录 | 实际结果及证据边界 |
|---|---|
| `final-tests.xcresult` | **114 个定义：111 passed / 2 failed / 1 既有 expected failure / 0 skipped。** 25 套组合，前轮五项失败均通过复验。源码前后摘要 `final-source-before/after.json` 相同。 |
| 本轮剩余失败 | `UnifiedSearchOperationInteractionTests.nativeCompletionDraftPickerPreviewAndStaleCandidate` 窗口非 key；`UnifiedSearchFileSettingRecoveryTests.nativePresentationRetryNeverWrites(superseded: true)` 同次记录为控件零尺寸/越界、窗口非 key。没有取消断言或将环境可能性当通过，焦点丢失来源未独立确认。false 重试路径通过；superseded 服务测试通过，但本轮最新原生路径仍未通过。 |
| 最后反馈修正 | 原 OperationPreview 保留文件组固定状态之外的原 Plan.grouped 等拒绝说明；FileSettingEditing 成功结果动作清除旧反馈；原生编辑测试补组成员移出拒绝及提示存在断言。这些最后修改没有完成原生复验。 |
| `closure.xcresult` | 最后源码编译后在测试包 CodeSign 失败，测试未执行；同轮 shell 写入出现 ENOSPC，磁盘可用约 112 MiB。未改签名/权限，未独立确认 CodeSign 内部错误的全部原因。源码前后摘要相同。只清理本轮 DerivedData 的约 75 MiB 可重建 Index.noindex，保留源码、产物、截图和所有 xcresult；随后观测可用空间约 3.4 GiB，不把全部回收归因于这次索引清理。 |
| `closure-repaired` | 对原 build/.build.lock 的下一次非等待申请退出 **3 / 锁忙**，未启动 xcodebuild；记录 `lock-blocked`。按用户要求停止后续测试/构建申请，未抢锁、删锁、干预持有任务或再排队。 |
| 正常配置 Debug / 验签 | **未运行**，由上述停止边界保留缺口；QA 编译或先前阶段 Debug 不能替代本阶段最终正常构建/验签。 |
| 截图 | `reviewed-screenshots/` 的 27 张原图及 5 张联系表已实际查看：26 张来自 final-tests；`group-presentation-retried-true.png` 是 native 首轮旧图（时间早于 final-tests），单独保留，不算最新 superseded 通过。覆盖 en/zh-Hans、浅深、standard/compact、620/304pt、组标题/预览/提交/阻断/noChange/unknown/清理/展示失败。最后反馈修正无新截图；首轮与后轮图片不合并冒充最终源码视觉验收。 |
| 静态与脚本 | 工作流定向 **101 项通过**，static 质量门禁含 **221 项脚本回归通过**。最终静态/严格局部 lint/差异检查在文档收尾后复跑，见 `delivery-*` 记录；不运行会启动非显式隔离宿主的 auto/swift profile，不冒充完整 Swift profile。 |

逐项行为对应如下。这里的“通过”仅指注明轮次中实际执行的测试；由于最后修改未完成复验，**本阶段本地交付整体仍为 partial**。

| 验收 | 已取得的证据 |
|---|---|
| **2 项** | final-tests 的 nativeGroupSavesWholeTemporaryFile(count: 2)：真实原生入列/准备/点击提交 → 临时 current.json → 整份内存与反馈；一次 commit 入口、一次实际替换、一次组通知、旧四键仍缺失。 |
| **3 项** | 同测试 count: 3，compact/304pt：Return 零提交，⌘Return 同一 Controller 路径 → 三字段整份保存；重复旧提交事件不增加 commit。 |
| **4 项** | 同测试 count: 4，中文/深色：四字段整份保存、原运行成员/组身份、整组成功反馈及显式完成释放通过。 |
| 文件与旧单项 | native fileSingle 通过；旧 SettingContract/Interaction/Lifecycle/Presentation 及旧 SettingsLocalPreferenceConsumer、SettingsPickerConsumer 所选回归通过，保留后者既有外观 expected failure。未做后端回退或双调用。 |
| 全 noChange / 部分不变 | final-tests 原生两分支通过。全 noChange 可进入 FileStore.commit 一次，但没有新记录/辅助写入/替换/发布/展示，完整内容/inode/mtime 清单不变；部分不变一次整组替换。 |
| 准备/编辑/重复/混合 | 显式 prepare、编辑后缺证据、重准备、旧单项冲突不能吞掉、重复字段/混合命令/旧后端多项阻断通过。组成员直接移除沿原 Plan 拒绝，最后新增原生提示断言未执行。 |
| 冲突 | 原生整组冲突、原基线与当前差异、过期 overwrite 确认拒绝、新确认后共同保存通过；服务整组受控返回/保持 IDs 与 returnedAttempts 通过，UI 不拆成员执行。 |
| unknown / recovery | replaceAfter 明确核验确认原精确提交、原 unknown localReceipt 保留，commit 不增加；replaceBefore 核验后仍 unknown，运行保留，无普通保存重试。未就绪后端原生阻断；cleanupBefore 显示“整组已保存”并另列恢复整理待处理。 |
| 展示失败/被替代 | 保存成立和展示失败分开；false 原生重试及服务重试证明不写文件/不重发已返回事件。superseded 服务证据成立，最新原生 true 分支因上述焦点/几何失败保留缺口，首轮旧通过不替代。 |
| 生命周期 | final-tests nativeRevocationAndLateSubmission 的失焦/合成锁定 × 提交前/后通过：旧事件拒绝、再显示不自动执行、提交事实保留；不是实际系统锁屏或认证验收。 |
| 无半组/无双写 | native 组事件回调核对完整文件==已发布整份状态且原 unit 已 committed；服务 publishOnlyCompleteStatesAndLocalFactPrecedesObservationAndEffects 的 Observation 断言仅看到完整旧/新状态。各原生组提交后隔离旧四键仍全部 missing；没有以最终值相同代替事件/替换次数。 |
| 4A 回归 | final-tests 中 PlanContract/Dependency/Interaction/Presentation/Lifecycle、ObjectPresentation、OperationContract/Presentation/Lifecycle、UnifiedSearchInput 通过；OperationInteraction 上述一项焦点失败尚未关闭。 |

本轮实际改动（此前并行修改不计入本轮实现）：

- Controller/原入口：[UnifiedSearchController](../AreaChain/Features/Search/UnifiedSearchController.swift)、[SettingEditing](../AreaChain/Features/Search/UnifiedSearchSettingEditing.swift)、[SettingSubmission](../AreaChain/Features/Search/UnifiedSearchSettingSubmission.swift)、[OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[PlanLinks](../AreaChain/Features/Search/UnifiedSearchPlanLinks.swift)、[PlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift)。
- 文件模式组合：[FileSettingEditing](../AreaChain/Features/Search/UnifiedSearchFileSettingEditing.swift)、[FileSettingSubmission](../AreaChain/Features/Search/UnifiedSearchFileSettingSubmission.swift)、[FileSettingCopy](../AreaChain/Features/Search/UnifiedSearchFileSettingCopy.swift)、[Localizable](../AreaChain/Resources/Localizable.xcstrings)。
- 原适配器扩展：[FileLocalSettingCommandAdapter](../AreaChain/Services/FileLocalSettingCommandAdapter.swift)、[Contract](../AreaChain/Services/FileLocalSettingCommandContract.swift)。
- 隔离测试：[ResultsTestSupport](../AreaChainTests/Features/UnifiedSearchResultsTestSupport.swift)、[FileSettingTestSupport](../AreaChainTests/Features/UnifiedSearchFileSettingTestSupport.swift)、[ContractTests](../AreaChainTests/Features/UnifiedSearchFileSettingContractTests.swift)、[InteractionTests](../AreaChainTests/Features/UnifiedSearchFileSettingInteractionTests.swift)、[RecoveryTests](../AreaChainTests/Features/UnifiedSearchFileSettingRecoveryTests.swift)。
- 同源维护：本文、[路由](../skill-routing.md)、[组件目录](component-catalog.md)、[架构](architecture.md)、[工程](engineering.md)、[检查器](../scripts/check_workflow.py)及[定向反例](../scripts/tests/test_check_workflow.py)。

指定 Cursor verifier 未执行、不重查登录、不由其他代理替代；人工、C2B、历史外观/多窗口缺口全部保留。单项英文计数目前复用 settings 复数文案，尚未专门细化。剩余收口先补最后源码的两个失败场景、反馈修正、正常 Debug/验签；生产启用需另行明确后端选择、用户迁移和恢复授权。其他 handler、敏感编辑、生产统一搜索、执行后撤销均未开放。本次停止于 3A-3B3B partial，不提交、不推送、不安装、不发布、不迁移用户设置或切换生产默认后端。


**并行状态补记。** 本会话没有运行暂存、提交、推送或回退命令。收尾只读 reflog 显示仓库在 2026-10-05 14:32:07 +0800 出现 `d24391e`（Enhance Command Preference Group Management and User Interaction），已包含部分本轮接线；不推测操作者，也不撤回或改写该提交。最后两处反馈修正、移除提示测试和本文仍在工作区。另有 DaybookScroller / DaybookScrollScope 及滚动验收的并行改动，全部保留。source 摘要只覆盖其 JSON 列明的 Search、SettingCommand、UnifiedSearch 测试与文案文件，不证明整工作树冻结；后续原生重验须采用当前完整树，不能把前轮证据外推到并行滚动修改。


#### 3A-3B3B-R：一次性预检与验收收口阻塞（2026-10-05）

本轮仅验收收口。HEAD 仍为 `d24391e`，保留该并行提交及全部工作区改动；未改 Swift/测试/签名配置。对照 final-source-after.json，列明范围中只有 OperationPreview、FileSettingEditing、FileSettingInteractionTests 的最后反馈修改，以及并行 ObjectPicker 滚动 modifier 与旧证据不同；其余被记录文件摘要一致。Theme 滚动仍有并行修改且不在旧摘要范围内，不能据此宣称整树或最终布局已验证。详见原证据目录下 `3B3B-R/source-comparison.json`。

**一次性只读环境检查。**

| 条件 | 本次实际结果 |
|---|---|
| 磁盘 | 可用约 **11 GiB**；正常 development-DerivedData **1.4 GiB**、local-DerivedData **304 MiB**、本阶段旧 QA DerivedData **855 MiB**。本次未清理任何构建物、缓存、截图或历史证据；前轮空间不足当前未重现。 |
| 历史签名错误 | closure.log 第 22–28 行：测试包 `AreaChainTests.xctest: internal error in Code Signing subsystem`；`Command CodeSign failed with a nonzero exit code`，随后取消测试。没有更具体的证书/权限/文件路径诊断；与同轮 ENOSPC 同时发生不证明因果，本次未将磁盘不足确认为根因。 |
| 原测试锁 | 对已有 build/.build.lock 只读打开，**一次**非等待独占探测返回 **busy / Errno 35**；没有写锁文件、轮询、删除锁或干预持有者。立即停止本轮所有测试/构建申请。 |
| 桌面 | 只读 NSWorkspace 返回前台 `com.openai.codex`；CGSession 字典未返回，未取得完整登录/锁屏条件，未启动 QA 来验证 key window。前台为 Codex 不能替代可交互 QA 焦点验收。 |

预检记录为 `3B3B-R/preflight.json`。锁仍阻塞，故本轮 **没有启动编译、原生测试、正常 Debug 构建或静态验签**；不重放已有效的 2/3/4 项共同保存链路，也没有生成新的修正后截图。

**两个失败与既有预期失败分别保留。**

| 用例 | 已知事实与本轮结论 |
|---|---|
| UnifiedSearchFileSettingRecoveryTests.nativePresentationRetryNeverWrites(superseded: true) | final-tests 的 activities 记录 assertBounds 零尺寸/越界及 click 的 window.isKeyWindow=false，发生于原生控件操作路径。false 分支与服务 superseded 证据已通过，但不能替代 true 原生分支。尚未确定是焦点撤树、控件定位、布局或外部干扰导致；**未复验、未关闭，不笼统标环境问题**。 |
| UnifiedSearchOperationInteractionTests.nativeCompletionDraftPickerPreviewAndStaleCandidate | final-tests 记录 window.isKeyWindow=false；未证明丢焦原因或定位错误，也没有本轮运行证据。**未复验、未关闭**；原按键、草稿、旧菜单与不可执行断言保持。 |
| SettingsPickerConsumerTests.appearanceUsesProcessAndHostEnvironment（既有 expected failure） | 源码与结果均保留既有 withKnownIssue：初始系统浅色时 dark→system 后 SwiftUI 环境仍为深色，原生 Picker 对照同样失败。该项是具体历史外观行为，**不是上述两项的环境归因，也未因标预期而视为修复**。本轮未修改已知问题或“通过”定义。 |

后续在锁正常释放且桌面条件可确认后，优先现有 nativeEditInvalidatesAndRequiresExplicitPreparation（含组移出拒绝提示）、nativePresentationRetryNeverWrites（含最后成功结果动作反馈清理与 superseded）、nativeCompletionDraftPickerPreviewAndStaleCandidate。保留全部原断言，只有定位/布局证据支持时修复；通过后再正常 Debug/验签，按最终实际影响补回归，不机械重跑完整 2/3/4 矩阵。本轮没有启动这些待办。

**截图来源。** `3B3B-R/screenshot-provenance.json` 对原 reviewed-screenshots 中 27 张组图核对摘要/时间：26 张属于 final-tests 后轮，group-presentation-retried-true.png 属 native 首轮。它们已在前轮实际查看；本轮没有新图。未受影响的历史内容可继续作为相应旧行为证据；最后反馈修正、并行滚动布局及 superseded 的最终图仍缺失，不用旧图替代。

本轮只追加本文，适用的局部 lint、工作流、static 门禁与差异检查输出位于 `3B3B-R`；这些静态结果不表示编译或运行完成。**环境阻塞仅磁盘条件已改善，锁仍阻塞，桌面完整条件及历史签名原因未确认；本阶段本地验收仍 partial/blocked。** 指定 Cursor verifier 未执行；人工、C2B、历史外观缺口分别保留。没有提交、推送、安装、迁移用户设置、切换生产后端或进入其他 handler/撤销阶段。


#### 3A-3B3B-R 定向续验：运行补证，正常构建仍受锁阻塞（2026-10-05）

本次续验正常取得原 build/.build.lock，只运行指定的三个测试方法：nativePresentationRetryNeverWrites（false/true 两分支）、nativeCompletionDraftPickerPreviewAndStaleCandidate、nativeEditInvalidatesAndRequiresExplicitPreparation。保持原完整 app/test target、原独立 QA 标识与 DerivedData、原生产 entitlement、六项钥匙串授权清除及串行约束。不重复 2/3/4 项共同保存矩阵，不修改产品代码或签名配置。

证据目录：`/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B3B-mjhmp89t/3B3B-R-4raxk0r2`。command.json / feedback-command.json 保存实际参数；source-before/after.json、feedback-before/after.json 覆盖全部当时 Swift 源码、测试和文案，**各轮前后均无变化**。

| 要求 | 本次实际结果 |
|---|---|
| superseded 的尺寸/边界/key-window | focused 轮 true/false 两分支均通过；保留原 assertBounds 与 key-window 断言，文件内容/inode/mtime 清单及 commit 次数不增加，旧外观没有覆盖后续 light。feedback 轮两分支再次通过。没有修改焦点或布局实现，历史失败的根因仍未定位，不将一次通过解释为根因修复。 |
| nativeCompletionDraftPickerPreviewAndStaleCandidate | focused 轮通过；原 Tab/Return、草稿、旧菜单回调及提交阻断断言保持。后续只改另两个测试方法，故复用该轮证据，没有重复此用例。 |
| 最后反馈修正 | focused 轮未找到移出按钮；失败辅助树没有任何计划控件，截图明确为整个操作面板遮罩，故不是已证明的单按钮滚动定位问题。保留 focused-missing-tree.txt / focused-masked.png，遮罩来源未确认。仅在原测试补场景开始时 key-window 且 operationVisible 的硬断言、不自动恢复显示，并补 group-removal-rejected 截图；原重准备/保存断言不变。feedback 轮移出拒绝、原提示存在、编辑使旧证据失效、明确重准备及保存通过。 |
| 成功动作清除旧反馈 | 原 nativePresentationRetryNeverWrites 增加 planMessage 回到 notExecutable 的断言；feedback 两分支通过。没有新增测试定义、跳过断言或改变产品通过口径。 |
| 测试计数 | focused.xcresult：3 个定义、4 次执行；2 个定义通过、1 个失败（移出控件缺失），0 skipped/expected failure。feedback.xcresult：**2 个定义、3 次执行全部通过，0 failed/skipped/expected failure**。不合并成一次全部通过；两个原失败与最后修正分别引用有效轮次。 |
| 签名 | 两轮 QA 测试包签名成功，历史 Code Signing subsystem 错误未重现；没有改变个人签名、权限或配置，也未确认历史错误与磁盘不足的因果关系。QA 签名不能替代正常 Debug 验签。 |
| 正常 Debug / 静态验签 | 测试通过后调用原 `./scripts/build.sh --no-wait`，**退出 3，锁忙，构建及验签均未执行**。debug-build.log 保存原提示。随即停止所有后续锁申请，不轮询或干预持有任务；本阶段仍不可标本地验收完成。 |

**最终截图范围。** 本目录 screenshots 的六张原图及 contact.png 已实际查看：group-removal-rejected、group-edit-reprepared、group-presentation-failed、group-presentation-retried-false/true 来自 feedback；operation-completion-preview 来自 focused。当前 compact/304pt 下拒绝提示和组状态均可见，展示失败、成功及 superseded 分开表达；原生几何/焦点由原测试断言提供，不靠截图数量替代。screenshot-manifest.json 保存摘要与时间。前述 native 首轮旧图、final-tests 后轮图继续保留；本轮新图补最后反馈和 superseded，未受影响的历史共同保存证据复用，不作为新的全语言/全尺寸验收。

**并行变化及收尾。** feedback 结束后只读摘要比对发现 DaybookScroller、DaybookScrollScope 及三份滚动测试继续变化（delivery-source-differences.json），全部保留。上述运行仅证明各轮冻结源码，不能外推整个当前滚动实现；本阶段 Search/SettingCommand 产品代码在两轮间及收尾没有修改。当前完整树的正常 Debug/验签仍待锁正常释放后执行。HEAD/并行提交 d24391e 保留，本会话未提交、推送、安装、删除缓存或修改生产后端。

本次实际新增编辑仅为已有 [InteractionTests](../AreaChainTests/Features/UnifiedSearchFileSettingInteractionTests.swift) 的开始条件断言/截图、[RecoveryTests](../AreaChainTests/Features/UnifiedSearchFileSettingRecoveryTests.swift) 的反馈清理断言及本文。最终适用 lint、工作流、static 门禁与差异检查记入本目录 delivery-*；它们不能替代未运行的正常构建。

本轮结束状态：指定两个历史失败及最后反馈修正已取得定向通过证据，历史间歇性失焦/遮罩根因仍未证实；**本阶段本地收口仍 partial（正常 Debug/静态验签受锁阻塞）**。SettingsPickerConsumerTests 的既有 dark→system expected failure 单独保留，未重跑/修改该定义；指定 Cursor、人工、C2B及其他历史外观缺口分别保留。不进入其他 handler、迁移、生产后端或执行后撤销阶段。


**最后构建申请（2026-10-05）。** 按用户仅构建/验签的收口要求，对照 feedback-after.json：本阶段 Search/SettingCommand 产品代码、文案和相关 UnifiedSearch 验收用例摘要一致；仍有六份并行差异：DaybookScroller、DaybookScrollScope、ScrollAssemblyConsumerTests、DaybookScrollContractTests、DaybookScrollNativeTests、DaybookScrollLifecycleTests，另有新增滚动测试不在旧摘要范围。操作/结果面板继续直接使用无 scope 的 Configurator；新羽化实现属于并行范围，未把旧证据外推为当前整个滚动子系统通过。未改源码、重跑测试或新增截图，保留 d24391e 及暂存/未暂存并行修改。

随后仅调用正常 `./scripts/build.sh --no-wait`，返回 **3 / 测试锁忙**，未进入 Debug 编译或静态验签。原提示见上述定向续验证据目录 `debug-close.log`，源码对照见 `debug-close-source-comparison.json`。立即停止，没有再查锁、轮询或干预任务。已有两个历史失败和最后反馈修正的定向通过证据仍保留；由于正常 Debug/静态验签尚未执行，**本阶段本地验收仍 partial，不能写为完成**。指定 Cursor、人工、C2B和历史外观/失焦根因缺口保持独立；未提交、推送、安装或切换生产后端。


#### §9.62 最后收口：本阶段本地验收完成（2026-10-05）

本次仅补正常 Debug 构建和静态验签，无测试重跑、新截图、功能或签名配置修改。比对 feedback-after.json，本阶段 Search/SettingCommand 产品代码、文案及相关用例与已通过证据一致；并行的滚动/羽化修改与测试继续独立保留，不能据此扩展为滚动子系统整体验收完成。设置操作面板和结果面板仍直接使用无 scope 的 Configurator，本次共同保存、反馈和执行门禁没有新改动。

正常 `./scripts/build.sh --no-wait` 已取得原锁并退出 **0**。首次 build.log 通过后发现并行 DaybookScrollScope 的羽化修饰顺序发生后续变化，因此未将旧产物视为该新源码的证据；追加一次相同正常增量构建，`current-build.log` 再次 **退出 0**，在同一进程立即采集的 current-before/after.json 全部产品 Swift/文案摘要一致，无构建期间源码变化。证据位于：

`/var/folders/bv/gtwkyczs3156pj4k13spg_3m0000gn/T/AreaChain-3A3B3B-mjhmp89t/3B3B-R-4raxk0r2/debug-close-l3u29hr_`

实际配置为原 development / Debug，`staticSignatureVerified=true`、`hardenedRuntime=true`、`distributionReady=false`。原脚本同时完成静态验签，无测试包签名错误重现；没有修改个人签名、权限或安装/启动产物。日志保留 arm64/x86_64 同时匹配而选首个目标的既有提示。历史 Code Signing subsystem 错误的根因仍未确认，成功构建不能倒推其一定由磁盘导致。

**本阶段本地验收完成。** 该结论组合此前有效的 2/3/4 项共同保存与恢复证据、focused 轮旧操作补全通过、feedback 轮最后反馈及 superseded 两分支通过、已查看且区分来源的截图、原最终静态门禁，以及本次正常 Debug/静态验签；不冒充同一轮全量测试，不重跑已有效链路。锁阻塞在本次正常构建时解除，不保证其他时刻无人持锁。

**整体治理仍为 partial。** 指定 Cursor verifier、人工 VoiceOver/真实输入法及多窗口、C2B、既有 dark→system expected failure、历史间歇性失焦/遮罩与签名根因等缺口分别保留；并行滚动功能的验收由其原阶段负责。本次仅更新本文并做文档/差异检查，未提交、推送、安装、迁移用户设置、切换生产后端或进入其他 handler/撤销阶段。完成后停止。

### 9.63 阶段 3T-0：普通任务新增、标题与备注的真实执行接线方案

2026-10-05（Asia/Shanghai）。**本节是只读代码核验与后续方案，不是 handler 实现、任务保存验收或真实写入授权。** 本轮只增补本文；不写业务数据、不构建、不申请原生测试锁、不运行下面列出的 Swift/写入测试。§9.62 最后收口确认四项设置本地验收完成，其指定 Cursor、人工、C2B 及历史缺口继续独立保留；设置文件的共同提交、修订号和恢复证据不推广到 SwiftData 任务。

范围仅为 `todo.create`、`todo.title`、`todo.notes`。完成/重开、删除、习惯、子任务、附件、批量修改、敏感正文及真实通知/日历操作本阶段不接；它们仍在 §8 完整交付范围。以下源码行号是本次阅读定位，符号为稳定检索入口，既有测试只代表可复用的测试意图。本轮只读探索不替代指定 Cursor verifier，不重新检查登录，不干预其他验收。

#### A. 目录事实与最小影响/复用表

先核对 [CommandCatalog+Tasks.swift](../AreaChain/Domain/CommandCatalog+Tasks.swift):6、9、14，再沿 [CommandCatalogBuilder.swift](../AreaChain/Domain/CommandCatalogBuilder.swift):31、[CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift):47、[CommandArgumentValidation.swift](../AreaChain/Domain/CommandArgumentValidation.swift):6 追踪真实参数；不是从功能名称猜 ID。

| 稳定 ID / 路径 | 当前目录参数与默认操作 | 范围与输出 |
|---|---|---|
| `todo.create` / `/tasks/add` | 必填 `title:shortText`、`day:day`，**两者都没有 defaultValue**；可选 `notes:longText`（replace/append/clear，默认 replace）、`tags:tags`（add/remove/replaceAll/clear，默认 add）、`time:time`（setReminder/cancelReminder，默认 setReminder）、`priority`（p1～p4，assign/clear，默认 assign） | 无 target。提醒的参数 ID 是 `time`，不是 `reminder`。`CommandDescriptor.createdObjectType` 只为此命令声明单个 `.todo` 输出（[源码](../AreaChain/Domain/CommandDescriptor.swift):123）。没有来源、完成态、截止、子项、附件或系统日历绑定参数。 |
| `todo.title` / `/tasks/title` | `target:object(todo)`；必填 `title:shortText`，仅 assign，无默认值 | 单对象。目录没有声明 notes/tags/time/priority 参数，但真实旧动作可能修改它们；不能据此当作纯标题 setter。 |
| `todo.notes` / `/tasks/notes` | `target:objects(todo)`；必填 notes，replace/append/clear，默认 replace，allowsEmpty=true | 目录允许 explicitMultiple；首批适配只接受恰好一个目标，多目标明确未装配，不删目录能力或静默取第一条。 |

三项都是 modification、declared、eligibleAfterWiring；实际 execution 仍为 unwired，目录和 Run 的 `isExecutable` 仍为 false。适配资格必须单独提供，不能打开整个目录。静态校验拒绝空白/换行 shortText、非法民事日期、越界时刻及空/重复 UUID 标签数组；longText 的空白 replace/append 仍被拒绝，`allowsEmpty=true` 目前只允许**无 value 的 clear**。未指定可选参数不是清空，空数组也不能代替 tags.clear。

| 权威规则 / 入口 | 真实消费者 | 拟复用与保持的边界 |
|---|---|---|
| `parseTaskCapture`、`parseTaskNotes`、`TagSyntax`、`InputTagResolver` | 快速新增、任务标题、备注 | 解析仍在 Domain；标签查找/恢复/创建仍在同一 SwiftData 事务。提取这三条具体业务入口，不在 handler 重写解析、造标签或反复调用 toggle。 |
| `TaskRepositoryProtocol` / `SwiftDataTaskRepository`、`ParsedNoteUpdate` | `DayBoardMutations` 与日历本地访问 | 继续由 Services 写模型；补窄的唯一活身份读取与创建身份输入，不改 restore/purge 所依赖的原 `fetchTodo` 墓碑语义。 |
| `ModelChanges` / `BoardEvents` | 仓储、角标、搜索失效、手记窗口、提醒、日历 | 保留保存成功后发布及 changed/changedLocally 区别；补显式注入和提交事实通知，不能屏蔽广播来伪装完整隔离。 |
| Draft / Plan / Run / HandoffCoordinator | 统一搜索活动草稿、计划项、结果依赖；现有设置适配 | 直接复用 lease（宿主访问版本）、stamp、唯一参数所有权、尝试号、回执去重和键盘规则；设置专用的基线、claim、核验入口不能直接充当任务 API。 |

#### B. 原 UI 到真实保存的三条调用链

1. **新增**：菜单栏 [CaptureField](../AreaChain/Features/MenuBar/CaptureField.swift):44 → [MenuBarPopoverView.addTodo](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift):362；工作台 [WorkspaceTodayView.addTodo](../AreaChain/Features/Workspace/WorkspaceTodayView.swift):160；[CalendarPage.addTodo](../AreaChain/Features/Calendar/CalendarPage.swift)；[QuadrantPage.addTodo](../AreaChain/Features/Quadrant/QuadrantPage.swift):215；[WorkspaceFilteredListView.addTodo](../AreaChain/Features/Workspace/WorkspaceFilteredListView.swift):96 → **`DayBoardMutations.addCapturedTodo`**（[Capture 源码](../AreaChain/Features/Tasks/DayBoardMutations+Capture.swift):6）→ trim / `parseTaskCapture` → `ModelChanges.perform/transaction` → `InputTagResolver.merging` → `taskRepo.addTodo(CreateTodoParams)` → 仓储 `saveAndNotify` / `ModelChanges.commit` 延后到最外层一次 save → `BoardEvents.changed`；Bool 成功后才清原 composer 草稿，并在解析到提醒时请求提醒授权。另有 [DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift):104 的旧 `addTodo(title:)`，不解析且先拒绝空标题，不选它冒充捕获入口。
2. **标题**：[TaskRow.saveEdit](../AreaChain/Features/Tasks/TaskRow+Actions.swift):45 → [TaskRowFactory.todo](../AreaChain/Features/Tasks/TaskRowFactory.swift):6 提供的 Bool `onSaveTitle`；详情 [TodoBasicsSectionView](../AreaChain/Features/Workspace/TaskDetailSections.swift):11 → `DayBoardMutations.editTodo`；两路最终进入 **`editTodoWithSyntax`**（Capture:88）→ `parseTaskCapture` → 同一 `ModelChanges.perform` 内 `updateTodo`、条件性 `setPriority` / `setRemind`、`InputTagResolver.merging` / `replaceTagIDs` → 最外层 save/广播 → 条件性提醒授权。不是只调用 `updateTodo(title:)`。
3. **备注**：[TaskDetailNotesView.flushSave](../AreaChain/Features/Workspace/TaskDetailNotesView.swift):104 → TodoBasicsSectionView 的 `updateNotes` → **`DayBoardMutations.saveNotes`**（Capture:127）→ `parseTaskNotes` → 同事务标签合并 → `ParsedNoteUpdate` → 仓储 **`applyParsedNotes`**（[源码](../AreaChain/Services/Repositories/SwiftDataTaskRepository.swift):198）→ save/广播 → 条件性提醒授权。旧 UI 只有“保存最终全文”的入口；没有独立的 append 动作。

原生提交不是统一的隐式 flush：[DaybookTextField](../AreaChain/Theme/DaybookTextField.swift):419、433 在 Return/⌘Return 前从 textView.string 同步 Binding；[DaybookTextEditor](../AreaChain/Theme/DaybookTextEditor.swift):70 在 ⌘Return 前同步，marked text 阻止提交，候选接受优先。按钮、失焦、卸载路径不能仅凭这些键盘证据声称已读到最后原生缓冲。

- 详情标题 Return/失焦保存、Esc 取消；失败留在编辑态，`EditDrafts.shared.titles` 按任务身份保留；卸载不额外提交（[TaskDetailHeaderSection](../AreaChain/Features/Workspace/TaskDetailHeaderSection.swift):55、109、115）。空白退出编辑并保留原模型，不等于支持清空标题。
- 行标题失败保留本行 `@State`；行卸载没有详情的跨卸载缓存，不能承诺所有标题草稿都可恢复。
- 备注 ⌘Return、失焦和卸载均可保存；先放入 `EditDrafts.notes`，成功才移除。Esc 先关候选，随后失焦可触发保存，不是取消备注。失败草稿仅为运行内内存，不承诺进程重启恢复。
- 指令接线前必须由当前编辑 owner 完成同修订的原生同步、拒绝未结束组词并重新取 stamp；不能强制提交其他窗口的未保存编辑，也不能给旧按钮回调换发新 lease。原 UI 的草稿/快捷键差异保留。

#### C. 输入、派生字段与当前产品差异

**新增。** 旧快速捕获的 date 是调用方传入：今日/菜单栏用 todayKey，日历/四象限用 selectedKey，标签页附既定 tagID，四象限附 fallbackQuadrant。`CreateTodoParams`（[协议](../AreaChain/Domain/Protocols/TaskRepositoryProtocol.swift):13）默认 notes/sourceBundleID/calendarEventID 为 `""`、remindMinutes=nil、重要/紧急=false、tagIDs=[]。源标记取 [CaptureStamp.current](../AreaChain/Services/ClipboardCapture.swift):5：偏好启用且前台 Bundle ID 非空、非本应用时记录，否则空；不是命令/用户身份。未来显式注入此采样，准备时冻结并预览，重试不重新采前台应用，不新增目录 source 参数。

[TodoItem](../AreaChain/Domain/Models.swift):184、204 默认随机 UUID、createdAt=.now、isDone=false、deletedAt=nil、dueMinutes=nil、空 subtasks；tagIDs 是编码字符串，附件另以 ownerKind+ownerID 关联。仓储创建还通过 `nextBoardOrder` 读取当日活任务和全部活习惯的 sortOrder，取最大值+1；这不是仅保存 title/day 两字段。创建不创建子任务、附件、检查记录或日历事件绑定，`calendarEventID` 初值为空；后续日历消费者可能回写它。

旧捕获先拒绝全空输入，但仓储允许**解析后空标题且仍有标签/提醒/重要紧急/非空备注**。例如已有测试刻画 `#1` 创建无标题任务；仅 `!p4` 的两个 bool 都为 false，不能仅凭“有语法”推导可创建。目录要求的是非空单行**输入值**：`title="#1"` 能过形状校验，空 title 或只提供独立 tags 则不能；不能把目录必填解释成最终 cleanTitle 必须非空，或将仓储元数据条件删去。目录 day 必填且规范 round-trip；旧仓储 addTodo 直接保存 dayKey，不能替代目录校验。新命令可显式预填当前日，但必须成为用户可见的具体参数，不能在最后提交时偷偷改成“今天”。

**标题解析。** `parseTaskCapture`（[NaturalLanguageParser](../AreaChain/Domain/NaturalLanguageParser.swift):75、119）收集全输入普通标签；标题移除标签/时间/优先级、折叠空白并反转义。标题内优先级和提醒胜过行内备注语法；标题重复时间/优先级取最后识别值。`//` / `／／` 分隔备注时会去其中的标签、优先级、第一个合法显式 @时间并折叠空白；无分隔符时首行作标题，其余行作为保留换行的备注，标签仍从全输入收集。`findNoteRange` 的规则是 `(?<![:\\])(//|／／)`，不能宣称它也具备 TagSyntax 的全部代码/链接保护。

`updateTodo` 拒绝显式空标题；`editTodoWithSyntax` 只有 parsed.notes 非空才覆盖旧 notes，空备注不覆盖。无提醒/优先级 token 保留旧值，有 token 才写；删除文字里的 hashtag 不解绑现有标签。标题中的 `//备注` 是真实备注写入，即使目录 title 的类型是 shortText。原行编辑允许 Shift 换行，目录 title 不允许换行，这个能力差异保留，不能截断输入后称为等价。

**备注解析。** `parseTaskNotes`（Parser:167）保留完整原文、换行及语法字符串，同时提取普通标签、优先级和第一个显式 `@HH:mm`；自然语句“下午3点”不改提醒。`ParsedNoteUpdate`（协议:5）同时携带 notes、完整 tagIDs、可选提醒及可选两个优先级 bool。仓储总是写 notes/tagIDs；提醒非 nil 才写，两个 bool 均非 nil 才改优先级。此处 nil 表示“保留”，不同于 `setRemind(nil)` 的取消。

| 模式 | 当前真实支持 | 后续命令契约 / 差异 |
|---|---|---|
| replace | `saveNotes(最终全文)` 替换并解析原文 | 直接共用。空白 replace 被目录拒绝；要清空应显式 clear。 |
| append | 无旧 UI/仓储追加原语 | 需先确定拼接规则，再生成最终全文走同一 parseTaskNotes / save。不得用两次保存或把 append 变成 replace 用户输入。见决定 D2。 |
| clear | `saveNotes("")` 可清空正文 | 只清 notes，保留标签、提醒和优先级；不能借 clear 删除所有派生属性。旧空白正文可直接保存与目录空白 replace 拒绝分别记录。 |

**基线必须按真实读写集合建立。** 新增没有旧任务字段基线，但有创建身份的“不存在”证据、规范日期、冻结来源、标签解析/存活/保护事实及排序来源。编辑至少有 store/context 来源、typed todo ID、恰好一行且存活的身份和如下字段；不用搜索结果摘要充当真实基线，不调用含 notes 的全量 snapshot 来方便复制正文。

| 操作 | 最少字段证据与最终复核 |
|---|---|
| 标题 | title；实际标签合并所依赖的 tagIDs（编码与规范 UUID 集合/顺序）；解析将写优先级时含 isImportant+isUrgent；将写提醒时含 remindMinutes；parsed.notes 将覆盖时含原 notes，随之进入长正文门禁。dayKey/isDone 等按提醒/日历计划的依赖采样，不作为无关字段的 blanket 冲突。 |
| 备注 replace/append/clear | notes；标签合并的完整 tagIDs 及目录身份；将写优先级时含两个 bool；将写提醒时含 remindMinutes。append 还必须将其读到的旧 notes 视为输入基线；拼接后整篇原文中旧 token 也可能再次参与解析。 |
| 两者共通 | prepare 只读；执行前在同一串行写入边界重新读取并比较影响字段、标签目录和对象存活。不能从旧对象 `todo.tagIDs` 拼好整串后只比较 notes，再覆盖他人刚改的标签/提醒。未触及字段取最后当前值保留，若既有实现无条件回写 tagIDs，就必须覆盖该读改写基线或先证明等价地避免该回写。 |

同字段或依赖字段变化返回明确冲突，缺基线返回不可准备，删除/重复身份不能“仍覆盖”。重新读取/采用当前/继续编辑/明确覆盖复用既定交互意图，但确认须绑定本次真实采样与所有版本，确认本身不写入，提交仍复核。没有字段修订号，当前值比较不能检测所有 ABA；不宣称设置版本协议已经存在于 Todo。

#### D. 标签、保护载荷与普通任务资格

[TagSyntax](../AreaChain/Domain/TagSyntax.swift):28、41 和 [DiaryMemoTags](../AreaChain/Domain/DiaryMemoTags.swift):5 对名称规范化，并在任务语法中排除精确中文预设 `密码/小巧思/日记`；转义、引号名、Markdown 链接/代码等按现有 TagSyntax 规则处理，不另写解析器。[InputTagResolver](../AreaChain/Services/Repositories/InputTagResolver.swift):7 先取首个活同名项，否则恢复首个已删同名项，否则插入新标签；合并保留原 UUID 顺序且去重，标签与任务同事务。

必须保留的现状差异：

- [Catalog.taskPickerTags](../AreaChain/Domain/Catalog.swift):80 只隐藏未关联的上述预设，已关联预设允许展示以供移除；手动新建任务标签也拒绝这些预设。
- **非预设但 `isPrivateDiary=true` 的标签目前仍可由任务 UI 和文本解析关联**。InputTagResolver、任务 add/replace/applyParsedNotes 均没有这一保护校验；显式 tagIDs 也未统一检查存在、存活、预设或重复实体。不能把“普通任务”写成现有全链路私密标签隔离保证。
- 同名多行时解析器取首个，`fetchTodo` / `fetchTag` 的 fetchLimit=1 也不证明唯一；活/墓碑同 UUID 仍是歧义。[ContentQueryTagNames.project](../AreaChain/Services/ContentQueryTagNames.swift):33 对缺失、多行或私密名字拒绝完整投影，这是查询保证，不能转借给写入。
- 推荐的命令普通资格见 D3；未确认前，不把旧任务 UI 改成新权限模型，不自动恢复受保护/歧义标签，不借搜索解析创建标签。普通标签的明确新建/恢复须显示在写入预览且属于后续授权范围。

[CommandDraftProtection.blocksUnprotectedExport](../AreaChain/Domain/CommandDraftProtection.swift):18 会阻止 protectedReference、required/unknown 保护要求，以及**任意 longText 参数或 longText 基线，连空字符串也是**。[CommandPlanValidation](../AreaChain/Domain/CommandPlanValidation.swift):54、[CommandPlan.seal](../AreaChain/Domain/CommandPlan.swift):213、[CommandExecutionRun.input](../AreaChain/Domain/CommandExecutionRun.swift):235 都消费这一守卫。

因此当前没有可安全直接借用的通用长正文执行通道：todo.notes、create 的 notes、会改备注的 title，均须等独立的受控借用协议和 C2B 前置，而不是改 cast、把 longText 降为 shortText、隐去真实基线、在 adapter 偷存正文副本或直接读取 protected payload 绕过 Run。clear 也需要原 notes 的冲突基线，不能因参数不带正文就例外放行。§9.52 最后结论仍是最终原生未验收、不得增加隔离接线；本方案不改变该结论。

首条无正文适配还必须检查**解析结果**：拒绝目录 notes 的任何操作、换行、被原规则识别的备注分隔段及非空 parsed.notes；不能让 shortText 的 `//` 携带正文越过守卫。保护要求只能沿已确认的普通来源/owner 传入，不能由 handler 因“类型是 todo”强制标成 ordinary；无法确认公开就拒绝。后续只可向明确限定的任务保存作用域提供同 ownership、item、修订、一次使用的借用，禁止返回任意 String/快照导出能力，且不得通往复制、日志、模板或其他对象类型；这些都是未实施、需另行确认的安全契约。

#### E. 本地提交、广播与外部结果的真实边界

[ModelChanges.transaction](../AreaChain/Services/ModelChanges.swift):78 将同 context 的内层 commit 延到外层，最终 save 成功才执行提交后 effects 和 `BoardEvents.changed`；回滚会重新物化七种 schema 模型。它有以下不能省略的限制：

1. 事务登记**之前**，`context.hasChanges` 为真就直接 `context.save()`（:85）；此预保存不经注入 save，也不广播，`value(in:)` 有相同预保存。外层失败不撤销已经预保存的其他内容。命令必须在进入共享入口前确认上下文干净，拒绝并保留既有 pending 编辑；不能用提前 save、rollback 或另一个 context 看不到脏值来掩盖问题。
2. 默认回滚是 context 范围，不是字段 CAS（比较并写入），不会阻止其他 context/进程写入，也没有禁用 autosave 的保证。首批只承诺 MainActor、明确写入者、最终校验到提交无 await 的隔离模型边界；生产接线前另核实同库所有实际写入者及未提交编辑。不能由内存测试推广多 context 并发或掉电耐久性。
3. `afterTransaction` 的 commit effect 失败只反馈错误，保存仍已成功（:96）；不能将失败解释为本地未写。Bool/throws 没有 unknown 分类，“save 已提交再抛错”或提交后丢回调必须另记结果未知，不能无条件映射 failedWithoutCommit。
4. 仓储 addTodo 在嵌套事务中返回模型时，最外层可能尚未保存；原 `addCapturedTodo` 又丢弃该返回值。新入口只在最外层 save 已返回后输出稳定引用，不能把内层对象创建成功当提交成功。

| 实际消费者 | 保存之后的作用与现有结果边界 | 后续隔离方式 |
|---|---|---|
| [BoardEvents](../AreaChain/Services/BoardEvents.swift):17、26、35 | 同步向 NotificationCenter.default 发 boardDidChange，再异步刷新 shared 提醒与日历。changedLocally 只刷新提醒，防日历回写循环。事件无 context/任务/提交 ID。XCTest 仅跳过 shared 提醒/日历，仍发 UI 通知。 | 注入作用于本次 context/事务的发布依赖，默认仍保持生产行为；QA 用私有 center，并显式连接同一事件到 fake 消费者，保持 changed 与 changedLocally 区别。不能以测试进程自动跳过当完整接线证据。 |
| 角标、搜索与手记窗口 | [StatusItemController](../AreaChain/Services/StatusItemController.swift):185 重读计数；[ContentQueryReadLifecycle](../AreaChain/Services/ContentQueryReadLifecycle.swift):49 / [ReadSession](../AreaChain/Services/ContentQueryReadSession.swift):365、420 同步失效许可、来源、展示；[DiaryWindows](../AreaChain/Features/Diary/DiaryWindows.swift):176 刷新编辑会话。通知缺席不能证明模型未变。 | 合成宿主/订阅接私有事件源，断言本地事实先登记、搜索撤权及 UI 一次发布；不向日用窗口发 QA 事件。 |
| 提醒授权与排程 | Capture 三入口成功后还直接请求 `NotificationScheduler.shared.ensureAuthorization`；排程器刷新全目录、取消旧请求、添加新请求，并更新 ReminderFollowUpStore。add 失败只日志，completedRefreshCount 仍可能增加；没有与本次任务绑定的逐步回执。 | [NotificationScheduler](../AreaChain/Services/NotificationScheduler.swift):139 已可注入 center/context/clock/calendar/debounce/followUps；必须全注入，followUps 用独立存储，授权也注入。新增可关联保存身份的完成事实后才能报告成功/失败；调用 scheduleRefresh 只表示请求已接收。 |
| 日历 | [CalendarSync](../AreaChain/Services/CalendarSync.swift):8 硬绑定 EventKit、生产 Persistence、shared prefs/status 和默认 ledger；Engine 执行远端 apply → 本地绑定/内容 save → changedLocally → ledger 文件 save（[Engine](../AreaChain/Services/CalendarSyncEngine.swift):112）。无提醒的活未完成任务也可生成全天事件；notes 不入 CalendarContent，但备注保存仍触发整轮同步，可拉回其他远端修改。 | 注入 CalendarSyncEngine/Coordinator 已有 client、local、ledger、enabled、clock、publish；fake EventKit + 真实内存 SwiftData local + 内存/临时账本。不要初始化生产 facade、请求真实授权或改用户日历偏好来“隔离”。 |

日历还可能创建系统日历；事件 notes 写的是 TodoDragToken 身份，不是任务备注。回写可改变 title/dayKey/remindMinutes/calendarEventID，账本默认写 `areachain-calendar-sync.json`。Engine 明文说明“不承诺跨 EventKit / SwiftData / 文件的原子回滚”；EventKit commit 后的异常、后续本地/ledger 失败都不能靠 reset 证明未写。当前 `.failed/.synced` 和全局 CalendarSyncStatus 没有本次操作的提交身份，不能直接拿全局绿灯为某条命令作证。

只换 taskRepositoryProvider 仍不足隔离：`BoardEvents`、提醒授权、捕获偏好/前台应用、默认 feedback 和 CalendarSync facade 尚有 shared 依赖。拟补的只是本任务实际需要的注入接缝及结果事实，不新建全业务万能 handler、通用 Outbox 或跨系统事务。正式启用前的真实授权必须列明：目标用户库、三项命令及目标/字段、普通标签新建或恢复范围、来源读取；若启用提醒，另含系统授权/增删请求/跟进偏好；若启用日历，另含系统日历和事件写入、全量同步范围、本地回写和账本写入。没有这项授权，真实消费者保持未装配；不靠屏蔽必要业务事件把生产任务保存伪装为无副作用能力。

#### F. 最小共享入口、幂等身份、冲突与核验设计（未实施）

**业务边界。** 推荐按阶段将 Capture 文件中三个 todo 方法的编排提到具体的 Services `TaskMutationService`（拟名），复用原解析与仓储。分别保留 create / editTitle / saveNotes 三个入口及具体输入类型；旧按钮保留自己的草稿/关闭/Bool 外壳，命令适配只做版本、资格、字段模式映射与结果衔接。共享入口独占解析、标签事务、模型写入和发布，不让 handler 拼接若干 repository setter。普通捕获、结构化参数、标题和备注的语法差异显式编码，不修改习惯/剪贴板规则。

**真实准备与提交次序。** prepare 经注入 context 读取完整身份行（包括墓碑，不能 fetchLimit=1），要求 `.todo`、dayKey=nil 的对象引用恰好对应一条活 Todo；读取失败/多行/墓碑均拒绝，不复活、不生成新对象。只读取本操作所需字段与标签事实，签发绑定 storage 实例、issuer/capture、lease、draft/plan/item stamps 的不可伪造准备证据。原 UI 仍可用原上下文；命令在共享入口外先执行干净上下文守卫，保存政策差异必须明确，不偷偷保存别人的编辑。

这不是旧仓储已有保证：Todo.id 没有 unique 属性约束，`fetchTodo(id:)` 明确包含已软删除行且只取首条（仓储:46）；updateTodo / applyParsedNotes 本身既不拒绝墓碑，也不比较字段基线。新增身份检查应是三项普通写入共享入口的窄守卫；保留恢复/彻底删除对墓碑的读取需求，不能全局把原 fetchTodo 改成 live-only。

执行由同一个 HandoffCoordinator 先取得占用；最终校验原 lease、Run/attempt、准备来源、最新身份/影响字段与标签事实，再同步相邻地进入共享事务。资格检查必须位于任何标签恢复/插入之前；校验失败零业务写入。对未知/敏感来源、批量、习惯/子任务/附件及未装配字段明确拒绝。存活和冲突不是授权替代品，用户“仍覆盖”也不能消除删除或重复身份。

**创建身份。** 在第一次业务调用前，为 `(ownership, runID, itemID)` 保留一个创建 UUID，重试沿用；它不同于 draftID，不在准备阶段插入模型。拟为 CreateTodoParams 增加兼容的可指定 ID（默认仍由旧入口生成），并让仓储在插入前完整检查该 UUID 的所有行。createdAt/来源等第一次提交输入一并冻结，重试不换身份。已经有该 ID 时，只有同一可信运行的提交事实才能认作原结果；其他行/碰撞/墓碑不能直接 adopt 或再生一个 UUID。多个 adapter 共用 Coordinator 的占用和已调用 attempt 登记，仅 adapter 自己的 busy Bool 不够。

**保存事实先于展示。** 共享事务在最终 save 返回后，先登记不可变本地提交事实/新对象引用，再发 BoardEvents 和外部请求；既有 ModelChanges 尚无这个带结果的前置回执钩子，需要窄扩展且回归旧调用。回执不含正文、用户标签名或原始错误字符串。提交后失焦/锁定只撤显示；可信完成绑定原 ownership/run，不能恢复旧 UI 权限，也不能丢掉已提交事实。通知、日历作为独立 external 效果记录，未启用且确无请求才可不列入；pending/running/failed/unknown 不写成 succeeded。

| 事实 / 故障 | Run 与用户结果 | 允许的后续 |
|---|---|---|
| 校验拒绝、未调用保存且无业务 mutation | notExecuted / 冲突；local.notSubmitted | 保留唯一草稿；修正并重新准备，不能沿旧确认提交。 |
| 已修改内存、确定未到提交点，回滚并验证原已保存模型/标签完整 | failedWithoutCommit；local.notSubmitted | 仅在隔离故障测试证明后签发 safeLocalReplay；创建沿原 UUID。回滚失败、save 调用是否提交不明不属于此行。 |
| save 返回且本地事实登记 | committed；create 输出真实 todo ID | 成功的本地步骤永不重放；即使通知拒绝、日历失败也不重复创建/标签恢复/排序分配。 |
| 本地成功、外部失败 | local.committed，notification/calendar 各自 failed 或 unknown | 有逐效果幂等与当前版本证据才重试失败外部步骤；已成功的不重做，不能用重新调用共享创建/编辑入口重试。现有全目录刷新与全局状态不足以签发该保证。 |
| save 可能提交、回执丢失或提交后异常 | commitUnknown / verificationRequired | 保留原快照、创建 ID、原未知回执和只读核验入口；禁止自动 replay/返回新建草稿。核验结果追加，不能改写原事实。 |
| 最终任务无变化 | 需任务专用 noChange 事实，零保存/发布/外部效果 | 当前通用 `.noChange` 只接受单项设置，不能直接拿来完成任务；必须窄扩展和测试。是否无变化要比较解析后的全部写集合，不能只比 title/notes。 |

**未知核验的上限。** 使用同库新建的只读 context 读取已保存状态，避开原 context 的 pending/cached 值。新建须核对保留 UUID、唯一行、冻结输入的全部已提交字段/关联、普通标签新建/恢复事实及本运行的写入来源；仅“有相同标题”不足。查不到 UUID 也不能证明从未提交（可能后来删掉，标签可能已提交），仍保留未知。编辑没有持久化 operation 标记，当前值碰巧等于目标不能证明本次更新提交；只有原保存返回/提交登记等可信证据才能确认，否则保留未知并交人工核验。本轮不引入任务事务日志、schema 迁移或跨进程恢复承诺；若要求崩溃后自动判断编辑提交，须另行讨论持久化身份，不能照搬设置 commitID。

**与原协议衔接的实际缺口。**

- `CommandExecutionRun.validConflict`（Run:136）只接受目录已声明参数；title/notes 的 tags/time/priority 诊断会被拒绝。应加任务专用影响字段证据和严格白名单，或受签发证据约束的等价窄扩展；不要把提醒冲突伪装为 notes 冲突，不给全部指令开放任意字段。
- Coordinator 的 `claimPreferenceInvocation` / replacePreferenceBaseline / returnUnsubmittedPreference 和 Run 的 verifyPreferenceGroup 都是现有设置路径。复用同一登记和所有权规则，新增窄任务入口；不改设置组资格、不让任务进入原子设置组。任务未知核验与 noChange 要有自己的合法转换；当前 unknown 不能经普通 receive 改成 committed。
- `CommandExecutionResult.committed(outputs:[itemID: .todo(id)], external: …)` 在本地提交确定时登记输出一次；Run 已校验生产者成员与 createdObjectType。对不需要创建输出的编辑传空 outputs。不能从 Bool 造 UUID，不能以预分配 UUID 提前宣称创建。
- 依赖当前要求生产者 **state.succeeded**，不是只有 local.committed；外部未完成时先保留输出但阻塞依赖，不为演示链路放宽。消费者第一次进入 local 尝试后绑定固定真实 ID，重试不换对象。
- 新建→标题编辑的后续集成还需要**绑定后的真实字段证据**：Run 的 snapshot 不可编辑，不能把当前查询行填回成第二份草稿。应由 Coordinator 在同一执行归属下登记不可编辑的 consumer 准备证据，绑定 producer 输出及提交字段事实，再读取当前对象比较；生产者保存后他人修改该字段须报冲突，不能在消费者开始时无条件将当前值当新基线。首轮只验证真实创建输出进入原依赖协议，不宣称另一个尚未装配的 handler 已执行。

#### G. 三项待确认的产品选择

**3T-1A 更新（2026-10-05）：D1～D3 已由用户明确确认，按阶段实施；下表保留 3T-0 的方案来源，当前确认与实施边界见 §9.64。** 本轮不提前开放结构化新增、append 或新命令标签资格门禁。

以下仅请求后续实施前定稿，不在 3T-0 代选或改变现有产品；不影响先做无语义变化的共享创建提取。

| 决定 | 推荐及具体影响 | 未确认时的边界 |
|---|---|---|
| **D1 结构化新增参数和语法如何合成** | 推荐保留旧捕获单源规则；结构化入口分别调用既有 title / notes parser，独立 notes 原文保存，缺独立 notes 才用标题派生备注。标题派生备注与显式 notes 同时存在且不同则要求用户消歧。优先级/提醒借鉴现有结构化习惯的 title语法→notes语法→显式值，但显式值/取消与语法相矛盾时阻止提交并展示冲突；tags 先承接解析/初始集合，再执行明确 add/remove/replaceAll/clear，预览最终关联。不靠拼接 `title+"//"+notes` 重解析。新建空基准上的 clear/remove/cancel 是显式无效果或消除解析结果，不假装继承旧任务值。保留旧元数据任务能力；目录空 title 的表达能力需另补明确形状校验，不能取消所有非空校验。 | 先只装配纯 title+具体 day；notes、其他字段模式与元数据专用创建不先开放。D1 决定参数预览、兼容夹具及后续目录校验，不能以实现方便选择覆盖顺序。 |
| **D2 备注 append 如何拼接及解析** | 推荐精确连接：任一侧为空时取另一侧，否则 `旧全文 + "\n" + 追加原文`，不 trim 任一侧；随后对最终全文调用 parseTaskNotes。这会保留原文，并可能使旧显式 token 继续决定属性（备注提醒是首个、优先级是最后一个），预览须揭示。clear 只清正文。若改成仅解析追加片段，就与“保存同一最终全文”的旧 UI 结果不同，需明确选择该产品变化。 | append 不实现；replace/clear 也仍受长正文执行门禁，不能先只按 notes 比较绕过派生字段。 |
| **D3 普通指令遇到私密/预设或歧义标签的资格** | 推荐首批拒绝新增关联私密/手记预设标签，以及任何缺失/重复身份/保护事实不全；遇目标已关联受保护标签且不能证实普通资格时整项拒绝。普通同名歧义也要求显式解决，不取任意首条。此为新命令的保守资格门禁，不将已有任务转为加密对象、不自动解绑、不改变旧任务 UI 的 `isPrivateDiary` 行为。以后要统一旧 UI 政策须单独确认。 | 含相关标签的 command 保持未装配/不可准备；不读取私密手记正文或凭据来判断，不在 T0 修改权限或标签行为。 |

#### H. 适合约 18k 上下文的实施拆分

每轮只取本节、列出的真实入口和对应测试，不重载全文历史；实际触及公共接口时同步原组件目录/架构说明并保留指定 Cursor 复核门禁。以下所有阶段均为建议，必须收到下一轮明确实施请求才开始；共享提取、业务适配和原生 UI 分开交付，不能一次建立全业务 handler 框架。

| 阶段与命令 / 共享入口 | 拟改文件（新文件为拟名） | 参数、基线、输出及保存/故障 | 隔离测试与 UI 接线前置 |
|---|---|---|---|
| **3T-1A：只提取普通新增共享链，无 handler**；原 `addCapturedTodo` → `TaskMutationService.createCaptured` | 新 `Services/TaskMutationService.swift`；`DayBoardMutations+Capture.swift`；`ModelChanges.swift`、`BoardEvents.swift` 的窄发布依赖；既有 ModelChanges/InputSyntaxPersistence 测试与一个任务专用合成 fixture | 原 raw text/day/tagIDs/fallback 原样，解析/默认/来源规则不改；显式注入来源、授权、发布和 feedback。对外在最终 save 后返回真实创建引用/本地事实，旧 UI 保持 Bool 和失败留稿。记录 pending 预保存限制，不把它顺手改成全库事务政策；注入保存失败验证任务与新建/恢复标签一起回滚。 | 内存完整 schema、autosave=false、私有事件源、fake 授权/刷新，对照原 UI 业务调用与共享入口全字段/关联/发布次数；回归 changedLocally。此轮不改标题/备注、目录、创建幂等协议、C2B 或统一搜索 UI，不接真实服务。 |
| **3T-1B：首条最小 `todo.create` 真实适配**；复用 1A 保存入口 | `TaskRepositoryProtocol.swift` / `SwiftDataTaskRepository.swift` 的显式创建 ID；新 `Services/TaskCreateCommandAdapter.swift` 与窄 contract；Coordinator / Run / ExecutionContract 的任务占用、事实和核验；对应创建测试 | 仅 title+day、无 target、单个创建；拒绝 longText、notes 任意模式、分隔备注、换行及解析出的标签/提醒/优先级，cleanTitle 非空。干净 context、创建 UUID 不存在证据、来源冻结；重复 attempt/适配器/回执不再次保存。产出真实 `.todo` 引用；未知不 replay，本地成功外部失败不重复创建。 | 原 UI/适配相同输入对照；真假保存失败、提交后异常、碰撞/墓碑、重复提交；fake notification/calendar 的各自失败与无真实调用；真实输出进入 Plan 依赖协议（消费者业务暂不执行）。仅隔离显式装配；默认未装配、生产 UI 不变。若本轮预算不足，先停在稳定 ID/提交事实，adapter 单独续轮，不削掉验证。 |
| **3T-2A：新增的其余普通参数**；仍只复用 create 入口 | `TaskMutationService` 的具体结构化输入/解析结果；TaskCreateCommandAdapter；必要的 CommandArgumentValidation/目录元数据；创建/标签/语法测试 | D1、D3 确认后处理 tags/time/priority 的全部声明模式、元数据标题与预览冲突；准备标签实际身份及可能恢复/创建效果，保证同事务。含 notes 或派生备注继续未装配，不能称 todo.create 全部完成。 | 日期、空值、仅 token、同名/已删/重复/预设/私密标签、优先级和提醒显式冲突；fake 授权/系统效果。源标记与旧捕获/象限/标签页差异逐项对照；未完成字段明确拒绝。 |
| **3T-2B：`todo.title` 普通无备注子集**；原 `editTodoWithSyntax` → 同一服务 editTitle | Capture 文件、TaskMutationService；新 `TaskTitleCommandAdapter`；任务影响字段基线/Run 冲突契约；TaskRowFactory / TaskDetailSections 仅必要适配及对应测试 | 单目标，复用标题 NLP/标签合并/条件性提醒优先级；拒绝备注派生和 longText 基线，保留旧 UI 的完整能力。唯一活身份、title+实际派生字段基线；不改日期/完成/截止/来源。noChange、冲突/删除/重复身份和失败草稿各有结果。 | 真内存模型；原行/详情业务调用对照；同字段和派生字段冲突、未提及字段保留；实现并验证 create→title 的固定输出绑定与消费者基线，再开放该两步隔离计划。原生 buffer/按钮/失焦另轮验证。 |
| **3T-3A：`todo.notes` 的共享全文模式与基线，暂不执行指令** | TaskMutationService、Capture `saveNotes` / `parsedNoteUpdate`；必要的 Domain 备注模式值；TaskDetailNotesView 的调用适配和相关测试 | D2/D3 后建立 replace/append/clear 最终全文和全部派生字段事实；原 UI 替换保存不变。任务写入测试仅合成数据，尚不穿过命令长正文保护出口。失败留稿，空值/clear 不取消属性，append 同基线不自动合并并发修改。 | 同一最终全文的原 UI/共享入口模型对照；旧 token 再解析与提醒/标签冲突；事件/fake 系统效果对照。无 todo.notes handler，不新增敏感原生探针或改 C2B 守卫。 |
| **3T-3B：三命令的长正文执行补全，当前前置未满足** | 只在独立安全方案批准后确定 CommandDraftContentSession / 原 Coordinator / Plan / Run 的受控借用改动；窄 TaskNotesCommandAdapter；不得复制保护服务 | C2B 最终验收、明确普通/敏感载荷资格及计划内同修订借用先完成；再接 todo.notes、create.notes、title 的派生备注。保留完整 notes 与派生字段基线，clear 不例外。 | 封存/锁定/失焦/旧修订/计划所有权及无明文出口，加真实内存业务对照；缺任一前置保持未装配。不得通过此阶段顺带接敏感生产编辑。 |
| **3T-4：按命令逐轮接原生 UI** | 原 UnifiedSearchController / OperationEditing / PlanEditing / OperationPreview、双语资源及现有隔离宿主；不建新面板状态所有者 | 只消费已经验证的适配能力、真实 prepare/report/冲突与核验；⌘Return/明确按钮提交，候选 Return 不保存。命令/字段未装配必须可解释，不能降级换路径写入。 | 每轮一个命令：标准/紧凑、中英、浅深色/最小尺寸、焦点/IME/撤销、失败重开草稿与迟到事件。真实库与通知/日历生产装配另行具体授权；不得由 fake 成功自动启用。 |

**下一阶段准确范围是 3T-1A。** 它可以在 D1～D3 未定时保持旧捕获规则推进；仅提取新增和补可注入提交/发布边界及内存对照，不顺手实现任意 handler，也不开始标题、备注或长文接线。第一次完整 command 链以 3T-1B 的窄 `todo.create` 为验收目标，未支持参数仍留在完整交付清单。

#### I. 后续验证矩阵（本阶段均未运行）

| 必需证据 | 复用的已阅读测试 / 新增验证点 |
|---|---|
| 内存 SwiftData 真模型与原 UI 业务入口对照 | [ModelChangesTests](../AreaChainTests/Services/ModelChangesTests.swift):13、57 和 [InputSyntaxPersistenceTests](../AreaChainTests/Services/InputSyntaxPersistenceTests.swift):45、68；比较新 context 回读、日期、来源、sortOrder、标签实体/关联和保存/广播次数，不只用 mock repo。 |
| 空值、语法、日期、标签兼容 | [NaturalLanguageParserTests](../AreaChainTests/Domain/NaturalLanguageParserTests.swift)、[TagSyntaxTests](../AreaChainTests/Domain/TagSyntaxTests.swift)、[BatchMutationsTests](../AreaChainTests/Domain/BatchMutationsTests.swift):296；补 required day、非规范日期、token-only、转义/链接/代码、分隔备注、空白与 clear、预设及私密/歧义标签。 |
| 失败保留草稿与干净事务 | 原 InputSyntaxPersistence:123 的失败对象是 Diary，不能代替 Todo；新增任务/新标签/恢复标签一起失败、干净/有 pending context 的拒绝、保存前抛错/保存后抛错/rollback 失败；原 UI 与指令唯一草稿都保留。 |
| 重复、存活、冲突与输出 | [SwiftDataTaskRepositoryTests](../AreaChainTests/Services/SwiftDataTaskRepositoryTests.swift) / [TaskContentQueryReaderTests](../AreaChainTests/Services/TaskContentQueryReaderTests.swift):92 的现存读语义；新增 UUID 碰撞、活+墓碑/双活、执行前删除、同字段/派生字段冲突、旧确认、两 adapter 重入与重复 receipt。真实创建 UUID 接 [CommandPlanDependencyTests](../AreaChainTests/Domain/CommandPlanDependencyTests.swift) / [CommandExecutionTests](../AreaChainTests/Domain/CommandExecutionTests.swift)，不从合成输出冒充真实创建结果。 |
| 本地成功、外部失败且无真实系统写入 | [CalendarSyncEngineTests](../AreaChainTests/Services/CalendarSyncEngineTests.swift):178、190 及其 fake fixture；[NotificationSchedulerTests](../AreaChainTests/Services/NotificationSchedulerTests.swift):169 是手动 refresh，不能证明完整广播链。新增同私有发布源自动触发 fake 消费者、逐效果回执、已提交事实先于通知、失败只重试外部、日历回写不回环；明确断言生产 facade/系统中心/默认 ledger 未调用。 |
| 原生最后输入与保护 | [InputSyntaxInteractionTests](../AreaChainTests/Features/InputSyntaxInteractionTests.swift):116、170、277；[WorkspaceHeaderInteractionTests](../AreaChainTests/Features/WorkspaceHeaderInteractionTests.swift):90 只是注入 Bool 失败。后续补真实模型保存失败与最新 buffer、marked text、按钮/失焦/卸载、旧 lease；protected/unknown/longText 及 shortText 派生正文不能越过守卫。C2B 历史失败不因此关闭。 |

后续测试必须使用独立 QA 标识、正常完整目标、原锁和串行原生规则；本轮不申请锁或运行这些命令。提醒 followUps 要显式独立存储（现有某些 helper 会默认回落 shared），日历不得触发 EventKit 授权；未提供这些依赖就拒绝装配。修改共享保存/协议行为后仍需指定 Cursor verifier，工具不可用按原规则保留缺口，不由上述探索代理替代。

#### J. 本轮文档检查与停止交接

修改前已检查暂存与未暂存差异；原本文 §9.62 的收口增量完整保留。阅读期间另有 CalendarPage、日历跨度测试和 usage 文档等并行改动出现，本轮不修改或回退它们；源码事实若在后续变化，应按本节符号重核，不把本次阅读作为运行验收。

本轮实际运行 `python3 -B scripts/quality_gate.py --profile docs --format json`、`python3 -B scripts/check_workflow.py` 及 `git diff --check`，均退出 0 / passed；最后内容修订后重跑同组检查。docs profile 的 change-scope、workflow-contract、diff-whitespace、performance-contract、comment-contract 通过；工作流的 11 类检查通过。显式 docs 避免因并行 Swift 改动被 auto 路由到构建/原生测试，未运行 scripts/tests、Swift 测试或应用。文档/引用/注释/性能清单静态结果不证明任务保存、原生或系统行为。

本次仅在 §9.62 后追加 §9.63。对追加前 1,049,505 字节做 SHA-256 对照，仍为 `a97b86d3b31aadffc6a49cb99c3a4527a6f539a0aad32f6a304198a4b53e3bac`，证明原有文档内容（包括暂存/未暂存收口）逐字保留；没有暂存、提交或修改其他文件。检查全工作区的并行路径不意味着这些修改属于本轮或通过了运行验收。

**停止点：3T-0 文档方案。** 不实现 handler、不写业务数据、不构建、不申请测试锁、不重复认证、不进入 3T-1A；不提交、推送、安装或发布。四项设置本地验收完成的状态保留，任务执行与全部未运行验证不冒充通过，指定 Cursor、人工、C2B 及历史缺口不变。


### 9.64 阶段 3T-1A：普通捕获共享新增与事务局部边界

2026-10-05（Asia/Shanghai）。本轮只提取普通 `addCapturedTodo` 链路，未实现 `todo.create` handler、固定创建 UUID 或幂等协议，未接统一搜索执行。标题、备注编辑、结构化习惯及剪贴板捕获实现保持原样。指定 Cursor verifier 无可调用入口，未重查登录；C2B、人工及历史缺口继续保留。代码和测试验证状态分别记录于本节末尾。

#### A. 已确认的产品决定与分阶段边界

- **D1 已确认**：结构化 title、notes 分别解析；独立备注与不同的标题派生备注必须消歧。优先级/提醒候选沿标题、备注、显式值组合，显式设置或取消与语法冲突阻止提交。标签先解析，再应用明确增删/替换/清空；不拼接 title 和 notes 重解析。旧捕获框继续原单段规则。本轮仅登记，结构化普通字段留给 3T-2A；长正文仍受 C2B 与独立协议前置约束。
- **D2 已确认**：append 任一侧为空取另一侧，否则旧全文＋一个换行＋追加原文，不 trim 两侧；最终全文统一解析。clear 只清正文，不连带清其他属性。本轮没有 append 实现，后续仍按 3T-3A/3B 边界推进。
- **D3 已确认**：新普通指令拒绝新增关联私密/手记预设标签；缺失、歧义、重复身份或保护资料不足阻止提交，既有关联无法确认普通资格则整项暂停。普通标签创建/恢复需要明确预览。不得改变旧任务 UI 政策、自动解绑或加密。本轮只登记，旧 InputTagResolver 规则未改变。

#### B. 实际入口与兼容

[TaskMutationService.swift](../AreaChain/Services/TaskMutationService.swift) 的 `createCaptured(_:in:dependencies:)` 接 `CaptureInput(text, dayKey, tagIDs, fallbackQuadrant)` 和调用方的同一 ModelContext。它唯一执行原 trim、parseTaskCapture、InputTagResolver.merging、TagIDList 与仓储 addTodo(CreateTodoParams) 链。原 [DayBoardMutations.addCapturedTodo](../AreaChain/Features/Tasks/DayBoardMutations+Capture.swift) 只负责生产装配和 Bool 适配；菜单栏、今日、标签页、日历、四象限仍走该旧入口。没有两份生产解析/保存实现。

明确优先级胜过象限 fallback；标签关联保持原顺序与去重，新建/恢复和任务同事务；notes、提醒、来源、仓储 sortOrder 与元数据任务能力保持。CaptureStamp 和 requestReminderAccessIfNeeded 的生产调用不变。旧 UI 实际调用均为顶层同步调用，保存失败 Bool=false 后保留原草稿；保存成功而发布失败仍返回 true，不能因刷新失败重复创建。嵌套使用旧 Bool 只能得到 false（尚不能确认保存），未来消费者应持有 Creation 句柄，不拿 Bool 代表内层提交。

#### C. 提交事实与注入范围

- `Dependencies` 显式注入来源采样、TaskRepositoryProtocol 工厂、事务 Boundary、本地创建登记和提醒授权请求；生产闭包惰性访问原服务，隔离测试全部替换。
- [ModelChanges.Boundary](../AreaChain/Services/ModelChanges.swift) 提供 preSave、save、publish、reportFailure；不修改全局可替换闭包。既有 context 对应的同步事务登记暂存同一 Boundary，嵌套继承外层，内层不能覆盖保存/发布。最外层结束后 defer 清理边界和 effects，不建立通用容器。
- `Creation.candidateID` 只说明仓储在上下文中产生过模型；`savedID` 只在最外层 save 返回后经 afterCommit 写入。状态为 emptyInput / pending / notSubmitted / commitUnknown / saved。调用方必须读 savedID，不能从 candidateID 伪造创建输出。
- `CommitFacts` 分别保留 preSave、save、rollback、publication 的 notCalled / called / returned，以及事务阶段和 publicationFailed。回滚恢复失败单列 recoveryFailed，不能冒充成功回滚。save 调用抛错（包括先 save 再抛错）一律保留不确定，回滚后查不到任务也不证明从未提交。这里不签发 safeLocalReplay，不提供执行 Run 回执或掉电耐久保证。
- 最外层顺序为 save 返回 → savedID 本地事实 → registerLocalCreation → 提交后发布 → 提醒授权请求。登记失败标记 registrationFailed；发布失败标记 publicationFailed 并走注入反馈，二者都不撤销 savedID，不触发重建。后续请求仍可发生；发布闭包抛错也可能已有部分消费者被调用，不能声称零外部副作用。
- [BoardEvents](../AreaChain/Services/BoardEvents.swift) 保留无参数入口及函数引用兼容，另提供显式 Dependencies(center, requestRefresh)。changed 请求 UI、提醒刷新与条件性日历刷新；changedLocally 仍不请求日历。生产保留原异步 Task 调度，测试私有事件源连接 fake 消费者，不向默认通知中心发送 QA 事件。请求发生不等于提醒送达、授权获准或日历写入完成。

#### D. 脏上下文与嵌套限制

原 transaction 在登记前预保存已有 context.hasChanges 的政策不变；新 Boundary 可单独观察/替换 preSave，旧 `transaction(save:)` 的 save 参数仍只替换最终保存。预保存不发布事件，后续创建失败不能撤销此前保存的无关内容。预保存自身失败不回滚进入前 pending 编辑，且没有开始本次创建。

后续命令必须在进入该入口前检查 `context.hasChanges == false`，并在同一 MainActor 同步作用域完成最终复核和调用；不提前保存、清稿、rollback 或另开 context 隐藏 pending 修改。仓储返回不表示提交；嵌套 Creation 在外层 save 前保持 pending，外层失败使其变为未提交或不确定，外层成功才填 savedID。没有嵌套 savepoint；内层业务失败后外层必须中止其组合工作，不可吞掉失败继续保存部分标签修改。提交后回调期间不接受新的嵌套事务，避免把新模型误挂在已返回的 save 上。

#### E. 验证入口与本轮证据

[TaskCaptureFixture](../AreaChainTests/Services/TaskCaptureFixture.swift) 使用完整七模型 schema、显式 ModelContext、autosave=false、私有 NotificationCenter、fake 授权及提醒/日历消费者。冻结的提取前算法只存在于测试支持；和旧 UI 委托、新服务比较实际标题、备注、日期、来源、优先级、提醒、排序、标签顺序及系统请求次数，并检查生成身份/默认状态。fixture 和业务依赖链不初始化生产 AppPreferences、NotificationScheduler、CalendarSync、Persistence 单例。正常 XCTest 应用宿主的 App.init 改为直接创建独立内存容器并关闭 autosave，避免初始化生产 Persistence.session；生产启动仍沿原 session/StoreHealth。业务 fixture 不使用宿主容器，系统副作用隔离由显式依赖保证。

[TaskMutationServiceTests](../AreaChainTests/Services/TaskMutationServiceTests.swift)、[TaskCaptureTransactionTests](../AreaChainTests/Services/TaskCaptureTransactionTests.swift) 覆盖空输入、元数据、备注分隔、标签/初始顺序、象限 fallback、来源、恢复/新建标签同提交、失败回滚、dirty preSave、嵌套延后、登记/发布异常、save 后抛错、私有事件与 changedLocally、旧 Bool 留稿及旧标签政策。复用 [ModelChangesTests](../AreaChainTests/Services/ModelChangesTests.swift) 的组合事务和 afterTransaction 回归，以及 [InputSyntaxPersistenceTests](../AreaChainTests/Services/InputSyntaxPersistenceTests.swift) 的新建/恢复标签共同回滚用例；选中用例补显式注入，不因名称含恢复而排除。

**首次交付状态（历史）：partial。** 先后修正本轮 MainActor 闭包隔离、changedLocally 无参数函数引用兼容和测试 throwing 断言的编译问题，未改/排除并行源码。最后一次成功的完整正常 PrivacyQA 测试产物为 `build/TaskCapture-3T1A-190729.xcresult`：57 个方法、74 次运行（含参数化），0 失败、0 跳过；已核对结果树包含四个选中 ModelChanges 用例和 InputSyntaxPersistence 的标签共同回滚用例。

| 验证 | 实际结果与限制 |
|---|---|
| 原算法／旧 UI／共享入口等价；保存失败、标签恢复、嵌套、dirty context、发布异常、save 后抛错 | 上述成功产物覆盖，实际字段/顺序/计数断言通过。是最终补充前版本的运行证据，不称最终版本全通过。 |
| 最终补充 | 成功测试后增加 rollback 调用/返回事实及 recoveryFailed 分支、将发布部分提取辅助函数，补默认通知中心零事件和 rollback 返回断言。重跑非等待申请 `build/.build.lock` 被占用，退出 3；按用户要求停止，不等待、不抢锁、不再申请。以上最终增量尚未编译/运行验证。 |
| 构建 | 成功测试之前完整应用与测试目标编译、QA 临时签名通过；最终增量编译及独立 `./scripts/build.sh` Debug 构建/验签未运行，锁门禁保持。 |
| 静态与脚本 | 最终相关编辑后 `python3 -B scripts/quality_gate.py --profile static --format json`、`python3 -B scripts/check_workflow.py`、`git diff --check` 及本轮十个 Swift 文件的 SwiftLint 通过；工作流定向 103 项、全 scripts/tests 223 项通过。新增四个组件守卫符号及缺失反例；曾漏更新测试夹具目录，修正后重跑通过。 |
| 原生与真实系统 | 没有执行真实窗口编辑/IME、真实提醒送达、真实日历写入或认证验证；本轮只验证业务调用与 fake 请求，不把编译或请求计数称作外部成功。 |
| 指定复核 | 当前工具清单没有 Cursor verifier，未登录、未替代复核；C2B、人工及历史缺口不变。 |

静态 profile 加独立定向 QA 与 SwiftLint，避免 swift profile 自动运行未显式隔离的全量业务测试。没有访问真实用户库、真实提醒/日历或钥匙串；未提交、推送、安装或发布。本轮未执行 git add；工作中检测到外部暂存更新包含部分本轮文件，保留而不撤销。再次授权续验时先核对并行差异与锁，再运行本节选中用例和必要构建；本轮不重试锁、不进入下一阶段。

#### E1. 最终验收续轮：已验证内容与新发现（2026-10-05）

本续轮读取当前工作区及外部暂存状态，不改暂存、不回退并行改动。正常非等待取得原 `build/.build.lock`，使用完整正常 PrivacyQA 目标、同一隔离 Bundle ID/DerivedData、本地临时签名、六项钥匙串授权清除和串行执行；没有排除源码。结果 `build/TaskCapture-3T1A-acceptance-192724.xcresult` 为 **23 个方法／37 次执行全部通过，0 失败、0 跳过**。它覆盖首次交付末尾的 rollback 事实、发布辅助函数、默认通知中心零事件及 rollback 返回断言；不再把这些内容只引用补充前的 57／74 证据。

仅运行 TaskMutationServiceTests、TaskCaptureTransactionTests，以及 ModelChangesTests 的 compositeRepositoriesCommitOnceAndRollBackTogether、captureIsSavedBeforeOtherContextsReadItsBadgeCount、afterTransactionRollbackRunsWhenSaveFails、afterTransactionCommitFailureStillPublishesBoardChange 和 InputSyntaxPersistenceTests 的 failedCombinedSaveRollsBackNewAndRestoredTagsWithTheirContents；未机械重跑未受影响的 NLP/TagSyntax 组。

- 已通过的事实：最外层保存后登记 savedID；内层 pending 不成功；保存调用抛错保持 unknown；任务和新建/恢复标签回滚；脏上下文预保存不被后续失败撤销；本地事实早于发布；发布失败不撤销已保存身份；私有事件不流入默认通知中心；跨 context 和后续事务不复用旧注入。
- 测试宿主：上述正常 XCTest 宿主实际启动并完成测试；源码核对测试分支直接创建完整 schema 的内存容器、关闭 autosave，不初始化 Persistence.session。非测试分支仍按原顺序取 Persistence.session.container 并应用 StoreHealth；生产启动只做静态比较，未以真实用户库启动应用。fixture 始终使用自身独立上下文与 fake 系统消费者。
- 新发现及必要窄修正：原代码按 `ModelRollback.failure` 返回值是否为 ModelRecoveryError 来判断本次恢复失败；原始错误自身属于该类型时，即使此次 restore 成功也误记 recoveryFailed。改为直接依据 ModelRollback.restore 的实际返回/抛错登记，仍复用同一恢复实现和错误包装，不改变事务政策；只新增 originalRecoveryErrorDoesNotMislabelSuccessfulRollback 一个针对性回归。
- **最终源码仍未全部运行验证**：上述窄修正后的第二次非等待锁申请返回 3（锁忙），尚未启动 xcodebuild。立即停止，不轮询、不抢锁、不干预持有者；没有尝试独立 Debug 构建。23／37 是这处新修正之前的源码证据，不能覆盖该修正或新增回归。
- 最终十个相关 Swift 文件的 SwiftLint、check_workflow.py、quality_gate.py --profile static 和暂存/未暂存 diff --check 通过；静态门禁包含 223 项脚本回归通过。指定 Cursor、C2B、人工及历史缺口不变。正常配置 Debug 构建与静态验签尚未完成。本轮仍为 **partial**，停止在 3T-1A，不实现 handler、不进入 3T-1B；未提交、推送、安装或操作真实数据。

再次续验记录（2026-10-05）：收到“继续”后核对回滚修正、针对性断言及外部暂存状态，源码未改。原 `build/.build.lock` 的非等待申请立即返回 3（锁忙），未启动 xcodebuild、未生成新测试结果、未申请独立 Debug 构建；不轮询、不抢锁、不干预其他任务。上列窄修正的运行验证及 Debug 构建/静态验签仍待完成，既有 23／37 不能提升为该修正的证据；指定复核和历史缺口保持。

#### E2. 最终源码定向测试通过，Debug 构建仍受锁阻塞（2026-10-05）

再次获得用户续验授权后，正常取得原 build/.build.lock；完整正常 PrivacyQA 目标、原独立 Bundle ID/DerivedData、六项授权变量清除及串行策略不变。产物 `build/TaskCapture-3T1A-closeout-194023.xcresult`：**24 个方法／38 次执行通过，0 失败、0 跳过**。保持 E1 的两个任务测试组和五个受影响回归，仅增加必要的 originalRecoveryErrorDoesNotMislabelSuccessfulRollback；结果树明确确认该新增回归通过。未扩大到未受影响的 NLP、TagSyntax 或真实系统矩阵。

本次覆盖最终 ModelChanges.restore 实际返回/抛错事实修正、发布辅助函数和所有补充断言。结果树确认最外层 savedID、本地事实先于事件、pending/unknown 不成功、发布失败保留提交事实、任务/标签回滚、dirty preSave 及跨 context 注入隔离相关用例均通过。测试前记录的 10 个相关 Swift 源码 SHA-256 在测试后逐一一致（`build/TaskCapture-3T1A-closeout-source.json`），没有用旧 23／37 或 57／74 替代最终源码证据。正常测试宿主再次实际启动，生产启动分支仍仅静态核对，未操作真实用户库。

随后执行 `./scripts/build.sh --no-wait`，构建锁已被其他任务占用，退出 3，日志为 `build/TaskCapture-3T1A-debug-build.log`。立即停止，不轮询、不再次申请；**正常配置 Debug 构建及独立静态验签仍未完成**，不能以 PrivacyQA 编译/临时签名替代。整体继续 partial；此时剩余本地验收缺口仅为正常 Debug 构建/静态验签，指定 Cursor、C2B、人工与历史缺口独立保留。

本轮没有新增源码修改，只记录验收证据并同步工程索引。最终十个相关 Swift 文件的 SwiftLint、工作流、静态门禁（含 223 项脚本回归）及暂存/未暂存差异检查均通过；编译日志中既有 accessibilityAttributeValue 弃用警告保留，不扩大修复。没有暂存、提交、推送、安装或实现 handler，停止在 3T-1A。

#### E3. 本地最终验收收口（2026-10-05）

**当前状态：3T-1A 实现与本次要求的本地最终验收已完成；指定 Cursor、C2B、人工及历史缺口仍独立保留，不能称整体验收全部通过。** E、E1、E2 中的锁忙与 partial 是当时的历史状态；本节更新其本地构建/验签缺口，不抹去历史失败或补充前证据。

本次核对受验十个 Swift 文件的 SHA-256 与 `build/TaskCapture-3T1A-closeout-source.json` 全部一致，构建后再次核对一致，未新增源码编辑。因此沿用 E2 最终源码 **24 方法／38 次执行通过、0 失败、0 跳过** 的测试证据，不机械重跑已通过且未变化的用例；该证据包括回滚事实新回归，而不是补充前的 23／37 或 57／74。

正常执行 `./scripts/build.sh --no-wait`，本次成功取得原构建锁并退出 0；没有覆盖签名参数、没有允许 provisioning、没有改变个人配置。正常 Debug 使用项目当前 development 配置，产物为 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`。脚本自动执行的静态验签返回 `configuration=Debug`、`staticSignatureVerified=true`、`hardenedRuntime=true`；`distributionReady=false` 保持，未公证或发布。日志 `build/TaskCapture-3T1A-debug-build.log` 保存本次成功输出；多匹配 macOS destination 的提示不影响退出结果。未启动或安装该产物，也未执行真实系统认证、日历、提醒或用户库操作。

最终仅更新同一权威文档和工程索引，保留并行修改及外部暂存；本轮十个相关 Swift 文件的 SwiftLint、工作流、静态门禁（含 223 项脚本回归）和暂存/未暂存差异检查全部通过。测试宿主正常运行、生产初始化分支静态等价、提交/发布和失败事实等证据沿 E1/E2；不把静态验签推广为真实系统解锁验收。停止在 3T-1A，不实现 handler、不进入 3T-1B，不提交、不推送、不安装。

#### F. 3T-1B 的准确最小接线要求

只做单个 title＋具体 day、无 target 的 todo.create；拒绝 notes 任意模式、换行、原备注分隔段、非空解析备注及解析出的标签/提醒/优先级，cleanTitle 非空。来源准备时冻结；入口前要求干净 context。下一轮再为 CreateTodoParams/仓储增加明确创建 UUID 和唯一不存在检查，绑定原 ownership/runID/itemID，在 Coordinator/Run 登记同一调用与真实事实；本轮随机 candidateID 不是幂等键，也不能从 Bool 造输出。

消费本轮 savedID 与 save/publication 事实，在发布前登记可信本地结果，再将真实 `.todo` 输出接既有依赖协议；pending 不报成功、unknown 不自动 replay，本地成功外部失败不再创建。碰撞/墓碑/重复身份、两适配器、重复 attempt/回执及外部逐步结果须另补测试。仅隔离显式装配，默认未装配和生产 UI 保持；不接标题/备注 handler，不开放 D1/D3 的其余字段，不绕过 C2B。**本轮停止于 3T-1A，不执行 3T-1B。**

### 9.65 阶段 3T-1B：最小普通 todo.create 的隔离真实适配

2026-10-05（Asia/Shanghai）。本节承接 §9.63 与 §9.64 最终交接，只实施单个普通纯标题＋明确民事日期的创建。生产搜索、其他命令、单命令原生 UI、真实用户库及系统服务均未接线；指定 Cursor verifier、C2B、人工和历史缺口继续保留，不重新认证或替代复核。以下实现与验证分别记录。

#### A. 最小资格与实际复用

[TaskCreateCommandAdapter](../AreaChain/Services/TaskCreateCommandAdapter.swift) 仅接受已进入唯一计划项的 `todo.create`，参数恰为 title:shortText 与 day:day，沿 CommandCatalog / CommandArgumentValidation 校验类型、操作和规范日期。无 target、其他 active/retained/pending 草稿、依赖、合并来源或 atomicGroup；不带已有字段基线。CommandTaskCreateInput 先检查原保护/longText 守卫，再复用 parseTaskCapture 与 hasTaskNoteSeparator（调用原 findNoteRange）核对完整解析结果。拒绝 notes 任意形式（包括 unspecified、空 longText、clear）、换行、空备注分隔、派生备注、标签、提醒、优先级及解析后空标题；不改类型、不删除基线、不隐藏派生字段。

实际写入仍为 TaskMutationService.createCaptured → CaptureInput → InputTagResolver → TaskRepositoryProtocol.addTodo(CreateTodoParams) → SwiftDataTaskRepository → ModelChanges，没有第二条解析/事务链。旧 addCapturedTodo 的完整捕获能力、来源、排序及 Bool 保存语义保持；没有接标题或备注编辑。

#### B. 固定 UUID、准备与占用

CaptureInput / CreateTodoParams 增加可选 creationID，未传时仍随机创建。仓储 fetchTodos(withID:) 完整读取精确 ID 的全部行，含墓碑且不设 fetchLimit；显式 ID 在插入前存在任何行即拒绝，不恢复、覆盖或采用旧行。协议新增查询有兼容默认实现，旧仓储消费者无需提供新参数。

prepare 只读，Coordinator 的运行内登记为原 draft/item 保留一个 UUID 和不可编辑准备证据：原参数、完整解析结果、具体日期、来源 protection/stampEnabled/bundleID、environment/context/container 身份、原 lease/draft/plan/item 版本。再次预览须精确一致；变动拒绝且不静默替换 UUID/来源。准备只接受已排队单项，本阶段没有显式刷新旧准备或自动 replay API。

claimTaskCreate 沿原 Coordinator 的调用占用机制先登记原 ownership、operation、run/attempt；所有适配实例共享准备与已调用集合。封存和 beginStep 只允许承接准备后的两个正常版本推进，其他旧 UI 事件不得换 lease 续租。一个准备只进入业务调用一次，即使纯协议单独收到 safeLocalReplay，适配也不会重新创建。保证仅覆盖本阶段 MainActor 同步、串行受控写入者；没有数据库 unique 约束、多 context/跨进程唯一性或跨重启幂等账本。

#### C. 干净上下文与隔离装配

[TaskCreateCommandEnvironment](../AreaChain/Services/TaskCreateCommandEnvironment.swift) 必须显式注入内存 ModelContext（autosave=false）、非 default 的私有 NotificationCenter、实际来源采样、共享服务 Dependencies 与 fake 刷新消费者。缺省 adapter 无环境时不可执行。prepare、execute、所有注入回调之后及进入 ModelChanges 之前检查同一 context 干净；pending 修改原地保留，不 save、rollback 或新建写 context 绕过。命令拒绝已存在的嵌套事务，避免继承未知外层发布依赖；共享服务原嵌套 Creation.pending 契约仍保留。ModelChanges 原预保存政策未改变。

#### D. 提交事实与后续步骤

Creation 是本地事实来源，Run.taskCreation 保存无正文事实：固定 ID、candidateID/savedID、save/rollback/publication 调用/返回及登记/发布失败。candidateID 与 pending 不产生成功输出；未调用 save 且实际回滚返回才能按对应事实记未提交。save 已调用却未返回（包含真正 save 后抛错）保持 unknown/verificationRequired；未知不重建 UUID，不自动重试。

save 返回 → savedID → Coordinator.recordTaskCreation 将 `.todo`＋固定 UUID 登入原 Run → 原本地登记回调 → BoardEvents.changed 私有事件 → fake 提醒/日历刷新。登记或发布异常不能撤销已保存输出；搜索失效只撤销旧显示许可，完成仍归原 ownership/run。changed 没有替换为 changedLocally；没有提醒的任务也请求日历全天同步路径。

UI 事件发布（taskPublication）、提醒刷新、日历刷新各自独立于 local.committed。Refresh 的请求事实与处理结果分开；仅发请求默认 unknown，无法得到具体结果就继续待核实，不冒充送达或同步。发布部分抛错也不证明零外部请求。外部失败不调用新增；本阶段没有外部重试装配，也没有重构通知/日历引擎。

最终创建事实也将 refreshRequested / notificationRequested / calendarRequested 保存在原 Run，避免环境复用覆盖旧运行的请求证据。来源采样和身份读取异常在指令边界归为固定 sourceUnavailable / storageUnavailable，不向外传播可能带源内容的原始错误；准备、解析输入与来源的 description/debugDescription 均脱敏。

verifyUnknown 仅使用原调用证据和固定 ID，在同一隔离容器新建只读 context 检查 absent/singleLive/tombstone/ambiguous/unreadable；任一存在性结果都不提升为历史提交成功，不按相同标题/日期认领任务。原未知回执、UUID 与 Run 保持。

#### E. 输出、兼容和验证交接

CommandExecutionRun.creationOutput(for:) 与 resolveInputs 共用现有 CommandCreationReference，严格核对原 producer item stamp、`.todo` 类型及生产者 succeeded。真实输出已保存但外部仍 unknown 时不解锁依赖；只有 fake 消费者实际处理并明确返回成功的隔离用例验证后续引用解析，不执行消费者命令。

新增 TaskCreateCommandTests / BoundaryTests / IdentityTests / FailureTests，全部复用 TaskCaptureFixture 的七模型内存容器、私有事件及显式 fake，断言实际库数量、保存和副作用次数；旧 UI 对照覆盖相同输入的标题、日期、notes、提醒、优先级、来源、排序、标签及默认状态。TaskCreateFailureRepository 只在真实 addTodo 内存变更后抛错以检验共同回滚，其他业务入口拒绝。

后续其余参数须落实已确认 D1/D3 的独立字段解析、冲突/标签普通资格和预览；notes/长正文继续受 C2B 与受控执行借用前置约束。单命令原生 UI 需独立装配同修订原生输入同步、IME/撤销/焦点、来源预览、旧事件拒绝及完整回执展示；生产接线需另核实真实写入者、数据和系统副作用授权。完成本阶段后停止，不进入上述后续工作。

#### F. 最终修改清单与实际验收（2026-10-05）

本轮 19 个 Swift 文件如下；既有文件只做本节所述窄增量，保留已暂存/未暂存的 3T-1A 和其他并行修改。

| 范围 | 文件与核心接口 |
|---|---|
| 新隔离适配 | [TaskCreateCommandAdapter.swift](../AreaChain/Services/TaskCreateCommandAdapter.swift)：prepare / submit / execute / verifyUnknown；[TaskCreateCommandEnvironment.swift](../AreaChain/Services/TaskCreateCommandEnvironment.swift)：显式内存/事件/来源/fake 装配。 |
| 新领域契约 | [CommandTaskCreateContract.swift](../AreaChain/Domain/CommandTaskCreateContract.swift)：Input / Preparation / Facts / Registry；[CommandTaskCreateExecution.swift](../AreaChain/Domain/CommandTaskCreateExecution.swift)：单项资格与 claimTaskCreate。 |
| 原执行协议 | [CommandHandoffCoordinator.swift](../AreaChain/Domain/CommandHandoffCoordinator.swift)：复用 claimRuntimeInvocation / validateRuntimeInvocation，任务登记/完成；[CommandExecutionRun.swift](../AreaChain/Domain/CommandExecutionRun.swift)：recordTaskCreation / creationOutput；[CommandExecutionContract.swift](../AreaChain/Domain/CommandExecutionContract.swift)：taskCreation / taskPublication；[CommandHostSession.swift](../AreaChain/Domain/CommandHostSession.swift)：窄事实转交。 |
| 原业务链 | [NaturalLanguageParser.swift](../AreaChain/Domain/NaturalLanguageParser.swift)：hasTaskNoteSeparator；[TaskRepositoryProtocol.swift](../AreaChain/Domain/Protocols/TaskRepositoryProtocol.swift)：CreateTodoParams.creationID / fetchTodos(withID:)；[SwiftDataTaskRepository.swift](../AreaChain/Services/Repositories/SwiftDataTaskRepository.swift)：完整身份检查；[TaskMutationService.swift](../AreaChain/Services/TaskMutationService.swift)：CaptureInput.creationID / validateBeforeTransaction；[ModelChanges.swift](../AreaChain/Services/ModelChanges.swift)：只读 hasActiveTransaction。 |
| 新隔离测试 | [TaskCreateCommandTests.swift](../AreaChainTests/Services/TaskCreateCommandTests.swift)、[TaskCreateCommandBoundaryTests.swift](../AreaChainTests/Services/TaskCreateCommandBoundaryTests.swift)、[TaskCreateCommandIdentityTests.swift](../AreaChainTests/Services/TaskCreateCommandIdentityTests.swift)、[TaskCreateCommandFailureTests.swift](../AreaChainTests/Services/TaskCreateCommandFailureTests.swift)、[TaskCreateCommandTestSupport.swift](../AreaChainTests/Services/TaskCreateCommandTestSupport.swift)、[TaskCreateFailureRepository.swift](../AreaChainTests/Services/TaskCreateFailureRepository.swift)。 |

另同步本文、架构、组件目录、技能路由和工程索引；check_workflow.py 增加 adapter / claim 两个稳定入口守卫，其测试新增缺失入口反例。没有修改生产搜索、保护载荷/C2B 或旧 UI 捕获实现。

最终完整正常 PrivacyQA 产物为 `build/TaskCreate-3T1B-1791205036922737000.xcresult`：**109 个方法／169 次执行通过，0 失败、0 跳过**。Xcode 26.6（17F113）、macOS 26.6.2 arm64；原 build/.build.lock 非等待取得，独立 com.areachain.privacy-qa 标识与 build/PrivacyQA，六项真实钥匙串授权清除，串行测试，不排除源码。新增四套 TaskCreateCommand 测试、3T-1A 两套、SwiftDataTaskRepository、Execution/Plan/Handoff/旧单项设置身份与边界回归通过；结果树同时含四个 ModelChanges 和 failedCombinedSaveRollsBackNewAndRestoredTagsWithTheirContents 共五个精确方法。

验证过程保留的修正：首次编译修正两处断言遗漏 try；重复参数原本在 reducer.validSeed 已拒绝，测试改为核验此真实早期拒绝；静态反例夹具改为复用同一个临时项目。一次失败运行同时因磁盘空间不足损坏 xcresult 归档，保留测试文本，仅清除本次失败生成的整机 logarchive 副本；后续使用 `-collect-test-diagnostics never` 避免额外整机诊断，未改变测试目标/断言。五个方法最初的无括号选择器未执行，改成完整 `method()` 后独立 5／5 通过，且最终 109／169 已再次包含它们。最终补充请求事实的 Run 归属及异常脱敏后重跑全部本轮定向，不把此前 103／163 作为最终源码证据。

本轮源码指纹记录在 `build/TaskCreate-3T1B-source.json`，测试后 19 文件逐一相同。指定 Cursor verifier 无可调用入口，未重查认证、未用其他代理冒充。C2B、人工及历史缺口不变；不提交、推送、安装、发布、不操作真实用户库/系统服务、不进入下一阶段。

**首次交付状态（历史）：partial。** 实现与最终 109／169 隔离定向测试已通过；当时最后一次 `./scripts/build.sh --no-wait` 申请原锁返回 **3（锁忙）**，未启动最终正常配置构建，日志 `build/TaskCreate-3T1B-debug-build.log`。立即停止构建/测试申请，不排队、不轮询、不抢锁。此前一次正常 Debug 构建和 staticSignatureVerified=true / hardenedRuntime=true 已通过，distributionReady=false；但它早于请求事实入 Run 与异常脱敏的最终补充，不能覆盖最终版本。最终 PrivacyQA 完整编译/临时签名也不能替代正常 Debug 构建/静态验签。当时该项与指定 Cursor 复核仍为缺口；本地最终收口见下文 H，原生执行 UI 和真实系统验收不在本阶段范围。

静态收尾：19 个相关 Swift 文件的严格 SwiftLint、check_workflow.py、quality_gate.py --profile static --format json、暂存及未暂存 diff --check 通过；工作流定向 104 项及完整 scripts/tests 224 项通过。最后文档收口后重跑受影响静态门禁，源码指纹再次一致。静态扫描无高风险秘密或敏感日志候选，不将它解释为指定独立复核或真实系统验收。生产入口仍未装配，工作停止于本阶段。

#### G. 最后收口续轮：源码未变，构建锁仍忙（2026-10-05）

本续轮核对 `build/TaskCreate-3T1B-source.json`：19 个受验 Swift 文件的 SHA-256 全部一致，构建申请返回后再次核对仍一致。按文件修改时间核对已有测试完成后的变化，Swift 新变化仅为四个并行 SearchMultiline 诊断测试文件；本阶段生产执行链、受验源码及构建/签名脚本未发现影响已有证据的新变化。本轮未修改代码，保留所有并行改动。

只读核对最终 xcresult 仍为 **109 方法／169 次执行通过，0 失败、0 跳过**；按本次要求不重跑这些测试。正常运行 `./scripts/build.sh --no-wait`，原 `build/.build.lock` 的非等待申请返回 **3（锁忙）**，未启动 xcodebuild，也未执行候选产物静态验签；日志仍为 `build/TaskCreate-3T1B-debug-build.log`。立即停止，不轮询、不再次申请、不抢锁或干预持有任务。

**本阶段本地验收仍为 partial：最终源码的隔离定向测试已通过，正常配置 Debug 构建及静态验签尚未完成。** 不借此前补充前的构建或最终 PrivacyQA 临时签名填补该缺口。指定 Cursor verifier、人工、C2B 及历史缺口独立保留，未重新检查登录、未替代复核。本轮只更新同一 §9.65，并做文档引用/差异校验；不提交、推送、安装、不访问真实用户库、不启用生产搜索、不扩展参数或原生 UI，不进入下一阶段。

再次续验（2026-10-05）：收到用户再次继续授权后，19 个受验源码指纹仍全部一致；测试完成后的 Swift 新变化仍只在并行 SearchMultiline 测试范围，未重跑 109 方法／169 次执行。正常执行 `./scripts/build.sh --no-wait` 再次返回 **3（锁忙）**，未启动构建或产物静态验签；立即停止，不轮询、不抢锁、不干预其他任务。本地验收保持 partial，指定 Cursor、人工、C2B 与历史缺口不变。仅补充本记录并校验文档，未修改业务代码或进入下一阶段。

#### H. 本地最终验收收口（2026-10-05）

**当前状态：3T-1B 本阶段要求的本地验收已完成；指定 Cursor verifier、人工、C2B 及历史缺口仍独立保留，不能称全部验收项均已通过。** F、G 的锁忙及 partial 保留为当时的历史记录，本节补齐最终正常 Debug 构建与静态验签证据，不抹去此前失败。

本次构建前后核对 `build/TaskCreate-3T1B-source.json`，19 个受验 Swift 文件的 SHA-256 均与最终测试版本一致；没有修改代码，也未发现影响本阶段测试证据的新生产源码变化。并行 SearchMultiline 测试文件继续保留。沿用 `build/TaskCreate-3T1B-1791205036922737000.xcresult` 的 **109 方法／169 次执行通过，0 失败、0 跳过**，按用户要求未重跑已通过测试。

正常执行 `./scripts/build.sh --no-wait`，本次成功取得原 `build/.build.lock`，构建及脚本自带静态验签退出 **0**。使用项目当前正常 development 配置，未覆盖签名参数、未启用 provisioning、未修改个人配置。产物为 `build/development-DerivedData/Build/Products/Debug/AreaChain.app`；验签结果 `configuration=Debug`、`staticSignatureVerified=true`、`hardenedRuntime=true`，`distributionReady=false` 保持。日志 `build/TaskCreate-3T1B-debug-build.log` 现保存本次成功输出；多匹配 macOS destination 提示不影响通过。静态验签不证明真实系统解锁、公证或发行。

本次只更新同一 §9.65 并进行文档引用/差异校验，保留并行修改及暂存状态。未重新检查 Cursor 登录、未替代指定复核；未提交、推送、安装或启动产物，未访问真实用户库、未启用生产搜索，未扩展参数或原生 UI。工作停止于 3T-1B，不进入下一阶段。


### 9.66 阶段 3T-4A：最小 todo.create 原生提交与隔离验收

2026-10-05（Asia/Shanghai）。承接 §9.65 的最小适配，在原 OperationPreview、普通 ParameterField、PlanList 与 SettingSubmission 组合内增加任务提交反馈，不新增命令面板。**当前状态：partial。** 已实现接线并取得部分真实隔离创建证据；最终复验锁忙，完整输入到创建链、旧 UI 回归及最终正常 Debug 构建/验签尚未完成。

#### 显式装配与最小参数

UnifiedSearchController 的 `taskCreate:` 必须由宿主显式注入 TaskCreateCommandAdapter；默认 nil，生产未装配，其他命令不会因它存在而可执行。普通 title/day 沿 OperationEditing、目录补全、原生字段与日期控件写入原草稿；页面展示的日期不是已接受参数，不默认写 today。todo.create 不安装偏好或合成基线，也不显示“原值尚未读取”。参数资格完全复用 CommandTaskCreateInput 和 Coordinator.taskCreatePlan：仅普通纯标题、规范明确日期、空目标/基线及单操作，notes 任意形式、换行、备注分隔、派生标签/提醒/优先级、保护/未知内容、依赖及多项均拒绝，未支持内容原地保留。

#### 准备、提交与所有权

单独“准备任务”只对已显式入列且结束编辑的唯一项调用 prepare；不在重绘时调用、不替换预留 UUID。活动草稿点击“创建任务”或 ⌘Return 先发送原 enqueue 原子移交，再 submit；已有唯一合法计划直接提交。活动加计划、retained、pending、参数/计划未结束编辑或已有运行均阻止。原 buffer/lease/plan 版本和同步 busy 守卫防止旧事件、重复点击、原生回声重放。Return 只补全/确认参数；共同入口额外检查当前原生 marked text。

预览显示拟创建标题、明确日期、尚未创建及资格问题。来源未准备时明确说明提交前采样；准备后显示原准备的来源标记开关与 bundleID 适用信息，不把 creationID 当作已存在记录。参数/计划变化使旧准备展示失效，适配器仍保留原预留 ID 并拒绝隐式刷新；来源变化沿原适配器拒绝。本阶段无刷新旧准备接口。

TaskCreateCommandAdapter.submit / execute 接受可选 displaySession，在准备前后及所有业务注入回调后的事务前复核 ReadSession。失焦、锁定、关闭或所有权变化阻止旧提交；本地保存后的显示撤销不会撤销事实或把回执转给新运行。查询保持在原 HostSession 中。

#### 回执、未知与失败保留

反馈只从原 Run 的 CommandTaskCreateFacts 派生。saved 使用 savedID 显示“任务已创建”；pending 表示仍未确认，notSubmitted 表示未提交，unknown 明确禁止再次创建。发布、登记回调和提醒/日历步骤与本地保存分别显示；刷新请求不代表送达或同步，fake 次数不生成“已同步”文案。只有原 unit.succeeded 且确实 saved 才提供原 releaseExecution 的完成按钮；其余保留原运行。

“核验当前记录”只调用 verifyUnknown，反馈 absent / singleLive / tombstone / ambiguous / unreadable；任何存在性结果不提升历史提交，不允许再次创建，不按相同标题认领。本阶段没有安全返回计划、创建重试或外部重试接口，界面明确说明限制，失败内容保留于原草稿/计划/运行，不复制新草稿。脏 context 原地拒绝，不 save、rollback 或更换 context。无打开结果动作或生产导航。

#### 有限验收与当前证据

本轮只覆盖用户指定的 13 项，分为真实点击/快捷键创建、参数与所有权拒绝、失败/未知/外部结果、生命周期/重复事件、双语尺寸截图与旧设置/计划回归。所有创建来自七模型内存容器、autosave=false、私有 NotificationCenter 及 fake 系统消费者，断言真实模型数量和 save/publication 次数，不用手工成功 Facts。

本轮实际证据均在忽略目录 `build/TaskCreateUIQA/`，完整正常 PrivacyQA、`com.areachain.privacy-qa`、`build/PrivacyQA`、原 `build/.build.lock`、六项真实钥匙串授权清除、串行测试，未排除任何源码。环境 Xcode 26.6 / macOS 26.6.2 arm64。未运行真实用户库或真实通知/日历。

| 验证 | 实际结果与限制 |
|---|---|
| 首轮 | `Initial-1791209958258455000.xcresult`：40 方法，37 通过 / 3 失败；参数化 67 通过 / 8 失败。失败为测试命令路径错误、恢复显示缺少 resumeDisplay、反馈容器辅助标识覆盖子按钮，均保留原日志。 |
| 编译中断 | `Recheck-1791210269778500000.xcresult`：并行 DaybookTextField 已引用新 DaybookTextEditing，但当次编译输入尚未纳入新文件，编译失败、测试未运行。未回退或排除并行修改。 |
| 已运行的最新完整 QA | `Native-1791210372618107000.xcresult`：**44 方法，42 通过 / 2 失败 / 0 跳过**；参数化 **80 通过 / 3 失败**。原 TaskCreateCommand 四套服务、UI 控制器契约/生命周期、marked text、展示矩阵及原生失败反馈通过。完整补全→标题→日期→计划→创建两条测试在日期网格未滚入可见区时失败；失焦/锁定场景直接 resignKey 后恢复 key window 失败。 |
| 真实原生创建 | `nativeFailureFeedbackUsesRealAdapter` 五种场景全部通过：真实按钮→原 enqueue→适配器→内存保存；保存后发布失败和 fake 日历失败各实际创建 1 条、save=1，ui 分别为 0/1；保存后抛错的 unknown 实际库为 1、save=1、ui=0，原生核验按钮返回 singleLive 且保留 unknown。脏 context、保存前仓储失败都未保存创建，内容保留。标题/日期由测试经原 Controller 参数入口预填，**不冒充完整原生输入链通过**。 |
| 防重与恢复 | 已运行测试验证单草稿自动移交、唯一计划、空基线、原 draft/run 身份、重复提交、旧准备/lease、来源变化拒绝、脏 context、保存前失败、unknown absent/singleLive/tombstone/ambiguous、本地成功后的发布/外部失败、写前/写后撤显示。unreadable 只验证文案映射，未制造真实读取失败；pending 只由实际 Facts 状态映射，未制造适配器不支持的嵌套事务。 |
| 截图 | `screenshots/` 有 **13 张本轮原生宿主缓存图**：8 张 en/zh-Hans × 浅深 × 标准444pt/紧凑304pt，5 张真实失败/未知/部分成功反馈。已检查全部联系表，放大检查最窄英文深色及本地保存后外部失败原图；长内容在固定面板滚动。不是系统窗口合成器截图，不证明系统输入法候选窗或真人朗读。 |
| 最后修正与锁忙 | 日期测试增加滚动到网格，焦点测试改用第二个隔离窗口；OperationPreview/PlanList 的任务分支修正旧“不可执行”提示，ResultsTestSupport 只调整换行。准备最终复验时原锁非等待申请返回 **3（锁忙）**，未启动 xcodebuild，未生成 Delivery.xcresult。立即停止后续锁申请。**上述最后 Swift 修改未编译/复验，不标通过；13 张图片早于最后提示修正。** |
| 旧设置/参数/计划回归 | 已列出定向回归范围，但因最后锁忙未运行。本轮不能引用旧阶段结果代替单项/多项设置与普通参数/计划原生回归。 |
| 正常 Debug / 静态验签 | 本轮未完成；最终锁忙后没有再申请 `build.sh`，不拿 PrivacyQA 临时签名或 3T-1B 历史正常构建代替。 |
| 静态 | 最终相关 Swift 严格 SwiftLint、工作流/引用检查、静态 strict 质量门禁及暂存/未暂存 diff 检查通过。检查器定向 104 项、质量门禁内脚本回归通过；static 配合上述显式隔离定向，不声称 auto/swift 全量 profile 通过。 |

指定 Cursor verifier 无可调用工具，未检查登录或冒充复核；C2B、系统输入法候选窗、VoiceOver 真人、最低系统及历史缺口独立保留。marked text 证据是实际 NSTextInputClient 协议及原生事件，不能等同系统中文候选窗。主线程自查与自动测试不替代指定复核。

#### 修改文件与下一次有限复验入口

新增 [UnifiedSearchTaskCreateEditing.swift](../AreaChain/Features/Search/UnifiedSearchTaskCreateEditing.swift)、[UnifiedSearchTaskCreateSubmission.swift](../AreaChain/Features/Search/UnifiedSearchTaskCreateSubmission.swift)；增量修改 [Controller](../AreaChain/Features/Search/UnifiedSearchController.swift)、[OperationEditing](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift)、[OperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift)、[ParameterField](../AreaChain/Features/Search/UnifiedSearchParameterField.swift)、[PlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift)、[SettingEditing](../AreaChain/Features/Search/UnifiedSearchSettingEditing.swift)、[SettingSubmission](../AreaChain/Features/Search/UnifiedSearchSettingSubmission.swift)、[TaskCreateCommandAdapter](../AreaChain/Services/TaskCreateCommandAdapter.swift) 与 [双语资源](../AreaChain/Resources/Localizable.xcstrings)。没有直接 UI 仓储调用、context.insert 或生产装配。

测试新增 [TaskCreateTestSupport](../AreaChainTests/Features/UnifiedSearchTaskCreateTestSupport.swift)、[ContractTests](../AreaChainTests/Features/UnifiedSearchTaskCreateContractTests.swift)、[LifecycleTests](../AreaChainTests/Features/UnifiedSearchTaskCreateLifecycleTests.swift)、[InteractionTests](../AreaChainTests/Features/UnifiedSearchTaskCreateInteractionTests.swift)、[RecoveryTests](../AreaChainTests/Features/UnifiedSearchTaskCreateRecoveryTests.swift)，并给原 [ResultsTestSupport](../AreaChainTests/Features/UnifiedSearchResultsTestSupport.swift) 增加可选隔离环境注入。同步本文、架构、组件目录、技能路由及 check_workflow.py 的两个稳定入口/反例，保留全部并行修改及原暂存状态。

后续本阶段续验应先编译最终完整源码，重跑两项失败测试及受最后 UI 提示影响的截图，再补旧单项/多项设置、普通参数/计划定向回归和正常 Debug 构建/静态验签；只在新的允许续验上下文中重新申请原锁。本轮不继续申请，不进入下一阶段。

其余普通参数接入仍需 D1/D3 的独立解析、冲突/标签普通资格、完整预览和事务事实验证；notes/长正文仍受 C2B 前置。生产需另行核实写入者、真实数据和系统副作用授权。本阶段不启用生产搜索、不访问用户库、不执行真实通知/日历、不提交推送安装，完成后停止。

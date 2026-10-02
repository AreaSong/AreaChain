# 统一搜索与指令体系

## 0. 状态、权威范围与基线

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
| 2 后续（未实施） | 标签、显式剪贴板/回收站提供者；执行记录尚无独立结果提供者 | 片段、聚合去重、统一排序/分页、全局覆盖汇总，以及真实数据/隐私/拥有者适配仍须独立实施验证；不能把已支持类型当作全部 tasks/global 已完整求值。 |
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
- Match.usage 只保存完整且合法的 TagUsageRecord。类型 coverage、每项 usageState、undeterminedObjects、ordering 与诊断 affectsDetermination 分开；isCompleteForCoveredTypes 只证明本次注入对象的查询/视图求值完整，不证明标签枚举完整、真实仓储读取或全局覆盖。普通名称查询可在统计未知时完整确定匹配，并保留统计警告；即使无候选，使用视图在 usage=nil 时仍有请求级能力提示。

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

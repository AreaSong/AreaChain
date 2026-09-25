# AreaChain 技能路由与交付闭环

这是 AreaChain 的项目级路由契约。它把仓库规则、项目技能、共享组件、实现和验收串成一条冷启动也能执行的流程；它不改变全局技能的启用策略，也不授予安装、签名、真实数据或远端写入权限。

## 来源优先级

发生冲突时按以下顺序核对，不能把旧提示词或模型记忆当成项目事实：

1. 用户本次明确的目标、范围和授权。
2. 仓库 [AGENTS.md](AGENTS.md) 的硬性边界。
3. 产品、使用、架构和工程文档中的已核实事实。
4. 当前代码、测试和脚本的实际行为。
5. 适用技能提供的方法和质量判据。

文档、代码和测试不一致时，先记录当前行为与目标行为，再决定是否需要改变；不能静默选择对实现最方便的一方。

## 冷启动必经流程

任何新对话、续作任务或子任务都按下面顺序开始。小任务可以合并步骤，但不能跳过“状态检查”和“复用检索”。

### 1. 接收与定界

- 判断任务属于：新增功能、界面优化、领域/服务改动、重构、诊断/审阅、验证、文档/规则维护，还是技能维护。
- 明确目标、非目标、受影响入口、必须保持的行为和可能的高风险边界。
- 执行 `git status --short`、`git diff --cached --stat`、`git diff --stat`；保留已有用户修改。

### 2. 读取最小上下文

- 所有任务先读 [AGENTS.md](AGENTS.md) 和本文件。
- 产品行为读 `docs/product.md`、`docs/features.md`、`docs/usage.md`。
- 模块、状态、窗口和数据契约读 `docs/architecture.md`。
- 构建、脚本、签名、恢复或交付读 `docs/engineering.md`，必要时再读 `docs/signing.md`。
- 需要新增或修改界面时读 [组件目录](docs/component-catalog.md) 及实际调用方；不能只看组件名。

### 3. 选择技能

| 任务类型 | 主流程 | 补充能力 | 必要交接 |
|---|---|---|---|
| 新增产品能力或页面 | `areasong-development`（当前会话可用时）与 [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | 有界面时用 [areachain-ui](.agents/skills/areachain-ui/SKILL.md) | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 既有界面、输入、窗口或视觉调整 | [areachain-ui](.agents/skills/areachain-ui/SKILL.md) 与 `areasong-development` 的 UI 路径 | 按实际问题选择 UI/UX 或平台方法 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| Domain、Services、持久化、同步或公共状态 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 的架构/可靠性/工程引用 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 重构、公共组件或跨模块契约 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 架构治理 | 独立只读复核（按影响安排）及 [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 只读诊断、代码审阅或进度查询 | 相关代码/文档和验证入口 | 不因“看起来像功能”而实施修改 | 按请求报告证据，不自动修复 |
| 验证或回归 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) | 按影响选择测试、构建和原生证据 | 报告通过、失败、跳过和未运行 |
| 文档、AGENTS、路由或项目技能维护 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | 创建/更新 Skill 时使用 `skill-creator` | `check_workflow.py`、技能格式校验和差异复核 |

技能不可用时，按同一表格读取项目文档和脚本完成安全部分，并明确缺口；不能冒充技能已调用。技能本身不扩大用户授权。

### 4. 复用门禁

在新增控件、规则、状态对象、仓储入口或测试夹具前，先完成一张简短的复用/影响表：

| 需求 | 已有入口或组件 | 文件与真实消费者 | 直接复用/局部扩展/新建 | 保持的契约 |
|---|---|---|---|---|

至少检索 [docs/component-catalog.md](docs/component-catalog.md)、所属 Feature、对应 Domain/Services 和相关测试。只有一个真实消费者时默认留在所属功能；多个消费者共享同一语义且需要同步演进时，才提取到公共层。新增公共组件必须补目录、调用方回归和边界测试。

复用不等于抹平差异：任务输入、手记输入、剪贴板捕获、搜索、菜单栏和独立窗口可以共享外观，但 Return、Command-Return、Escape、失焦、隐私和保存语义必须分别核对。

### 5. 实施

- 沿 `Domain → Services → Features → Theme` 的责任方向修改；目录名不是依赖证明，需沿实际调用链核对。
- 规则、筛选、日期、搜索和事务只保留一个权威入口；页面不能复制第二套判断。
- 共享视觉使用语义令牌和现有基座；不以局部需求重建设计系统。
- 保存成功、通知排程、外部同步和界面反馈分别判断；失败不清除唯一草稿或虚报成功。
- 触及真实钥匙串、系统日历、签名、迁移、删除或外部发布时，先按 `AGENTS.md` 的高风险门禁停下确认。

### 6. 验证与交接

完成相关编辑后：

1. 运行本次影响对应的静态检查、定向测试、脚本测试或构建；不要用旧结果代替新证据。
2. UI 变更分别检查行为、焦点/键盘、双语、浅深色、最小窗口和原生宿主；网页截图不能证明 macOS 原生验收。
3. 共享组件或公共契约变化扩大到所有真实消费者，并按影响安排独立只读复核。
4. 最终报告区分：已实现、已验证、已安装、已发布、跳过、未运行和残余风险。
5. 更新权威文档和组件目录；不生成重复的计划性规范。

## 完成状态

项目任务只能使用以下状态词：

- **已实现**：代码或文档已修改。
- **已验证**：对应检查已实际运行并通过。
- **部分完成**：有明确缺口，但仍有安全可交付内容。
- **阻塞**：缺少必要授权、环境或失败证据，无法继续宣称完成。
- **已安装/已发布**：只有执行并验证了对应外部动作后才能使用。

“代码存在”“构建成功”“测试目标存在”都不能单独替代运行行为或原生界面证据。

## 路由维护

- 新增项目技能时，同时更新本文件、`AGENTS.md`、`.gitignore`、`scripts/check_workflow.py` 的技能清单和对应测试。
- 新增共享控件或公共规则时，同时更新 [组件目录](docs/component-catalog.md)、实际调用方测试和必要架构说明。
- 修改验证入口时，保持脚本、技能、README 和工程手册使用同一命令来源；不维护两套互相漂移的门禁。
- 任何路由文件、技能引用或组件目录变更，都要运行 `python3 -B scripts/check_workflow.py`；修改检查器本身还要运行其定向测试。

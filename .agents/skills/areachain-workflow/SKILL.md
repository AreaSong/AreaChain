---
name: areachain-workflow
description: "用于 AreaChain 仓库的任务定界、上下文加载、组件与规则复用、技能协作、变更交接和验证闭环；适用于新增功能、重构、跨模块改动以及项目规则/文档/技能维护；不用于纯进度查询、单独部署或只读解释。"
---

# AreaChain 工作流编排

本技能是 AreaChain 的项目级总协调入口。它不替代界面实现技能或验收技能，也不扩大安装、签名、真实数据、系统权限或远端写入授权。

## 必读来源

开始任何修改前完整阅读：

- [项目规则](../../../AGENTS.md)
- [技能路由](../../../skill-routing.md)
- [架构与目录](../../../docs/architecture.md)
- [质量门禁](../../../docs/quality-gates.md)
- [共享组件与复用目录](../../../docs/component-catalog.md)（涉及界面、公共规则或复用时）

再按任务选择产品、使用、工程或签名文档；不要为了“完整”把无关源码和文案库全部载入上下文。

## 工作方式

用户无需调用本技能或提供额外工作流提示词。收到 AreaChain 的自然语言任务后，先按下列步骤自行加载上下文；用户只需描述想查看、调整或新增的目标。

1. 识别任务类型、目标、非目标、影响范围和高风险边界。
2. 执行 `git status --short`、`git diff --cached --stat`、`git diff --stat`，保留既有修改。
3. 沿路由表选择技能：有界面时交给 [areachain-ui](../areachain-ui/SKILL.md)，需要验证时交给 [areachain-verify](../areachain-verify/SKILL.md)；当前会话可用时，新功能再由 `areasong-development` 协调通用标准。生命周期质量项以 [质量门禁](../../../docs/quality-gates.md) 为单一入口。
4. 修改前输出简短的影响/复用表：已有入口、实际消费者、保持的契约、直接复用或新建的理由。
5. 沿 `Domain → Services → Features → Theme` 的责任方向实施，复用已有解析、筛选、日期、仓储、事务和窗口入口。
6. 修改后先运行 `python3 -B scripts/quality_gate.py`，再按影响补定向测试、构建、原生隔离和真实系统证据；区分静态、单测、构建、原生隔离和真实系统证据。
7. 交接时列出变更、复用项、实际命令、失败/跳过/未运行项和残余风险；不把计划或旧结果写成通过。日常任务不读取、不写入 `.cursor/plans/`。

## 复用硬门槛

- 新控件先查 [组件目录](../../../docs/component-catalog.md) 和真实调用方；不得仅凭名称猜测契约。
- 新业务规则先查 Domain、Services 和现有测试；不得在页面复制第二套筛选、日期、搜索或保存逻辑。
- 一个消费者默认留在所属 Feature；多个消费者共享同一语义且需同步演进时才提取公共组件。
- 新共享组件必须补目录条目、调用方回归和可观察边界测试。
- 任务、手记、剪贴板捕获、搜索和菜单栏可以共享视觉基座，但提交、快捷键、隐私和草稿语义必须分别验证。

## 验证与规则维护

- 规则、路由、技能或组件目录发生变化时运行 `python3 -B scripts/check_workflow.py`；修改检查器时再运行 `scripts/tests` 中的 `test_check_workflow.py` 和完整脚本回归。该检查器也拦住 `AreaChain` 与 `AreaChainTests` 里超过 500 行的 Swift 文件。
- 新增或修改 Skill 时运行 `python3 -B scripts/check_workflow.py`（含 `skill-format`），检查 `agents/openai.yaml`、引用文件和 Git 作用域；不依赖本机 `skill-creator`。不新建发行、诊断或 Domain 技能来填补空缺。
- Swift 或 UI 改动按 [areachain-verify](../areachain-verify/SKILL.md) 选择定向测试和构建；本技能不把编译成功当作原生交互通过。
- 共享契约、持久化语义、复杂状态或跨模块行为变化，只交给 Cursor `verifier` 做只读复核；测试与隔离原生仍交给 [areachain-verify](../areachain-verify/SKILL.md)。

## 适用边界

纯进度查询、只读代码审阅、单独部署或真实系统操作不因发现本技能而自动进入实施流程。技能不可用时，直接按 [技能路由](../../../skill-routing.md) 和项目规则完成允许的部分，并报告缺口。

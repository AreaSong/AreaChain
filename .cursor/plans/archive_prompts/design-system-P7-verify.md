# 任务：AreaChain 设计系统收敛 · 阶段 P7 禁令、文档、全量回归 · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P7-execute.md` 加了 `theme-tokens` 检查、补了文档，并声称完成。你不相信汇报：自己重跑命令、自己看代码，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码、测试和文档。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「检查器怎么判」和给出的函数。对照仓库里的 `check_theme_tokens`，不要只看汇报。

---

## 检查清单

### A. 检查器按给定规则实现

```bash
rg -n 'def check_theme_tokens|THEME_SHAPE|theme_line_allowed|check_theme_tokens\(root\)' scripts/check_workflow.py
rg -n 'theme-tokens 只匹配' scripts/check_workflow.py
```

`run_checks` 必须调用 `check_theme_tokens`。函数必须先用原文判断 `// control:` 和 `// token-exempt:`，再在 `swift_code()` 的结果上匹配。如果先屏蔽注释再找豁免词，豁免永远不会生效 → FAIL。

`WorkspaceHeaderSearchCapsule` 不能被当成 `Capsule`。形状正则必须有「前面不是字母」的限制。没有 → FAIL。

`Divider().opacity(0.35)` 这种没有 `DaybookPalette` 或 `Color.` 的行，不能被透明度规则命中。检查器如果对所有 `.opacity(数字)` 都报 → FAIL。

同一行有 `DaybookRadius` 的 `RoundedRectangle` 不能报。检查器如果见形状就报 → FAIL。

白名单必须正好是这三个路径：

```text
AreaChain/Features/Workspace/MainSplitWorkspaceView.swift
AreaChain/Features/Workspace/WorkspaceSidebarView.swift
AreaChain/Features/Workspace/WorkspaceHeaderBar.swift
```

### B. 当前仓库和单测都通过

```bash
python3 -B scripts/check_workflow.py
echo "WORKFLOW=$?"
python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v
echo "UNIT=$?"
python3 -B -m unittest discover -s scripts/tests -v
echo "SCRIPTS=$?"
```

三个退出码都是 0 → PASS。`test_default_checks_pass_in_isolated_repository` 的检查名里必须有 `theme-tokens`。单测输出里要能看到步骤 3 的四个新测试名字。少一个 → FAIL。

### C. 点名的豁免还在，而且没有改形状代码

```bash
rg -n 'token-exempt: (习惯完成点|筛选状态圆点|头部状态圆点|筛选色点|搜索种类胶囊|进度环|子任务圆|星期圆点|计数胶囊|加标签胶囊|筛选胶囊)' \
  AreaChain/Features
```

预期至少 18 行。少了就对照执行稿的 18 处，缺哪一行写进整改清单。

这 18 行除了行尾注释，形状调用必须还在。`Circle()` 被改成 `DaybookChip` 或删掉 → FAIL。

### D. 文档改了该改的，没改不该改的

```bash
rg -n 'DaybookInputShell|theme-tokens|不证明视觉一致' docs/architecture.md docs/engineering.md
rg -n 'DaybookPalette.swift' AGENTS.md
git diff --stat -- AGENTS.md AreaChain/Domain/SyntaxAutocomplete.swift
```

`docs/architecture.md` 的 Theme 段要提到令牌层和基座层，以及菜单栏基准。`docs/engineering.md` 要提到 `theme-tokens`。

`AGENTS.md` 有 diff → FAIL，除非 diff 只是空白。`SyntaxAutocomplete.swift` 有 diff → FAIL。

### E. 全量应用测试

```bash
./scripts/build.sh test
echo "TEST=$?"
```

`TEST=0` → PASS。非 0 → FAIL，贴最后 80 行。运行期间不要操作其他窗口。

如果唯一失败是 `priorityAndTimeCandidatesStillMatchSpokenWords`，单独写成「双语阶段遗留」，不要因此说检查器没做成。其他失败仍算不通过。

### F. 计划状态

```bash
rg -n '\[x\] P7 禁令、文档、全量回归' .cursor/plans/design-system.md
rg -n 'P7 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P7 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A 检查器规则 | ... | ... |
| B 仓库检查与脚本测试 | ... | WORKFLOW=? UNIT=? SCRIPTS=? |
| C 18 处豁免仍在 | ... | ... |
| D 文档 | ... | ... |
| E 全量测试 | ... | TEST=? |
| F 计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D、E 任一 FAIL 或 BLOCKED → 不通过。只有 F 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P7 验收：通过 / 不通过（<原因>）`。

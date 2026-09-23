# 任务：AreaChain 设计系统收敛 · 阶段 P6 删除 DaybookTheme · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-theme-delete-execute.md` 删除了 `DaybookTheme` 并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的替换表和「绝对不要做」。
5. 文档里还可以出现这个旧名字。P7 才改文档。检查范围只包括 `AreaChain/` 和 `AreaChainTests/`。

---

## 检查清单

### A. 旧名字没了，工厂还在

```bash
# A1 源码和测试（预期零输出）
rg -n 'DaybookTheme' AreaChain AreaChainTests

# A2 旧文件已删
test ! -f AreaChain/Theme/DaybookTheme.swift && echo DELETED

# A3 工厂还在（预期各至少 1）
rg -c 'static func daybook' AreaChain/Theme/DaybookColor.swift
rg -c 'enum ContrastMath' AreaChain/Theme/DaybookColor.swift
rg -c 'func daybookScroll' AreaChain/Theme/DaybookColor.swift
rg -c 'enum Window' AreaChain/Theme/DaybookMetrics.swift
```

`DaybookColor.swift` 里不能再有 `enum DaybookTheme`。有 → FAIL。

### B. 替换方向对

```bash
rg -c 'DaybookPalette\.text\.primary' AreaChain/Features/MenuBar/MenuBarPopoverView.swift
rg -c 'DaybookPalette\.fill\.page' AreaChain/Features/MenuBar/MenuBarPopoverView.swift
rg -c 'DaybookMetrics\.Window\.popoverWidth' AreaChain/Features/MenuBar/MenuBarPopoverView.swift
rg -c 'DaybookMetrics\.Window\.workspaceSize' AreaChain/Services/AppWindows.swift
rg -c 'DaybookMetrics\.Hit\.regular' AreaChain/Features/Workspace/TaskDetailHeaderSection.swift
rg -c 'DaybookPalette\.cardSurface' AreaChain/Features/Calendar/CalendarMonthGrid.swift
rg -c 'DaybookPalette\.checkmark' AreaChain/Features/Tasks/TaskRowSubtaskMiniViews.swift
rg -c 'DaybookPalette\.accent\.base' AreaChain/Theme/DaybookPalette.swift
```

每一条至少 1。菜单栏纸色、弹层宽度、工作台窗口尺寸、28pt 点击区、日历格子底、对勾色少一处 → FAIL。

窗口数字没有被改。下面这些期望必须还在测试里：

```bash
rg -n 'popoverWidth == 380|workspaceSize.width == 960|workspaceSize.height == 640' AreaChainTests/Theme/DaybookContrastTests.swift
```

预期 3 行，而且左边已经是 `DaybookMetrics.Window`，不是 `DaybookTheme`。

### C. 没删测试，也没改筛选

```bash
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
git diff --stat -- AreaChain/Domain/SyntaxAutocomplete.swift
git diff --cached --stat -- AreaChain/Domain/SyntaxAutocomplete.swift
```

有 `@Test` 被删，或 `SyntaxAutocomplete.swift` 有 diff → FAIL。

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/SyntaxHighlighterTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests
echo "EXIT=$?"
python3 -B scripts/check_workflow.py; echo "WORKFLOW=$?"
```

`EXIT=0` 且 `WORKFLOW=0` → PASS。非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

如果失败的测试名是 `priorityAndTimeCandidatesStillMatchSpokenWords`，把它单独标成「双语阶段遗留」，不要因此把删除这一份判成代码没换完。其余失败仍算不通过。

### E. 计划状态

```bash
rg -n '\[x\] P6 Theme 删 DaybookTheme' .cursor/plans/design-system.md
rg -n 'P6 删除 DaybookTheme 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 删除 DaybookTheme 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A 旧名字删除、工厂仍在 | ... | ... |
| B 颜色和窗口尺寸换到了新名字 | ... | ... |
| C 测试和筛选没被改坏 | ... | ... |
| D 编译、测试、check_workflow | ... | EXIT=? |
| E 计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 删除 DaybookTheme 验收：通过 / 不通过（<原因>）`。

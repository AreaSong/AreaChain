# R0a 执行：结果检查器 check_s0.py

你是执行工程师。按本文写出 S0 摸底结果的检查器并测好。本对话新增内容不超过 16k tokens：不读本文没点名的文件（包括 `AreaChain/` 源码），不派子代理，命令输出一律截断。项目 `AGENTS.md` 已自动加载，不要再读。不 commit、不安装，只用 Python 3 标准库。本机 `python3` 是 3.9.6，不要用 3.10 以上才有的写法（`match`、运行时求值的 `X | Y` 类型标注、`zip(strict=)` 等）。

## 要写的文件
- `.cursor/plans/excellence/tools/check_s0.py`：不超过 250 行，每个函数不超过 50 行。
- `.cursor/plans/excellence/tools/test_check_s0.py`：unittest。

别的文件一律不改；`log.md` 只追加一行。

## 命令行契约
`python3 .cursor/plans/excellence/tools/check_s0.py [--root DIR] RESULT.md [RESULT.md ...]`
- `--root` 默认是仓库根 `Path(__file__).resolve().parents[4]`。单元表固定在 `<root>/.cursor/plans/excellence/S0-units.tsv`：制表符分隔，首行表头 `unit kind path lines`，其余每行一个文件。
- 文件行数一律按 Python 逐行计数 `sum(1 for _ in fh)`，与单元表生成方式一致。
- 退出码：0 全部 OK；1 有 FAIL；2 没有 FAIL 但有 INCOMPLETE；3 用法错误（没给文件、单元表不存在）。
- 输出：每个结果文件一行；FAIL 的原因缩进列出，最多 10 条，多了写「另有 N 条」；最后一行汇总：

```text
OK S0-007 发现 3（高 0 / 中 2 / 低 1）
FAIL S0-008
  - 覆盖缺少 AreaChain/Domain/X.swift
INCOMPLETE S0-009（未完成：剩余 AreaChain/Domain/Y.swift）
TOTAL ok=1 fail=1 incomplete=1
```

## 结果文件格式
与 `S0-audit.md` 的「结果文件」一节完全相同，示例：

```markdown
---
unit: S0-007
kind: code
files_read: 1
---

## 覆盖
| 文件 | 行数 | 已读 |
|---|---|---|
| AreaChain/Domain/Example.swift | 120 | 120 |

## 发现
| ID | 位置 | 类别 | 级别 | 原文 | 说明 |
|---|---|---|---|---|---|
| S0-007-01 | AreaChain/Domain/Example.swift:42 | 单一来源 | 中 | `let formatter = DateFormatter()` | 另一处也建了同样的格式器 |

## 可复用积木
无

## 未完成
无
```

- 头部在首尾两行 `---` 之间。四个二级标题必须按顺序出现：`## 覆盖`、`## 发现`、`## 可复用积木`、`## 未完成`。
- 表格行以 `|` 开头；跳过表头行和 `|---|` 分隔行；去掉首尾 `|` 后按 `|` 切分、去空格。
- 「发现」「可复用积木」可以只写一行 `无`；「未完成」写 `无` 或任意说明。

## 必须检查的规则（任一不满足即 FAIL，原因写清是哪条、哪一行）
1. 头部：`unit`、`kind`、`files_read` 齐全；`unit` 在单元表里；`kind` 与单元表一致。
2. 覆盖：路径集合与单元表中该单元完全相同；行数等于单元表，也等于文件当前行数（不等时原因写「单元表可能过期」）；已读是 0 到行数之间的整数；`files_read` 等于「已读 = 行数」的行数。
3. 未完成为 `无` 时，每个文件都必须已读 = 行数。未完成不是 `无` 且没有其他 FAIL 时，判 INCOMPLETE。
4. 发现每行恰好 6 格：
   - ID 为 `<unit>-两位数字`，不重复；
   - 位置为 `路径:行号`，路径属于本单元，行号在 1 到文件行数之间；
   - 类别属于：职责、单一来源、模式、分层、阈值、双语、行为、注释、测试覆盖、断言、脆弱、重复准备、命名、脚本、文档；
   - 级别属于高、中、低，且整体按高、中、低排序；
   - 原文格是一对反引号包住的 4–60 个字符，里面没有反引号；把连续空白压成一个空格后，它必须是「行号 −2 到 +2」某一行（同样压空白）的子串；
   - 说明不为空。
5. 可复用积木每行恰好 3 格；位置为 `路径:行号`，路径存在，行号不超过该文件行数。

## 测试（test_check_s0.py）
在 `tempfile.TemporaryDirectory()` 里造一个假仓库：写好 `.cursor/plans/excellence/S0-units.tsv` 和两三个小源文件，用 `--root` 指过去（用 `subprocess` 调脚本或直接调函数都行）。至少覆盖以下 13 种情况，括号里是预期退出码：
- 合法结果（0）；「发现」只写「无」（0）；原文在 ±2 行内（0）；
- 覆盖缺文件（1）；行数与单元表不符（1）；原文超出 ±2 行（1）；类别非法（1）；级别未排序（1）；ID 重复（1）；位置路径不属于本单元（1）；已读不足但未完成写「无」（1）；
- 如实写未完成（2）；
- 不给参数（3）。

## 最终验证
```bash
python3 -B -m unittest discover -s .cursor/plans/excellence/tools -p 'test_check_s0.py' > /tmp/r0a-unit.log 2>&1; echo "UNIT=$?"; tail -n 4 /tmp/r0a-unit.log
python3 -B .cursor/plans/excellence/tools/probe_check_s0.py; echo "PROBE=$?"
python3 -B .cursor/plans/excellence/tools/check_s0.py; echo "NOARGS=$?"
wc -l .cursor/plans/excellence/tools/check_s0.py
git status --porcelain -- AreaChain AreaChainTests scripts docs AGENTS.md .agents
shasum -a 256 -c --quiet .cursor/plans/excellence/MANIFEST.sha256; echo "MANIFEST=$?"
```
预期：`UNIT=0`；`PROBE=0`，7 项全部 PASS（探针由架构师提供，检查器还不存在时它输出「缺少检查器」并退出 3）；`NOARGS=3`；行数不超过 250；git 那条零输出；`MANIFEST=0`。

`PROBE` 不为 0 时，先对照探针打印的用例名修检查器，不要改探针，也不要为了变绿放宽规则。

## 记录与汇报
1. 追加记录（不必先读 log.md，把问号换成实际值）：
   `printf '%s\n' "- $(date '+%F %H:%M') R0a 执行：完成（提示词：R0a-execute.md；UNIT=?、PROBE=?、NOARGS=?、MANIFEST=?）" >> .cursor/plans/excellence/log.md`
2. 回复不超过 8 行：写了哪些文件、各退出码、没做或发现的问题。不要宣布「通过」，验收按 `R0a-verify.md`。

## 绝对不要做
- 不改 `MANIFEST.sha256` 里列出的任何文件（探针、扫描脚本、单元表、模板、提示词）。
- 不为了让探针或测试通过而放宽规则。
- 不读 `AreaChain/` 下的源码，这一阶段用不到。

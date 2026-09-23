# R0b 验收：批量执行器 run.py

你是独立验收员。另一个对话按 `.cursor/plans/excellence/R0b-execute.md` 写了批量执行器并声称完成。你不相信汇报：自己跑、自己看，逐项打 PASS / FAIL / BLOCKED。**只读**：除了冒烟会自动写入再删除的两个文件，唯一允许的写操作是最后往 `log.md` 追加一行。本对话新增内容不超过 16k tokens，不派子代理；项目 `AGENTS.md` 已自动加载，不要再读。

## 0. 绑定核对
- 启动指令里的文件名必须是 `R0b-verify.md`。
- `rg -n 'R0b 执行' .cursor/plans/excellence/log.md | tail -n 3` 至少一行，且写明「提示词：R0b-execute.md」。
- `rg -c 'R0a 验收：通过' .cursor/plans/excellence/log.md` 至少为 1。

不满足 → 结论 BLOCKED，写明原因后结束。

## A. 规模与依赖
```bash
wc -l .cursor/plans/excellence/tools/run.py .cursor/plans/excellence/tools/test_run.py
python3 - <<'PY'
import ast, importlib.util, sys, sysconfig
p = ".cursor/plans/excellence/tools/run.py"
tree = ast.parse(open(p, encoding="utf-8").read())
funcs = [(n.end_lineno - n.lineno + 1, n.name) for n in ast.walk(tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
mods = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
mods |= {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module and n.level == 0}
std = sysconfig.get_paths()["stdlib"]
def stdlib(m):
    spec = importlib.util.find_spec(m)
    origin = (spec.origin or "") if spec else ""
    return m in sys.builtin_module_names or origin in ("built-in", "frozen") or (origin.startswith(std) and "site-packages" not in origin)
print("最长函数", max(funcs)); print("非标准库", sorted(m for m in mods if not stdlib(m)))
PY
```
run.py 不超过 450 行、最长函数不超过 50 行、「非标准库」为空列表 → PASS。

## B. 单测
```bash
python3 -B -m unittest discover -s .cursor/plans/excellence/tools -p 'test_run.py' -v > /tmp/r0b-v.log 2>&1; echo "UNIT=$?"; grep -c ' ok$' /tmp/r0b-v.log; tail -n 3 /tmp/r0b-v.log
```
`UNIT=0` 且通过的用例不少于 7 → PASS。

## C. 命令构造
```bash
python3 -B .cursor/plans/excellence/tools/run.py audit --ids S0-001 --dry-run > /tmp/r0b-dry.txt 2>&1; echo "DRY=$?"
for f in 'env -i' 'stream-json' '--strict-mcp-config' '--no-session-persistence' '--permission-mode dontAsk' '--effort medium' 'disableAllHooks' 'S0-audit.md' 'results/**'; do printf '%-28s %s\n' "$f" "$(grep -cF -- "$f" /tmp/r0b-dry.txt)"; done
grep -cE -- '--bare|--model|bypassPermissions|Bash\((awk|echo)' /tmp/r0b-dry.txt
python3 -B .cursor/plans/excellence/tools/run.py verify --batches V01 --dry-run 2>&1 | grep -oE 'S0-[0-9]{3}' | sort -u | tr '\n' ' '; echo
```
`DRY=0`；每个必需片段计数至少 1；禁用片段计数为 0；V01 恰好是 S0-001 到 S0-004 → PASS。

## D. status
`python3 -B .cursor/plans/excellence/tools/run.py status` 显示 106 个单元、27 个批次 → PASS。

## E. 冒烟（独立重跑一次）
```bash
python3 -B .cursor/plans/excellence/tools/run.py smoke; echo "SMOKE=$?"
tail -n 1 .cursor/plans/excellence/logs/run-log.tsv
ls .cursor/plans/excellence/results/SMOKE.md AreaChain/SMOKE-DENIED.md 2>&1 | head -n 2
```
`SMOKE=0`、日志最后一行的基线和峰值是数字、`ls` 显示两个文件都不存在 → PASS。因限流重试用尽 → BLOCKED，不算 FAIL。

## F. 没越界
```bash
git status --porcelain -- AreaChain AreaChainTests scripts docs AGENTS.md .agents
shasum -a 256 -c --quiet .cursor/plans/excellence/MANIFEST.sha256; echo "MANIFEST=$?"
```
第一条零输出、`MANIFEST=0` → PASS。

## 输出格式
```text
## R0b 验收报告
| 项 | 结果 | 证据 |
|---|---|---|
| 0 绑定 | … | … |
| A 规模与依赖 | … | 行数、最长函数 |
| B 单测 | … | UNIT=?，通过 ? 个 |
| C 命令构造 | … | 缺失或多出的片段 |
| D status | … | 单元数、批次数 |
| E 冒烟 | … | SMOKE=?，基线、新增 |
| F 没越界 | … | MANIFEST=? |

## 结论
通过 / 不通过 / 待冒烟 / BLOCKED

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：任一项 FAIL → 不通过。只有 E 是 BLOCKED、其余全部 PASS → 结论写「待冒烟」：用户稍后在普通终端运行 `python3 .cursor/plans/excellence/tools/run.py smoke`，成功后自己追加一行 `R0b 冒烟：通过`，之后才能开始 S0 试点。其他 BLOCKED → BLOCKED。

最后追加记录（把尖括号换成实际内容）：
`printf '%s\n' "- $(date '+%F %H:%M') R0b 验收：<通过|不通过|待冒烟|BLOCKED>（提示词：R0b-verify.md；<一句话原因；冒烟基线与新增>）" >> .cursor/plans/excellence/log.md`

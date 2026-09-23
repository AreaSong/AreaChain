# R0a 验收：结果检查器 check_s0.py

你是独立验收员。另一个对话按 `.cursor/plans/excellence/R0a-execute.md` 写了检查器并声称完成。你不相信汇报：自己跑、自己看，逐项打 PASS / FAIL / BLOCKED。**只读**；唯一允许的写操作是最后往 `log.md` 追加一行。本对话新增内容不超过 16k tokens，不派子代理；项目 `AGENTS.md` 已自动加载，不要再读。

## 0. 绑定核对
- 启动指令里的文件名必须是 `R0a-verify.md`。
- `rg -n 'R0a 执行' .cursor/plans/excellence/log.md | tail -n 3` 至少一行，且写明「提示词：R0a-execute.md」。

不满足 → 结论 BLOCKED，写明原因后结束。

## A. 规模与依赖
```bash
wc -l .cursor/plans/excellence/tools/check_s0.py .cursor/plans/excellence/tools/test_check_s0.py
python3 - <<'PY'
import ast, importlib.util, sys, sysconfig
p = ".cursor/plans/excellence/tools/check_s0.py"
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
check_s0.py 不超过 250 行、最长函数不超过 50 行、「非标准库」为空列表 → PASS。

## B. 单测
```bash
python3 -B -m unittest discover -s .cursor/plans/excellence/tools -p 'test_check_s0.py' -v > /tmp/r0a-v.log 2>&1; echo "UNIT=$?"; grep -c ' ok$' /tmp/r0a-v.log; tail -n 3 /tmp/r0a-v.log
```
`UNIT=0` 且通过的用例不少于 13 → PASS。

## C. 探针（架构师提供，独立于执行者的测试）
```bash
python3 -B .cursor/plans/excellence/tools/probe_check_s0.py; echo "PROBE=$?"
```
7 项全部 PASS 且 `PROBE=0` → PASS。

## D. 契约抽查
```bash
python3 -B .cursor/plans/excellence/tools/check_s0.py; echo "NOARGS=$?"
rg -n 'parents\[4\]|S0-units.tsv' .cursor/plans/excellence/tools/check_s0.py | head -n 4
for c in 职责 单一来源 模式 分层 阈值 双语 行为 注释 测试覆盖 断言 脆弱 重复准备 命名 脚本 文档; do rg -q "$c" .cursor/plans/excellence/tools/check_s0.py || echo "缺类别 $c"; done
```
`NOARGS=3`；默认根目录与单元表路径与执行稿一致；没有「缺类别」输出 → PASS。

## E. 没越界
```bash
git status --porcelain -- AreaChain AreaChainTests scripts docs AGENTS.md .agents
shasum -a 256 -c --quiet .cursor/plans/excellence/MANIFEST.sha256; echo "MANIFEST=$?"
```
第一条零输出、`MANIFEST=0` → PASS。清单里的文件被改过 → FAIL，写明是哪个。

## 输出格式
```text
## R0a 验收报告
| 项 | 结果 | 证据 |
|---|---|---|
| 0 绑定 | … | … |
| A 规模与依赖 | … | 行数、最长函数 |
| B 单测 | … | UNIT=?，通过 ? 个 |
| C 探针 | … | PROBE=? |
| D 契约 | … | NOARGS=? |
| E 没越界 | … | MANIFEST=? |

## 结论
通过 / 不通过 / BLOCKED

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：任一项 FAIL → 不通过；任一项 BLOCKED 且无 FAIL → BLOCKED。

最后追加记录（把尖括号换成实际内容）：
`printf '%s\n' "- $(date '+%F %H:%M') R0a 验收：<通过|不通过|BLOCKED>（提示词：R0a-verify.md；<一句话原因或各项退出码>）" >> .cursor/plans/excellence/log.md`

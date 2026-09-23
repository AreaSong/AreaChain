# R0b 执行：批量执行器 run.py

你是执行工程师。按本文写批量执行器：它为 S0 的每个单元、每个验收批次各开一个全新的 `claude -p` 会话，一个作业一个会话。本对话新增内容不超过 16k tokens：只读本文点名的文件，不派子代理，命令输出一律截断。项目 `AGENTS.md` 已自动加载，不要再读。不 commit、不安装，只用 Python 3 标准库。本机 `python3` 是 3.9.6，不要用 3.10 以上才有的写法（`match`、运行时求值的 `X | Y` 类型标注、`zip(strict=)` 等）。

## 前提
`rg -n 'R0a 验收：通过' .cursor/plans/excellence/log.md` 至少一行；没有就停下，告诉用户先完成 R0a。

## 要写的文件
- `.cursor/plans/excellence/tools/run.py`：不超过 450 行，每个函数不超过 50 行。
- `.cursor/plans/excellence/tools/test_run.py`：unittest，不调用真实 claude。
- `.cursor/plans/excellence/.gitignore`：一行 `logs/`。

别的文件一律不改；`log.md` 只追加。

## 路径
仓库根 = `Path(__file__).resolve().parents[4]`，可用 `--root` 覆盖。以下都在 `<根>/.cursor/plans/excellence/` 下：单元表 `S0-units.tsv`（首行表头，单元顺序 = 首次出现顺序）、结果 `results/<单元>.md`、验收 `verify/<批次>.md`、检查器 `tools/check_s0.py`、清单 `MANIFEST.sha256`、日志 `logs/run-log.tsv`、原始流 `logs/jobs/<作业>-<第几次>.jsonl`。运行前自动建好 `results`、`verify`、`logs/jobs`。

## 子命令
| 子命令 | 作业 | 跳过 | 成功条件 |
|---|---|---|---|
| `audit [--ids …] [--limit N] [--force]` | 每个单元一个；不给 `--ids` 就是全部 | 结果文件已存在（`--force` 除外） | 进程退出 0、结果文件存在、检查器退出 0 或 2 |
| `verify [--batches …] [--limit N] [--force]` | 按单元顺序每 4 个一批，`V01` 是前 4 个，编号两位 | 验收文件已存在；本批结果未齐（打印提示） | 验收文件存在，最后一个非空行以 `结论：` 开头 |
| `fix --ids …` | 每个单元一个 | 所在批次的验收文件里，该单元那一行结论不是「不通过」 | 同 audit |
| `smoke` | 1 个 | — | 见「冒烟」 |
| `status` | 不开会话 | — | 打印：单元总数、已有结果数、检查器 OK / INCOMPLETE / FAIL 数、批次总数、已验收数、通过 / 不通过 / BLOCKED 数、待整改单元（最多 20 个） |

公共选项：`--dry-run`（用 `shlex.join` 打印前 2 条完整命令和作业总数，不启动会话，也不做「已存在」「未齐」的跳过判断，只在末尾标注）、`--effort`（默认 `medium`）、`--max-retries`（默认 3）、`--backoff`（秒，默认 60；第 n 次重试前等 backoff×2^(n−1)）、`--stop-after`（连续几个作业失败就停，默认 2）、`--timeout`（每个作业的秒数，默认 1500）、`--claude-bin`（默认 `claude`）、`--checker`（默认上面的检查器，测试时可替换）。

## 会话启动指令（逐字使用，模板依赖这些措辞）
- audit：`先用 Read 工具完整读取 .cursor/plans/excellence/S0-audit.md，然后严格按它执行单元 {unit}。`
- verify：`先用 Read 工具完整读取 .cursor/plans/excellence/S0-verify.md，然后严格按它验收批次 {batch}，单元：{空格分隔的单元}。`
- fix：`先用 Read 工具完整读取 .cursor/plans/excellence/S0-audit.md，然后按其中「整改模式」整改单元 {unit}，整改清单在 .cursor/plans/excellence/verify/{batch}.md。`

## 怎么启动会话（本机是 claude 2.1.280，以 `claude --help` 为准）
工作目录为仓库根，用参数列表调用（不经 shell）：

```text
env -i HOME=… PATH=… USER=… TMPDIR=… LANG=… TERM=dumb
  <claude-bin> -p <启动指令>
  --output-format stream-json --verbose
  --tools Read,Bash,Write,Edit
  --allowedTools <规则…>
  --permission-mode dontAsk
  --strict-mcp-config --no-session-persistence
  --effort <effort>
  --settings {"disableAllHooks":true}
```

- `env -i` 必须有：桌面端会给子进程注入宿主认证变量，不清掉会报 Not logged in。HOME、PATH、USER、TMPDIR 取当前值，LANG 缺省用 `en_US.UTF-8`。
- 禁止 `--bare`（会跳过 CLAUDE.md）、`--model`（保持用户设定的模型）和 `bypassPermissions`。
- 规则：`Read`、`Bash(rg *)`、`Bash(wc *)`、`Bash(sed -n *)`、`Bash(head *)`、`Bash(tail *)`、`Bash(python3 .cursor/plans/excellence/tools/check_s0.py *)`、`Bash(python3 .cursor/plans/excellence/tools/l10n_scan.py)`，再加写权限：audit、fix、smoke 用 `Edit(.cursor/plans/excellence/results/**)` 和 `Write(.cursor/plans/excellence/results/**)`，verify 把 `results` 换成 `verify`。不要加 `awk`、`echo` 这类能重定向写文件的命令。规则语法如果与 `claude --help` 或官方文档不符，只改写法、不改语义，并在汇报里写明。
- 规则挡不住 `sed` 写文件，所以下面的 git 比对和清单校验是最后防线，不能省。

## 每个作业
1. 启动前取一次 `git status --porcelain -- AreaChain AreaChainTests scripts docs AGENTS.md .agents README.md`，结束后再取一次，并用 hashlib 校验 `MANIFEST.sha256` 里的每个文件。git 两次结果不同，或清单有文件不符：立刻中止整批，打印差异，退出码 4，不要尝试还原。
2. 原始输出逐行写进 jsonl。对 `type` 为 `assistant` 的事件取 `message.usage`，上下文 = `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`；基线是第一次的值，峰值是最大值，新增 = 峰值 − 基线。从 `type` 为 `result` 的事件取 `num_turns`、`total_cost_usd`、`is_error`。字段缺失记 `NA`，不能崩。
3. 进程退出码非 0、`is_error` 为真、超时、成功条件不满足，都算这次尝试失败，按退避重试。输出里出现 `429`、`overloaded`、`temporarily unavailable`、`rate limit` 时，备注标「限流」。重试用尽算一个失败作业。
4. 每次尝试往 `run-log.tsv` 追加一行，首次写表头：`time mode job attempt exit seconds turns baseline peak new cost status note`。控制台同时打印一行，例如 `S0-001 #1 ok 312s peak=24.1k new=11.3k`；新增超过 16000 时末尾加 `超出16k`。
5. 串行执行，不并发。整批结束打印汇总。退出码：全部成功 0，有失败作业 1，用法错误 3，git 比对或清单校验中止 4。

## 冒烟（smoke）
启动指令：`用 Write 工具把 ok 写入 .cursor/plans/excellence/results/SMOKE.md；再用 Write 工具尝试把 x 写入 AreaChain/SMOKE-DENIED.md，被拒绝就不要换别的办法；最后只回复 done。` 权限同 audit。

通过条件：`results/SMOKE.md` 内容是 `ok`；`AreaChain/SMOKE-DENIED.md` 不存在；日志里基线和峰值都是数字。结束后删掉这两个文件（只删这两个），打印基线（即固定开销）和新增。冒烟不做 git 比对，但要做清单校验。

## 测试（test_run.py）
在临时目录造假仓库：`git init`，提交一个 `AreaChain/a.swift`，写一份至少 5 个单元的小单元表和一份空的 `MANIFEST.sha256`。再造一个假 `claude` 可执行脚本放进临时 bin 目录，用 `--claude-bin` 指过去。因为有 `env -i`，假脚本不能靠环境变量拿指令：让它读工作目录下的 `fake_claude.json` 决定行为（写结果文件并输出带 usage 的 stream-json；输出 429 并退出 1；改动 `AreaChain/a.swift`）。检查器用 `--checker` 换成总是退出 0 的假脚本。至少覆盖：
1. dry-run 的命令含 `env -i`、`--strict-mcp-config`、`--no-session-persistence`、`--permission-mode dontAsk`、`--effort medium`，不含 `--bare`、`--model`；
2. 成功作业写出日志，基线和峰值解析正确；
3. 结果已存在时跳过；
4. 先 429 后成功（`--backoff 0`）；
5. 连续失败达到 `--stop-after` 就停；
6. 改动受保护文件时退出码 4；
7. verify 的 `V01` 恰好是前 4 个单元。

## 最终验证
```bash
python3 -B -m unittest discover -s .cursor/plans/excellence/tools -p 'test_run.py' > /tmp/r0b-unit.log 2>&1; echo "UNIT=$?"; tail -n 4 /tmp/r0b-unit.log
python3 -B .cursor/plans/excellence/tools/run.py audit --ids S0-001 --dry-run
python3 -B .cursor/plans/excellence/tools/run.py verify --batches V01 --dry-run | tail -n 3
python3 -B .cursor/plans/excellence/tools/run.py status
python3 -B .cursor/plans/excellence/tools/run.py smoke; echo "SMOKE=$?"
tail -n 2 .cursor/plans/excellence/logs/run-log.tsv
git status --porcelain -- AreaChain AreaChainTests scripts docs AGENTS.md .agents
shasum -a 256 -c --quiet .cursor/plans/excellence/MANIFEST.sha256; echo "MANIFEST=$?"
```
预期：`UNIT=0`；dry-run 能看到完整命令，V01 的单元是 S0-001 S0-002 S0-003 S0-004；status 显示 106 个单元、27 个批次；`SMOKE=0`；git 那条零输出；`MANIFEST=0`。

冒烟因限流重试用尽时记为 BLOCKED，照实汇报，不要改参数硬试。

## 记录与汇报
1. 追加记录（把问号换成实际值）：
   `printf '%s\n' "- $(date '+%F %H:%M') R0b 执行：完成（提示词：R0b-execute.md；UNIT=?、SMOKE=?、基线=?、新增=?）" >> .cursor/plans/excellence/log.md`
2. 回复不超过 10 行：写了哪些文件、各退出码、冒烟测到的基线和新增、与本文不一致的写法（例如权限规则语法）。不要宣布「通过」，验收按 `R0b-verify.md`。

## 绝对不要做
- 不改 `MANIFEST.sha256` 里列出的任何文件，也不改 `check_s0.py`。
- 不用 `--bare`、`--model`、`bypassPermissions`。
- 不在测试里调用真实 claude；冒烟只跑这一次（失败重试除外）。

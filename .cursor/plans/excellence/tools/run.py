#!/usr/bin/env python3
"""S0 批量执行器：每个单元、每个验收批次各开一个全新的 claude -p 会话，串行执行。

子命令：audit / verify / fix / smoke / status；--dry-run 只打印命令，不启动会话。
退出码：0 全部成功，1 有失败作业，3 用法错误，4 git 比对或清单校验中止。
"""
import argparse
import collections
import datetime
import difflib
import hashlib
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

REL = ".cursor/plans/excellence"
GUARDED = ["AreaChain", "AreaChainTests", "scripts", "docs", "AGENTS.md", ".agents", "README.md"]
BATCH_SIZE = 4
NEW_LIMIT = 16000
LOG_HEADER = "time mode job attempt exit seconds turns baseline peak new cost status note".split()
USAGE_KEYS = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
READ_RULES = [
    "Read", "Bash(rg *)", "Bash(wc *)", "Bash(sed -n *)", "Bash(head *)", "Bash(tail *)",
    "Bash(python3 .cursor/plans/excellence/tools/check_s0.py *)",
    "Bash(python3 .cursor/plans/excellence/tools/l10n_scan.py)",
]
# 启动指令逐字取自 R0b-execute.md，S0 模板依赖这些措辞，不要改写。
PROMPTS = {
    "audit": "先用 Read 工具完整读取 .cursor/plans/excellence/S0-audit.md，然后严格按它执行单元 {unit}。",
    "verify": "先用 Read 工具完整读取 .cursor/plans/excellence/S0-verify.md，然后严格按它验收批次 {batch}，单元：{units}。",
    "fix": "先用 Read 工具完整读取 .cursor/plans/excellence/S0-audit.md，然后按其中「整改模式」整改单元 {unit}，整改清单在 .cursor/plans/excellence/verify/{batch}.md。",
    "smoke": "用 Write 工具把 ok 写入 .cursor/plans/excellence/results/SMOKE.md；再用 Write 工具尝试把 x 写入 AreaChain/SMOKE-DENIED.md，被拒绝就不要换别的办法；最后只回复 done。",
}
SMOKE_FILES = (REL + "/results/SMOKE.md", "AreaChain/SMOKE-DENIED.md")
RATE_RE = re.compile(r"\b429\b|overloaded|temporarily unavailable|rate limit", re.I)
Job = collections.namedtuple("Job", "mode name prompt")
Attempt = collections.namedtuple("Attempt", "code seconds timed_out stats")


class UsageError(Exception):
    """用法错误，退出码 3。"""


class Abort(Exception):
    """git 比对或清单校验不符：中止整批，退出码 4。"""


class Ctx:
    """一次运行的选项、路径与单元表；运行前建好 results、verify、logs/jobs。"""

    def __init__(self, args):
        self.args = args
        self.root = Path(args.root).resolve()
        self.base = self.root / REL
        self.units = load_units(self.base / "S0-units.tsv")
        self.batches = collections.OrderedDict(
            ("V%02d" % (i // BATCH_SIZE + 1), self.units[i:i + BATCH_SIZE])
            for i in range(0, len(self.units), BATCH_SIZE))
        self.results, self.verify = self.base / "results", self.base / "verify"
        self.jobs_dir, self.run_log = self.base / "logs" / "jobs", self.base / "logs" / "run-log.tsv"
        self.manifest = self.base / "MANIFEST.sha256"
        self.checker = Path(args.checker).resolve() if args.checker else self.base / "tools" / "check_s0.py"
        for folder in (self.results, self.verify, self.jobs_dir):
            folder.mkdir(parents=True, exist_ok=True)

    def result(self, unit):
        return self.results / f"{unit}.md"

    def batch_of(self, unit):
        return "V%02d" % (self.units.index(unit) // BATCH_SIZE + 1)


def load_units(path):
    """首行表头，取 unit 列；单元顺序 = 首次出现顺序。"""
    if not path.is_file():
        raise UsageError(f"找不到单元表：{path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    header = lines[0].split("\t") if lines else []
    col = header.index("unit") if "unit" in header else 0
    rows = (line.split("\t") for line in lines[1:])
    return list(dict.fromkeys(r[col].strip() for r in rows if len(r) > col and r[col].strip()))


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_snapshot(ctx):
    """受保护路径的 git 状态；脏文件附内容哈希，这样已脏的文件再被改动也能发现。"""
    cmd = ["git", "--no-optional-locks", "-c", "core.quotePath=false", "status", "--porcelain",
           "--untracked-files=all", "--", *GUARDED]
    proc = subprocess.run(cmd, cwd=ctx.root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise Abort("git status 失败：" + proc.stderr.strip()[:300])
    snapshot = []
    for line in proc.stdout.splitlines():
        path = ctx.root / line[3:].split(" -> ")[-1].strip('"')
        snapshot.append(f"{line}\t{sha256(path) if path.is_file() else '-'}")
    return snapshot


def manifest_bad(ctx):
    """用 hashlib 校验 MANIFEST.sha256 里的每个文件，返回不符的条目。"""
    if not ctx.manifest.is_file():
        return ["缺少 MANIFEST.sha256"]
    bad = []
    for line in ctx.manifest.read_text(encoding="utf-8").splitlines():
        match = re.match(r"([0-9a-fA-F]{64}) [ *](.+)$", line)
        if not match:
            if line.strip():
                bad.append(f"无法解析：{line[:60]}")
            continue
        path = ctx.root / match.group(2)
        if not path.is_file() or sha256(path) != match.group(1).lower():
            bad.append(match.group(2))
    return bad


def guard(ctx, before):
    """最后防线（规则挡不住 sed 写文件）：git 快照变了或清单不符就中止整批，不尝试还原。"""
    if before is not None:
        after = git_snapshot(ctx)
        if after != before:
            diff = difflib.unified_diff(before, after, "作业前", "作业后", lineterm="", n=0)
            raise Abort("受保护路径有变动：\n" + "\n".join(list(diff)[:60]))
    bad = manifest_bad(ctx)
    if bad:
        raise Abort("清单校验不符：" + " ".join(bad[:30]))


def build_cmd(ctx, job):
    """完整命令（参数列表，不经 shell）；env -i 清掉桌面端注入的宿主认证变量。"""
    env = [f"{k}={os.environ[k]}" for k in ("HOME", "PATH", "USER", "TMPDIR") if k in os.environ]
    env += ["LANG=" + (os.environ.get("LANG") or "en_US.UTF-8"), "TERM=dumb"]
    area = "verify" if job.mode == "verify" else "results"
    rules = READ_RULES + [f"Edit(.cursor/plans/excellence/{area}/**)", f"Write(.cursor/plans/excellence/{area}/**)"]
    return (["env", "-i"] + env + [ctx.args.claude_bin, "-p", job.prompt]
            + ["--output-format", "stream-json", "--verbose", "--tools", "Read,Bash,Write,Edit"]
            + ["--allowedTools"] + rules
            + ["--permission-mode", "dontAsk", "--strict-mcp-config", "--no-session-persistence"]
            + ["--effort", ctx.args.effort, "--settings", '{"disableAllHooks":true}'])


class Stats:
    """逐行解析 stream-json：上下文 = input + cache_read + cache_creation；缺字段保持 None（记 NA）。"""

    def __init__(self):
        self.baseline = self.peak = self.turns = self.cost = self.is_error = None
        self.rate_limited = False

    @property
    def new(self):
        return None if self.baseline is None or self.peak is None else self.peak - self.baseline

    def feed(self, line):
        self.rate_limited = self.rate_limited or bool(RATE_RE.search(line))
        try:
            event = json.loads(line)
        except ValueError:
            return
        if not isinstance(event, dict):
            return
        message = event.get("message")
        if event.get("type") == "assistant" and isinstance(message, dict):
            self.add_usage(message.get("usage"))
        elif event.get("type") == "result":
            self.turns, self.cost = event.get("num_turns"), event.get("total_cost_usd")
            self.is_error = event.get("is_error")

    def add_usage(self, usage):
        if not isinstance(usage, dict) or not any(k in usage for k in USAGE_KEYS):
            return
        size = sum(v for v in (usage.get(k) for k in USAGE_KEYS) if isinstance(v, (int, float)))
        self.baseline = size if self.baseline is None else self.baseline
        self.peak = size if self.peak is None else max(self.peak, size)


def kill_group(proc, fired):
    fired.set()
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        pass


def spawn(ctx, job, attempt):
    """启动一次会话，原始输出逐行写入 jsonl；超时杀掉整个进程组（含工具子进程）。"""
    stats, fired, start = Stats(), threading.Event(), time.monotonic()
    proc = subprocess.Popen(
        build_cmd(ctx, job), cwd=ctx.root, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", start_new_session=True)
    timer = threading.Timer(ctx.args.timeout, kill_group, (proc, fired))
    timer.start()
    try:
        with (ctx.jobs_dir / f"{job.name}-{attempt}.jsonl").open("w", encoding="utf-8") as out:
            for line in proc.stdout:
                out.write(line)
                stats.feed(line)
        code = proc.wait()
    finally:
        timer.cancel()
        if proc.poll() is None:
            kill_group(proc, threading.Event())
    return Attempt(code, round(time.monotonic() - start), fired.is_set(), stats)


def run_checker(ctx, unit):
    """检查器退出码：0 OK、2 INCOMPLETE、其余视为 FAIL。"""
    cmd = [sys.executable, str(ctx.checker), "--root", str(ctx.root), f"{REL}/results/{unit}.md"]
    try:
        return subprocess.run(cmd, cwd=ctx.root, capture_output=True, timeout=300).returncode
    except subprocess.TimeoutExpired:
        return -1


def last_line(path):
    """最后一个非空行；文件不存在返回空串。"""
    if not path.is_file():
        return ""
    lines = [s.strip() for s in path.read_text(encoding="utf-8", errors="replace").splitlines() if s.strip()]
    return lines[-1] if lines else ""


def outcome_problems(ctx, job, stats):
    """各模式的成功条件；返回不满足的项。"""
    if job.mode in ("audit", "fix"):
        if not ctx.result(job.name).is_file():
            return ["缺结果"]
        code = run_checker(ctx, job.name)
        return [] if code in (0, 2) else [f"检查器{code}"]
    if job.mode == "verify":
        return [] if last_line(ctx.verify / f"{job.name}.md").startswith("结论：") else ["缺结论"]
    ok_file, denied = (ctx.root / rel for rel in SMOKE_FILES)
    problems = []
    if not ok_file.is_file() or ok_file.read_text(encoding="utf-8", errors="replace").strip() != "ok":
        problems.append("SMOKE.md不是ok")
    if denied.exists():
        problems.append("越界写入未被拒绝")
    if stats.baseline is None or stats.peak is None:
        problems.append("基线或峰值缺失")
    return problems


def failure_note(ctx, job, result):
    """本次尝试的失败原因；空串表示成功。"""
    notes = ["超时"] if result.timed_out else []
    if result.code != 0:
        notes.append(f"退出{result.code}")
    if result.stats.is_error:
        notes.append("is_error")
    notes += outcome_problems(ctx, job, result.stats)
    if notes and result.stats.rate_limited:
        notes.append("限流")
    return ",".join(notes)


def fmt(value):
    return "NA" if value is None else str(value)


def kilo(value):
    return "NA" if value is None else f"{value / 1000:.1f}k"


def log_attempt(ctx, job, attempt, result, note):
    """每次尝试追加一行 run-log.tsv（首次写表头），控制台同时打印一行。"""
    stats, status = result.stats, ("fail" if note else "ok")
    row = [datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), job.mode, job.name, attempt,
           result.code, result.seconds, stats.turns, stats.baseline, stats.peak, stats.new,
           stats.cost, status, note]
    fresh = not ctx.run_log.is_file() or ctx.run_log.stat().st_size == 0
    with ctx.run_log.open("a", encoding="utf-8") as handle:
        if fresh:
            handle.write("\t".join(LOG_HEADER) + "\n")
        handle.write("\t".join(re.sub(r"\s+", " ", fmt(v)) for v in row) + "\n")
    line = f"{job.name} #{attempt} {status} {result.seconds}s peak={kilo(stats.peak)} new={kilo(stats.new)}"
    if note:
        line += f" {note}"
    if stats.new is not None and stats.new > NEW_LIMIT:
        line += " 超出16k"
    print(line, flush=True)


def clean_smoke(ctx):
    """只删冒烟的两个文件。"""
    for rel in SMOKE_FILES:
        path = ctx.root / rel
        if path.is_file():
            path.unlink()


def run_job(ctx, job):
    """一个作业：失败按退避重试，每次尝试后都过防线。返回 (是否成功, 最后一次尝试, 备注)。"""
    before = None if job.mode == "smoke" else git_snapshot(ctx)
    for attempt in range(1, ctx.args.max_retries + 2):
        if attempt > 1:
            time.sleep(ctx.args.backoff * 2 ** (attempt - 2))
        if job.mode == "smoke":
            clean_smoke(ctx)
        result = spawn(ctx, job, attempt)
        note = failure_note(ctx, job, result)
        log_attempt(ctx, job, attempt, result, note)
        guard(ctx, before)
        if not note:
            break
    return not note, result, note


def run_batch(ctx, jobs):
    """串行执行；连续失败达到 --stop-after 就停。返回退出码 0 或 1。"""
    guard(ctx, None)
    ran = failed = streak = 0
    for job in jobs:
        ok = run_job(ctx, job)[0]
        ran, failed = ran + 1, failed + (not ok)
        streak = 0 if ok else streak + 1
        if streak >= ctx.args.stop_after:
            print(f"连续 {streak} 个作业失败，停止", flush=True)
            break
    print(f"汇总：共 {len(jobs)} 个作业，成功 {ran - failed}，失败 {failed}，未执行 {len(jobs) - ran}")
    return 1 if failed else 0


def pick(names, known, what):
    """校验 --ids / --batches 并按表内顺序返回；不给就是全部。"""
    unknown = [n for n in names or [] if n not in known]
    if unknown:
        raise UsageError(f"未知{what}：{' '.join(unknown)}")
    return [k for k in known if not names or k in names]


def unit_verdict(ctx, unit):
    """所在批次验收表里该单元那一行的「结论」列；没有就返回空串。"""
    path = ctx.verify / f"{ctx.batch_of(unit)}.md"
    if not path.is_file():
        return ""
    col = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip().strip("`* ") for c in line.strip().strip("|").split("|")]
        if cells[0] == "单元" and "结论" in cells:
            col = cells.index("结论")
        elif col is not None and cells[0] == unit and col < len(cells):
            return cells[col]
    return ""


def batch_verdict(line):
    """验收文件最后一行 → 通过 / 不通过 / BLOCKED / 其他。"""
    rest = line[len("结论："):] if line.startswith("结论：") else ""
    return next((k for k in ("不通过", "BLOCKED", "通过") if rest.startswith(k)), "其他")


def audit_jobs(ctx):
    """audit / fix：每个单元一个作业，附跳过原因（空串表示要跑）。"""
    pairs = []
    for unit in pick(ctx.args.ids, ctx.units, "单元"):
        if ctx.args.cmd == "audit":
            prompt = PROMPTS["audit"].format(unit=unit)
            skip = "结果已存在" if ctx.result(unit).exists() and not ctx.args.force else ""
        else:
            batch = ctx.batch_of(unit)
            prompt = PROMPTS["fix"].format(unit=unit, batch=batch)
            skip = "" if unit_verdict(ctx, unit).startswith("不通过") else f"验收结论不是不通过（{batch}）"
        pairs.append((Job(ctx.args.cmd, unit, prompt), skip))
    return pairs


def verify_jobs(ctx):
    """按单元顺序每 4 个一批（V01 起）；本批结果未齐或验收文件已存在就跳过。"""
    pairs = []
    for batch in pick(ctx.args.batches, ctx.batches, "批次"):
        units = ctx.batches[batch]
        missing = [u for u in units if not ctx.result(u).exists()]
        if missing:
            skip = "本批结果未齐，缺 " + " ".join(missing)
        elif (ctx.verify / f"{batch}.md").exists() and not ctx.args.force:
            skip = "验收文件已存在"
        else:
            skip = ""
        prompt = PROMPTS["verify"].format(batch=batch, units=" ".join(units))
        pairs.append((Job("verify", batch, prompt), skip))
    return pairs


def dry_run(ctx, pairs):
    """打印前 2 条完整命令和作业总数；不做跳过判断，只在末尾标注。"""
    pairs = pairs[:getattr(ctx.args, "limit", None)]
    print(f"作业总数：{len(pairs)}（dry-run，不启动会话）")
    for job, _ in pairs[:2]:
        print(shlex.join(build_cmd(ctx, job)))
    counts = collections.Counter(re.split("[，（]", reason)[0] for _, reason in pairs if reason)
    marks = "、".join(f"{k} {v} 个" for k, v in counts.items()) or "无"
    print(f"注：dry-run 未做跳过判断，实际运行会跳过：{marks}")
    return 0


def cmd_jobs(ctx, pairs):
    """audit / verify / fix 的公共流程：跳过、限量后串行执行。"""
    if ctx.args.dry_run:
        return dry_run(ctx, pairs)
    skipped = collections.OrderedDict()
    for job, reason in pairs:
        if reason:
            skipped.setdefault(reason, []).append(job.name)
    for reason, names in skipped.items():
        more = " …" if len(names) > 12 else ""
        print(f"跳过 {len(names)} 个（{reason}）：{' '.join(names[:12])}{more}")
    jobs = [job for job, reason in pairs if not reason][:getattr(ctx.args, "limit", None)]
    if not jobs:
        print("没有需要执行的作业")
        return 0
    return run_batch(ctx, jobs)


def cmd_smoke(ctx):
    """冒烟：不做 git 比对，但做清单校验；结束后只删 SMOKE 两个文件。"""
    job = Job("smoke", "SMOKE", PROMPTS["smoke"])
    if ctx.args.dry_run:
        return dry_run(ctx, [(job, "")])
    guard(ctx, None)
    try:
        ok, result, note = run_job(ctx, job)
    finally:
        clean_smoke(ctx)
    numbers = f"基线（固定开销）={fmt(result.stats.baseline)} 新增={fmt(result.stats.new)}"
    if ok:
        print(f"冒烟 ok：{numbers}")
        return 0
    state = "BLOCKED（限流，重试用尽）" if "限流" in note else f"失败（{note}）"
    print(f"冒烟 {state}：{numbers}")
    return 1


def cmd_status(ctx):
    """不开会话：汇总结果、检查器、验收与待整改单元。"""
    have = [u for u in ctx.units if ctx.result(u).is_file()]
    checks = collections.Counter({0: "OK", 2: "INCOMPLETE"}.get(run_checker(ctx, u), "FAIL") for u in have)
    files = [ctx.verify / f"{b}.md" for b in ctx.batches]
    verdicts = collections.Counter(batch_verdict(last_line(f)) for f in files if f.is_file())
    todo = [u for u in ctx.units if unit_verdict(ctx, u).startswith("不通过")]
    print(f"单元总数：{len(ctx.units)}")
    print(f"已有结果：{len(have)}（检查器 OK {checks['OK']} / INCOMPLETE {checks['INCOMPLETE']} / FAIL {checks['FAIL']}）")
    print(f"批次总数：{len(ctx.batches)}")
    print(f"已验收：{sum(verdicts.values())}（通过 {verdicts['通过']} / 不通过 {verdicts['不通过']} / BLOCKED {verdicts['BLOCKED']}）")
    more = " …" if len(todo) > 20 else ""
    print(f"待整改单元：{len(todo)}" + (f"（{' '.join(todo[:20])}{more}）" if todo else ""))
    return 0


class Parser(argparse.ArgumentParser):
    """argparse 的用法错误默认退出 2，这里统一为 3。"""

    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(3, f"{self.prog}: 错误: {message}\n")


def build_parser():
    common = argparse.ArgumentParser(add_help=False)
    add = common.add_argument
    add("--root", default=str(Path(__file__).resolve().parents[4]), help="仓库根，默认按本文件位置推算")
    add("--dry-run", action="store_true", help="只打印前 2 条完整命令和作业总数")
    add("--effort", default="medium")
    add("--max-retries", type=int, default=3)
    add("--backoff", type=float, default=60, help="秒；第 n 次重试前等 backoff×2^(n−1)")
    add("--stop-after", type=int, default=2, help="连续几个作业失败就停")
    add("--timeout", type=float, default=1500, help="每个作业单次尝试的秒数")
    add("--claude-bin", default="claude")
    add("--checker", help="检查器路径，默认 tools/check_s0.py")
    parser = Parser(description="S0 批量执行器：一个作业一个全新的 claude -p 会话，串行执行")
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name, ids in (("audit", "--ids"), ("verify", "--batches")):
        cmd = sub.add_parser(name, parents=[common])
        cmd.add_argument(ids, nargs="+")
        cmd.add_argument("--limit", type=int)
        cmd.add_argument("--force", action="store_true")
    sub.add_parser("fix", parents=[common]).add_argument("--ids", nargs="+", required=True)
    for name in ("smoke", "status"):
        sub.add_parser(name, parents=[common])
    return parser


def validate(args):
    limit = getattr(args, "limit", None)
    problems = [msg for ok, msg in (
        (args.max_retries >= 0, "--max-retries 不能为负"),
        (args.backoff >= 0, "--backoff 不能为负"),
        (args.stop_after >= 1, "--stop-after 至少为 1"),
        (args.timeout > 0, "--timeout 必须大于 0"),
        (limit is None or limit >= 1, "--limit 至少为 1")) if not ok]
    if problems:
        raise UsageError("；".join(problems))


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        validate(args)
        ctx = Ctx(args)
        if args.cmd == "status":
            return cmd_status(ctx)
        if args.cmd == "smoke":
            return cmd_smoke(ctx)
        return cmd_jobs(ctx, verify_jobs(ctx) if args.cmd == "verify" else audit_jobs(ctx))
    except UsageError as exc:
        print(f"用法错误：{exc}", file=sys.stderr)
        return 3
    except Abort as exc:
        print(f"中止：{exc}", file=sys.stderr)
        return 4


if __name__ == "__main__":
    sys.exit(main())

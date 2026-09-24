"""run.py 的单元测试：临时假仓库 + 假 claude + 假检查器，不调用真实 claude。"""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

RUN = Path(__file__).resolve().parent / "run.py"
UNITS = ["S0-001", "S0-002", "S0-003", "S0-004", "S0-005", "S0-006"]
# env -i 之后拿不到环境变量，假 claude 按工作目录下 fake_claude.json 的 seq 依次决定每次调用的行为。
FAKE_CLAUDE = r'''#!PYTHON
import json, re, sys
from pathlib import Path
seq = json.loads(Path("fake_claude.json").read_text(encoding="utf-8"))["seq"]
calls = Path(".fake_calls")
count = int(calls.read_text()) if calls.exists() else 0
calls.write_text(str(count + 1))
action, prompt = seq[min(count, len(seq) - 1)], sys.argv[sys.argv.index("-p") + 1]
if action == "429":
    print("API Error: 429 rate limit exceeded")
    sys.exit(1)
if action == "touch":
    Path("AreaChain/a.swift").write_text("// touched\n")
base = Path(".cursor/plans/excellence")
batch = re.search(r"批次 (V\d+)", prompt)
if batch:
    (base / "verify" / (batch.group(1) + ".md")).write_text("# 验收\n\n结论：通过\n", encoding="utf-8")
else:
    unit = re.search(r"单元 (S0-\d+)", prompt).group(1)
    (base / "results" / (unit + ".md")).write_text("ok\n", encoding="utf-8")
def usage(fresh, read, created):
    return {"type": "assistant", "message": {"usage": {
        "input_tokens": fresh, "cache_read_input_tokens": read, "cache_creation_input_tokens": created}}}
for event in ({"type": "system", "subtype": "init"}, usage(100, 20000, 0), usage(50, 25000, 1000),
              {"type": "result", "num_turns": 3, "total_cost_usd": 0.12, "is_error": False}):
    print(json.dumps(event))
'''
VERIFY_V01 = """| 单元 | 检查器 | 抽查属实 | 漏报抽查 | 结论 | 整改清单 |
|---|---|---|---|---|---|
| S0-001 | OK | 2/2 | 无 | 通过 | 无 |
| S0-002 | OK | 1/2 | 无 | 不通过 | S0-002-03 级别改为低 |

结论：不通过（S0-002）
"""


class RunTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "AreaChain").mkdir()
        (self.root / "AreaChain" / "a.swift").write_text("// a\n")
        git = ["git", "-C", str(self.root), "-c", "user.name=t", "-c", "user.email=t@example.com",
               "-c", "commit.gpgsign=false"]
        for args in (["init", "-q"], ["add", "AreaChain/a.swift"], ["commit", "-q", "--no-verify", "-m", "init"]):
            subprocess.run(git + args, check=True, capture_output=True)
        self.base = self.root / ".cursor" / "plans" / "excellence"
        self.base.mkdir(parents=True)
        # 每个单元两行，验证「单元顺序 = 首次出现顺序」。
        rows = "".join(f"{u}\tcode\tAreaChain/a.swift\t1\n{u}\tcode\tAreaChain/b.swift\t2\n" for u in UNITS)
        (self.base / "S0-units.tsv").write_text("unit\tkind\tpath\tlines\n" + rows, encoding="utf-8")
        (self.base / "MANIFEST.sha256").write_text("")
        (self.root / "bin").mkdir()
        self.claude, self.checker = self.root / "bin" / "claude", self.root / "bin" / "checker.py"
        self.claude.write_text(FAKE_CLAUDE.replace("PYTHON", sys.executable, 1), encoding="utf-8")
        self.claude.chmod(0o755)
        self.checker.write_text("import sys\nsys.exit(0)\n")

    def run_cli(self, *args, seq=("ok",)):
        (self.root / "fake_claude.json").write_text(json.dumps({"seq": list(seq)}))
        cmd = [sys.executable, "-B", str(RUN), *args, "--root", str(self.root), "--claude-bin",
               str(self.claude), "--checker", str(self.checker), "--backoff", "0"]
        return subprocess.run(cmd, capture_output=True, text=True, timeout=120)

    def log_rows(self):
        path = self.base / "logs" / "run-log.tsv"
        if not path.exists():
            return []
        lines = path.read_text(encoding="utf-8").splitlines()
        header = lines[0].split("\t")
        return [dict(zip(header, line.split("\t"))) for line in lines[1:]]

    def calls(self):
        path = self.root / ".fake_calls"
        return int(path.read_text()) if path.exists() else 0

    def test_dry_run_prints_full_command(self):
        proc = self.run_cli("audit", "--ids", "S0-001", "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        for part in ("env -i", "--strict-mcp-config", "--no-session-persistence",
                     "--permission-mode dontAsk", "--effort medium"):
            self.assertIn(part, proc.stdout)
        self.assertNotIn("--bare", proc.stdout)
        self.assertNotIn("--model", proc.stdout)
        self.assertEqual(self.calls(), 0)

    def test_success_logs_baseline_and_peak(self):
        proc = self.run_cli("audit", "--ids", "S0-001")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        row, = self.log_rows()
        self.assertEqual([row[k] for k in ("status", "turns", "baseline", "peak", "new", "cost")],
                         ["ok", "3", "20100", "26050", "5950", "0.12"])
        self.assertTrue((self.base / "logs" / "jobs" / "S0-001-1.jsonl").is_file())
        self.assertIn("S0-001 #1 ok", proc.stdout)

    def test_existing_result_is_skipped(self):
        (self.base / "results").mkdir()
        (self.base / "results" / "S0-001.md").write_text("done\n")
        proc = self.run_cli("audit", "--ids", "S0-001")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertEqual((self.calls(), self.log_rows()), (0, []))

    def test_retry_after_rate_limit(self):
        proc = self.run_cli("audit", "--ids", "S0-001", seq=("429", "ok"))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        first, second = self.log_rows()
        self.assertEqual(first["status"], "fail")
        self.assertIn("限流", first["note"])
        self.assertEqual((second["attempt"], second["status"]), ("2", "ok"))

    def test_stops_after_consecutive_failures(self):
        proc = self.run_cli("audit", "--ids", "S0-001", "S0-002", "S0-003", "--max-retries", "0",
                            "--stop-after", "2", seq=("429",))
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertEqual((self.calls(), len(self.log_rows())), (2, 2))

    def test_protected_change_aborts_with_4(self):
        proc = self.run_cli("audit", "--ids", "S0-001", seq=("touch",))
        self.assertEqual(proc.returncode, 4, proc.stdout + proc.stderr)
        self.assertIn("AreaChain/a.swift", proc.stderr)

    def test_verify_v01_is_first_four_units(self):
        proc = self.run_cli("verify", "--batches", "V01", "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("验收批次 V01，单元：S0-001 S0-002 S0-003 S0-004。", proc.stdout)
        proc = self.run_cli("verify", "--batches", "V02", "--dry-run")
        self.assertIn("验收批次 V02，单元：S0-005 S0-006。", proc.stdout)

    def test_fix_runs_only_failed_units(self):
        (self.base / "verify").mkdir()
        (self.base / "verify" / "V01.md").write_text(VERIFY_V01, encoding="utf-8")
        proc = self.run_cli("fix", "--ids", "S0-001", "S0-002")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertEqual(self.calls(), 1)
        self.assertEqual(self.log_rows()[0]["job"], "S0-002")


if __name__ == "__main__":
    unittest.main()

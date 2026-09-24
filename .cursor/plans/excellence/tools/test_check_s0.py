#!/usr/bin/env python3
"""check_s0.py 的单元测试：在临时假仓库里造单元表、源文件和结果文件，按退出码断言。"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().with_name("check_s0.py")
UNITS = "unit\tkind\tpath\tlines\nS0-900\tcode\tsrc/A.swift\t8\nS0-900\tcode\tsrc/B.swift\t3\n" \
        "S0-901\tcode\tsrc/C.swift\t2\n"
SOURCES = {
    "src/A.swift": ["struct A {", "    let name: String", "    let   count:  Int", "", "    func run() {",
                    "        print(name)", "    }", "}"],
    "src/B.swift": ["enum B {", "    case one", "}"],
    "src/C.swift": ["let c = 1", "let d = 2"],
}
COVERAGE = ["| src/A.swift | 8 | 8 |", "| src/B.swift | 3 | 3 |"]
FINDING = "| S0-900-01 | src/A.swift:3 | 命名 | 中 | `let count: Int` | 计数字段命名含糊 |"


def result(coverage=None, findings=None, blocks=None, pending="无", files_read=2):
    findings = [FINDING] if findings is None else findings
    blocks = ["| B | src/B.swift:1 | 枚举示例 |"] if blocks is None else blocks
    lines = ["---", "unit: S0-900", "kind: code", "files_read: %d" % files_read, "---", "",
             "## 覆盖", "| 文件 | 行数 | 已读 |", "|---|---|---|"] + (COVERAGE if coverage is None else coverage)
    lines += ["", "## 发现"]
    if findings:
        lines += ["| ID | 位置 | 类别 | 级别 | 原文 | 说明 |", "|---|---|---|---|---|---|"] + findings
    else:
        lines.append("无")
    lines += ["", "## 可复用积木"]
    lines += (["| 名称 | 位置 | 用途 |", "|---|---|---|"] + blocks) if blocks else ["无"]
    return "\n".join(lines + ["", "## 未完成", pending, ""])


class CheckS0Test(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        table = self.root / ".cursor/plans/excellence/S0-units.tsv"
        table.parent.mkdir(parents=True)
        table.write_text(UNITS, encoding="utf-8")
        for rel, lines in SOURCES.items():
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text("\n".join(lines) + "\n", encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def run_checker(self, *args):
        return subprocess.run([sys.executable, "-B", str(CHECKER)] + list(args),
                              capture_output=True, text=True)

    def check(self, text, code, needle=None):
        path = self.root / "S0-900.md"
        path.write_text(text, encoding="utf-8")
        proc = self.run_checker("--root", str(self.root), str(path))
        self.assertEqual(proc.returncode, code, proc.stdout + proc.stderr)
        if needle:
            self.assertIn(needle, proc.stdout)
        return proc.stdout

    def test_valid_result(self):
        out = self.check(result(), 0, "OK S0-900 发现 1（高 0 / 中 1 / 低 0）")
        self.assertIn("TOTAL ok=1 fail=0 incomplete=0", out)

    def test_findings_none(self):
        self.check(result(findings=[], blocks=[]), 0, "OK S0-900 发现 0")

    def test_quote_within_two_lines(self):
        row = "| S0-900-01 | src/A.swift:4 | 命名 | 低 | `print(name)` | 两行之后仍可命中 |"
        self.check(result(findings=[row]), 0)

    def test_coverage_missing_file(self):
        self.check(result(coverage=COVERAGE[:1], files_read=1), 1, "覆盖缺少 src/B.swift")

    def test_line_count_mismatch(self):
        self.check(result(coverage=["| src/A.swift | 9 | 8 |", COVERAGE[1]]), 1, "与单元表 8 不符")

    def test_quote_outside_window(self):
        row = "| S0-900-01 | src/A.swift:1 | 命名 | 低 | `print(name)` | 超出范围 |"
        self.check(result(findings=[row]), 1, "±2 行内")

    def test_invalid_category(self):
        self.check(result(findings=[FINDING.replace("命名", "风格")]), 1, "类别「风格」不合法")

    def test_levels_not_sorted(self):
        low = "| S0-900-01 | src/B.swift:2 | 命名 | 低 | `case one` | 太短 |"
        high = "| S0-900-02 | src/A.swift:6 | 行为 | 高 | `print(name)` | 直接打印 |"
        self.check(result(findings=[low, high]), 1, "未按高、中、低排序")

    def test_duplicate_id(self):
        self.check(result(findings=[FINDING, FINDING]), 1, "ID S0-900-01 重复")

    def test_location_outside_unit(self):
        row = "| S0-900-01 | src/C.swift:1 | 命名 | 低 | `let c = 1` | 别的单元 |"
        self.check(result(findings=[row]), 1, "不属于本单元")

    def test_partial_read_marked_done(self):
        text = result(coverage=["| src/A.swift | 8 | 5 |", COVERAGE[1]], files_read=1)
        self.check(text, 1, "未完成写「无」")

    def test_honest_incomplete(self):
        text = result(coverage=["| src/A.swift | 8 | 5 |", COVERAGE[1]], files_read=1,
                      pending="剩余 src/A.swift 第 6–8 行")
        self.check(text, 2, "INCOMPLETE S0-900（未完成：剩余 src/A.swift 第 6–8 行）")

    def test_no_arguments(self):
        self.assertEqual(self.run_checker().returncode, 3)

    def test_missing_units_table(self):
        path = self.root / "S0-900.md"
        path.write_text(result(), encoding="utf-8")
        proc = self.run_checker("--root", str(self.root / "nowhere"), str(path))
        self.assertEqual(proc.returncode, 3)

    def test_stale_units_table(self):
        (self.root / "src/B.swift").write_text("enum B {}\n", encoding="utf-8")
        self.check(result(), 1, "单元表可能过期")

    def test_reasons_capped_at_ten(self):
        rows = ["| X-%02d | nowhere:1 | 风格 | 中 | `code` | 说明 |" % i for i in range(6)]
        self.check(result(findings=rows), 1, "另有")


if __name__ == "__main__":
    unittest.main()

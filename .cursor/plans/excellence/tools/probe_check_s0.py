"""R0a 验收探针：用单元表里真实的 S0-001 构造 7 种结果，逐个跑检查器，核对退出码。只写临时目录。

由架构师提供，执行者和验收者都不要修改。"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PLAN = ROOT / ".cursor/plans/excellence"
CHECK = PLAN / "tools/check_s0.py"
UNIT = "S0-001"


def unit_rows():
    rows = []
    for line in (PLAN / "S0-units.tsv").read_text(encoding="utf-8").splitlines()[1:]:
        cols = line.split("\t")
        if cols[0] == UNIT:
            rows.append((cols[1], cols[2], int(cols[3])))
    return rows


def render(rows, read=None, findings="无", unfinished="无"):
    done = sum(1 for *_, n in rows if read is None or read == n)
    out = ["---", f"unit: {UNIT}", f"kind: {rows[0][0]}", f"files_read: {done}", "---", "",
           "## 覆盖", "| 文件 | 行数 | 已读 |", "|---|---|---|"]
    out += [f"| {p} | {n} | {n if read is None else read} |" for _, p, n in rows]
    out += ["", "## 发现", findings, "", "## 可复用积木", "无", "", "## 未完成", unfinished, ""]
    return "\n".join(out)


def table(entries):
    rows = ["| ID | 位置 | 类别 | 级别 | 原文 | 说明 |", "|---|---|---|---|---|---|"]
    rows += [f"| {UNIT}-{i:02d} | {loc} | {cat} | {lvl} | `{quote}` | 探针构造 |"
             for i, (loc, cat, lvl, quote) in enumerate(entries, 1)]
    return "\n".join(rows)


def pick_quote(path):
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for number, raw in enumerate(lines, 1):
        text = raw.strip()
        if len(text) >= 12 and "|" not in text and "`" not in text and sum(text in o for o in lines) == 1:
            return number, text[:40]
    raise SystemExit(f"{path} 里找不到可用的唯一行")


def cases(rows):
    path, size = rows[0][1], rows[0][2]
    n, quote = pick_quote(path)
    at, far = f"{path}:{n}", f"{path}:{min(n + 10, size)}"
    return [
        ("合法、无发现", render(rows), 0),
        ("引用属实", render(rows, findings=table([(at, "职责", "中", quote)])), 0),
        ("引用不在 ±2 行内", render(rows, findings=table([(far, "职责", "中", quote)])), 1),
        ("类别不在清单", render(rows, findings=table([(at, "其他", "中", quote)])), 1),
        ("级别未按高中低排序", render(rows, findings=table([(at, "职责", "低", quote), (at, "注释", "高", quote)])), 1),
        ("已读少于行数却写未完成为无", render(rows, read=1), 1),
        ("如实标注未完成", render(rows, read=1, unfinished=f"剩余：{path}"), 2),
    ]


def main():
    if not CHECK.exists():
        print(f"缺少检查器：{CHECK.relative_to(ROOT)}")
        return 3
    rows = unit_rows()
    if not rows:
        print(f"单元表里没有 {UNIT}")
        return 3
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        for i, (name, text, expected) in enumerate(cases(rows), 1):
            result = Path(tmp) / f"case{i}.md"
            result.write_text(text, encoding="utf-8")
            run = subprocess.run([sys.executable, str(CHECK), str(result)], capture_output=True, text=True)
            ok = run.returncode == expected
            failed += not ok
            print(f"{'PASS' if ok else 'FAIL'} {name}：预期 {expected}，实际 {run.returncode}")
            if not ok:
                print("   " + (run.stdout + run.stderr).strip().replace("\n", "\n   ")[:400])
    print("探针全部通过" if failed == 0 else f"探针失败 {failed} 项")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

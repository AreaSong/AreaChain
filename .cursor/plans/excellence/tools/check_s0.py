#!/usr/bin/env python3
"""S0 摸底结果检查器：按单元表核对结果文件的头部、覆盖、发现、积木与未完成。"""
import re
import sys
from pathlib import Path

SECTIONS = ["覆盖", "发现", "可复用积木", "未完成"]
CATEGORIES = set("职责 单一来源 模式 分层 阈值 双语 行为 注释 测试覆盖 断言 脆弱 重复准备 命名 脚本 文档".split())
LEVELS = ["高", "中", "低"]
MAX_REASONS = 10
UNITS_TSV = ".cursor/plans/excellence/S0-units.tsv"

class Repo:
    """仓库根与单元表；源文件内容按需读取并缓存（逐行迭代，与单元表计数方式一致）。"""
    def __init__(self, root):
        self.root = Path(root)
        self.units, self._lines = {}, {}
        with open(self.root / UNITS_TSV, encoding="utf-8") as fh:
            next(fh, None)
            for raw in fh:
                parts = raw.rstrip("\n").split("\t")
                if len(parts) == 4:
                    entry = self.units.setdefault(parts[0], {"kind": parts[1], "files": {}})
                    entry["files"][parts[2]] = int(parts[3])

    def lines_of(self, rel):
        """返回文件逐行内容；路径为空或文件不存在时返回 None。"""
        full = self.root / rel if rel else None
        if rel not in self._lines and full is not None and full.is_file():
            with open(full, encoding="utf-8") as fh:
                self._lines[rel] = [line.rstrip("\n") for line in fh]
        return self._lines.get(rel)

def squash(text):
    return re.sub(r"\s+", " ", text)

def parse_header(lines):
    """返回 (头部字典, 正文起始行)；缺首尾 --- 时头部为 None。"""
    stripped = [l.strip() for l in lines]
    if not stripped or stripped[0] != "---" or "---" not in stripped[1:]:
        return None, 0
    end = stripped.index("---", 1)
    pairs = [l.split(":", 1) for l in stripped[1:end] if ":" in l]
    return {k.strip(): v.strip() for k, v in pairs}, end + 1

def parse_sections(lines, errors):
    """按二级标题切分正文，要求四个标题各出现一次且顺序正确。"""
    found, bodies, current = [], {}, None
    for line in lines:
        if line.startswith("## "):
            current = line[3:].strip()
            found.append(current)
            bodies.setdefault(current, [])
        elif current is not None:
            bodies[current].append(line)
    if [name for name in found if name in SECTIONS] != SECTIONS:
        errors.append("二级标题须按顺序各出现一次：%s（实际：%s）" % ("、".join(SECTIONS), "、".join(found) or "无"))
        return None
    return bodies

def table_rows(body):
    """返回 (是否只写了「无」, 数据行单元格列表)；分隔行及其上一行表头被跳过。"""
    rows = []
    for line in body:
        text = line.strip()
        if not text.startswith("|"):
            continue
        cells = [c.strip() for c in text.strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in cells):
            if rows:
                rows.pop()
            continue
        rows.append(cells)
    return [l.strip() for l in body if l.strip()] == ["无"], rows

def data_rows(body, section, width, errors):
    """返回格数正确的数据行；只写「无」时为空；空表和格数不对记为原因。"""
    is_none, rows = table_rows(body)
    if not is_none and not rows:
        errors.append("%s为空：应写表格或一行「无」" % section)
    errors.extend("%s第 %d 行应为 %d 格，实际 %d 格" % (section, n, width, len(c))
                  for n, c in enumerate(rows, 1) if len(c) != width)
    return [] if is_none else [c for c in rows if len(c) == width]

def split_location(text):
    match = re.fullmatch(r"(.+):(\d+)", text)
    return (match.group(1), int(match.group(2))) if match else (None, None)

def check_header(header, repo, errors):
    errors.extend("头部缺少 %s" % key for key in ("unit", "kind", "files_read") if not header.get(key))
    unit, kind = header.get("unit"), header.get("kind")
    if unit and unit not in repo.units:
        errors.append("头部 unit %s 不在单元表里" % unit)
        return None
    if unit and kind and kind != repo.units[unit]["kind"]:
        errors.append("头部 kind %s 与单元表 %s 不符" % (kind, repo.units[unit]["kind"]))
    return repo.units.get(unit)

def check_coverage(body, entry, repo, errors):
    """核对覆盖表，返回 {路径: 已读} 供后续规则使用。"""
    expected, reads = entry["files"], {}
    rows = data_rows(body, "覆盖", 3, errors)
    for path, lines, read in rows:
        if path in reads:
            errors.append("覆盖重复列出 %s" % path)
        if path not in expected:
            errors.append("覆盖多出不属于本单元的 %s" % path)
            continue
        want, content = expected[path], repo.lines_of(path)
        if content is None:
            errors.append("覆盖 %s 文件不存在" % path)
        elif len(content) != want:
            errors.append("覆盖 %s 当前 %d 行，单元表记 %d 行（单元表可能过期）" % (path, len(content), want))
        if lines != str(want):
            errors.append("覆盖 %s 行数 %s 与单元表 %d 不符" % (path, lines, want))
        if not re.fullmatch(r"\d+", read) or int(read) > want:
            errors.append("覆盖 %s 已读 %s 应为 0 到 %d 的整数" % (path, read, want))
            continue
        reads[path] = int(read)
    listed = {cells[0] for cells in rows}
    errors.extend("覆盖缺少 %s" % p for p in expected if p not in listed)
    return reads

def check_quote(quote, content, line_no, where, errors):
    match = re.fullmatch(r"`([^`]{4,60})`", quote)
    if not match:
        errors.append("%s 原文须是反引号包住的 4–60 个字符且内部无反引号" % where)
        return
    needle = squash(match.group(1))
    if not any(needle in squash(l) for l in content[max(0, line_no - 3):line_no + 2]):
        errors.append("%s 原文不在第 %d 行 ±2 行内" % (where, line_no))

def check_finding(cells, unit, entry, repo, errors):
    where = "发现 %s" % cells[0]
    if not re.fullmatch(re.escape(unit) + r"-\d{2}", cells[0]):
        errors.append("%s ID 应为 %s-两位数字" % (where, unit))
    path, line_no = split_location(cells[1])
    content = repo.lines_of(path) if path in entry["files"] else None
    if content is None or not 1 <= line_no <= len(content):
        errors.append("%s 位置 %s %s" % (where, cells[1], "行号越界" if content is not None else "不属于本单元"))
        content = None
    if cells[2] not in CATEGORIES:
        errors.append("%s 类别「%s」不合法" % (where, cells[2]))
    if cells[3] not in LEVELS:
        errors.append("%s 级别「%s」应为高/中/低" % (where, cells[3]))
    if content is not None:
        check_quote(cells[4], content, line_no, where, errors)
    if not cells[5]:
        errors.append("%s 说明为空" % where)

def check_findings(body, unit, entry, repo, errors):
    """返回各级别计数；ID 重复与级别排序在这里统一检查。"""
    counts, seen, last = dict.fromkeys(LEVELS, 0), set(), 0
    for cells in data_rows(body, "发现", 6, errors):
        if cells[0] in seen:
            errors.append("发现 ID %s 重复" % cells[0])
        seen.add(cells[0])
        check_finding(cells, unit, entry, repo, errors)
        if cells[3] in LEVELS:
            counts[cells[3]] += 1
            rank = LEVELS.index(cells[3])
            if rank < last:
                errors.append("发现 %s 级别未按高、中、低排序" % cells[0])
            last = max(last, rank)
    return counts

def check_blocks(body, repo, errors):
    for name, where, _ in data_rows(body, "可复用积木", 3, errors):
        path, line_no = split_location(where)
        content = repo.lines_of(path)
        if content is None:
            errors.append("可复用积木 %s 位置 %s 路径不存在" % (name, where))
        elif not 1 <= line_no <= len(content):
            errors.append("可复用积木 %s 位置 %s 行号越界" % (name, where))

def check_pending(body, reads, entry, errors):
    """返回未完成说明（压成一行）；写「无」时要求每个文件都已读完。"""
    pending = " ".join(l.strip() for l in body if l.strip())
    if not pending:
        errors.append("未完成为空：应写「无」或说明")
    elif pending == "无":
        errors.extend("未完成写「无」，但 %s 已读 %d / %d" % (p, r, entry["files"][p])
                      for p, r in reads.items() if r != entry["files"][p])
    return pending

def check_result(path, repo):
    """返回 (状态, 名称, FAIL 原因列表或 OK/INCOMPLETE 的后缀)。"""
    errors = []
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        return "FAIL", str(path), ["无法读取：%s" % exc]
    header, start = parse_header(lines)
    if header is None:
        return "FAIL", str(path), ["头部缺少首尾 --- 包围的元数据"]
    name = header.get("unit") or str(path)
    entry = check_header(header, repo, errors)
    bodies = parse_sections(lines[start:], errors)
    if entry is None or bodies is None:
        return "FAIL", name, errors
    reads = check_coverage(bodies["覆盖"], entry, repo, errors)
    done = sum(1 for p, r in reads.items() if r == entry["files"][p])
    if header.get("files_read") and header["files_read"] != str(done):
        errors.append("头部 files_read=%s，但已读 = 行数的文件有 %d 个" % (header["files_read"], done))
    counts = check_findings(bodies["发现"], name, entry, repo, errors)
    check_blocks(bodies["可复用积木"], repo, errors)
    pending = check_pending(bodies["未完成"], reads, entry, errors)
    if errors:
        return "FAIL", name, errors
    if pending != "无":
        return "INCOMPLETE", name, "（未完成：%s）" % pending
    return "OK", name, " 发现 %d（高 %d / 中 %d / 低 %d）" % (
        sum(counts.values()), counts["高"], counts["中"], counts["低"])

def parse_args(argv):
    """返回 (root, files)；--root 缺值时 files 为空，按用法错误处理。"""
    root, args = Path(__file__).resolve().parents[4], list(argv)
    if "--root" in args:
        idx = args.index("--root")
        if idx + 1 >= len(args):
            return root, []
        root = Path(args[idx + 1])
        del args[idx:idx + 2]
    return root, args

def main(argv=None):
    root, files = parse_args(sys.argv[1:] if argv is None else argv)
    if not files:
        print("用法：check_s0.py [--root DIR] RESULT.md [RESULT.md ...]", file=sys.stderr)
        return 3
    try:
        repo = Repo(root)
    except (OSError, ValueError):
        print("单元表不存在或格式错误：%s" % (Path(root) / UNITS_TSV), file=sys.stderr)
        return 3
    tally = {"OK": 0, "FAIL": 0, "INCOMPLETE": 0}
    for path in files:
        status, name, detail = check_result(path, repo)
        tally[status] += 1
        print("%s %s%s" % (status, name, "" if status == "FAIL" else detail))
        for reason in detail[:MAX_REASONS] if status == "FAIL" else []:
            print("  - %s" % reason)
        if status == "FAIL" and len(detail) > MAX_REASONS:
            print("  - 另有 %d 条" % (len(detail) - MAX_REASONS))
    print("TOTAL ok=%d fail=%d incomplete=%d" % (tally["OK"], tally["FAIL"], tally["INCOMPLETE"]))
    return 1 if tally["FAIL"] else (2 if tally["INCOMPLETE"] else 0)

if __name__ == "__main__":
    sys.exit(main())

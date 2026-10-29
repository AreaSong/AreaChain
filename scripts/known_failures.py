"""已知既有失败登记表：只改变失败的归类，不跳过、不过滤任何测试。

测试照常全部运行。门禁汇总时，命中登记表的失败单列为“已知”、不计入本次失败、不触发重新对照；
登记表外的失败照常报失败；登记表里的用例这次实际运行并通过时，提示可从登记表移除。
"""

import json
from pathlib import Path
import re

REGISTRY = Path("scripts") / "known_test_failures.json"
_TEST_ID = re.compile(r"^[A-Za-z_]\w*Tests\.[A-Za-z_]\w*$")
_FIELDS = ("test", "firstSeen", "reason")
# xcodebuild 末尾的“Failing tests:”块：每行一个制表符缩进的“套件.方法(参数标签)”，同一用例可能重复出现。
_FAILING_BLOCK = re.compile(r"^Failing tests:\n((?:\t[^\n]*\n?)+)", re.M)


def normalize(name):
    """`AreaChainTests.Suite.method(after:)` / `Suite/method()` / `-[Suite method(args)]` → `Suite.method`。"""
    name = name.strip()
    if name.startswith("-[") and name.endswith("]"):
        name = name[2:-1].replace(" ", ".", 1)
    name = name.split("(", 1)[0].replace("/", ".")
    parts = [part for part in name.split(".") if part]
    if parts and parts[0] == "AreaChainTests":
        parts = parts[1:]
    return ".".join(parts[-2:])


def load(root):
    """返回 ({测试标识: 条目}, 问题列表)；登记表缺失视为空表，格式错误时不用于归类。"""
    path = Path(root) / REGISTRY
    if not path.is_file():
        return {}, []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return {}, [f"{REGISTRY}：无法读取（{error}）"]
    entries = data.get("entries") if isinstance(data, dict) else None
    if data.get("schemaVersion") != 1 or not isinstance(entries, list):
        return {}, [f"{REGISTRY}：需要 schemaVersion=1 与 entries 数组"]
    registry, problems = {}, []
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or any(not isinstance(entry.get(key), str) or not entry[key].strip()
                                               for key in _FIELDS):
            problems.append(f"{REGISTRY} 第 {index + 1} 条缺少 {'/'.join(_FIELDS)}")
            continue
        test = entry["test"]
        if not _TEST_ID.match(test):
            problems.append(f"{REGISTRY} 第 {index + 1} 条测试标识须为 类.方法：{test}")
        elif test in registry:
            problems.append(f"{REGISTRY} 重复登记：{test}")
        else:
            registry[test] = entry
    return ({} if problems else registry), problems


def failing_tests(output):
    """从 xcodebuild 输出的“Failing tests:”块取失败用例标识；没有该块返回空集合。"""
    found = set()
    for block in _FAILING_BLOCK.findall(output):
        found |= {normalize(line) for line in block.splitlines() if line.strip()}
    return found


def classify(failing, registry):
    """返回 (已知, 登记表外) 两个排好序的列表。"""
    known = sorted(name for name in failing if name in registry)
    return known, sorted(name for name in failing if name not in registry)


def _selected(test, filters):
    if filters is None:
        return True
    suite, method = test.split(".", 1)
    return any(item in (f"AreaChainTests/{suite}", "AreaChainTests")
               or item.startswith(f"AreaChainTests/{suite}/{method}(") or item == f"AreaChainTests/{suite}/{method}"
               for item in filters)


def removable(registry, failing, filters):
    """本次实际被选中运行、却没有失败的登记用例；只在各轮都正常跑完时由调用方使用。"""
    return sorted(test for test in registry if _selected(test, filters) and test not in failing)

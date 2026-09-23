"""S0 字符串表机械核对：缺语言、占位符不一致、stale、待翻译。只读，最多列 40 条。"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PATH = "AreaChain/Resources/Localizable.xcstrings"
SEMANTIC = re.compile(r"[a-z][A-Za-z0-9]*(\.[A-Za-z0-9_]+)+")
SPEC = re.compile(r"%(?!%)(?:\d+\$)?(?:ll|l|hh|h)?[@A-Za-z]")
KEY_LINE = re.compile(r'^(".*")\s*:\s*\{\}?,?$')
LANGS = ("en", "zh-Hans")


def key_lines(text):
    # 兼容 `"key": {` 与 Xcode 默认的 `"key" : {` 两种写法。
    lines = {}
    for number, raw in enumerate(text.splitlines(), 1):
        match = KEY_LINE.match(raw.strip())
        if match:
            lines.setdefault(match.group(1), number)
    return lines


def value(entry, lang, key, source):
    loc = entry.get("localizations", {}).get(lang, {})
    unit = loc.get("stringUnit", {})
    if unit.get("value"):
        return unit["value"], unit.get("state", "")
    if loc.get("variations"):
        return "", "variations"
    # 源语言可以省略译文，此时 key 本身就是文案；语义化 key（a.b.c）不算。
    if lang == source and not SEMANTIC.fullmatch(key):
        return key, "source"
    return None, ""


def problems(key, entry, source):
    got = {lang: value(entry, lang, key, source) for lang in LANGS}
    missing = [lang for lang, (text, _) in got.items() if text is None]
    found = []
    if missing:
        found.append("缺语言 " + "/".join(missing))
    elif "variations" not in (got["en"][1], got["zh-Hans"][1]):
        if sorted(SPEC.findall(got["en"][0])) != sorted(SPEC.findall(got["zh-Hans"][0])):
            found.append("占位符不一致")
    if entry.get("extractionState") == "stale":
        found.append("stale")
    if any(state in ("new", "needs_review") for _, state in got.values()):
        found.append("待翻译")
    return found


def main():
    text = (ROOT / PATH).read_text(encoding="utf-8")
    data = json.loads(text)
    source = data.get("sourceLanguage", "en")
    lines = key_lines(text)
    issues, kinds = [], {}
    for key, entry in data.get("strings", {}).items():
        if entry.get("shouldTranslate") is False:
            continue
        at = lines.get(json.dumps(key, ensure_ascii=False), 0)
        for kind in problems(key, entry, source):
            issues.append((at, kind, key))
            name = kind.split()[0]
            kinds[name] = kinds.get(name, 0) + 1
    summary = " ".join(f"{k}={v}" for k, v in sorted(kinds.items())) or "无问题"
    total = len(data.get("strings", {}))
    print(f"文件={PATH} 行数={len(text.splitlines())} 源语言={source} key={total} 问题={len(issues)} {summary}")
    for at, kind, key in sorted(issues)[:40]:
        print(f"{at}\t{kind}\t{key[:60]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

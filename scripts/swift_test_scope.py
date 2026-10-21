"""按变更推导 Swift 定向测试范围；只读源码文本，不调用 Xcode。

改什么测什么：同名测试 → 测试里直接引用了变更文件声明的类型；只含扩展的文件按扩展里声明的成员名找，
不把整个被扩展类型的引用都带上。找不到任何相关测试的文件列为无法推导，由调用方只编译并提示，
不再按层目录兜底；间接影响留给批次收尾的全量回归，全量只由显式 profile 触发。
"""

from pathlib import Path
import re


TEST_TARGET = "AreaChainTests"
SOURCE_ROOT = "AreaChain"
# 一个文件的引用命中超过此数时在说明里提示“影响面大”，范围仍只是直接引用。
REFERENCE_SUITE_LIMIT = 60
# 扩展成员名出现在超过这么多测试文件里就算常见名（如 accept、operations），按名字匹配没有区分度，跳过并提示。
MEMBER_FILE_LIMIT = 30
# 测试支持文件（夹具）只再展开一跳：测试 → 夹具 → 被测类型。
SUPPORT_HOPS = 2

# 顶层声明只看不缩进的行；嵌套类型不能作为 -only-testing 的独立标识。
_TYPE_DECLARATION = re.compile(r"^(?![\s/])[^\n]*?\b(?:struct|class|enum|actor|protocol)\s+([A-Za-z_]\w*)", re.M)
_EXTENSION = re.compile(r"^(?:(?:public|internal|fileprivate|private)\s+)?extension\s+([A-Za-z_]\w*)", re.M)


def declared_types(text):
    return set(_TYPE_DECLARATION.findall(text))


def shared_types(text):
    """其他文件能用到的顶层类型（排除 private/fileprivate），用于追踪写在套件文件里的共享夹具。"""
    return {m.group(1) for m in _TYPE_DECLARATION.finditer(text)
            if not re.search(r"\b(?:private|fileprivate)\b", m.group(0)) and not m.group(1).endswith("Tests")}


def extension_targets(text):
    return set(_EXTENSION.findall(text))


def test_suites(text):
    """文件里能作为 -only-testing 标识的套件；本仓库套件统一以 Tests 结尾，扩展文件归入原套件。"""
    if "@Test" not in text and "XCTestCase" not in text:
        return set()
    return {name for name in declared_types(text) | extension_targets(text) if name.endswith("Tests")}


# 标了 .backgroundWindow 的套件：类型声明可与 @Suite 同行，也可隔着若干行 @MainActor 等属性。
_BACKGROUND_SUITE = re.compile(
    r"^@Suite\b[^\n]*\.backgroundWindow\b(?:[^\n]*\n(?:@[^\n]*\n)*)?[^\n]*?\b(?:struct|class|enum|actor)\s+(\w+Tests)\b",
    re.M)


def background_suites(root):
    """整套件只用程序化动作、窗口开在后台的套件；它们与需要前台的套件分两次 xcodebuild 运行。"""
    test_root = Path(root) / TEST_TARGET
    if not test_root.is_dir():
        return set()
    return {name for path in test_root.rglob("*.swift") for name in _BACKGROUND_SUITE.findall(_read(path))}


def split_rounds(root, filters):
    """返回 [(轮次, build.sh 参数)]；前台轮在前（需要离开电脑），后台轮在后（可以边用电脑边跑）。

    filters 为 None 表示全量：前台轮排除后台套件，后台轮只跑后台套件。
    macOS 14 起应用让出前台后不能强行抢回，所以两类不能混在同一个测试进程里。
    """
    background = background_suites(root)
    # 只写测试目标名（如 AreaChainTests）等于全量，不能让后台套件混进前台进程。
    if filters is not None and any("/" not in item for item in filters):
        filters = None
    if filters is None:
        rounds = [("前台轮", [arg for name in sorted(background)
                             for arg in ("--skip-testing", f"{TEST_TARGET}/{name}")])]
        if background:
            rounds.append(("后台轮", [arg for name in sorted(background)
                                     for arg in ("--only-testing", f"{TEST_TARGET}/{name}")]))
        return rounds
    def is_background(item):
        parts = item.split("/")
        return len(parts) > 1 and parts[1] in background
    rounds = []
    for label, chosen in (("前台轮", [f for f in filters if not is_background(f)]),
                          ("后台轮", [f for f in filters if is_background(f)])):
        if chosen:
            rounds.append((label, [arg for item in chosen for arg in ("--only-testing", item)]))
    return rounds


def _read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


class TestIndex:
    """一次性读入测试与源码文本，供多文件推导复用。"""

    def __init__(self, root):
        self.root = Path(root)
        test_root = self.root / TEST_TARGET
        self.tests = {path.relative_to(self.root).as_posix(): _read(path)
                      for path in sorted(test_root.rglob("*.swift"))} if test_root.is_dir() else {}

    def mentioning(self, file_name):
        """直接按文件名读取该资源的套件，例如读取 Localizable.xcstrings 的文案测试。"""
        return set().union(*(test_suites(text) for text in self.tests.values() if file_name in text))

    def same_name(self, stem):
        wanted = f"{stem}Tests.swift"
        return set().union(*(test_suites(text) for path, text in self.tests.items()
                             if Path(path).name == wanted))

    def member_mentions(self, names):
        """按扩展成员名直接匹配的套件（不展开夹具），以及因过于常见而跳过的名字。"""
        rare, common = set(), set()
        for name in names:
            pattern = re.compile(r"\b%s\b" % re.escape(name))
            files = [text for text in self.tests.values() if pattern.search(text)]
            (common if len(files) > MEMBER_FILE_LIMIT else rare).add(name)
        if not rare:
            return set(), common
        pattern = re.compile(r"\b(?:%s)\b" % "|".join(map(re.escape, sorted(rare))))
        return set().union(*(test_suites(text) for text in self.tests.values() if pattern.search(text))), common

    def referencing(self, names):
        """引用这些类型的套件；夹具文件没有套件时，用它声明的类型再找一跳。"""
        found, visited, frontier = set(), set(), set(names)
        for _ in range(SUPPORT_HOPS):
            if not frontier:
                break
            pattern = re.compile(r"\b(?:%s)\b" % "|".join(map(re.escape, sorted(frontier))))
            following = set()
            for path, text in self.tests.items():
                if path in visited or not pattern.search(text):
                    continue
                visited.add(path)
                suites = test_suites(text)
                found |= suites
                # 夹具可能单独成文件，也可能和套件写在一起；两种都再展开一跳。
                following |= shared_types(text)
            frontier = following
        return found


# 扩展成员里这些名字太通用（协议要求或 SwiftUI/AppKit 惯用名），按名字找会误命中大量测试。
_GENERIC_MEMBERS = {"body", "init", "description", "debugDescription", "hash", "encode", "makeNSView",
                    "updateNSView", "makeCoordinator", "sizeThatFits", "layout", "draw", "value", "state",
                    "title", "count", "items", "isEmpty", "id", "rawValue", "allCases"}
# 缩进一级的成员声明（含嵌套类型与 typealias）；private/fileprivate 成员测试引用不到，不作为搜索词，
# 但 private(set) 只限制写入，测试仍能读取。
_MEMBER = re.compile(
    r"^ {4}(?=\S)(?![^\n]*\b(?:private|fileprivate)\b(?!\(set\)))[^\n/]*?"
    r"\b(?:func|var|let|case|struct|class|enum|actor|typealias)\s+([A-Za-z_]\w*)", re.M)
# 表头以 "{" 结尾的顶格 extension 到下一个顶格 "}" 为一个扩展块；单行 `extension X: P {}` 没有成员，不成块。
# private/fileprivate extension 的成员测试引用不到，不收。已知限制：多行字符串里出现顶格 "}" 会提前截断扩展块。
_EXTENSION_BLOCK = re.compile(r"^(?:(?:public|internal)\s+)?extension\b[^\n]*\{[ \t]*\n(.*?)^\}", re.M | re.S)


def _member_candidates(text):
    return {name for block in _EXTENSION_BLOCK.findall(text) for name in _MEMBER.findall(block)}


def extension_members(text):
    """扩展块里缩进一级、非私有、有区分度的成员名；同文件自有类型的字段不算。"""
    return {name for name in _member_candidates(text) if name not in _GENERIC_MEMBERS and len(name) > 3}


def _changed_names(path, text):
    """变更文件声明的类型；删除的文件只能按文件名猜。扩展成员另由 extension_members 处理。"""
    if not text:
        return {Path(path).stem.split("+")[0]}
    return declared_types(text)


def _plan_file(index, path, ui_mode):
    """返回 (套件集合或 None, 说明或 None)；None 表示该文件无法推导。"""
    text = _read(index.root / path)
    is_test = path.startswith(TEST_TARGET + "/")
    if is_test:
        if not text:
            return set(), None
        # 改套件文件时，除自身套件外，还要跑经它的共享夹具间接受影响的套件。
        own = test_suites(text)
        shared = shared_types(text)
        return own | (index.referencing(shared) if shared else set()), None
    if not path.startswith(SOURCE_ROOT + "/"):
        return None, f"{path}：不在源码或测试目录"
    names = _changed_names(path, text)
    stem = Path(path).stem.split("+")[0]
    same = set() if is_test else index.same_name(stem)
    refs = index.referencing(names) if names else set()
    # 扩展文件按成员名直接匹配，不把被扩展类型的全部使用者带上，也不经夹具再展开。
    members, common = index.member_mentions(extension_members(text)) if extension_targets(text) else (set(), set())
    # 通用名、过短名与过于常见的名字一样没有用于匹配，一并写进说明，不悄悄丢弃。
    common |= _member_candidates(text) - extension_members(text)
    refs |= members
    skipped = f"；常见成员名未用于匹配：{', '.join(sorted(common))}" if common else ""
    if len(refs) > REFERENCE_SUITE_LIMIT:
        if not ui_mode:
            # 改什么测什么：只跑直接引用的套件，不再追加整层；间接使用由批次收尾的 --profile full 兜住。
            return same | refs, f"{path}：被 {len(refs)} 个测试类引用，只跑直接引用；间接影响留给收尾全量{skipped}"
        return same, f"{path}：被 {len(refs)} 个测试类引用，UI 模式只跑同名测试{skipped}"
    if same or refs:
        return same | refs, (f"{path}：{skipped[1:]}" if skipped else None)
    return None, f"{path}：没有同名或直接引用的测试，只编译{skipped}"


def plan_swift_tests(root, paths, ui_mode=False):
    """返回 {"filters": [...], "notes": [...], "unresolved": [...]}；filters 为空表示无需运行测试。"""
    swift_paths = sorted(p for p in paths if p.endswith(".swift"))
    resources = sorted(p for p in paths if p.startswith(SOURCE_ROOT + "/") and not p.endswith(".swift"))
    unresolved = sorted(p for p in paths if p.endswith(".xcodeproj/project.pbxproj"))
    notes = [f"{p}：工程配置变更无法映射到测试" for p in unresolved]
    if not swift_paths and not resources:
        return {"filters": [], "notes": notes, "unresolved": unresolved}
    index = TestIndex(root)
    suites = set()
    for path in resources:
        found = index.mentioning(Path(path).name)
        if found:
            suites |= found
        else:
            unresolved.append(path)
            notes.append(f"{path}：资源变更没有按文件名读取它的测试")
    for path in swift_paths:
        found, note = _plan_file(index, path, ui_mode)
        if note:
            notes.append(note)
        if found is None:
            unresolved.append(path)
        else:
            suites |= found
    return {"filters": [f"{TEST_TARGET}/{name}" for name in sorted(suites)],
            "notes": notes, "unresolved": unresolved}


def only_background(root, filters):
    """xcodebuild 过滤参数（-only-testing:/-skip-testing:）是否只选中后台套件；用于 build.sh 自动决定是否开前台守护。"""
    selected = [item.split(":", 1)[1] for item in filters if item.startswith("-only-testing:")]
    if not selected or len(selected) != len(filters):
        return False
    background = background_suites(root)
    return all(len(item.split("/")) > 1 and item.split("/")[1] in background for item in selected)


if __name__ == "__main__":
    import sys
    # 用法：swift_test_scope.py --background-only <xcodebuild 过滤参数…>；只选中后台套件时退出码 0。
    arguments = sys.argv[1:]
    if arguments[:1] != ["--background-only"]:
        sys.exit(2)
    sys.exit(0 if only_background(Path(__file__).resolve().parents[1], arguments[1:]) else 1)

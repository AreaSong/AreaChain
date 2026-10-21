"""按变更推导 Swift 定向测试范围；只读源码文本，不调用 Xcode。

推导分三层：同名测试 → 测试里引用了变更文件声明的类型 → 没有任何相关测试时才按所在层目录兜底。
被大量测试引用的核心文件只跑直接引用的测试，不再加整层；间接使用留给批次收尾的全量回归。
无法推导的文件单独列出，由调用方明确报告；全量只由显式 profile 触发，不在这里静默回退。
"""

from pathlib import Path
import re


TEST_TARGET = "AreaChainTests"
SOURCE_ROOT = "AreaChain"
LAYERS = ("Domain", "Services", "Features", "Theme", "E2E")
# 一个文件的引用命中超过此数时在说明里提示“影响面大”，范围仍只是直接引用。
REFERENCE_SUITE_LIMIT = 60
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


def _layer(path):
    parts = Path(path).parts
    return parts[1] if len(parts) > 2 and parts[1] in LAYERS else None


class TestIndex:
    """一次性读入测试与源码文本，供多文件推导复用。"""

    def __init__(self, root):
        self.root = Path(root)
        test_root = self.root / TEST_TARGET
        self.tests = {path.relative_to(self.root).as_posix(): _read(path)
                      for path in sorted(test_root.rglob("*.swift"))} if test_root.is_dir() else {}
        source_root = self.root / SOURCE_ROOT
        self.app_types = set()
        if source_root.is_dir():
            for path in source_root.rglob("*.swift"):
                self.app_types |= declared_types(_read(path))

    def mentioning(self, file_name):
        """直接按文件名读取该资源的套件，例如读取 Localizable.xcstrings 的文案测试。"""
        return set().union(*(test_suites(text) for text in self.tests.values() if file_name in text))

    def same_name(self, stem):
        wanted = f"{stem}Tests.swift"
        return set().union(*(test_suites(text) for path, text in self.tests.items()
                             if Path(path).name == wanted))

    def layer_suites(self, layer):
        prefix = f"{TEST_TARGET}/{layer}/"
        return set().union(*(test_suites(text) for path, text in self.tests.items() if path.startswith(prefix)))

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


def _changed_names(index, path, text):
    """变更文件声明的类型，加上它扩展的应用内类型；删除的文件只能按文件名猜。"""
    if not text:
        return {Path(path).stem.split("+")[0]}
    return declared_types(text) | (extension_targets(text) & index.app_types)


def _plan_file(index, path, layer_fallback):
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
    names = _changed_names(index, path, text)
    stem = Path(path).stem.split("+")[0]
    same = set() if is_test else index.same_name(stem)
    refs = index.referencing(names) if names else set()
    layer = _layer(path)
    if len(refs) > REFERENCE_SUITE_LIMIT:
        if layer_fallback:
            # 改什么测什么：只跑直接引用的套件，不再追加整层；间接使用由批次收尾的 --profile full 兜住。
            return same | refs, f"{path}：被 {len(refs)} 个测试类引用，只跑直接引用；间接影响留给收尾全量"
        return same, f"{path}：被 {len(refs)} 个测试类引用，UI 模式只跑同名测试"
    if same or refs:
        return same | refs, None
    if layer_fallback and layer:
        return index.layer_suites(layer), f"{path}：没有同名或引用测试，改跑 {layer} 层"
    return None, f"{path}：没有同名、引用或所在层测试"


def plan_swift_tests(root, paths, layer_fallback=True):
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
        found, note = _plan_file(index, path, layer_fallback)
        if note:
            notes.append(note)
        if found is None:
            unresolved.append(path)
        else:
            suites |= found
    return {"filters": [f"{TEST_TARGET}/{name}" for name in sorted(suites)],
            "notes": notes, "unresolved": unresolved}

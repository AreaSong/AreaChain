"""前台守护的纯函数测试；用假的命令输出，不读取或切换真实前台应用。"""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import keep_front


def reader(idle_ns, front, running):
    def read(arguments):
        if arguments[0] == "ioreg":
            return f'| |   "HIDIdleTime" = {idle_ns}\n'
        if arguments[:2] == ["lsappinfo", "front"]:
            return "ASN:0x0-0x1-\"Front\":\n"
        if arguments[:2] == ["lsappinfo", "info"]:
            return f'"CFBundleIdentifier"="{front}"\n'
        if arguments[:2] == ["lsappinfo", "find"]:
            return 'ASN:0x0-0x2-"AreaChain":\n' if running else "\n"
        return ""
    return read


QA = "com.areachain.privacy-qa"


class KeepFrontTests(unittest.TestCase):
    def activations(self, read):
        calls = []
        previous = keep_front.tick(QA, read=read, activate=lambda: calls.append(QA))
        self.assertEqual(previous is not None, bool(calls))
        return calls

    def test_activates_running_qa_app_only_when_user_is_idle(self):
        self.assertEqual(self.activations(reader(6_000_000_000, "com.anthropic.claudefordesktop", True)), [QA])

    def test_leaves_an_active_user_alone(self):
        self.assertEqual(self.activations(reader(2_000_000_000, "com.anthropic.claudefordesktop", True)), [])

    def test_does_nothing_when_qa_is_already_front_or_not_running(self):
        self.assertEqual(self.activations(reader(9_000_000_000, QA, True)), [])
        # 不在运行就不激活，避免 open -b 把 QA 应用当成新进程启动。
        self.assertEqual(self.activations(reader(9_000_000_000, "com.apple.finder", False)), [])

    def test_unreadable_idle_time_counts_as_busy(self):
        self.assertEqual(keep_front.idle_seconds(lambda _: ""), 0.0)

    def test_only_qa_identifiers_are_accepted(self):
        self.assertTrue(keep_front.is_qa_identifier("com.areachain.privacy-qa.m4"))
        for identifier in ("com.areachain.app", "com.areachain.privacy-qax", ""):
            with self.subTest(identifier=identifier):
                self.assertFalse(keep_front.is_qa_identifier(identifier))
                self.assertEqual(keep_front.main([identifier]), 2)


if __name__ == "__main__":
    unittest.main()

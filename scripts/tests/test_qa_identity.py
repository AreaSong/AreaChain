import plistlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import qa_identity


class QAIdentityTests(unittest.TestCase):
    def setUp(self):
        policy = patch.object(qa_identity.signing, "verify_app", return_value={"mode": "local"})
        self.policy = policy.start()
        self.addCleanup(policy.stop)

    def test_signed_compiled_and_packaged_identity_must_agree(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "QA.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            (app / "Contents/MacOS/AreaChain").write_bytes(b"synthetic-binary")
            info = {"CFBundleIdentifier": "com.areachain.privacy-qa.test", "AreaChainBuildIdentitySchema": "1",
                    "AreaChainBuildRole": "qa", "AreaChainQABundleIdentifier": "com.areachain.privacy-qa.test"}
            path = app / "Contents/Info.plist"
            path.write_bytes(plistlib.dumps(info))
            with patch.object(qa_identity.subprocess, "run") as signature, patch.object(
                    qa_identity.subprocess, "check_output", return_value="0001 T _AreaChainQABuildIdentityV1\n") as symbols:
                self.assertTrue(qa_identity.verify(app)["signatureVerified"])
                self.assertEqual(self.policy.call_args.args[2]["bundleIdentifier"], info["CFBundleIdentifier"])
                self.policy.side_effect = qa_identity.signing.SigningError("synthetic policy rejection")
                with self.assertRaises(qa_identity.signing.SigningError):
                    qa_identity.verify(app)
                self.policy.side_effect = None
                signature.assert_called_with(["codesign", "--verify", "--deep", "--strict", str(app.resolve())],
                                             check=True, capture_output=True)
                for key, value in [("AreaChainBuildRole", "application"), ("AreaChainBuildIdentitySchema", "9"),
                                   ("AreaChainQABundleIdentifier", "com.areachain.app"), ("CFBundleIdentifier", "com.areachain.app")]:
                    path.write_bytes(plistlib.dumps({**info, key: value}))
                    with self.assertRaises(ValueError):
                        qa_identity.verify(app)
                path.write_bytes(plistlib.dumps(info))
                with self.assertRaises(ValueError):
                    qa_identity.verify(app, "com.areachain.privacy-qa.other")
                for value in ["", "0001 T _AreaChainApplicationBuildIdentityV1\n",
                              "0001 T _AreaChainQABuildIdentityV1\n0002 T _AreaChainApplicationBuildIdentityV1\n"]:
                    symbols.return_value = value
                    with self.assertRaises(ValueError):
                        qa_identity.verify(app)

    def test_debug_dylib_is_part_of_verified_code_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "QA.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            for name in ["AreaChain", "AreaChain.debug.dylib"]:
                (app / "Contents/MacOS" / name).write_bytes(b"synthetic")
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.areachain.privacy-qa", "AreaChainBuildIdentitySchema": "1",
                "AreaChainBuildRole": "qa", "AreaChainQABundleIdentifier": "com.areachain.privacy-qa"}))
            with patch.object(qa_identity.subprocess, "run"), patch.object(qa_identity.subprocess, "check_output",
                    side_effect=["0001 T _main\n", "0001 T _AreaChainQABuildIdentityV1\n"]):
                self.assertEqual(set(qa_identity.verify(app)["codeImages"]), {"AreaChain", "AreaChain.debug.dylib"})

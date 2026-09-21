import copy
import datetime as dt
import hashlib
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import signing


def settings(mode="development"):
    return {
        "AREACHAIN_SIGNING_MODE": mode,
        "PRODUCT_BUNDLE_IDENTIFIER": "com.example.notes",
        "DEVELOPMENT_TEAM": "ABCDE12345" if mode == "development" else "",
        "CODE_SIGN_IDENTITY": "Apple Development" if mode == "development" else "-",
        "CODE_SIGN_ENTITLEMENTS": "AreaChain.SystemUnlock.entitlements" if mode == "development" else "AreaChain.entitlements",
    }


class SettingsTests(unittest.TestCase):
    def test_local_mode_has_no_system_unlock_or_distribution_claim(self):
        result = signing.validate_settings(settings("local"))
        self.assertFalse(result["systemUnlockConfigured"])
        self.assertFalse(result["distributionReady"])

    def test_development_mode_is_not_distribution_ready(self):
        result = signing.validate_settings(settings())
        self.assertTrue(result["systemUnlockConfigured"])
        self.assertFalse(result["distributionReady"])

    def test_invalid_configurations_fail_closed(self):
        invalid = {
            "AREACHAIN_SIGNING_MODE": ["unknown", None],
            "DEVELOPMENT_TEAM": ["", "YOURTEAMID", None],
            "CODE_SIGN_IDENTITY": ["-", "Developer ID Application"],
            "CODE_SIGN_ENTITLEMENTS": ["AreaChain.entitlements", ""],
            "PRODUCT_BUNDLE_IDENTIFIER": ["$(UNRESOLVED)", "com.example.yourname.areachain"],
            "CODE_SIGNING_ALLOWED": ["NO"],
        }
        for field, values in invalid.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    candidate = settings()
                    candidate[field] = value
                    with self.assertRaises(signing.SigningError):
                        signing.validate_settings(candidate)

    def test_local_mode_rejects_mixed_development_configuration(self):
        candidate = settings("local")
        candidate["DEVELOPMENT_TEAM"] = "ABCDE12345"
        with self.assertRaises(signing.SigningError):
            signing.validate_settings(candidate)


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.expected = signing.validate_settings(settings())
        self.app_id = "OLDPREFIX1.com.example.notes"
        self.now = dt.datetime(2026, 9, 16, tzinfo=dt.timezone.utc)
        self.certificate = b"synthetic-public-certificate"
        self.certificate_hash = hashlib.sha256(self.certificate).hexdigest()
        self.entitlements = {
            "com.apple.application-identifier": self.app_id,
            "com.apple.developer.team-identifier": "ABCDE12345",
            "keychain-access-groups": [self.app_id],
        }
        self.profile = {
            "UUID": "synthetic-profile",
            "TeamIdentifier": ["ABCDE12345"],
            "ExpirationDate": dt.datetime(2026, 9, 23),
            "DeveloperCertificates": [self.certificate],
            "Entitlements": {
                "com.apple.application-identifier": self.app_id,
                "keychain-access-groups": ["OLDPREFIX1.*"],
            },
        }

    def validate(self):
        return signing.validate_profile(self.profile, self.entitlements, self.expected,
                                        self.certificate_hash, self.now)

    def test_valid_profile_allows_legacy_prefix_distinct_from_team(self):
        result = self.validate()
        self.assertEqual(result["remainingHours"], 168)
        self.assertEqual(result["profileExpiresUTC"], "2026-09-23T00:00:00+00:00")

    def test_expired_and_missing_expiration_are_rejected(self):
        for expiration in (self.now, self.now - dt.timedelta(seconds=1), None):
            with self.subTest(expiration=expiration):
                self.profile["ExpirationDate"] = expiration
                with self.assertRaises(signing.SigningError):
                    self.validate()

    def test_wrong_team_is_rejected(self):
        self.profile["TeamIdentifier"] = ["OTHER12345"]
        with self.assertRaises(signing.SigningError):
            self.validate()

    def test_wrong_signed_team_is_rejected(self):
        self.entitlements["com.apple.developer.team-identifier"] = "OTHER12345"
        with self.assertRaises(signing.SigningError):
            self.validate()

    def test_wrong_application_allowlist_is_rejected(self):
        self.profile["Entitlements"]["com.apple.application-identifier"] = "OLDPREFIX1.com.other.app"
        with self.assertRaises(signing.SigningError):
            self.validate()

    def test_foreign_or_additional_keychain_group_is_rejected(self):
        for groups in (["OTHER12345.other"], [self.app_id, "OLDPREFIX1.other"]):
            with self.subTest(groups=groups):
                self.entitlements["keychain-access-groups"] = groups
                with self.assertRaises(signing.SigningError):
                    self.validate()

    def test_profile_must_authorize_the_app_keychain_group(self):
        self.profile["Entitlements"]["keychain-access-groups"] = ["OTHER12345.*"]
        with self.assertRaises(signing.SigningError):
            self.validate()

    def test_signing_certificate_must_be_in_profile(self):
        self.profile["DeveloperCertificates"] = [b"another-public-certificate"]
        with self.assertRaises(signing.SigningError):
            self.validate()

    def test_validation_does_not_modify_input(self):
        original = copy.deepcopy(self.profile)
        self.validate()
        self.assertEqual(original, self.profile)


class ReleaseTests(unittest.TestCase):
    def test_local_mode_reports_runtime_limit_without_relaxing_development(self):
        metadata = signing.parse_signature("CodeDirectory v=20500 flags=0x2(adhoc)")
        self.assertFalse(signing.validate_hardening(metadata, "local"))
        with self.assertRaises(signing.SigningError):
            signing.validate_hardening(metadata, "development")

    def test_development_requirement_uses_inline_expression_not_a_file(self):
        with mock.patch.object(signing, "run_tool") as tool:
            signing.verify_development_anchor(Path("/example/AreaChain.app"), "ABCDE12345")
        arguments = tool.call_args.args[0]
        self.assertEqual(arguments[3], "-R")
        self.assertEqual(arguments[4], '=anchor apple generic and certificate leaf[subject.OU] = "ABCDE12345"')

    def test_development_requirement_rejects_invalid_team_before_running_tool(self):
        with mock.patch.object(signing, "run_tool") as tool:
            with self.assertRaises(signing.SigningError):
                signing.verify_development_anchor(Path("/example/AreaChain.app"), 'invalid"')
        tool.assert_not_called()

    def test_certificate_export_uses_the_optional_argument_form_and_cleans_up(self):
        certificate = b"synthetic-public-certificate"
        exported = []

        def export(arguments):
            self.assertTrue(arguments[2].startswith("--extract-certificates="))
            path = Path(arguments[2].split("=", 1)[1] + "0")
            path.write_bytes(certificate)
            exported.append(path)

        with mock.patch.object(signing, "run_tool", side_effect=export):
            result = signing.certificate_hash(Path("/example/AreaChain.app"))
        self.assertEqual(result, hashlib.sha256(certificate).hexdigest())
        self.assertFalse(exported[0].exists())

    def test_release_accepts_normal_sandbox_permissions(self):
        signing.validate_release({"com.apple.security.app-sandbox": True}, ["Contents/MacOS/AreaChain"])

    def test_release_rejects_debug_or_temporary_permissions(self):
        for key in ("get-task-allow", "com.apple.security.get-task-allow",
                    "com.apple.security.temporary-exception.files.absolute-path.read-only"):
            with self.subTest(key=key), self.assertRaises(signing.SigningError):
                signing.validate_release({key: True}, [])

    def test_release_rejects_test_bundles_and_frameworks(self):
        for path in ("Contents/PlugIns/AreaChainTests.xctest", "Contents/Frameworks/XCTest.framework",
                     "Contents/Frameworks/Testing.framework"):
            with self.subTest(path=path), self.assertRaises(signing.SigningError):
                signing.validate_release({}, [path])

    def test_runtime_must_be_a_code_directory_flag(self):
        valid = signing.parse_signature("CodeDirectory v=20500 size=5 flags=0x10002(adhoc,runtime) hashes=3")
        self.assertTrue(signing.has_hardened_runtime(valid))
        misleading = signing.parse_signature("Executable=/tmp/runtime/AreaChain\nCodeDirectory v=20500 flags=0x2(adhoc)")
        self.assertFalse(signing.has_hardened_runtime(misleading))

    def test_multi_architecture_requires_all_directories_to_have_runtime(self):
        both_runtime = signing.parse_signature(
            "CodeDirectory v=20500 flags=0x10000(runtime)\nCodeDirectory v=20400 flags=0x10000(runtime)"
        )
        self.assertTrue(signing.has_hardened_runtime(both_runtime))
        partial_runtime = signing.parse_signature(
            "CodeDirectory v=20500 flags=0x10000(runtime)\nCodeDirectory v=20400 flags=0x2(adhoc)"
        )
        self.assertFalse(signing.has_hardened_runtime(partial_runtime))


if __name__ == "__main__":
    unittest.main()

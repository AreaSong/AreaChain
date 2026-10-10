"""只读核验新 QA 包；签名、编译标识和 plist 必须同时匹配，不补写旧包。"""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys


def verify(app, expected_identifier=None):
    app = Path(app).resolve(strict=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    identifier = info.get("CFBundleIdentifier", "")
    if not (identifier == "com.areachain.privacy-qa" or identifier.startswith("com.areachain.privacy-qa.")):
        raise ValueError("不是明确的 QA 标识")
    if expected_identifier is not None and identifier != expected_identifier:
        raise ValueError("QA 标识与本批不符")
    if (info.get("AreaChainBuildIdentitySchema") != "1" or info.get("AreaChainBuildRole") != "qa"
            or info.get("AreaChainQABundleIdentifier") != identifier):
        raise ValueError("QA 构建身份缺失或矛盾")
    binary = app / "Contents/MacOS/AreaChain"
    # 新版 Xcode 的 Debug 执行器将应用代码放在同签名包的 debug.dylib；两种装配均需检查。
    images = [binary]
    debug = binary.with_name("AreaChain.debug.dylib")
    if debug.is_file():
        images.append(debug)
    symbols = "\n".join(subprocess.check_output(["nm", "-g", str(image)], text=True) for image in images)
    names = {line.split()[-1] for line in symbols.splitlines() if line.split()}
    if "_AreaChainQABuildIdentityV1" not in names or "_AreaChainApplicationBuildIdentityV1" in names:
        raise ValueError("QA 编译身份缺失或矛盾")
    return {"schema": 1, "role": "qa", "bundleIdentifier": identifier,
            "compiledIdentity": "AreaChainQABuildIdentityV1", "signatureVerified": True,
            "codeImages": {image.name: hashlib.sha256(image.read_bytes()).hexdigest() for image in images},
            "executableSHA256": hashlib.sha256(binary.read_bytes()).hexdigest()}


if __name__ == "__main__":
    try:
        print(json.dumps(verify(sys.argv[1]), sort_keys=True))
    except (OSError, ValueError, subprocess.CalledProcessError):
        print("QA 构建身份核验失败", file=sys.stderr)
        sys.exit(1)

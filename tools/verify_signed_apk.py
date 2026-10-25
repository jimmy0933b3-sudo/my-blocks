#!/usr/bin/env python3
"""Fail the build unless the APK matches the user-provided signing certificate."""
import hashlib
import os
from pathlib import Path
import re
import ssl
import subprocess


def run(*args: str) -> str:
    return subprocess.run(
        args, check=True, capture_output=True, text=True
    ).stdout


def main() -> None:
    required = ("KEY_ALIAS", "KEYSTORE_PASSWORD", "ANDROID_HOME", "RUNNER_TEMP")
    missing = [key for key in required if not os.environ.get(key)]
    if missing:
        raise SystemExit("Missing signing verification inputs: " + ", ".join(missing))

    tmp = Path(os.environ["RUNNER_TEMP"])
    apk = Path("build/MyBlocks-signed.apk")
    if not apk.is_file() or apk.stat().st_size == 0:
        raise SystemExit("The signed APK is missing")

    sdk = Path(os.environ["ANDROID_HOME"]) / "build-tools" / "35.0.0"
    checked = run(str(sdk / "apksigner"), "verify", "--verbose", "--print-certs", str(apk))
    match = re.search(
        r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]{64})",
        checked,
    )
    if not match:
        raise SystemExit("apksigner did not return a valid signer SHA-256 digest")

    certificate = run(
        "keytool",
        "-exportcert", "-rfc",
        "-keystore", str(tmp / "my-blocks-release.p12"),
        "-storepass:env", "KEYSTORE_PASSWORD",
        "-alias", os.environ["KEY_ALIAS"],
    )
    pem = re.search(
        r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
        certificate, re.DOTALL,
    )
    if not pem:
        raise SystemExit("The keystore has no readable certificate")
    expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem.group(0))).hexdigest()
    actual = match.group(1).lower()
    if expected != actual:
        raise SystemExit("APK signing certificate does not match the supplied keystore")

    info = run(str(sdk / "aapt"), "dump", "badging", str(apk))
    pkg = re.search(
        r"^package:\s+name='([^']+)'\s+versionCode='([0-9]+)'",
        info, re.MULTILINE,
    )
    if not pkg or pkg.group(1) != "com.jimmy0933.myblocks":
        raise SystemExit("Android package ID changed unexpectedly")
    if int(pkg.group(2)) != 1000 + int(os.environ["GITHUB_RUN_NUMBER"]):
        raise SystemExit(f"APK versionCode {pkg.group(2)} did not match CI expected {1000 + int(os.environ['GITHUB_RUN_NUMBER'])}")

    message = (
        "Package: " + pkg.group(1) + "\n"
        "Version code: " + pkg.group(2) + "\n"
        "Certificate SHA-256: " + expected + "\n"
        "Note: Public certificate fingerprint only, never private keys.\n"
    )
    Path("build/SIGNING-INFO.txt").write_text(message, encoding="utf-8")
    print("APK signed by supplied keystore (SHA-256): " + expected)
    print("Android package ID and version code verified")


if __name__ == "__main__":
    main()

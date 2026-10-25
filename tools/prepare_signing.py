#!/usr/bin/env python3
"""Restore the user's signing secret securely and make a monotonically versioned APK.

This is used only in trusted GitHub Actions branch builds. The private key is
not printed, not checked in, and not made available to PR workflows.
"""
import base64
import os
from pathlib import Path
import re
import subprocess
import sys


def main() -> None:
    required = ("KEYSTORE_BASE64", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing GitHub repository secret(s): " + ", ".join(missing))

    b64 = "".join(os.environ["KEYSTORE_BASE64"].split())
    try:
        content = base64.b64decode(b64, validate=True)
    except ValueError as exc:
        raise SystemExit("KEYSTORE_BASE64 is not valid Base64") from exc
    if len(content) < 300:
        raise SystemExit("KEYSTORE_BASE64 decoded to an unexpectedly short keystore")

    temp = Path(os.environ["RUNNER_TEMP"])
    original = temp / "my-blocks-original.jks"
    normalized = temp / "my-blocks-release.p12"
    original.write_bytes(content)
    original.chmod(0o600)
    alias = os.environ["KEY_ALIAS"]
    try:
        # Godot accepts one keystore password for the release key, whereas JKS
        # allows separate store and private key passwords. Keytool rewraps the
        # SAME private key + certificate into a temporary PKCS12 with one pass.
        subprocess.run(
            [
                "keytool",
                "-importkeystore",
                "-srckeystore", str(original),
                "-srcstorepass:env", "KEYSTORE_PASSWORD",
                "-srcalias", alias,
                "-srckeypass:env", "KEY_PASSWORD",
                "-destkeystore", str(normalized),
                "-deststoretype", "PKCS12",
                "-deststorepass:env", "KEYSTORE_PASSWORD",
                "-destkeypass:env", "KEYSTORE_PASSWORD",
                "-destalias", alias,
                "-noprompt",
            ],
            check=True,
        )
        normalized.chmod(0o600)
    finally:
        original.unlink(missing_ok=True)

    preset = Path("export_presets.cfg")
    body = preset.read_text(encoding="utf-8")
    run = int(os.environ["GITHUB_RUN_NUMBER"])
    code = 1000 + run
    if code < 2 or code > 2_100_000_000:
        raise SystemExit("Invalid generated Android version code")

    body, count = re.subn(
        r'(?m)^version/code=[0-9]+[ \t]*' + '$',
        f"version/code={code}", body,
    )
    if count != 1:
        raise SystemExit("Could not update version/code")
    body, count = re.subn(
        r'(?m)^version/name="[^"]+"[ \t]*' + '$',
        f'version/name="0.1.{run}"', body,
    )
    if count != 1:
        raise SystemExit("Could not update version/name")
    preset.write_text(body, encoding="utf-8")
    print(f"Fixed keystore ready. versionCode={code}, versionName=0.1.{run}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError:
        raise SystemExit("Cannot read the supplied keystore, alias or private key") from None

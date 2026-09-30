#!/usr/bin/env python3
"""Pre-release safety checks for Kiln Keeper (runs on ubuntu-latest).

Verifies the release-critical invariants without touching Apple signing:
bundle identity, platform floor, App-Store-review safety (no http:// URLs,
no analytics/tracking SDK imports, no external-open calls), and the
non-exempt-encryption declaration. Fails loudly on any violation.
"""

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPECTED_BUNDLE = "app.kilnkeeper.game"
EXPECTED_DISPLAY_NAME = "Kiln Keeper"
MIN_DEPLOYMENT = (17, 0)

# Third-party SDKs that would violate the zero-data-collection promise.
# NOTE: GoogleMobileAds is intentionally NOT banned — it is the app's ad
# network (rewarded + interstitial), added in milestone 2. No other
# analytics/tracking SDKs are allowed.
BANNED_IMPORTS = [
    "Firebase",
    "AppTrackingTransparency",
    "AdSupport",
    "Facebook",
    "Amplitude",
    "Mixpanel",
]

# AdMob test IDs that must never ship in a Release build. The check below
# only verifies presence of the app ID key; replacing test IDs with real
# ones is a documented manual step in README ("Monetization setup").
ADMOB_TEST_APP_ID = "ca-app-pub-3940256099942544~3347511713"

failures = []


def check(condition, message):
    print(("PASS" if condition else "FAIL") + ": " + message)
    if not condition:
        failures.append(message)


def main():
    info_path = ROOT / "KilnKeeper" / "Info.plist"
    check(info_path.exists(), "KilnKeeper/Info.plist exists")
    if info_path.exists():
        with info_path.open("rb") as fh:
            info = plistlib.load(fh)
        check(info.get("CFBundleDisplayName") == EXPECTED_DISPLAY_NAME,
              f"CFBundleDisplayName == {EXPECTED_DISPLAY_NAME}")
        check(info.get("ITSAppUsesNonExemptEncryption") is False,
              "ITSAppUsesNonExemptEncryption is false (no export-compliance prompt)")
        orientations = info.get("UISupportedInterfaceOrientations", [])
        check(orientations == ["UIInterfaceOrientationPortrait"],
              "portrait-only orientations declared")
        check(info.get("GADApplicationIdentifier") == ADMOB_TEST_APP_ID,
              "GADApplicationIdentifier present (AdMob test ID — Henry must "
              "replace with the real AdMob App ID before release; see README)")

    pbx = ROOT / "KilnKeeper.xcodeproj" / "project.pbxproj"
    check(pbx.exists(), "KilnKeeper.xcodeproj/project.pbxproj exists")
    if pbx.exists():
        text = pbx.read_text()
        check(f"PRODUCT_BUNDLE_IDENTIFIER = {EXPECTED_BUNDLE};" in text,
              f"bundle identifier {EXPECTED_BUNDLE} present in project")
        m = re.search(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9]+)\.([0-9]+);", text)
        if m:
            ver = (int(m.group(1)), int(m.group(2)))
            check(ver >= MIN_DEPLOYMENT, f"deployment target {ver} >= 17.0")
        else:
            check(False, "IPHONEOS_DEPLOYMENT_TARGET found in project")

    swift_files = sorted((ROOT / "KilnKeeper").rglob("*.swift"))
    check(len(swift_files) > 0, f"Swift sources present ({len(swift_files)} files)")
    for path in swift_files:
        rel = path.relative_to(ROOT)
        src = path.read_text()
        for banned in BANNED_IMPORTS:
            if re.search(rf"^\s*import\s+{re.escape(banned)}\b", src, re.M):
                check(False, f"{rel}: banned import {banned}")
        for match in re.finditer(r"https?://[^\s\"']+", src):
            url = match.group(0)
            if url.startswith("http://"):
                check(False, f"{rel}: non-https URL {url}")
        if "UIApplication.shared.open" in src:
            check(False, f"{rel}: external URL open() call (no web links allowed)")

    # .github/workflows is deliberately NOT in the repo (GitHub only lets the
    # repo owner grant the `workflows` permission). The release workflow lives
    # at ~/workspace/your_files/kilnkeeper-apple-release.yml and Henry uploads
    # it via the GitHub web UI when he's ready for TestFlight.
    gh_workflows = ROOT / ".github" / "workflows"
    check(not gh_workflows.exists(),
          "no .github/workflows in the repo (blocked: owner-only permission)")

    if failures:
        print(f"\nKILNKEEPER-RELEASE-CHECK: {len(failures)} FAILURE(S)")
        sys.exit(1)
    print("\nKILNKEEPER-RELEASE-CHECK: PASS")


if __name__ == "__main__":
    main()

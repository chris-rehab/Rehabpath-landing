#!/usr/bin/env python3
"""Static App Store / data-governance gate for the RehabPath iOS app.

Runs anywhere (no Xcode needed) so agents and Linux CI can enforce the rules in
ios/docs/APP_STORE_READINESS.md and ios/docs/DATA_GOVERNANCE.md before a macOS build.

Usage: python3 ios/scripts/compliance_check.py        (exit code 1 on any failure)
"""
from __future__ import annotations

import plistlib
import re
import struct
import sys
from pathlib import Path

IOS = Path(__file__).resolve().parent.parent
APP = IOS / "RehabPath"
CORE = IOS / "Packages" / "RehabPathCore" / "Sources"
RESOURCES = APP / "Resources"

failures: list[str] = []
passes: list[str] = []


def check(ok: bool, message: str) -> None:
    (passes if ok else failures).append(message)


def swift_sources(*roots: Path) -> dict[Path, str]:
    return {p: p.read_text(encoding="utf-8") for root in roots for p in sorted(root.rglob("*.swift"))}


def string_literals(source: str) -> list[str]:
    return re.findall(r'"((?:[^"\\\n]|\\.)*)"', source)


production = swift_sources(APP, CORE)
all_text = "\n".join(production.values())

# 1. Privacy manifest (required since May 2024) -------------------------------------------
manifest_path = RESOURCES / "PrivacyInfo.xcprivacy"
check(manifest_path.exists(), "PrivacyInfo.xcprivacy exists")
manifest = plistlib.loads(manifest_path.read_bytes()) if manifest_path.exists() else {}
check(manifest.get("NSPrivacyTracking") is False, "Privacy manifest declares NSPrivacyTracking = false")
for key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"):
    check(isinstance(manifest.get(key), list), f"Privacy manifest has {key}")

declared_api = {entry.get("NSPrivacyAccessedAPIType") for entry in manifest.get("NSPrivacyAccessedAPITypes", [])}
required_reason_apis = {
    "NSPrivacyAccessedAPICategoryUserDefaults": r"\bUserDefaults\b|@AppStorage|@SceneStorage",
    "NSPrivacyAccessedAPICategoryFileTimestamp": r"creationDate|modificationDate|contentModificationDateKey|\.attributesOfItem",
    "NSPrivacyAccessedAPICategorySystemBootTime": r"systemUptime|mach_absolute_time",
    "NSPrivacyAccessedAPICategoryDiskSpace": r"volumeAvailableCapacity|systemFreeSize|\.statfs\b",
    "NSPrivacyAccessedAPICategoryActiveKeyboards": r"activeInputModes",
}
for category, pattern in required_reason_apis.items():
    if re.search(pattern, all_text):
        check(category in declared_api, f"Required-reason API used → {category} declared in privacy manifest")

# 2. Info.plist ------------------------------------------------------------------------------
info = plistlib.loads((RESOURCES / "Info.plist").read_bytes())
check("ITSAppUsesNonExemptEncryption" in info, "Info.plist declares ITSAppUsesNonExemptEncryption (export compliance)")
ats = info.get("NSAppTransportSecurity", {})
check(not ats.get("NSAllowsArbitraryLoads", False), "App Transport Security is not disabled")

usage_strings = {
    "HealthKit": ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"],
    "CoreLocation": ["NSLocationWhenInUseUsageDescription"],
    "AVFoundation": ["NSCameraUsageDescription"],
    "PhotosUI": [],  # PHPicker needs no permission — prefer it.
    "Photos": ["NSPhotoLibraryUsageDescription"],
    "Contacts": ["NSContactsUsageDescription"],
    "AppTrackingTransparency": ["NSUserTrackingUsageDescription"],
}
for framework, keys in usage_strings.items():
    if re.search(rf"^\s*import\s+{framework}\b", all_text, re.M):
        for key in keys:
            check(bool(info.get(key)), f"import {framework} → Info.plist has {key}")

# 3. No tracking, ads or third-party analytics (governance §7.5) -----------------------------
for banned in ("AdSupport", "AppTrackingTransparency", "FirebaseAnalytics", "FirebaseCrashlytics",
               "FacebookCore", "FBSDKCoreKit", "Mixpanel", "Amplitude", "Segment", "AppsFlyerLib"):
    check(not re.search(rf"^\s*import\s+{banned}\b", all_text, re.M), f"No {banned} import")
check("ASIdentifierManager" not in all_text, "No advertising identifier access")

# 4. No secrets in the iOS tree --------------------------------------------------------------
secret_patterns = {
    "JWT / Supabase key": r"eyJhbGciOi[A-Za-z0-9_\-]{10,}",
    "AWS access key": r"AKIA[0-9A-Z]{16}",
    "Stripe live key": r"sk_live_[0-9a-zA-Z]{10,}",
    "Private key block": r"-----BEGIN (?:RSA |EC )?PRIVATE KEY-----",
}
scanned = [p for p in IOS.rglob("*") if p.is_file() and p.suffix in {".swift", ".plist", ".json", ".yml", ".xcconfig", ".md"}]
for label, pattern in secret_patterns.items():
    hits = [str(p.relative_to(IOS)) for p in scanned if re.search(pattern, p.read_text(errors="ignore"))]
    check(not hits, f"No {label} committed" + (f" (found in {', '.join(hits)})" if hits else ""))

# 5. No health data in logs (governance §7.3) ------------------------------------------------
print_hits = [str(p.relative_to(IOS)) for p, src in production.items()
              if re.search(r"(?<![\w.])(print|debugPrint|NSLog|dump)\(", src)]
check(not print_hits, "No print/NSLog/dump in app code" + (f" (found in {', '.join(print_hits)})" if print_hits else ""))
log_hits = [f"{p.relative_to(IOS)}: {m.group(0)[:60]}" for p, src in production.items()
            for m in re.finditer(r"\b(?:log|logger|Logger\([^)]*\))\.\w+\(([^\n]*)\)", src) if "\\(" in m.group(1)]
check(not log_hits, "Logger calls have no interpolated values" + (f" ({'; '.join(log_hits)})" if log_hits else ""))

# 6. Health claims and copy standards (App Review 1.4.1, ARCHITECTURE.md §7) ------------------
banned_claims = [r"clinically (?:proven|validated|approved)", r"\bcures?\b", r"\bguarantee", r"\bdiagnos(?:e|es|is) your\b",
                 r"\bmedical device\b", r"\bFDA\b", r"\bMedsafe approved\b"]
claim_hits = [f"{p.relative_to(IOS)}: \"{lit[:50]}\"" for p, src in production.items()
              for lit in string_literals(src) if any(re.search(c, lit, re.I) for c in banned_claims)]
check(not claim_hits, "No overstated health claims in UI copy" + (f" ({'; '.join(claim_hits)})" if claim_hits else ""))

# 7. Patient rights are reachable in-app (HIPC rules 6 & 7; App Review 5.1.1) ------------------
privacy_view = (APP / "Features" / "Privacy" / "PrivacyView.swift").read_text()
check("ShareLink" in privacy_view and "exportJSON" in privacy_view, "Privacy tab offers data export")
check("deleteAllData" in privacy_view and "role: .destructive" in privacy_view, "Privacy tab offers delete-all with destructive confirmation")
check("privacyPolicyURL" in privacy_view, "Privacy tab links to privacy policy")
config = (APP / "App" / "AppConfig.swift").read_text()
check(all(u.startswith("https://") for u in re.findall(r'URL\(string: "([^"]+)"', config)), "Config URLs use HTTPS")

# 8. Notifications never carry health details (governance §7.4) -------------------------------
reminders = (APP / "App" / "Reminders.swift").read_text()
body = re.findall(r'content\.(?:title|body|subtitle) = "([^"]*)"', reminders)
check(bool(body) and all("\\(" not in b for b in body), "Notification text is static (no interpolated patient data)")
check(not re.search(r"pain|injur|knee|physio", " ".join(body), re.I), "Notification text has no health terms")

# 9. Storage protections (governance §7.1–7.2) -----------------------------------------------
store = (CORE / "RehabPathCore" / "DataStore.swift").read_text()
check(".completeFileProtection" in store, "Data file written with complete file protection")
check("isExcludedFromBackup = true" in store, "Data file excluded from backup")
check("NSUbiquitousKeyValueStore" not in all_text and "CKContainer" not in all_text, "No iCloud storage of health data")

# 10. App icon: 1024×1024, opaque -----------------------------------------------------------
icon = RESOURCES / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
if icon.exists():
    header = icon.read_bytes()[:33]
    width, height, _, color_type = struct.unpack(">IIBB", header[16:26])
    check((width, height) == (1024, 1024), "App icon is 1024×1024")
    check(color_type in (0, 2), "App icon has no alpha channel")
else:
    check(False, "App icon exists")

# Report -------------------------------------------------------------------------------------
for message in failures:
    print(f"FAIL  {message}")
print(f"\n{len(passes)} passed, {len(failures)} failed")
sys.exit(1 if failures else 0)

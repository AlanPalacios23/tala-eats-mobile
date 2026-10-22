#!/usr/bin/env python3
"""Offline release readiness: no secrets, no network, no optimistic GO.

It checks actual files on disk, NOT the status of Node.js staging, Stripe,
Google Play App Signing or physical Android device tests.
"""
from __future__ import annotations
import argparse
import json
import sys

import build_signed_play_bundle as aab
import verify_landing_assets as hd
import verify_play_store_media as listing


def review() -> dict[str, object]:
    result: dict[str, object] = {
        "application": "Tala Eats Usuarios",
        "release": "1.0.41+52",
        "package": "com.talaeats.app",
        "target_api_expected": 36,
        "source": "BLOCKED",
        "original_hd": "BLOCKED",
        "play_listing_hd": "BLOCKED",
        # Must be verified only by trusted external/manual evidence.
        "signed_aab": "NOT_VERIFIED",
        "node_staging_e2e": "NOT_VERIFIED",
        "stripe_test_e2e": "NOT_VERIFIED",
        "admin_support_replies": "NOT_VERIFIED",
        "device_16kb_test": "NOT_VERIFIED",
        "privacy_and_play_review": "NOT_VERIFIED",
    }
    errors: list[str] = []
    try:
        aab.check_source()
        result["source"] = "PASS"
    except (OSError, AssertionError, RuntimeError) as exc:
        errors.append("fuente Android: " + str(exc))
    failed = []
    for name, (digest, length) in hd.EXPECTED.items():
        try:
            hd.validate(name, digest, length)
        except (OSError, ValueError) as exc:
            failed.append(str(exc))
    if not failed:
        result["original_hd"] = "PASS"
    else:
        errors.extend(failed)
    play_issues = listing.inspect_listing()
    if not play_issues:
        result["play_listing_hd"] = "PASS"
    else:
        errors.extend(play_issues)
    result["offline_assets_ready"] = (
        result["source"] == "PASS"
        and result["original_hd"] == "PASS"
        and result["play_listing_hd"] == "PASS"
    )
    result["release_ready"] = False
    result["reason"] = (
        "Este control local nunca confirma E2E, firma ni aprobación Play; "
        "requiere evidencias manuales y de servicios para autorización."
    )
    result["asset_errors"] = errors
    return result


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true", required=True)
    args = p.parse_args()
    report = review()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if report["offline_assets_ready"]:
        print("RC4_OFFLINE_ASSETS_PASS; publicación pendiente de E2E y Play", file=sys.stderr)
        return 0
    print("RC4_OFFLINE_ASSETS_BLOCKED: faltan recursos; NO PUBLICAR", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

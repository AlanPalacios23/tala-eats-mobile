#!/usr/bin/env python3
"""Unauthenticated, READ-ONLY observability of real Tala Eats API.

No auth credentials, account IDs, writes, webhooks, checkout, bank or payouts.
Reachability status is NOT equivalent to user E2E or a certified deployment.
A WAF block / missing backend feature is reported separately from Flutter CI.
"""
import json
import urllib.error
import urllib.request

BASE = "https://talaeats.alan-palacios-dev.com/api/v1"
CHECKS = (
    ("ready", "/ready"),
    ("market_tala", "/restaurants?market_code=TALA-JAL&limit=25&offset=0"),
    ("market_ameca", "/restaurants?market_code=AMECA-JAL&limit=25&offset=0"),
    ("fcm_config", "/mobile-push/config"),
    ("anonymous_orders", "/orders/mine"),
    ("anonymous_devices", "/auth/devices"),
    ("anonymous_addresses", "/platform/addresses"),
)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def get_json(path):
    assert path.startswith("/") and "://" not in path
    req = urllib.request.Request(
        BASE + path,
        headers={"Accept": "application/json", "X-TalaEats-Client": "mobile",
                 "User-Agent": "TalaEats-Users-GithubQA-ReadOnly/1.0"},
        method="GET",
    )
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(req, timeout=7) as resp:
            data = resp.read(120_000)
            # Don't log raw content; production may contain sensitive fields.
            if resp.headers.get("content-type", "").lower().split(";")[0] != "application/json":
                return resp.status, None
            try:
                return resp.status, json.loads(data)
            except (UnicodeDecodeError, ValueError):
                return resp.status, None
    except urllib.error.HTTPError as exc:
        code = exc.code
        exc.close()
        return code, None
    except (OSError, TimeoutError, ValueError):
        return 0, None


def evaluate(label, code, data):
    if code == 0:
        return "UNREACHABLE"
    if code in (401, 403):
        if label.startswith("anonymous_"):
            return "PASS_NO_ANON_ACCESS" if code == 401 else "BLOCKED_OR_FORBIDDEN"
        return "BLOCKED"
    if code != 200:
        return "HTTP_" + str(code)
    if label == "ready":
        return ("PASS" if isinstance(data, dict) and
                all(data.get(k) is True for k in ("ready", "database", "redis"))
                else "NOT_CERTIFIED")
    if label.startswith("market_"):
        if not isinstance(data, list):
            return "BAD_CATALOG"
        target = "TALA-JAL" if label == "market_tala" else "AMECA-JAL"
        if any(not isinstance(row, dict) or
               row.get("market_code", "").upper() != target for row in data):
            return "FAIL_MIXED_MARKET"
        # No merchants is inconclusive, NOT evidence region is deployed.
        return "PASS_OBSERVED" if data else "EMPTY_INCONCLUSIVE"
    if label == "fcm_config":
        if not isinstance(data, dict):
            return "BAD_CONFIG"
        return "ENABLED_NOT_DELIVERY_TEST" if data.get("enabled") is True else "OFF"
    if label.startswith("anonymous_"):
        return "FAIL_UNAUTHORIZED_DATA_ENDPOINT"
    return "UNKNOWN"


def main():
    # Show only check name, HTTP status and sanitized code. No body, token,
    # merchant name, user identity, financial provider data or address.
    output = {}
    for label, path in CHECKS:
        code, data = get_json(path)
        result = evaluate(label, code, data)
        output[label] = {"status": code, "result": result}
        print(f"READONLY_QA {label} HTTP_{code} {result}", flush=True)
    print("READONLY_QA_SUMMARY " + json.dumps(output, sort_keys=True))
    print("READONLY_QA_LIMITATION: no authentication, app E2E, FCM delivery, "
          "provider TEST or Kali proof; no LIVE writes.")


if __name__ == "__main__":
    main()

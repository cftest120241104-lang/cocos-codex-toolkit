import json
import re
import sys
from collections import Counter
from pathlib import Path


EVENT_METHODS = {
    "Runtime.consoleAPICalled",
    "Console.messageAdded",
    "Runtime.exceptionThrown",
    "Log.entryAdded",
}

ASSET_RE = re.compile(
    r'The Asset used by component "([^"]+)" in (scene|prefab) "([^"]+)" is missing\.\s*'
    r'Detailed information:\s*'
    r'Node path: "([^"]+)"\s*'
    r'Asset url: "([^"]+)"\s*'
    r'Missing uuid: "([^"]+)"',
    re.S,
)

EXCEPTION_RE = re.compile(
    r"TypeError|ReferenceError|SyntaxError|load script .* failed|Cannot set property",
    re.I,
)

ALLOWLIST_RE = [
    re.compile(r"codex-cdp-smoke-test"),
    re.compile(r"Timer 'scene:reloading' does not exist"),
    re.compile(r"Port \d+ is in use, trying"),
]


def simplify(raw: str):
    try:
        message = json.loads(raw)
    except Exception:
        return None

    method = message.get("method")
    if method not in EVENT_METHODS:
        return None

    if method == "Runtime.consoleAPICalled":
        parts = []
        for arg in message.get("params", {}).get("args", []):
            if arg.get("value") is not None:
                parts.append(str(arg["value"]))
            elif arg.get("description") is not None:
                parts.append(str(arg["description"]))
            else:
                parts.append(str(arg.get("type")))
        return {
            "method": method,
            "level": message.get("params", {}).get("type"),
            "source": "runtime",
            "text": " | ".join(parts),
        }

    if method == "Console.messageAdded":
        msg = message.get("params", {}).get("message", {})
        return {
            "method": method,
            "level": msg.get("level"),
            "source": msg.get("source"),
            "text": msg.get("text"),
        }

    if method == "Runtime.exceptionThrown":
        details = message.get("params", {}).get("exceptionDetails", {})
        exc = details.get("exception", {}) or {}
        return {
            "method": method,
            "level": "exception",
            "source": "runtime",
            "text": exc.get("description") or details.get("text"),
        }

    entry = message.get("params", {}).get("entry", {})
    return {
        "method": method,
        "level": entry.get("level"),
        "source": entry.get("source"),
        "text": entry.get("text"),
    }


def normalize_issue(event: dict, scope: str):
    text = event.get("text") or ""
    match = ASSET_RE.search(text)
    if match:
        return {
            "type": "asset-missing",
            "currentAsset": scope,
            "component": match.group(1),
            "ownerType": match.group(2),
            "ownerName": match.group(3),
            "nodePath": match.group(4),
            "assetUrl": match.group(5),
            "missingUuid": match.group(6),
            "message": text,
        }

    if "object already destroyed" in text:
        return {
            "type": "destroyed-object",
            "currentAsset": scope,
            "summary": first_line(text),
            "message": text,
        }

    if EXCEPTION_RE.search(text):
        return {
            "type": "exception",
            "currentAsset": scope,
            "summary": first_line(text),
            "message": text,
        }

    return None


def first_line(text: str) -> str:
    return text.strip().splitlines()[0] if text.strip() else ""


def is_allowlisted(event: dict) -> bool:
    text = event.get("text") or ""
    return any(pattern.search(text) for pattern in ALLOWLIST_RE)


def issue_key(issue: dict) -> str:
    issue_type = issue["type"]
    if issue_type == "asset-missing":
        return "|".join(
            [
                issue_type,
                issue.get("ownerType") or "",
                issue.get("ownerName") or "",
                issue.get("component") or "",
                issue.get("nodePath") or "",
                issue.get("assetUrl") or "",
                issue.get("missingUuid") or "",
            ]
        )

    return "|".join(
        [
            issue_type,
            issue.get("summary") or first_line(issue.get("message") or ""),
            issue.get("currentAsset") or "",
        ]
    )


def build_issue_view(issue: dict) -> dict:
    if issue["type"] == "asset-missing":
        return {
            "type": issue["type"],
            "component": issue["component"],
            "ownerType": issue["ownerType"],
            "ownerName": issue["ownerName"],
            "nodePath": issue["nodePath"],
            "assetUrl": issue["assetUrl"],
            "missingUuid": issue["missingUuid"],
            "message": issue["message"],
        }

    return {
        "type": issue["type"],
        "summary": issue.get("summary") or first_line(issue.get("message") or ""),
        "message": issue["message"],
    }


def merge_issue(existing: dict | None, issue: dict) -> dict:
    if existing is None:
        merged = build_issue_view(issue)
        merged["occurrences"] = 1
        merged["scopes"] = [issue.get("currentAsset") or "startup"]
        return merged

    existing["occurrences"] += 1
    scope = issue.get("currentAsset") or "startup"
    if scope not in existing["scopes"]:
        existing["scopes"].append(scope)
    return existing


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize_cdp_log.py <raw-jsonl-path>", file=sys.stderr)
        return 2

    raw_path = Path(sys.argv[1])
    events = []
    raw_issue_count = 0
    ignored_event_count = 0
    ignored_messages: Counter[str] = Counter()
    issue_type_counts: Counter[str] = Counter()
    deduped_issues: dict[str, dict] = {}

    with raw_path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            event = simplify(entry.get("raw", ""))
            if not event:
                continue
            events.append(event)
            if is_allowlisted(event):
                ignored_event_count += 1
                ignored_messages[first_line(event.get("text") or "")] += 1
                continue
            issue = normalize_issue(event, entry.get("scope", "startup"))
            if issue:
                raw_issue_count += 1
                issue_type_counts[issue["type"]] += 1
                deduped_issues[issue_key(issue)] = merge_issue(deduped_issues.get(issue_key(issue)), issue)

    issues = sorted(
        deduped_issues.values(),
        key=lambda item: (
            0 if item["type"] == "asset-missing" else 1 if item["type"] == "exception" else 2,
            item["scopes"][0] if item["scopes"] else "",
            item.get("ownerName") or item.get("summary") or "",
            item.get("missingUuid") or "",
        ),
    )
    verdict = "PASS" if not issues else "FAIL"
    ignored = [
        {"message": message, "occurrences": count}
        for message, count in ignored_messages.most_common()
    ]

    print(
        json.dumps(
            {
                "capturedEventCount": len(events),
                "ignoredEventCount": ignored_event_count,
                "rawIssueCount": raw_issue_count,
                "issueCount": len(issues),
                "issueTypeCounts": dict(issue_type_counts),
                "ignoredMessages": ignored,
                "verdict": verdict,
                "issues": issues,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

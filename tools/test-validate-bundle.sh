#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/validate-bundle-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

assert_line() {
  file=$1
  expected=$2

  if ! grep -Fx "$expected" "$file" >/dev/null; then
    printf 'FAIL: %s is missing required line: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

make_fixture() {
  fixture=$1
  mkdir -p "$fixture/tools"
  cp "$ROOT/release.ini" "$ROOT/README.md" "$fixture/"
  cp "$ROOT/tools/validate-bundle.sh" \
    "$ROOT/tools/validate-scan-report.py" \
    "$fixture/tools/"
  cp -R "$ROOT/scanner-bundle" "$fixture/"
}

run_failure_case() {
  fixture=$1
  expected=$2
  output="$fixture/validation.log"

  if sh "$fixture/tools/validate-bundle.sh" >"$output" 2>&1; then
    printf 'FAIL: validator unexpectedly accepted mismatched fixture\n' >&2
    cat "$output" >&2
    exit 1
  fi

  if ! grep -F "$expected" "$output" >/dev/null; then
    printf 'FAIL: validator did not report the targeted mismatch\n' >&2
    printf 'Expected: %s\n' "$expected" >&2
    cat "$output" >&2
    exit 1
  fi
}

synced="$TMP_ROOT/synced"
make_fixture "$synced"
sh "$synced/tools/validate-bundle.sh" >/dev/null

scanner_mismatch="$TMP_ROOT/scanner-mismatch"
make_fixture "$scanner_mismatch"
sed -i 's/Scanner [^ ][^ ]* \/ Report Format/Scanner mismatched \/ Report Format/' \
  "$scanner_mismatch/scanner-bundle/startup.nsh"
run_failure_case "$scanner_mismatch" \
  "startup.nsh banner is out of sync with release.ini"

report_mismatch="$TMP_ROOT/report-mismatch"
make_fixture "$report_mismatch"
sed -i 's/· Report format [^ ]* · Public beta/· Report format mismatched · Public beta/' \
  "$report_mismatch/README.md"
run_failure_case "$report_mismatch" \
  "README release heading is out of sync with release.ini"

assert_line "$ROOT/.github/CODEOWNERS" \
  "/.github/CODEOWNERS @kwdd64-D"
assert_line "$ROOT/.github/CODEOWNERS" \
  "/.github/workflows/test.yml @kwdd64-D"
assert_line "$ROOT/.github/CODEOWNERS" \
  "/tools/test-validate-bundle.sh @kwdd64-D"

python3 - "$ROOT/.github/main-branch-protection.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as policy_file:
    policy = json.load(policy_file)

reviews = policy.get("required_pull_request_reviews") or {}
expected = {
    "dismiss_stale_reviews": True,
    "require_code_owner_reviews": True,
    "required_approving_review_count": 1,
}
if any(reviews.get(key) != value for key, value in expected.items()):
    raise SystemExit(
        "FAIL: main branch protection must require one fresh code-owner approval"
    )
PY

printf 'OK: release-version regression checks passed\n'
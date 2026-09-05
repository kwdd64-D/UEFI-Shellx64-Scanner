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

REQUIRED_CODEOWNERS="$TMP_ROOT/required-codeowners"
cat >"$REQUIRED_CODEOWNERS" <<'EOF'
/.github/CODEOWNERS @kwdd64-D
/.github/main-branch-protection.json @kwdd64-D
/.github/workflows/test.yml @kwdd64-D
/package.json @kwdd64-D
/tools/configure-main-branch-protection.sh @kwdd64-D
/tools/test-validate-bundle.sh @kwdd64-D
/tools/validate-bundle.sh @kwdd64-D
/tools/validate-scan-report.py @kwdd64-D
EOF

verify_codeowners() {
  codeowners_file=$1

  while IFS= read -r required_entry; do
    grep -Fx "$required_entry" "$codeowners_file" >/dev/null || return 1
  done <"$REQUIRED_CODEOWNERS"
}

verify_release_entrypoints() {
  entrypoint_root=$1

  grep -Fx "        run: pnpm test" \
    "$entrypoint_root/.github/workflows/test.yml" >/dev/null &&
    grep -Fx '    "test": "sh tools/test-validate-bundle.sh",' \
      "$entrypoint_root/package.json" >/dev/null
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

if ! verify_codeowners "$ROOT/.github/CODEOWNERS"; then
  printf 'FAIL: .github/CODEOWNERS does not protect every release-safety control\n' >&2
  exit 1
fi

while IFS= read -r protected_entry; do
  weakened_codeowners="$TMP_ROOT/weakened-codeowners"
  grep -Fvx "$protected_entry" "$ROOT/.github/CODEOWNERS" \
    >"$weakened_codeowners"

  if verify_codeowners "$weakened_codeowners"; then
    printf 'FAIL: ownership verification accepted removal of: %s\n' \
      "$protected_entry" >&2
    exit 1
  fi
done <"$REQUIRED_CODEOWNERS"

if ! verify_release_entrypoints "$ROOT"; then
  printf 'FAIL: release-safety entry points do not invoke the protected test driver\n' >&2
  exit 1
fi

entrypoint_fixture="$TMP_ROOT/entrypoints"
mkdir -p "$entrypoint_fixture/.github/workflows"
cp "$ROOT/.github/workflows/test.yml" \
  "$entrypoint_fixture/.github/workflows/test.yml"
cp "$ROOT/package.json" "$entrypoint_fixture/package.json"

sed -i \
  's/run: pnpm test/run: printf "checks bypassed\\n"/' \
  "$entrypoint_fixture/.github/workflows/test.yml"
if verify_release_entrypoints "$entrypoint_fixture"; then
  printf 'FAIL: entry-point verification accepted a weakened workflow command\n' >&2
  exit 1
fi

cp "$ROOT/.github/workflows/test.yml" \
  "$entrypoint_fixture/.github/workflows/test.yml"
sed -i \
  's/"test": "sh tools\/test-validate-bundle.sh"/"test": "true"/' \
  "$entrypoint_fixture/package.json"
if verify_release_entrypoints "$entrypoint_fixture"; then
  printf 'FAIL: entry-point verification accepted a weakened package test command\n' >&2
  exit 1
fi

python3 - \
  "$ROOT/.github/main-branch-protection.json" \
  "$ROOT/.github/main-branch-protection.evidence.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as policy_file:
    policy = json.load(policy_file)
with open(sys.argv[2], encoding="utf-8") as evidence_file:
    evidence = json.load(evidence_file)

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

if evidence.get("required_pull_request_reviews") != expected:
    raise SystemExit(
        "FAIL: branch-protection evidence is missing the code-owner review policy"
    )

verification_pr = evidence.get("verification_pull_request") or {}
protected_files = set(verification_pr.get("protected_files_changed") or [])
if (
    not verification_pr.get("url")
    or not protected_files.intersection(
        {".github/workflows/test.yml", "tools/test-validate-bundle.sh"}
    )
    or verification_pr.get("codeowners_errors") != []
):
    raise SystemExit(
        "FAIL: evidence must identify an error-free PR changing a protected file"
    )
PY

printf 'OK: release-version regression checks passed\n'
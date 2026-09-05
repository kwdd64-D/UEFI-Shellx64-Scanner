#!/bin/sh
set -eu

repo="${1:-kwdd64-D/UEFI-Shellx64-Scanner}"

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/${repo}/branches/main/protection" \
  --input .github/main-branch-protection.json

gh api \
  -H "Accept: application/vnd.github+json" \
  "repos/${repo}/branches/main/protection" |
  jq -e '
    if (
      .required_status_checks.strict == true
      and .required_status_checks.contexts == ["pnpm test"]
      and .enforce_admins.enabled == true
      and .required_pull_request_reviews == null
    ) then
      {
        required_status_checks: .required_status_checks.contexts,
        strict: .required_status_checks.strict,
        enforce_admins: .enforce_admins.enabled,
        required_pull_request_reviews: .required_pull_request_reviews
      }
    else
      error("main branch protection does not match the required policy")
    end
  '
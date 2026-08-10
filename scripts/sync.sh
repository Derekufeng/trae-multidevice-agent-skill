#!/usr/bin/env bash
set -euo pipefail

TRAE_HOME="${HOME}/.trae-cn"
SYNC_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_ITEMS=("skills" "skill-config.json" "plugin-config.json")

merge_directory() {
  local repo_dir="$1" local_dir="$2" changed=0
  while IFS= read -r -d '' f; do
    local rel="${f#$repo_dir/}"
    local dst="$local_dir/$rel"
    if [ ! -e "$dst" ]; then mkdir -p "$(dirname "$dst")"; cp "$f" "$dst"; echo "    + local <- repo: $rel"
    elif ! diff -q "$f" "$dst" >/dev/null 2>&1; then cp "$dst" "$f"; echo "    ~ diff (keep local): $rel"; changed=1; fi
  done < <(find "$repo_dir" -type f -print0)
  while IFS= read -r -d '' f; do
    local rel="${f#$local_dir/}"
    local dst="$repo_dir/$rel"
    if [ ! -e "$dst" ]; then mkdir -p "$(dirname "$dst")"; cp "$f" "$dst"; echo "    + repo <- local: $rel"; changed=1; fi
  done < <(find "$local_dir" -type f -print0)
  return $changed
}

merge_json() {
  python3 - "$1" "$2" << 'PY'
import json,sys
def dm(b,o):
    if isinstance(b,dict) and isinstance(o,dict):
        r=dict(b)
        for k,v in o.items(): r[k]=dm(r[k],v) if k in r else v
        return r
    return o
rp,lp=sys.argv[1],sys.argv[2]
with open(rp) as f:repo=json.load(f)
with open(lp) as f:local=json.load(f)
m=dm(repo,local)
rs=json.dumps(repo,indent=2,ensure_ascii=False)
ls=json.dumps(local,indent=2,ensure_ascii=False)
ms=json.dumps(m,indent=2,ensure_ascii=False)
if ms!=rs:
    with open(rp,'w') as f:f.write(ms);print("REPO_CHANGED")
if ms!=ls:
    with open(lp,'w') as f:f.write(ms)
PY
}

cmd_init(){ cd "$SYNC_DIR"; [ ! -d .git ] && git init; mkdir -p user-config; echo "==> repo initialized"; echo "    next: git remote add origin <url>"; }

cmd_push(){
  echo "==> pushing local config to repo..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="${TRAE_HOME}/${item}" dst="${SYNC_DIR}/user-config/${item}"
    if [ -e "$src" ]; then mkdir -p "$(dirname "$dst")"; rm -rf "$dst"; cp -R "$src" "$dst"; echo "  copied: ${item}"; fi
  done
  cd "$SYNC_DIR"; git add -A
  if git diff --cached --quiet; then echo "==> no changes, skip"; else
    git commit -m "push: $(date '+%Y-%m-%d %H:%M:%S') from $(hostname)"; git push; echo "==> pushed"; fi
}

cmd_pull(){
  echo "==> pulling from remote..."; cd "$SYNC_DIR"; git pull --rebase
  for item in "${SYNC_ITEMS[@]}"; do
    src="${SYNC_DIR}/user-config/${item}" dst="${TRAE_HOME}/${item}"
    if [ -e "$src" ]; then mkdir -p "$(dirname "$dst")"; rm -rf "$dst"; cp -R "$src" "$dst"; echo "  applied: ${item}"; fi
  done
  echo "==> done"
}

cmd_sync(){
  local max_retries=3 attempt=0 branch
  branch=$(git -C "$SYNC_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  while [ $attempt -lt $max_retries ]; do
    attempt=$((attempt + 1))
    echo "==> sync attempt ${attempt}/${max_retries}"
    cd "$SYNC_DIR"
    if ! git fetch origin 2>&1 | sed 's/^/  /'; then
      echo "  fetch failed"; [ $attempt -lt $max_retries ] && sleep $((attempt * 2)); continue; fi
    if ! git reset --hard "origin/${branch}" >/dev/null 2>&1; then
      echo "  reset failed"; [ $attempt -lt $max_retries ] && sleep $((attempt * 2)); continue; fi
    local has_changes=0
    for item in "${SYNC_ITEMS[@]}"; do
      repo_path="${SYNC_DIR}/user-config/${item}" local_path="${TRAE_HOME}/${item}"
      repo_exists=false; local_exists=false
      [ -e "$repo_path" ] && repo_exists=true; [ -e "$local_path" ] && local_exists=true
      echo "  [${item}]"
      if [ "$repo_exists" = false ] && [ "$local_exists" = false ]; then echo "    both absent"; continue; fi
      if [ "$local_exists" = false ]; then mkdir -p "$(dirname "$local_path")"; cp -R "$repo_path" "$local_path"; echo "    local <- repo"; continue; fi
      if [ "$repo_exists" = false ]; then cp -R "$local_path" "$repo_path"; echo "    repo <- local"; has_changes=1; continue; fi
      if [ -d "$repo_path" ]; then
        if merge_directory "$repo_path" "$local_path"; then :; else has_changes=1; fi
      else
        result=$(merge_json "$repo_path" "$local_path" 2>/dev/null || true)
        [ "$result" = "REPO_CHANGED" ] && has_changes=1
      fi
    done
    if [ "$has_changes" = 1 ]; then
      git add -A
      git commit -m "sync merge: $(date '+%Y-%m-%d %H:%M:%S') from $(hostname)" >/dev/null 2>&1
      local push_out
      if push_out=$(git push 2>&1); then
        echo "$push_out" | sed 's/^/  /'; echo "==> merged & pushed"; return 0
      else
        echo "$push_out" | sed 's/^/  /'; echo "  push failed (concurrent push by another machine)"
        if [ $attempt -lt $max_retries ]; then echo "  retrying in $((attempt * 2))s..."; sleep $((attempt * 2)); fi
      fi
    else
      echo "==> in sync (nothing to push)"; return 0
    fi
  done
  echo "==> failed after ${max_retries} attempts, try again later"; return 1
}

cmd_status(){
  echo "==> comparing local vs repo..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="${TRAE_HOME}/${item}" dst="${SYNC_DIR}/user-config/${item}"
    if [ ! -e "$src" ] && [ ! -e "$dst" ]; then echo "  ${item}: both absent"
    elif [ ! -e "$dst" ]; then echo "  ${item}: local only"
    elif [ ! -e "$src" ]; then echo "  ${item}: repo only"
    elif diff -rq "$src" "$dst" >/dev/null 2>&1; then echo "  ${item}: identical"
    else echo "  ${item}: differs"; fi
  done
}

case "${1:-}" in
  init) cmd_init ;; push) cmd_push ;; pull) cmd_pull ;;
  sync) cmd_sync ;; status) cmd_status ;;
  *) echo "usage: ./sync.sh {init|push|pull|sync|status}"; exit 1 ;;
esac

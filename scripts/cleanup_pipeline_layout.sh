#!/usr/bin/env bash
set -euo pipefail

# Defaults
APPLY=0
COMMIT=0
REMOVE_BOT_NUKE=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/cleanup_pipeline_layout.sh [--apply] [--commit] [--remove-bot-nuke]

What it does (dry-run by default):
  1) Rename bot_config/bot_config -> bot_config/core
  2) Replace "bot_config.bot_config" -> "bot_config.core" across source files
  3) Remove stray file: bot_config/tree-stucture-bot-common.txt
  4) (Optional) Remove pyproject_templates/bot_nuke if --remove-bot-nuke
  5) Prints a summary and suggested git commands

Flags:
  --apply             Actually perform the actions (default is dry-run)
  --commit            Make a git commit with a standard message (implies --apply)
  --remove-bot-nuke   Also remove pyproject_templates/bot_nuke
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --commit) COMMIT=1; APPLY=1; shift ;;
    --remove-bot-nuke) REMOVE_BOT_NUKE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

say() { printf "• %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*" >&2; }
ok() { printf "✅ %s\n" "$*"; }

is_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

DO() {
  # Run a command if APPLY=1, else print it
  if [[ "$APPLY" -eq 1 ]]; then
    eval "$*"
  else
    echo "(dry-run) $*"
  fi
}

# 0) Pre-flight checks
if [[ "$COMMIT" -eq 1 ]] && ! is_git_repo; then
  warn "Cannot commit: not inside a git repo. Continuing without --commit."
  COMMIT=0
fi

if is_git_repo; then
  # Ensure a clean working tree when applying
  if [[ "$APPLY" -eq 1 ]]; then
    if ! git diff --quiet || ! git diff --cached --quiet; then
      warn "Git working tree not clean. Please commit/stash changes first."
      exit 1
    fi
  fi
fi

# 1) Rename folder bot_config/bot_config -> bot_config/core
SRC_DIR="bot_config/bot_config"
DST_DIR="bot_config/core"
if [[ -d "$SRC_DIR" ]]; then
  say "Will rename $SRC_DIR -> $DST_DIR"
  if [[ -d "$DST_DIR" ]]; then
    warn "$DST_DIR already exists; will not overwrite. Skipping rename."
  else
    if is_git_repo; then
      DO "git mv \"$SRC_DIR\" \"$DST_DIR\""
    else
      DO "mv \"$SRC_DIR\" \"$DST_DIR\""
    fi
  fi
else
  say "No $SRC_DIR found — skipping rename."
fi

# 2) Replace imports/usages "bot_config.bot_config" -> "bot_config.core"
# Target common text-based files
GLOBS=(-name "*.py" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.md" -o -name "*.sh" -o -name "*.txt")
MATCHES=$(find . \( "${GLOBS[@]}" \) -type f -print0 | xargs -0 grep -nH "bot_config\.bot_config" || true)
if [[ -n "$MATCHES" ]]; then
  say "Found references to bot_config.bot_config (will rewrite to bot_config.core):"
  echo "$MATCHES" | sed 's/^/  /'
  if [[ "$APPLY" -eq 1 ]]; then
    # GNU sed (Ubuntu) inline replacement
    find . \( "${GLOBS[@]}" \) -type f -print0 | \
      xargs -0 sed -i 's/bot_config\.bot_config/bot_config\.core/g'
  else
    echo "(dry-run) sed -i 's/bot_config\\.bot_config/bot_config\\.core/g' on matched files"
  fi
else
  say "No references to bot_config.bot_config found."
fi

# 3) Remove stray file tree-stucture-bot-common.txt (typo kept as-is)
STRAY="bot_config/tree-stucture-bot-common.txt"
if [[ -f "$STRAY" ]]; then
  say "Will remove stray file: $STRAY"
  if is_git_repo; then
    DO "git rm \"$STRAY\""
  else
    DO "rm -f \"$STRAY\""
  fi
else
  say "Stray file not present: $STRAY (ok)."
fi

# 4) Optional: Remove pyproject_templates/bot_nuke
NUKE_DIR="pyproject_templates/bot_nuke"
if [[ "$REMOVE_BOT_NUKE" -eq 1 ]]; then
  if [[ -d "$NUKE_DIR" ]]; then
    say "Removing $NUKE_DIR (since --remove-bot-nuke)"
    if is_git_repo; then
      DO "git rm -r \"$NUKE_DIR\""
    else
      DO "rm -rf \"$NUKE_DIR\""
    fi
  else
    say "No $NUKE_DIR directory found (already clean)."
  fi
else
  if [[ -d "$NUKE_DIR" ]]; then
    warn "$NUKE_DIR still exists. Use --remove-bot-nuke to delete it if you no longer need Nuke templates."
  else
    say "No Nuke template dir present — good."
  fi
fi

# 5) Summary of lingering references to 'bot_nuke' and 'natron' state (report only)
say "Scanning for lingering 'bot_nuke' references (report only):"
find . \( "${GLOBS[@]}" \) -type f -print0 | xargs -0 grep -nH "bot_nuke" || true

say "Scanning for Natron hooks present (report):"
if [[ -d "bot_config/bot_natron/hooks" ]]; then
  find bot_config/bot_natron/hooks -maxdepth 2 -type f | sed 's/^/  /'
else
  warn "bot_config/bot_natron/hooks not found."
fi

# 6) Commit if requested
if [[ "$COMMIT" -eq 1 ]]; then
  say "Committing changes..."
  DO "git add -A"
  DO "git commit -m 'chore(pipeline): rename bot_config/bot_config→core, fix imports, remove stray files, (opt) drop bot_nuke'"
  ok "Committed."
fi

if [[ "$APPLY" -eq 1 ]]; then
  ok "Apply complete."
else
  ok "Dry-run complete. Re-run with --apply to make changes."
fi

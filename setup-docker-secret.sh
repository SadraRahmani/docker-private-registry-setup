#!/usr/bin/env bash
set -euo pipefail

# (Optional) disable your shell history while this runs
set +o history

echo -n "🔒  Enter secret value: "
# -s = silent (no echo); SECRET won’t include a trailing newline
read -rs SECRET
echo

echo -n "🏷️  Enter Docker secret name: "
# Name can include dots, underscores, etc.
read NAME
echo

# (Optional) re-enable history
set -o history

# If it already exists, remove it so we can recreate
if docker secret inspect "$NAME" &>/dev/null; then
  echo "⚠️  Secret '$NAME' exists—removing old one…"
  docker secret rm "$NAME"
fi

# Create the new secret from the in-memory variable, no files involved
printf '%s' "$SECRET" \
  | docker secret create "$NAME" - \
  >/dev/null

echo "✅  Secret '$NAME' created."

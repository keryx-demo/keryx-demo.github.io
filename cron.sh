#!/usr/bin/env bash
#
# Daily ops run: keep the TUF metadata fresh and push it to the demo site.
#
# The ops role is the online half of the repository: it owns snapshot.json and
# timestamp.json. This run does the one thing ops does on a schedule — re-sign
# timestamp.json with the online ops key and a fresh expiry — and nothing else:
#
#   1. re-sign timestamp.json with a fresh expiry (the online ops key)
#   2. validate the whole repository chain
#   3. commit and push the site (GitHub Pages deploys it)
#
# No item, channel, or root metadata changes, so there is no wake-up to send:
# devices pick the new timestamp up on their next update check. Run it once a day
# (cron or a systemd timer); the timestamp lives 48 h, so one failed run still
# leaves a full day of margin.
#
# Everything is relative to this script: no secrets, no configuration, no
# environment variables. The private keys live in ../keryx-demo-keys, outside
# every repository, and are never read by this script — the publisher CLI loads
# them. Run it from anywhere:
#
#   ./cron.sh
#
# It needs: the keryx checkout as a sibling (../keryx) with bin/pub built
# (make cli), the keystore at ../keryx-demo-keys, and git push access to the
# demo site repository.
set -euo pipefail

# --- where everything is, relative to this script ----------------------------
here="$(cd "$(dirname "$0")" && pwd)"
keryx="$here/../keryx"             # the keryx checkout (publisher CLI lives here)
keys="$here/../keryx-demo-keys"     # the release keystore (never in git)
pub="$keryx/bin/pub"                # the publisher CLI
repo="$here/keryx"                  # the TUF repository inside the site
anchor="$here/.well-known/keryx"     # the root anchor (root.json + N.root.json)

# --- how long the refreshed timestamp stays valid ---------------------------
ttl=48h                               # one daily run leaves a full day of margin

say() { printf '\n== %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# --- 0. the tools and keys we need ----------------------------------------
[[ -x "$pub" ]] || die "$pub not found: build it with 'make cli' in $keryx"
[[ -d "$keys" ]] || die "$keys not found: the release keystore"

# an unattended run must not sweep unrelated work into its commit
[[ -z "$(git -C "$here" status --porcelain)" ]] || die "worktree is dirty: commit or stash first"

# --- 1. re-sign timestamp with a fresh expiry (the online ops key) ----------
say "refreshing timestamp ($ttl)"
"$pub" refresh-timestamp --expires "$ttl" \
  --repo "$repo" --anchor "$anchor" --keystore "$keys"

# --- 2. validate, commit and push (Pages deploys it) ----------------------
say "validating and pushing the site"
"$pub" validate --repo "$repo" --anchor "$anchor"
git -C "$here" add -A
git -C "$here" commit -m "chore: refresh timestamp"
git -C "$here" push origin main

say "done: the site serves a freshly signed timestamp."

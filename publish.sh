#!/usr/bin/env bash
#
# Publish one "Test N" item to the demo site and wake the app.
#
# The whole chain, in the order it happens:
#
#   1. pull main: the daily "Refresh TUF timestamp" workflow pushes here too,
#      so start from its commits
#   2. create the item draft (spec/feeds.md §1.1)
#   3. sign it with both security authors (authored channel, threshold 2)
#   4. make room: unpublish the oldest "Test N" items first, so the channel
#      never indexes more than 10 of them
#   5. publish the new item into the channel index (role + snapshot + timestamp)
#   6. commit and push the site (GitHub Pages deploys it)
#   7. pub notify: wait for the deployed site to serve the new metadata,
#      then tell the relay to wake the devices
#
# Everything is relative to this script: no secrets, no configuration, no
# environment variables. The private keys live in ../keryx-demo-keys, outside
# every repository, and are never read by this script — the publisher CLI loads
# them. Run it from anywhere:
#
#   ./publish.sh
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

# --- what we publish and where ---------------------------------------------
channel=security                    # the authored channel
company=keryx-demo.github.io          # the canonical company_id
relay=https://keryx-relay.fly.dev     # the staging relay
keep=10                               # how many "Test N" items stay published

say() { printf '\n== %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# --- 0. the tools and keys we need ----------------------------------------
[[ -x "$pub" ]] || die "$pub not found: build it with 'make cli' in $keryx"
[[ -d "$keys" ]] || die "$keys not found: the release keystore"

# the two author keyids of the security channel (public ids, read from the store)
author_a="$("$pub" keys list --keystore "$keys" | awk '$1 == "author-security-a" { print $3 }')"
author_b="$("$pub" keys list --keystore "$keys" | awk '$1 == "author-security-b" { print $3 }')"
[[ -n "$author_a" && -n "$author_b" ]] || die "author-security-a/b missing from $keys"

# --- 1. sync with origin/main --------------------------------------------
# The timestamp refresh workflow commits keryx/timestamp.json to main on its own
# schedule. Pull before touching the repository, or the push in step 6 is rejected.
# --autostash keeps a dirty worktree from blocking the pull.
say "syncing with origin/main"
git -C "$here" pull --rebase --autostash origin main

# --- 2. the next test number and the draft --------------------------------
# existing items are channels/security/test-<n>[-<date>].json; take the highest n
last=0
for f in "$repo"/channels/"$channel"/test-*.json; do
  [[ -e "$f" ]] || continue
  n="$(basename "$f" | sed -E 's/^test-([0-9]+).*/\1/')"
  (( n > last )) && last="$n"
done
next=$((last + 1))
id="test-$next"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

draft="$(mktemp)"
trap 'rm -f "$draft"' EXIT
say "creating $id (Test $next)"
cat > "$draft" <<EOF
{
  "id": "$id",
  "title": "Test $next",
  "content_html": "<p>Test $next — published by publish.sh at $now.</p>",
  "date_published": "$now",
  "tags": ["demo", "security", "en"],
  "language": "en"
}
EOF

# --- 3. sign it with both authors (the channel's threshold is 2) -----------
say "signing with author-security-a and author-security-b"
"$pub" item sign --file "$draft" --channel "$channel" --keyid "$author_a" --keystore "$keys"
"$pub" item sign --file "$draft" --channel "$channel" --keyid "$author_b" --keystore "$keys"

# --- 4. make room: unpublish the oldest test items first -------------------
# The new item is not published yet, so remove count + 1 - keep of the oldest:
# the channel index never holds more than $keep "Test N" items, not even between
# the two writes.
mapfile -t tests < <(
  for f in "$repo"/channels/"$channel"/test-*.json; do
    [[ -e "$f" ]] || continue
    basename "$f" .json
  done | sort -t- -k2 -n
)
room=$(( ${#tests[@]} + 1 - keep ))
if (( room > 0 )); then
  say "unpublishing the $room oldest test item(s) to make room"
  for (( i = 0; i < room; i++ )); do
    "$pub" item unpublish --channel "$channel" --id "${tests[$i]}" \
      --repo "$repo" --anchor "$anchor" --keystore "$keys"
  done
fi

# --- 5. publish it (indexes the item, re-signs role/snapshot/timestamp) -------
say "publishing $id into $channel"
"$pub" publish --channel "$channel" --file "$draft" \
  --repo "$repo" --anchor "$anchor" --keystore "$keys"

# --- 6. validate, commit and push (Pages deploys it) ----------------------
say "validating and pushing the site"
"$pub" validate --repo "$repo" --anchor "$anchor"
git -C "$here" add -A
git -C "$here" commit -m "feat: publish Test $next"
git -C "$here" push origin main

# --- 7. wake the devices ------------------------------------------------
# pub notify polls the deployed site until it serves the versions published
# above, then signs a wake-up with the channel key and posts it to the relay.
say "notifying the relay (waits for the deploy)"
"$pub" notify --repo "$repo" --channel "$channel" \
  --company "$company" --relay "$relay" --keystore "$keys"

say "done: Test $next is live — the app should show it without a reload,"
echo "and the wake-up notification should arrive on the phone."

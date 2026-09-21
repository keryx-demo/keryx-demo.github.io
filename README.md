# Keryx demo — published demo publisher

Generated demonstration site for the [Keryx](https://github.com/v1b3coder/keryx)
protocol: a signed company→customer broadcast channel (TUF metadata chain,
per-channel delegated roles with an authors role on the security channel,
one signed item file per TUF target, private capability feed).

Live at **https://keryx-demo.github.io/**

- Join link: see [`join.txt`](join.txt) (also rendered as QR on `/join/`)
- Root anchor: `/.well-known/keryx/root.json`
- This is demo data only, based on real public Trezor blog posts — not
  published by Trezor.

This is the **live demonstration site** for the tooling. The in-repository
`keryx/demo/` artifact is a structure demonstration only — its keys are
disposable; see the keryx README's Demo section.

## Keys

This repository contains **no private keys** and must never contain any. The
site's keystore lives outside every repository, at `../keryx-demo-keys/`
(`~/projekty/keryx-demo-keys`), and is never committed, copied into the
site, or handed to another repository:

- `master.json` is the offline root key. Losing it ends this site's trust
  anchor: no further metadata can be signed and every client has to re-pair.
- The remaining files are the ops (snapshot/timestamp), channel, author, and
  engine keys that the signed metadata authorizes.
- Back the directory up encrypted. Rotate keys only through TUF metadata
  (`pub rotate-root`, `pub channel key rotate/revoke`), never by minting a
  fresh keystore — a fresh keystore starts a new root v1 that no existing
  client or relay can rotate to (spec/repository.md §5).

The site previously committed its keystore under `keys/` (removed from the
tree in `3f8fef6`, keys rotated in `cddccc7`). That history is still
clonable; the rotated keys are what the live site trusts now.

## Regenerate

Always regenerate through the keryx repository's `make demo` target: it uses
`../keryx-demo-keys` by default.

```sh
cd ../keryx
make demo          # regenerate this site from ../keryx-demo-keys
make demo-verify   # verify the result
```

When `../keryx-demo-keys` is absent, `make demo` mints a fresh, independent
keystore instead — a new root v1 that re-anchors every client. Restore the
release keys from backup instead of pushing such a demo (spec/repository.md §5).

The equivalent manual run:

```sh
cd ../keryx/demo-tool
go run . -mode build -site ../../keryx-demo -keys ../../keryx-demo-keys -base https://keryx-demo.github.io
go run . -mode verify -site ../../keryx-demo -keys ../../keryx-demo-keys -base https://keryx-demo.github.io
```

Then commit and push — the Pages workflow deploys automatically.

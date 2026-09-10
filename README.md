# Keryx demo — published demo publisher

Generated demonstration site for the [Keryx](https://github.com/v1b3coder/keryx)
protocol: a signed company→customer broadcast channel (TUF metadata chain,
per-channel delegated roles, signed JSON Feeds, private capability feed).

Live at **https://v1b3coder.github.io/keryx-demo/**

- Join link: see [`join.txt`](join.txt) (also rendered as QR on `/join/`)
- Root anchor: `/.well-known/keryx/root.json`
- This is demo data only, based on real public Trezor blog posts — not
  published by Trezor. Demo signing keys are committed on purpose.

## Regenerate

```sh
cd ../keryx/demo-tool
go run . -mode build -site ../../keryx-demo -base https://v1b3coder.github.io/keryx-demo
go run . -mode verify -site ../../keryx-demo -base https://v1b3coder.github.io/keryx-demo
```

Then commit and push — the Pages workflow deploys automatically.

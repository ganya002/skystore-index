# SkyStore index

The public index of addons for [SkyRose](https://github.com/ganya002/skyrose)'s SkyStore.
SkyRose downloads `index.json` and `index.json.sig` over HTTPS and refuses the index unless the
Ed25519 signature matches a key built into SkyRose. Each version lists its bundle's SHA-256.
Every `build` raises `serial` (signed with the rest); SkyRose refuses an index with a lower serial
than one it already saw, so an old signed index cannot be replayed to hide a revocation.

    index.json          what SkyRose reads (built from addons/, never edited by hand)
    index.json.sig      base64 Ed25519 signature of index.json
    addons/<id>.json    one entry per published addon (the source of index.json)
    submissions/        pull requests from creators land here; reviewed, then folded into addons/
    media/<id>/         icons and screenshots, linked from the entries
    tools/skystore.swift  keygen | build | sign | verify

## Submitting an addon

Turn on creator mode in SkyRose (Settings › SkyStore), then:

    skyrose store new dev.you.my-theme
    skyrose store validate dev.you.my-theme
    skyrose store submit dev.you.my-theme --repo you/my-addons --yes

`submit` uploads the bundle as a release asset of **your** repo with your `gh` login, then opens a
pre-filled pull request here that adds `submissions/<id>-<version>.json`. A maintainer reviews
every submission by hand. Nothing is published automatically.

Data addons only for now: colour schemes and wallpapers. See SkyRose's docs/SKYSTORE.md and
docs/skystore-security.md.

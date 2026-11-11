# Reviewing a submission

Each step is done by a person. Never merge a submission as-is: index.json is built and signed only
after the steps below.

1. Read the PR: `submissions/<id>-<version>.json` must have one version, an `https://github.com/<creator>/…/releases/download/…` url,
   a sha256 and a size.
2. Fetch and check the bundle (in a scratch folder):

       curl -L -o bundle.skyaddon '<url from the submission>'
       shasum -a 256 bundle.skyaddon            # must equal the submission's sha256
       mkdir x && ditto -x -k bundle.skyaddon x
       skyrose store validate x                 # creator mode on; must print OK

3. Look at every file. Schemes: colours only. Wallpapers: open each image or video. Check that the
   licence allows redistribution and that the author owns the work.
4. Mirror the reviewed bundle into this repo's releases, so the creator cannot swap it later:

       gh release create <id>-v<version> bundle.skyaddon#<id>-<version>.skyaddon --repo ganya002/skystore-index \
         --title '<name> <version>' --notes 'SHA-256 <sha256>'

5. Copy the icon and screenshots from `x/` into `media/<id>/`.
6. Write or update `addons/<id>.json`: the submission's fields, plus
   - `url` = `https://github.com/ganya002/skystore-index/releases/download/<id>-v<version>/<id>-<version>.skyaddon`
   - `icon` / `screenshots` = `https://raw.githubusercontent.com/ganya002/skystore-index/main/media/<id>/<file>`
   - append the version to `versions` (keep the older ones for the version history).
   Delete the submission file.
7. Build and sign (the key never leaves your Mac):

       swift tools/skystore.swift build
       swift tools/skystore.swift sign ~/.skystore/signing.key
       swift tools/skystore.swift verify <public key>

8. Commit `addons/`, `media/`, `index.json` and `index.json.sig` together, and push.

## Revoking (kill switch)

Set `"revoked": "<reason>"` on the entry (whole addon) or on one version in `addons/<id>.json`,
then build, sign and push. Every SkyRose that has it switches it off within 6 hours, or at once
when the Store opens.

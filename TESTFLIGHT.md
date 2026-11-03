# TestFlight notes for maintainers

The existing HTML Arcade app is a personal, private TestFlight build. It is not a public install link. To distribute your own fork, use your own Apple Developer team, bundle ID, App Store Connect app record, and signing credentials.

## Configure a release

1. Update the team and bundle identifier in `project.yml`, then run `xcodegen generate`.
2. The release helper in `scripts/testflight.py` currently defaults to the original maintainer's app identity. If you are maintaining a fork, update its `TEAM` and `BUNDLE` constants to your own values before using it.
3. Register that bundle ID and create its app record on App Store Connect.
4. Keep your App Store Connect API credentials outside this repository, for example in `~/.html-arcade/asc.env`:

```sh
ASC_KEY_ID=your_key_id
ASC_ISSUER_ID=your_issuer_id
ASC_KEY_PATH=/absolute/path/to/AuthKey.p8
```

## Archive and upload

```sh
python3 scripts/testflight.py --archive-only
python3 scripts/testflight.py
```

The helper verifies the app identity, matches an available distribution private key, installs a provisioning profile, archives, and optionally uploads. Use `--credentials /path/to/asc.env` for another local configuration, or `--upload-existing /path/to/HTMLArcade.xcarchive` to upload an existing archive.

Logs and the upload manifest are written to `artifacts/release/` by default. After upload, verify that Apple processing finishes and assign the build to your intended testing group. An upload success is not an installation check.

## Suggested test notes

- Import one or several `.html` / `.htm` games from Files.
- Find → Browse device files → search Downloads, On My iPhone, or iCloud Drive → import.
- Find → open a game URL → Import this page, or follow an HTML download.
- Play full screen in portrait or landscape; use the movable ••• menu to return, restart, or change orientation.
- Check that games with their own local-save support keep progress after reopening.
- Test in airplane mode with Wi-Fi off before relying on a game during a flight.

Orbit is the only bundled game. Third-party game downloads and the optional PokeSurvivor QA fixture are not distributed in this repository.

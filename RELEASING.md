# Releasing Gibbous

Releases are cut by **GitHub Actions** ([`.github/workflows/release.yml`](.github/workflows/release.yml)).
Pushing a version tag builds the app, signs it with the **Developer ID Application**
certificate, **notarizes** it with Apple, **staples** the ticket, packages a `.dmg`,
and publishes it to a [GitHub Release](https://github.com/heirloomlogic/Gibbous/releases)
that anyone can download and run without Gatekeeper warnings.

This is direct download — a separate distribution channel from the Mac App Store,
which uses a different (Apple Distribution) certificate. The two coexist.

## Cutting a release

1. Update `CHANGELOG.md` and commit to `main`.
2. Tag with a **bare semver** version — **no `v` prefix**:

   ```sh
   git tag 1.0.0
   git push origin 1.0.0
   ```

3. The `Release` workflow runs (only tags matching `[0-9]+.[0-9]+.[0-9]+` trigger it).
   Watch it under the repo's **Actions** tab.
4. When it finishes, a Release appears with `Gibbous-1.0.0.dmg` attached.

The tag is the version: it is injected as `MARKETING_VERSION`, so it overrides the
`1.0` baked into `Gibbous.xcodeproj`. The build number (`CURRENT_PROJECT_VERSION`)
is set to the workflow run number.

## Required repository secrets

Set under **Settings → Secrets and variables → Actions → Repository secrets**
(`heirloomlogic` is a personal account, so these are per-repo — re-add them for each
app; the underlying Apple credentials are reused team-wide):

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_CERT_P12` | base64 of the exported `.p12` (Developer ID Application cert **+** private key) |
| `DEVELOPER_ID_CERT_PASSWORD` | the password set when exporting the `.p12` |
| `AC_API_KEY_P8` | base64 of the App Store Connect API key (`AuthKey_XXXXXXXXXX.p8`) |
| `AC_API_KEY_ID` | the API key's Key ID |
| `AC_API_ISSUER_ID` | the team's Issuer ID |
| `KEYCHAIN_PASSWORD` | any random string (an ephemeral CI keychain password) |

### Regenerating the credentials

- **Developer ID Application cert** — created once by the team Account Holder at
  developer.apple.com → Certificates (or Xcode → Settings → Accounts → Manage
  Certificates). Export from Keychain Access as a `.p12` (select both the cert and
  its private key). Encode: `base64 -i developerID_application.p12 | pbcopy`.
- **App Store Connect API key** — appstoreconnect.apple.com → Users and Access →
  Integrations → App Store Connect API → Team Keys. Role *Developer* is enough for
  notarization. Encode: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`.

## Verifying / troubleshooting

- The workflow self-checks: `stapler validate`, `codesign --verify`, and `spctl`
  run before publishing.
- **Notarization rejected?** The workflow prints the full `notarytool log` for the
  submission. The usual cause is an unsigned nested binary or a missing secure
  timestamp / hardened runtime.
- **Test run:** push a throwaway tag that matches the pattern (e.g. `0.0.1`), let it
  publish, validate the DMG on a clean Mac, then delete the tag and the release:

  ```sh
  git push --delete origin 0.0.1
  gh release delete 0.0.1 --cleanup-tag
  ```

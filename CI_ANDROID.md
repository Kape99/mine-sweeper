# Android CI Setup (GitHub Actions)

`.github/workflows/android-release.yml` builds a signed Android App Bundle (`.aab`)
for the Google Play Store whenever you push a `v*` tag, and attaches it to a GitHub Release.

## Release a version

```bash
git tag v1.2.3
git push origin v1.2.3
```

The version comes from the tag:

| Tag | versionName | versionCode |
|---|---|---|
| `v1.0` | `1.0` | `10000` |
| `v1.2.3` | `1.2.3` | `10203` |
| `v1.2.3-beta` | `1.2.3-beta` | `10203` |

`versionCode = major*10000 + minor*100 + patch`. Play rejects an upload whose
versionCode is not higher than the previous one, so keep minor/patch below 100.

You can also run the workflow manually from the **Actions** tab and enter
the versionName and versionCode yourself.

## Required GitHub Secrets

**Settings > Secrets and variables > Actions > New repository secret**

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_B64` | Base64 of your upload keystore: `base64 -w0 upload.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password (Godot also uses it as the key password) |
| `ANDROID_KEY_ALIAS` | Key alias name |

> Godot signs with one password for both the keystore and the key, so they must be
> the same. Keystores created by modern `keytool` (PKCS12) already work this way.

### Create an upload keystore (if you don't have one)

```bash
keytool -genkey -v -keystore upload.keystore -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.keystore   # paste output into ANDROID_KEYSTORE_B64
```

> **Important:** Back up `upload.keystore` and its password. Keep it out of the repo.

## Configure Play App Signing

1. In Google Play Console, go to **Release > Setup > App integrity**.
2. Enable **Play App Signing** and register your upload certificate.
3. CI signs the `.aab` with your upload key. Play re-signs it with the app signing key.

## Settings in the workflow

At the top of `.github/workflows/android-release.yml`:

- `PACKAGE_NAME`: Android application id. **It cannot change after the first Play upload.**
- `APP_NAME`: launcher name.
- `GODOT_VERSION`: must match the editor version the project uses.

## How it works

- Downloads Godot `GODOT_VERSION` and the official export templates (cached between runs).
- `export_presets.cfg` is gitignored, so CI writes its own with Gradle build and AAB output enabled.
- Signing credentials are never written to disk in plain text. Godot reads them
  from the `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables.
- `--install-android-build-template` creates `android/` (gitignored) for the Gradle build.

## Output

- GitHub Release for the tag, with `MineSweeper-<version>.aab` attached.
- Workflow artifact `MineSweeper-<version>` (kept 30 days).

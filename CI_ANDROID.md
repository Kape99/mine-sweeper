# Android CI Setup (GitHub Actions)

Builds a signed Android App Bundle (`.aab`) for Google Play Store on tag push
or manual dispatch.

## Required GitHub Secrets

Go to your repo: **Settings > Secrets and variables > Actions > New repository secret**

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_B64` | Base64 of your upload keystore file: `base64 -i upload.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias name |
| `ANDROID_KEY_PASSWORD` | Key password |

### Create a release keystore (if you don't have one)

```bash
keytool -genkey -v -keystore upload.keystore -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Encode it for the secret:

```bash
base64 -i upload.keystore  # copy output into ANDROID_KEYSTORE_B64
```

> **Important:** Back up `upload.keystore`. If lost, you cannot update your app on Play Store.

## Configure Play App Signing

1. In Google Play Console, go to **Release > Setup > App integrity**.
2. Enable **Play App Signing** and upload your upload certificate/public key.
3. CI signs the `.aab` with your upload key; Play Store re-signs with the app signing key for distribution.

## Edit the preset

Open `.github/workflows/android-release.yml` and set:

- `APP_ID` — your Android package id (e.g. `com.youraccount.minesweeper`)
- `version_code` / `version_string` — bump on each release

## Trigger a build

```bash
git tag v1.0
git push origin v1.0
```

Or run the **Build Android App Bundle** workflow manually from the Actions tab.

## Output

Artifact `android-app-bundle` contains `build/MineSweeper.aab`. Upload that file to Google Play Console.

## Notes

- `export_presets.cfg` is generated at runtime (it is gitignored).
- Godot 4.7 headless binary + Android export templates are downloaded each run.
- `.aab` does not need zipalign (that is for `.apk`).

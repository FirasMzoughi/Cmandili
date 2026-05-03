# Mapbox setup — cmandili apps

All three Flutter apps (`cmandili_mobile`, `cmandili_driver`, `cmandili_partner`) use
[mapbox_maps_flutter](https://pub.dev/packages/mapbox_maps_flutter).

Mapbox uses two different tokens — do not mix them up.

| Token | Scope | Where it lives |
|---|---|---|
| `pk.*` **public** | map tiles, Directions API at runtime | `.env` (`MAPBOX_PUBLIC_TOKEN`) — shipped inside the app |
| `sk.*` **secret** with `DOWNLOADS:READ` | downloading the native SDK | build machine only (`android/gradle.properties` or `~/.netrc`), never shipped |

If the secret token ever ends up in the APK/IPA, rotate it immediately in the
Mapbox dashboard.

---

## Android

Already wired up:

1. `android/settings.gradle.kts` declares the Mapbox private Maven repo and
   reads the credential from the `MAPBOX_DOWNLOADS_TOKEN` Gradle property.
2. `android/gradle.properties` holds the `sk.*` token locally and is git-ignored.
3. The old `com.google.android.geo.API_KEY` meta-data was removed from each
   `AndroidManifest.xml`.

Nothing else to do for local development. Just `flutter pub get && flutter run`.

### CI

Do **not** commit `android/gradle.properties`. Instead, inject the token as a
secret environment variable in CI (GitHub Actions, Bitrise, Codemagic, …):

```yaml
env:
  MAPBOX_DOWNLOADS_TOKEN: ${{ secrets.MAPBOX_DOWNLOADS_TOKEN }}
```

The repository block in `settings.gradle.kts` falls back to `System.getenv()`
when the Gradle property is missing, so CI works without any extra step.

---

## iOS

Mapbox's iOS SDK is delivered via CocoaPods from a private repo that
authenticates with the same `sk.*` download token, but it reads it from
`~/.netrc` — not from `Info.plist` and not from any file in the repo.

### One-time setup on each developer machine

Add (or create) `~/.netrc` with:

```
machine api.mapbox.com
  login mapbox
  password sk.YOUR_MAPBOX_SECRET_DOWNLOAD_TOKEN_HERE
```

Then:

```
chmod 600 ~/.netrc
```

After that, `cd ios && pod install` works normally. The public `pk.*` token is
read at runtime from `.env` via `MapboxOptions.setAccessToken()` in `main.dart`
— no `Info.plist` key is required.

### CI

On macOS CI runners, write `~/.netrc` from a secret before running
`pod install`:

```yaml
- name: Configure Mapbox download credentials
  run: |
    echo "machine api.mapbox.com" > ~/.netrc
    echo "  login mapbox" >> ~/.netrc
    echo "  password $MAPBOX_DOWNLOADS_TOKEN" >> ~/.netrc
    chmod 600 ~/.netrc
  env:
    MAPBOX_DOWNLOADS_TOKEN: ${{ secrets.MAPBOX_DOWNLOADS_TOKEN }}
```

---

## Rotating the secret token

1. Mapbox dashboard → revoke the old `sk.*` token.
2. Generate a new one with the same `DOWNLOADS:READ` scope.
3. Update `MAPBOX_DOWNLOADS_TOKEN` in each `android/gradle.properties`, in each
   developer's `~/.netrc`, and in CI secrets.
4. Re-run `flutter clean && flutter pub get` and `pod install` to re-authenticate.

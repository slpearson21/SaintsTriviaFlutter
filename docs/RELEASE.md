# Release

`pubspec.yaml` is the only version source:

```yaml
version: 1.0.0+1
```

The name (`1.0.0`) is semver. The number after `+` is the build number. Increment the build number on every Play Store or App Store upload, including a resubmission that keeps the same name. Bump the name when the user-facing release changes.

Android reads that line as `flutter.versionName` and `flutter.versionCode` in `android/app/build.gradle.kts`. iOS reads it through `CFBundleShortVersionString` = `$(FLUTTER_BUILD_NAME)` and `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)` in `ios/Runner/Info.plist`.

The application id and bundle id are `com.dusk.scripturetrivia` on Android and iOS. The iOS test target is `com.dusk.scripturetrivia.RunnerTests`. The Apple signing team is unset until a team is chosen. The launcher name on both platforms is Scripture Trivia.

## Upload keystore

The app has not been published. Create the Play App Signing upload key once, and keep it out of git.

```sh
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Store the `.jks` outside the repo, or under `android/` (that directory ignores `*.jks` and `*.keystore`). Copy the example and fill in real values. Do not commit `android/key.properties` or the keystore.

```sh
cp android/key.properties.example android/key.properties
```

`storeFile` is resolved from `android/app/`. A keystore at `android/upload-keystore.jks` is `../upload-keystore.jks`. An absolute path works too.

| Key | Meaning |
| --- | --- |
| `storePassword` | Password for the keystore file |
| `keyPassword` | Password for the key entry |
| `keyAlias` | Alias passed to `keytool` (`upload` above) |
| `storeFile` | Path to the `.jks` or `.keystore` |

If `android/key.properties` is missing, the release build type signs with the debug keystore so local and CI release builds still run. A debug-signed artifact cannot be uploaded to the Play Store.

Release builds turn on R8 (`isMinifyEnabled`) and resource shrinking, using `proguard-android-optimize.txt` and `android/app/proguard-rules.pro`.

## Build

Android App Bundle (Play upload) and APK:

```sh
flutter build appbundle --release
flutter build apk --release
```

iOS. `flutter build ipa` needs an Apple signing team, which is not set yet. This checks the release compile without signing:

```sh
flutter build ios --release --no-codesign
```

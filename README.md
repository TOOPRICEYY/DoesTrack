# DoseTrack

DoseTrack is a SwiftUI iOS protocol and medication tracker built for local-first use with optional GitHub repository sync. The current UI is modeled from the screenshots in `model_app_screenshots`.

## Features

- Home, Tracker, Pulse, and Profile tabs matching the model app structure.
- Optimization stack/protocol management with active/inactive states.
- Four-step protocol editor for naming, medication selection, dose/schedule preferences, inventory toggles, and review.
- Medication catalog with dosage, instructions, notes, color, active state, protocol grouping, and inventory thresholds.
- Repeating schedules by time and weekday.
- Calendar and upcoming shots views.
- Notifications center with Today, Upcoming, and Reminders tabs.
- Customizable home card library.
- Manual dose logging and dated history review.
- Adherence insights, seven-day chart, streaks, and refill warnings.
- Local notification scheduling for active medication schedules.
- GitHub sync using the GitHub Contents API to push and merge a JSON backup file in a repository.

## GitHub Sync

Create a fine-grained GitHub personal access token with repository contents read/write access for the target repo. In the app, open Profile > App Settings > Data Management and enter:

- Repository owner
- Repository name
- Branch, usually `main`
- Backup file path, for example `DoseTrack/dosetrack-sync.json`
- Personal access token

The token is stored in the iOS Keychain. Sync writes a JSON backup through the GitHub Contents API rather than shelling out to `git`, which is the practical path on iOS.

## Build

Regenerate the Xcode project:

```sh
xcodegen generate
```

Build for a physical iOS target or generic device:

```sh
xcodebuild -project DoseTrack.xcodeproj -scheme DoseTrack -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The app icon asset catalog is present under `DoseTrack/Supporting/Assets.xcassets`, but it is excluded in `project.yml` for local sandbox builds because this environment's CoreSimulator asset compiler is unavailable. Re-enable the asset catalog and `ASSETCATALOG_COMPILER_APPICON_NAME` before a distribution archive.

## TestFlight Deployment

The project is configured for App Store Connect distribution with:

- iOS deployment target 17.0.
- Bundle identifier `com.gp.dosetrack`.
- Marketing version `1.0` and build number `1` from `project.yml`.
- Automatic signing style with Release builds using an Apple Distribution identity.
- A full `AppIcon` asset catalog is present on disk, including the 1024px marketing icon.
- A privacy manifest with no tracking domains or required-reason API declarations.
- `ITSAppUsesNonExemptEncryption=false` for standard platform/HTTPS encryption use.
- `Config/ExportOptions-TestFlight.plist` for App Store Connect upload.

Before uploading, confirm these publisher-specific values:

- Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if `com.gp.dosetrack` is not registered to your Apple Developer account.
- Increment `CURRENT_PROJECT_VERSION` in `project.yml` for every TestFlight upload after the first accepted build.
- Confirm the App Store Connect app privacy questionnaire. DoseTrack stores medication data locally and can optionally send a backup JSON file to GitHub when the user configures sync; the GitHub token is stored in Keychain.
- Confirm export compliance if the app later adds custom encryption beyond Apple's platform crypto, HTTPS, or Keychain usage.
- Re-enable `DoseTrack/Supporting/Assets.xcassets` in `project.yml` before archiving so the App Store build has its app icon.

Regenerate the project after changing `project.yml`:

```sh
xcodegen generate
```

Archive for App Store Connect. Replace `YOUR_TEAM_ID` with your Apple Developer Team ID:

```sh
xcodebuild \
  -project DoseTrack.xcodeproj \
  -scheme DoseTrack \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/DoseTrack.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates \
  archive
```

Upload the archive to App Store Connect/TestFlight:

```sh
xcodebuild \
  -exportArchive \
  -archivePath build/DoseTrack.xcarchive \
  -exportPath build/TestFlight \
  -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
  -allowProvisioningUpdates
```

You can also open `DoseTrack.xcodeproj` in Xcode, select the DoseTrack target, choose your Team under Signing & Capabilities, then use Product > Archive and distribute through Organizer.

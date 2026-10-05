# DoesTrack

DoesTrack is a SwiftUI iPhone, iPad, and Mac protocol and medication tracker built for local-first use with optional iCloud and GitHub repository sync. The current UI is modeled from the screenshots in `model_app_screenshots`.

## Features

- Home, Tracker, Pulse, and Profile tabs matching the model app structure.
- Optimization stack/protocol management with active/inactive states, plus per-medication pause with an optional auto-resume date ("Pause for X days").
- Four-step protocol editor for naming, medication catalog selection, dose/schedule preferences (per-dose or weekly-total amounts), per-dose cost tracking, inventory toggles, and review. Editing preserves custom weekday schedules, notes, and display names.
- Medication catalog with dosage, instructions, notes, color, active state, protocol grouping, and inventory thresholds.
- Repeating schedules by time and weekday.
- Calendar and upcoming shots views, with scheduled-dose dots and missed-day markers on the home date strip.
- Notifications center with Today, Upcoming, and Reminders tabs, including dose logging actions, weekly check-in state, and a persistent Mark All that clears the bell badge for the day.
- Customizable home card library: drag to reorder, half/full card sizes, per-card accent colors, and live values in the editor; layout persists as versioned JSON (with migration from the old format) and drives the Home tab, with week-over-week compliance deltas.
- Supplements with benefit tags, weekday schedules, daily check-off, and benefit-coverage tracking.
- Lab results with reference ranges, out-of-range detection, and a biomarker trend chart.
- Tap-to-log hydration card with a daily goal, per-protocol on/off cycling with live phase, and a reconstitution planner (concentration, U-100 syringe draw, doses per vial).
- Pulse chat as a persistent on-device thread (excluded from GitHub backups) plus a Fortnightly Review of adherence, doses, check-ins, body metrics, labs, and rule-based recommendations.
- Manual dose logging with structured method, injection site, pain, and site-reaction fields; site pickers show real last-used dates and can auto-pick the least recently used site.
- Adherence insights, seven-day chart, streaks, refill warnings, Pulse detail sheets, and local protocol chat summaries.
- Pharmacokinetic modelling in Pulse for supported protocol medications, with relative exposure curves (logged amounts take precedence over nominal doses) and citations for bundled default parameters.
- Local notification scheduling that runs automatically: reminders re-sync on launch, on foreground, and whenever medications or logs change (once permission is granted from Settings > Notifications), skip doses already logged, and stay below iOS's 64 pending-request limit.
- Discreet reminder settings (device-local, not synced): full / name-only (uses the medication nickname) / generic content with a custom title and message, hide details on the lock screen, sound / silent / quiet (passive) delivery, every dose or a once-a-day summary, remind-early lead time, follow-up nudges, snooze length, quiet hours, an optional weekly check-in reminder, a live preview, and a Send Test button.
- Mark Taken and Snooze actions directly on reminders (labelled Done / Later in generic mode).
- Monthly expense estimates computed from tracked per-dose costs and the upcoming 30-day schedule.
- GitHub sync using the GitHub Contents API to push and merge a JSON backup file in a repository.
- Private iCloud sync across iPhone, iPad, and Mac, with automatic launch/foreground/background sync, manual sync, conflict retry, and deletion propagation.

## Pharmacokinetic Modelling

Open Pulse > PK Model to view educational relative exposure curves for supported active medications. The model sums scheduled and recorded dose events with first-order absorption and first-order elimination:

```text
relative exposure = dose * scale * ka / (ka - ke) * (exp(-ke * elapsed days) - exp(-ka * elapsed days))
ke = ln(2) / elimination half-life days
ka = ln(2) / absorption half-life days
```

Bundled defaults currently cover:

- Tirzepatide: 5-day elimination half-life, 80% subcutaneous bioavailability, and 8-72 hour Tmax from the current [DailyMed Mounjaro label](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0).
- hCG: 32-33 hour elimination half-life and about 20 hour peak timing from [Mannaerts et al. 1998](https://pubmed.ncbi.nlm.nih.gov/9688371/), with route comparison support from [Saal et al. 1991](https://pubmed.ncbi.nlm.nih.gov/1712735/).
- BPC-157: preclinical rat/dog IV and IM short half-life and rapid IM peak timing from [Wu et al. 2022](https://doi.org/10.3389/fphar.2022.1026182). No validated human subcutaneous PK or absolute subcutaneous bioavailability was found, so this is a rough washout visualization only.
- Testosterone cypionate: an explicitly-labelled effective depot visualization model derived from [Nankin 1987](https://pubmed.ncbi.nlm.nih.gov/3595893/) observed post-injection serum timing and [DailyMed Depo-Testosterone](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cfbb53d4-b868-4a28-8436-f9112eb01c39) depot-label context, not a measured terminal half-life or serum testosterone prediction.

This feature is for tracking and visualization only. Absorption values are display assumptions or fits to published peak timing where direct route-specific parameters are unavailable. It does not estimate clinical serum concentration, optimize dosing, or replace labs or clinician guidance.

## GitHub Sync

Create a fine-grained GitHub personal access token with repository contents read/write access for the target repo. In the app, open Profile > App Settings > Data Management, sign in with the token, then choose an accessible repository from the repository picker. DoesTrack fills the owner, repo, and default branch from the selected repo; the backup file path defaults to `DoesTrack/doestrack-sync.json` and can be edited.

The token is stored in Keychain. Sync writes a JSON backup through the GitHub Contents API rather than shelling out to `git`, which works consistently on iPhone, iPad, and Mac. Manual owner/repo/branch fields remain available under advanced settings for fallback setup.

## iCloud Sync

Open Profile > App Settings > Data Management and turn on **Sync with iCloud**. DoesTrack stores its sync backup as an asset in the user's private CloudKit database and synchronizes on launch, when returning to the foreground, and when moving to the background. A manual **Sync iCloud Now** action is also available.

The synced backup includes medication protocols, dose logs, symptoms, supplements, labs, hydration, cycles, reconstitution plans, batches, and deletion tombstones. Apple Health snapshots and Pulse chat stay on the device, matching their existing privacy behavior.

The app uses the `iCloud.com.gp.doestrack` container. Before running a signed build, add that container to the App ID for `com.gp.doestrack` in the Apple Developer portal and enable CloudKit for both the iOS and Mac Catalyst provisioning profiles. Deploy the development CloudKit schema to production before distributing the app.

## Build

Regenerate the Xcode project:

```sh
xcodegen generate
```

Build for a physical iOS target or generic device:

```sh
xcodebuild -project DoesTrack.xcodeproj -scheme DoesTrack -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Build the universal Mac Catalyst app (macOS 14 or newer):

```sh
xcodebuild -project DoesTrack.xcodeproj -scheme DoesTrack -destination 'generic/platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```

In Xcode, select the **DoesTrack** scheme and choose **My Mac (Mac Catalyst)** to run the Mac app. The Catalyst destination intentionally reuses the iOS SwiftUI target so the full feature set remains available on Mac.

The app icon asset catalog is included under `DoesTrack/Supporting/Assets.xcassets` and `AppIcon` is configured as the app icon.

## TestFlight Deployment

The project is configured for App Store Connect distribution with:

- iOS deployment target 17.0.
- Mac Catalyst deployment target macOS 14.0, using the same bundle identifier for universal purchase and shared CloudKit data.
- Bundle identifier `com.gp.doestrack`.
- Marketing version `1.0` and build number `1` from `project.yml`.
- Automatic signing style with Apple Developer Team ID `7GXNZJMGPD`.
- A full `AppIcon` asset catalog is present on disk, including the 1024px marketing icon.
- A privacy manifest with no tracking domains or required-reason API declarations.
- `ITSAppUsesNonExemptEncryption=false` for standard platform/HTTPS encryption use.
- `Config/ExportOptions-TestFlight.plist` for App Store Connect upload.

Before uploading, confirm these publisher-specific values:

- Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if `com.gp.doestrack` is not registered to your Apple Developer account.
- Change `DEVELOPMENT_TEAM` in `project.yml` and `teamID` in `Config/ExportOptions-TestFlight.plist` if you use a different Apple Developer team.
- Increment `CURRENT_PROJECT_VERSION` in `project.yml` for every TestFlight upload after the first accepted build.
- Confirm the App Store Connect app privacy questionnaire. DoesTrack stores medication data locally and can optionally store a backup in the user's private iCloud database or send one to GitHub; the GitHub token is stored in Keychain.
- Confirm export compliance if the app later adds custom encryption beyond Apple's platform crypto, HTTPS, or Keychain usage.

Regenerate the project after changing `project.yml`:

```sh
xcodegen generate
```

Archive for App Store Connect:

```sh
xcodebuild \
  -project DoesTrack.xcodeproj \
  -scheme DoesTrack \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/DoesTrack.xcarchive \
  -allowProvisioningUpdates \
  archive
```

Upload the archive to App Store Connect/TestFlight:

```sh
xcodebuild \
  -exportArchive \
  -archivePath build/DoesTrack.xcarchive \
  -exportPath build/TestFlight \
  -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
  -allowProvisioningUpdates
```

You can also open `DoesTrack.xcodeproj` in Xcode, select the DoesTrack target, choose your Team under Signing & Capabilities, then use Product > Archive and distribute through Organizer.

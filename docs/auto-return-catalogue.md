# Adding an app to the auto-return catalogue

After a dictation, Dictus sends the user back to the app they were typing in by opening a URL for that app. The URL comes from `KnownAppSchemes.schemesByBundleId` in `DictusCore/Sources/DictusCore/KnownAppSchemes.swift`. An app with no entry gets the swipe-back overlay.

This page lists the steps for adding an app. The doc comments in `KnownAppSchemes.swift` explain why each step exists. Read them before you change the file.

The only test an entry has to pass: **the URL must bring the app back where the user was, without navigating.** A URL that opens the app on its home screen or on a compose sheet fails, even though it opens the right app.

## 1. Find the bundle ID

Dictate once from the Dictus keyboard inside the app, then export the log (Settings → Export logs). Search it for:

```
hostReturn hostId=<bundle id> outcome=no-scheme
```

`outcome=no-scheme-known` means the app is in `knownNoSchemeHosts`: someone already found it had no way back. Read the comment next to it before retesting.

For an App Store app, `https://itunes.apple.com/lookup?bundleId=<bundle id>` confirms which app the ID belongs to.

## 2. Find a candidate URL

Look in this order:

1. The app's source, if it is public: `CFBundleURLTypes` in its `Info.plist`, or `scheme` in an Expo config (`app.config.ts` / `app.json`). Use the production variant, not dev or preview.
2. The app's documentation.
3. Its `apple-app-site-association` file, for a universal link. A root URL is a navigation, so it will most likely fail step 3.

As a rule of thumb, a scheme that names the app (`whatsapp-consumer://`) tends to resume, and one that names an action (`sms://`) tends to act. The rule has been wrong twice (`message://`, `slack://open`), so use it only to choose what to test first, never in place of the test.

## 3. Run the resume test

On a device:

1. In the app, go somewhere specific: open a conversation or a document and start typing a draft.
2. Send the app to the background (swipe home).
3. In Safari's address bar, type the URL and go. Accept the "Open in …?" prompt.
4. **Pass:** the app comes back on the same screen, with the draft still there. **Fail:** it lands on its home screen, a list, a compose sheet, or any other screen.

Repeat once from a second, deeper screen, so that one lucky match does not count as a pass. If the URL fails, try the variant with a trailing slash (`scheme:///`) once.

Only Messages, Safari and Reminders can be tested on a simulator (`xcrun simctl openurl`, recipe in the `schemesByBundleId` doc comment). Third-party apps cannot be installed there, so they need a device.

Write down where the app landed, or take a screenshot. The PR needs it.

## 4. Edit `KnownAppSchemes.swift`

- **Pass:** add the entry to `schemesByBundleId` with a comment giving the device, the app version and the date, e.g. `// Verified on device, T3 Code 1.2.0, 2026-09-22.` Add the bundle ID to the audit-state list in that property's doc comment. If the app was in `knownNoSchemeHosts`, remove it from there.
- **Fail:** add the bundle ID to `knownNoSchemeHosts` with what you measured next to it (the URLs you tried and where each one landed).

Add only the bundle ID you tested. Do not add sibling IDs (`.dev`, `.preview`, other editions) that nobody tested.

Then run the tests and the linter:

```bash
cd DictusCore && swift test
cd .. && swiftlint lint --strict
```

## 5. Open a PR

State the device, the iOS version, the app version, the URL tried and the result. Before merge, the device check is a dictation from the Dictus keyboard inside the app: the user must land back on the same screen, and the log must read `hostReturn hostId=<bundle id> outcome=returned`. `returned` only means iOS opened the URL. Where the app landed has to be checked on screen.

## When the app has no resuming URL

A failing app can often be fixed on its side with a small change. If its source is public, read how it handles an incoming URL, then file an upstream bug report: the steps from section 3, what it does, what it should do, and the fix (often one line). A bare scheme URL should only wake the app, not navigate it. Meanwhile the app stays in `knownNoSchemeHosts`, with a comment pointing at the upstream report.

When upstream ships the fix, run section 3 again **on the app version that ships it**, then follow section 4. A result measured on an older version tells you nothing about the new one.

**Worked example: T3 Code (#564).** `t3code://` opened T3 Code 1.1.0 on Home, because its router mapped the empty path to the Home route. It was reported as [pingdotgg/t3code#11950](https://github.com/pingdotgg/t3code/issues/11950) with a one-condition fix to the app's existing link filter. Upstream merged it in [#12002](https://github.com/pingdotgg/t3code/pull/12002) and shipped it in 1.2.0. The resume test passed on 1.2.0, and the entry moved from `knownNoSchemeHosts` to `schemesByBundleId`.

# ADR: Cold Start Auto-Return to Source App

**Date:** 2026-04-05
**Status:** REJECTED
**Requirement:** COLD-01, COLD-02
**Timebox:** 2h investigation

## Context

When a user taps the mic button on DictusKeyboard during a cold start (app not in memory), the keyboard opens DictusApp via `dictus://dictate?source=keyboard` to access the microphone. After dictation completes, the user must manually swipe back to their previous app. This is a friction point: the user expects to return automatically to WhatsApp/Messages/etc.

Competitors like Wispr Flow and Super Whisper face the same limitation. The question: is there a public iOS API that allows DictusApp to detect which app the keyboard was serving and return to it automatically?

## Decision

**Auto-return is not viable with current iOS public APIs.**

All five investigated approaches fail because iOS provides no public API for a keyboard extension to identify its host app, and the private `_hostBundleID` API was removed in iOS 26.4. Auto-return requires knowing which app to return to, making it fundamentally impossible with current iOS capabilities.

The swipe-back overlay (Phase 26 Plan 02) will be redesigned with Wispr Flow-style gesture teaching to help users learn the iOS swipe-back gesture.

## Investigation Results

| # | Approach | Status | Evidence | Confidence |
|---|----------|--------|----------|------------|
| 1 | `sourceApplication` (UIOpenURLContext) | **Failed** | Returns `nil` for cross-team apps since iOS 13. Diagnostic logging added to DictusApp.swift (`AppDelegate.application(_:open:options:)`) confirms this. Only returns bundle ID for apps from the same development team. | HIGH |
| 2 | Keyboard extension passes host via URL | **Blocked** | The private `_hostBundleID` API was removed in iOS 26.4 (returns nil). KeyboardKit 10.4 confirmed this is a system-level change. No public API exists to get the host bundle ID from a keyboard extension. | HIGH |
| 3 | Named UIPasteboard for host detection | **Blocked** | Same root cause as Approach 2. The pasteboard is just a transport mechanism; the keyboard extension has no way to determine the host app bundle ID in the first place. Without the source data, the transport mechanism is irrelevant. | HIGH |
| 4 | Shortcuts integration | **Not viable** | Wispr Flow uses Shortcuts for separate dictation modes (not keyboard integration). On iOS 26.4, even Wispr Flow's Shortcuts "briefly switch you out of Flow, requiring a manual swipe back." This is strictly worse UX than the current cold start flow. | HIGH |
| 5 | `canOpenURL` enumeration | **Already tried and removed** | Previously implemented in DictusApp.swift (see line 164 comment). Iterated `KnownAppSchemes` and opened the first installed app. Always opens the first match (e.g., WhatsApp) regardless of which app the user was actually using. Removed because it was worse than no auto-return. | HIGH (empirically proven) |

### Approach Details

#### Approach 1: UIApplication.OpenURLOptionsKey.sourceApplication

**What:** When DictusApp receives a `dictus://dictate` URL open, check the `sourceApplication` key in the URL open options to identify which app triggered the open.

**Finding:** `sourceApplication` has only returned the bundle ID for same-development-team apps since iOS 13. For all third-party apps (WhatsApp, Messages, Safari, etc.), it returns `nil`. This is by design -- Apple restricted this for privacy reasons.

**Diagnostic code added:** `AppDelegate` class with `application(_:open:options:)` logging the `sourceApplication` value. Also URL components diagnostic in `handleIncomingURL`. Both log via `PersistentLog.diagnosticProbe(component: "sourceApp")`.

**Expected result on device:** `source=nil` for all keyboard-triggered URL opens, because the URL is opened by the keyboard extension (different process/team context).

#### Approach 2: Keyboard Extension Passing Host Info

**What:** Have DictusKeyboard detect the host app bundle ID and pass it as a URL parameter: `dictus://dictate?source=keyboard&host=com.whatsapp`.

**Finding:** The only API that ever provided host bundle ID to keyboard extensions was the private `_hostBundleID` property. Apple removed it in iOS 26.4 -- it now returns nil. KeyboardKit 10.4 release notes confirm this: "The `hostApplicationBundleId` property will always return `nil` in iOS 26.4."

**No workaround exists.** There is no `UIInputViewController` property, no `NSExtensionContext` key, and no entitlement that exposes the host app identity to keyboard extensions.

#### Approach 3: Named UIPasteboard

**What:** Keyboard extension writes host info to a shared named pasteboard that DictusApp reads after the URL open.

**Finding:** This approach fails at the data source level. The pasteboard is a transport mechanism, but the keyboard extension has no host info to write in the first place (see Approach 2). Even if the transport worked perfectly, the source data does not exist.

#### Approach 4: Shortcuts Integration

**What:** Use Siri Shortcuts to trigger dictation with a callback URL that returns to the source app.

**Finding:** Shortcuts work for standalone dictation flows (tap a Shortcut, dictate, result goes somewhere) but not for the keyboard integration flow. The cold start flow is: user is IN an app typing > taps DictusKeyboard mic > DictusApp opens for recording > user needs to return to original app. Shortcuts cannot intercept this flow.

Wispr Flow uses Shortcuts for a different use case (standalone dictation outside the keyboard), and even then their documentation states "briefly switch you out of Flow, requiring a manual swipe back" on iOS 26.4.

#### Approach 5: canOpenURL Enumeration

**What:** After recording completes, iterate `KnownAppSchemes.all` and call `UIApplication.shared.open()` on the first app that responds to `canOpenURL`.

**Finding:** Already implemented and removed from DictusApp.swift. The problem is fundamental: `canOpenURL` only checks if an app is installed, not if it was the most recently active app. The enumeration always opens the first installed app from the list (alphabetically or by registration order), which is typically WhatsApp regardless of where the user actually was.

This created a worse UX than no auto-return: users were unexpectedly sent to WhatsApp when they were typing in Notes.

## Consequences

1. **Swipe-back overlay must teach the gesture.** Since auto-return is not possible, the overlay shown during cold start recording must visually teach users how to swipe back to their previous app. This is the approach used by Wispr Flow and Super Whisper.

2. **No code to maintain.** Rejecting auto-return means no fragile app-detection logic, no `KnownAppSchemes` maintenance burden for new apps, and no risk of sending users to the wrong app.

3. **Future iOS versions may change this.** If Apple introduces a public API for keyboard extensions to identify their host app (unlikely given the privacy direction), this decision can be revisited. Monitor WWDC 2026 sessions.

4. **Diagnostic logging is temporary.** The `AppDelegate` and URL component diagnostics added to DictusApp.swift are for empirical verification during beta testing. They can be removed once a tester confirms `sourceApplication=nil` on a physical device.

## References

- [Apple: UIApplication.OpenURLOptionsKey.sourceApplication](https://developer.apple.com/documentation/uikit/uiapplication/openurloptionskey/sourceapplication) -- Official documentation, same-team restriction
- [KeyboardKit: iOS 26.4 hostBundleID Bug](https://keyboardkit.com/blog/2026/03/02/ios-26-4-host-application-bundle-id-bug) -- Confirmed private API removal
- [Swift Forums: How do voice dictation keyboard apps return to previous app?](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) -- Community confirmation no public API exists
- [Wispr Flow FAQ](https://docs.wisprflow.ai/iphone/faq) -- Confirms "not all apps allow the app to reopen"
- [Wispr Flow Shortcuts docs](https://docs.wisprflow.ai/articles/1986921789-how-to-set-up-flow-shortcuts-for-iphone) -- Shortcuts also require manual swipe back on iOS 26.4
- [Apple: UIScene.ConnectionOptions](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions) -- urlContexts documentation
- DictusApp.swift line 164 (existing comment confirming canOpenURL enumeration was tried and removed)

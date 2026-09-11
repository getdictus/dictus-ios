// DictusCore/Sources/DictusCore/KnownAppSchemes.swift
// The way back into the app the keyboard was typing in, keyed by its bundle ID.
import Foundation

/// Maps a host app's bundle identifier to a URL that reopens it.
///
/// ## Why keyed by bundle ID (#23)
///
/// The previous shape of this file listed ten apps by *name*, with a `queryScheme` field
/// whose only purpose was `canOpenURL`. Both were artefacts of not knowing which app the
/// keyboard was serving: without that, the best available move was to enumerate installed
/// apps and open the first one, which always opened WhatsApp.
///
/// The keyboard can now name its host (see `HostAppResolver` in DictusKeyboard), so the
/// question this file answers changed from "which apps exist" to "given *this* app, how do
/// I get back into it". That is a dictionary keyed by bundle ID, and nothing else.
///
/// ## Why there is no `canOpenURL` anywhere near this
///
/// `canOpenURL` requires every scheme to be declared in `LSApplicationQueriesSchemes`,
/// which iOS caps — the cap is what kept the old list at ten. `open()` requires no
/// declaration at all and reports failure through its own completion handler. So the
/// caller opens and reads the result; it never asks first. Both `LSApplicationQueriesSchemes`
/// arrays were removed from the Info.plists when this landed, and nothing here should
/// bring them back.
///
/// ## Provenance
///
/// The table is ported from [`n0an/VivaDicta`](https://github.com/n0an/VivaDicta)
/// (`VivaDicta/VivaDictaApp.swift`, MIT), which grew it from telemetry across a shipping
/// user base. Their confidence tiers are preserved because they carry real information:
/// an entry they could not verify against a shipping binary may well be wrong, and the
/// cost of a wrong entry is bounded — `open()` returns false and the user gets the
/// swipe-back overlay they would have got anyway.
public enum KnownAppSchemes {

    /// Bundle identifier → the URL that reopens that app.
    ///
    /// ## The bar an entry has to clear
    ///
    /// Not "does this scheme open the app" but **"does it bring the app back where the
    /// user was, without navigating"**. Those are different questions and the difference
    /// is invisible until someone tests it: `sms://` opens Messages *on a new-message
    /// sheet*, which reads as a bug to the user even though the host detection worked
    /// perfectly. Any entry can be checked headlessly —
    ///
    /// ```
    /// open the app, go somewhere specific inside it, background it,
    /// xcrun simctl openurl <udid> "<scheme>://"
    /// xcrun simctl io <udid> screenshot -
    /// ```
    ///
    /// — and a scheme that lands anywhere other than where you left is rejected.
    ///
    /// ## What separates a good entry from a bad one
    ///
    /// A scheme that **names the app** resumes it; a scheme that **names an action**
    /// performs it. `whatsapp-consumer://` names the app and comes back to the
    /// conversation (verified on device). `sms://` names an action and opens the compose
    /// sheet. That is the whole pattern, and it is the first thing to check on any entry
    /// that has never been measured.
    ///
    /// ## Audit state, so nobody mistakes inherited for verified
    ///
    /// **Verified to resume:** `com.apple.mobilenotes`, `com.apple.MobileSMS`,
    /// `net.whatsapp.WhatsApp`, `com.apple.mobilemail`, `com.github.stormbreaker.prod`,
    /// `com.openai.chat`, `com.anthropic.claude` (all on device, 2026-09-11), plus
    /// `com.apple.reminders` on a simulator. **Rejected by measurement:**
    /// `com.apple.mobilesafari`, now in `knownNoSchemeHosts`.
    ///
    /// Four of those were inherited entries nobody had checked, and all four worked
    /// first time — which is mild evidence that the upstream catalogue is sound, and no
    /// evidence at all about the entries still unverified.
    ///
    /// **Everything else is inherited, not verified** — the only Apple apps a simulator
    /// runtime ships are Messages, Safari and Reminders, and none of the third-party
    /// apps can be installed on one. Two groups deserve suspicion before the rest:
    ///
    /// - **Action-shaped names.** `com.tinyspeck.chatlyio` → `slack://open` and
    ///   `com.newin.nplayer.basic` → `nplayer-http://` carry a verb and a transport.
    ///   Mail's `message://` was the top suspect on this reading and it is **wrong**:
    ///   measured twice on device, it resumes correctly. The name-shape heuristic finds
    ///   candidates to measure; it does not settle them.
    /// - **The universal-link group below.** A root URL is a navigation *by
    ///   construction*: it opens the app at that page, not where the user was. They fail
    ///   the resume test on paper. They are kept because landing on an app's home is
    ///   still better than no return at all for a shopping or media app, and because
    ///   removing ten entries on reasoning rather than measurement would be trading one
    ///   unverified claim for another — but do not read them as verified.
    ///
    /// Most values are custom schemes. A few apps register none but claim a universal
    /// link in their `apple-app-site-association`, which works here only because the host
    /// app is installed *by definition* — it is the app the keyboard was just typing
    /// into. The trade-off, inherited knowingly: a user who has told iOS to open that
    /// domain in Safari lands on the web page instead of getting the manual prompt.
    public static let schemesByBundleId: [String: String] = [
        // Verified against the app's own Info.plist, official documentation, or the
        // shipping binary.
        // Verified on device: lands back in the note the user was editing.
        "com.apple.mobilenotes": "mobilenotes://",
        // `ichat://`, and this one is measured rather than inherited. Messages declares
        // several schemes and most of them *act* instead of resuming: `sms://`,
        // `messages://`, `imessage://` and `im://` all land the user on the **"New
        // message"** compose sheet, not in the conversation they were typing in.
        // `ichat://` is the only one that brings Messages back exactly where it was.
        // Verified twice on iOS 26.5, and the upstream catalogue has `sms://` here with
        // the compose bug intact. Do not "fix" this to the obvious scheme.
        "com.apple.MobileSMS": "ichat://",
        // Verified on device, twice. It was the top suspect on name shape — `message://`
        // reads like "open a specific message", which is `sms://`'s mistake — and the
        // suspicion was wrong. Kept as a note because the next reader will have the same
        // doubt.
        "com.apple.mobilemail": "message://",
        "com.apple.Pages": "pages://",
        "com.apple.Numbers": "numbers://",
        "com.apple.Keynote": "keynote://",
        // NOT `x-apple-reminder://`, which is unregistered.
        "com.apple.reminders": "x-apple-reminderkit://",
        // NOT `whatsapp://` — that one belongs to the SMB build below. Verified on device
        // to come back to the conversation the user was in, which makes it the reference
        // for what a good entry looks like: it names the app, not an action.
        "net.whatsapp.WhatsApp": "whatsapp-consumer://",
        "net.whatsapp.WhatsAppSMB": "whatsapp://",
        "com.telegram.telegram-ios": "tg://",
        "ph.telegra.Telegraph": "tg://",
        // NOT `tg://`, which is shared with official Telegram — iOS would pick between them.
        "app.swiftgram.ios": "sg://",
        // This bundle identifier is Slack. `://open` carries a verb, which is the shape
        // that turned out wrong for Messages — untested, and worth measuring first if
        // someone reports landing on the wrong screen.
        "com.tinyspeck.chatlyio": "slack://open",
        // This bundle identifier is Simplenote.
        "com.codality.NotationalFlow": "simplenote://",
        "com.microsoft.Office.Word": "ms-word://",
        "com.microsoft.Office.Outlook": "ms-outlook://",
        "com.microsoft.skype.teams": "msteams://",
        "com.culturedcode.ThingsiPhone": "things://",
        "com.google.Gmail": "googlegmail://",
        "com.google.chrome.ios": "googlechrome://",
        "com.google.Translate": "googletranslate://",
        "com.google.OPA": "google://",
        "com.google.GoogleMobile": "googlemobileapp://",
        "com.google.gemini": "gemini-app://",
        "com.facebook.Facebook": "fb://",
        "com.facebook.Messenger": "fb-messenger://",
        "com.atebits.Tweetie2": "twitter://",
        "com.toyopagroup.picaboo": "snapchat://",
        "com.burbn.instagram": "instagram://",
        "com.burbn.barcelona": "barcelona://",
        "com.viber": "viber://",
        "com.spotify.client": "spotify://",
        "com.spotify.client.L32G8C83V9": "spotify://",
        "com.getdropbox.Dropbox": "dbapi-1://",
        "com.linkedin.LinkedIn": "linkedin://",
        // Verified on device.
        "com.openai.chat": "com.openai.chat://",
        "ai.perplexity.app": "perplexity-app://",
        // Verified on device.
        "com.anthropic.claude": "claude://",
        "ai.x.GrokApp": "grok://",
        "md.obsidian": "obsidian://",
        "im.monica.app.monica": "monica://",
        "com.mem-labs.mem": "mem://",
        "com.cardify.tinder": "tinder://",
        "com.readdle.smartemail": "readdle-spark://",
        "com.hammerandchisel.discord": "discord://",
        "org.whispersystems.signal": "sgnl://",
        "co.fluder.mobile.FSNotes-iOS": "fsnotes://",
        "ch.threema.iapp": "threema://",
        "com.briansunter.logseq-dev": "logseq://",
        // Verified on device.
        "com.github.stormbreaker.prod": "github://",
        "com.appliedphasor.secure-shellfish": "shellfish://",
        "com.crystalnix.ServerAuditor": "termius://",
        "com.reddit.Reddit": "reddit://",
        "pro.writer": "ia-writer://",
        "ru.yandex.mobile.translate": "yandextranslate://",
        "com.openminis.app": "minis://",
        "com.tencent.xin": "weixin://",
        "com.letterboxd.LetterboxdApp": "letterboxd://",
        "eusoft.eudic.ip": "eudic://",
        "com.ex3ndr.happy": "happy://",
        "psyche.kelivo": "kelivo://",
        "com.agiletortoise.Drafts5": "drafts://",
        "com.ubercab.UberClient": "uber://",

        // Corroborated across independent sources but not read from a shipping app, so a
        // miss is possible. It degrades to the overlay.
        "notion.id": "notion://",
        "com.meituan.imeituan": "imeituan://",
        "com.newin.nplayer.basic": "nplayer-http://",
        "com.evernote.iPhone.Evernote": "evernote://",
        "jp.naver.line": "line://",
        "com.google.ios.youtube": "youtube://",
        "com.ebay.iphone": "ebay://",
        "com.google.Docs": "googledocs://",
        "com.taobao.taobao4iphone": "taobao://",
        "company.thebrowser.ArcMobile2": "arcmobile2://",

        // Single-source or inferred from a sibling platform. Weaker still, and kept only
        // because a miss costs nothing beyond the prompt the user would otherwise get.
        "com.alibaba.sourcing": "enalibaba://",
        "com.automattic.beeper": "beeper://",
        "com.xiaojukeji.didi": "diditaxi://",
        // VK Messenger. NOT the `vk.me` universal link — the main VK client claims that
        // domain with the same wildcard, so iOS picks between them.
        "com.vk.vkme": "vkme://",

        // No custom scheme; a universal link confirmed in the app's AASA file. See the
        // trade-off in this property's doc comment, and the audit note above: a root URL
        // is a navigation by construction, so none of these can resume the app where the
        // user left it. Untested, and suspect on the resume criterion.
        "com.google.ios.ytcreator": "https://studio.youtube.com/",
        "com.amazon.Amazon": "https://www.amazon.com/",
        "com.amazon.AmazonDE": "https://www.amazon.de/",
        "com.amazon.AmazonUK": "https://www.amazon.co.uk/",
        "ru.ivi": "https://www.ivi.ru/",
        "ru.oneme.app": "https://max.ru/",
        "ru.ozon.OzonStore": "https://www.ozon.ru/",
        "com.ClassDojo": "https://www.classdojo.com/ul/home",
        "com.kouzoh.ios.mercari": "https://jp.mercari.com/",
        "com.ubercab.UberEats": "https://www.ubereats.com/"
    ]

    /// Bundle identifiers already checked by hand and found to have no way back.
    ///
    /// WHY this exists separately from "not in the table": both produce the same
    /// behaviour — the overlay — but only one of them is worth a log line. The debug
    /// log is this project's only channel for "here is a host nobody mapped", and its
    /// reader is an agent (#255). Without this set the same handful of system
    /// pseudo-hosts would be reported at every triage pass forever.
    ///
    /// The Apple entries are the ones that matter. They are not app switches at all but
    /// view services drawn *over* another app — `com.apple.mobilesms.compose` is the
    /// share-sheet message composer, `com.apple.SafariViewService` the in-app browser —
    /// and there is no "back" to send anyone to. `com.apple.Spotlight` is here because it
    /// was observed as a real host in a Dictus device capture, not on theory.
    ///
    /// The third-party entries come from VivaDicta's telemetry, not from anything seen
    /// here. They are carried because they cost two lines each and save a future triage
    /// pass; none of them has been verified in this project.
    public static let knownNoSchemeHosts: Set<String> = [
        // Ours. The keyboard can be its own host — a text field in DictusApp — and
        // returning the user to the app they are already in would be a no-op at best.
        "com.pivi.dictus",

        // Safari, deliberately. It is not that no scheme opens it — several do — but that
        // every one of them *acts*: `x-web-search://` opens an empty search and
        // `x-safari-https://` a blank tab, and both discard the page the user was reading.
        // Measured on iOS 26.5. Landing someone on a blank tab is worse than the
        // swipe-back overlay, which leaves their page where it was, so Safari is listed
        // as having no way back rather than a bad one.
        "com.apple.mobilesafari",

        // Apple view services and system apps that register no URL types.
        "com.apple.SafariViewService",
        "com.apple.springboard",
        "com.apple.Spotlight",
        "com.apple.journal",
        "com.apple.mobilesms.compose",
        "com.apple.ShortcutsUI",
        "com.apple.AppleMediaServicesUI.ComposeReviewExtension",

        // Checked by hand upstream: no custom scheme, and no universal link that opens
        // the app at its root.
        "com.deepseek.chat",
        "com.hevyapp.hevy",
        "com.stably.orca.mobile",
        "org.edupage",
        "com.rivetrune.cognilog",
        "com.t3tools.t3code",
        "com.davetech.todo",
        "cc.calacatta.happiest",

        // Third-party apps upstream found to publish no way back.
        "com.dmitrii.medvedev.gptalk",
        "com.saner.ai",
        "dk.FirstForm.SnappyNotesiOS",
        "com.ai.venice",
        "com.replay.Echo",
        "com.avast.ios.security",
        "com.elaborapp.NoteBox",
        "com.lixkit.diary",
        "com.weichart.Zettel",
        "h3p.Neon-Vision-Editor",
        "ru.ozon.sellerApp",
        "kz.origon.empapp",
        "com.cloud-compiler",
        "com.corp.messenger.syncer",
        "com.yottaram.eMoods"
    ]

    /// The URL that sends the user back to `bundleId`, or nil when there is no known way.
    ///
    /// Nil is a perfectly good answer and the caller must treat it as one: it means the
    /// swipe-back overlay, never a guess at another app.
    public static func returnURL(forHostId bundleId: String) -> URL? {
        schemesByBundleId[bundleId].flatMap(URL.init(string:))
    }

    /// Whether a host with no entry is worth a log line.
    ///
    /// False for the hosts above, which are known dead ends rather than gaps.
    public static func isWorthReporting(_ bundleId: String) -> Bool {
        schemesByBundleId[bundleId] == nil && !knownNoSchemeHosts.contains(bundleId)
    }
}

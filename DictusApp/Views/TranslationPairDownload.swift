// DictusApp/Views/TranslationPairDownload.swift
// Downloading the language pair a Translate mode needs (issue #648).
import SwiftUI
import DictusCore
#if canImport(Translation)
import Translation
#endif

/// Downloads a language pair for Apple's Translation framework, from any screen of the
/// app (#648).
///
/// Translate runs on the framework's `.highFidelity` strategy, which only translates a
/// pair installed on the iPhone. Installing one goes through `prepareTranslation()`,
/// which can present a system prompt, and SwiftUI's `.translationTask` is the only way
/// to host it. That is why this is a view modifier, and why it lives in DictusApp: a
/// keyboard extension cannot present it, so the keyboard never downloads anything.
///
/// One component, several callers. The Smart Modes settings list offers it when a
/// Translate mode's pair is missing; the onboarding's "pick three Smart Modes" step
/// (#649, decision 16) will call it when the user pins a Translate mode.
///
/// ```swift
/// @State private var download: TranslationLanguagePair?
/// …
/// .translationPairDownload($download) { pair, status in … }
/// // then, to start: download = TranslationLanguagePair(source: "fr", target: .english)
/// ```
///
/// Setting the binding starts the download; the modifier sets it back to nil when it is
/// over and reports the pair's status at that moment. A refusal or a failed download is
/// not an error the user has to see: Translate keeps working on Apple FM, and the
/// status the callback receives is still `.notInstalled`.
extension View {
    func translationPairDownload(
        _ pair: Binding<TranslationLanguagePair?>,
        onFinished: @escaping (TranslationLanguagePair, TranslationPairStatus) -> Void = { _, _ in }
    ) -> some View {
        modifier(TranslationPairDownloadModifier(pair: pair, onFinished: onFinished))
    }
}

private struct TranslationPairDownloadModifier: ViewModifier {
    @Binding var pair: TranslationLanguagePair?
    let onFinished: (TranslationLanguagePair, TranslationPairStatus) -> Void

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 26.4, *) {
            content.modifier(PrepareModifier(pair: $pair, onFinished: onFinished))
        } else {
            // Below 26.4 Translate runs on Apple FM only: there is nothing to download.
            content.onChange(of: pair) { _, requested in
                guard let requested else { return }
                pair = nil
                onFinished(requested, .unknown)
            }
        }
        #else
        content
        #endif
    }
}

#if canImport(Translation)
@available(iOS 26.4, *)
private struct PrepareModifier: ViewModifier {
    @Binding var pair: TranslationLanguagePair?
    let onFinished: (TranslationLanguagePair, TranslationPairStatus) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var preparing: TranslationLanguagePair?

    func body(content: Content) -> some View {
        content
            .onChange(of: pair) { _, requested in
                guard let requested, preparing == nil else { return }
                preparing = requested
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: requested.source),
                    target: Locale.Language(identifier: requested.target.rawValue),
                    preferredStrategy: .highFidelity
                )
            }
            .translationTask(configuration) { session in
                // A refusal or a failure is not surfaced: the status read below says
                // what happened, and Translate works on Apple FM either way.
                try? await session.prepareTranslation()
                guard let finished = await MainActor.run(body: { preparing }) else { return }
                let status = await TranslationPairStatus.current(for: finished)
                await MainActor.run {
                    preparing = nil
                    configuration = nil
                    pair = nil
                    onFinished(finished, status)
                }
            }
    }
}
#endif

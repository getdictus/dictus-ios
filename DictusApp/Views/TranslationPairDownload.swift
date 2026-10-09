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
/// status the callback receives is still `.notInstalled`. Each request writes one
/// `translationPairPrepared` line to the persistent log, with the status before and after.
///
/// `strategy` is `.highFidelity`, what Translate ships on, unless a caller says
/// otherwise. Only the Polish debug screen does: with Apple Intelligence on,
/// `.highFidelity` never needs a download (`TranslationPairStatus`), so a `.lowLatency`
/// pair is the only way to see the system prompt this component exists to host.
extension View {
    func translationPairDownload(
        _ pair: Binding<TranslationLanguagePair?>,
        strategy: TranslationStrategy = .highFidelity,
        onFinished: @escaping (TranslationLanguagePair, TranslationPairStatus) -> Void = { _, _ in }
    ) -> some View {
        modifier(TranslationPairDownloadModifier(pair: pair, strategy: strategy, onFinished: onFinished))
    }
}

private struct TranslationPairDownloadModifier: ViewModifier {
    @Binding var pair: TranslationLanguagePair?
    let strategy: TranslationStrategy
    let onFinished: (TranslationLanguagePair, TranslationPairStatus) -> Void

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 26.4, *) {
            content.modifier(PrepareModifier(pair: $pair, strategy: strategy, onFinished: onFinished))
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
    let strategy: TranslationStrategy
    let onFinished: (TranslationLanguagePair, TranslationPairStatus) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var preparing: Request?

    /// What is being prepared, captured when it was asked for.
    private struct Request {
        let pair: TranslationLanguagePair
        let strategy: TranslationStrategy
        let before: TranslationPairStatus
        let start: Date
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: pair) { _, requested in
                guard let requested, preparing == nil else { return }
                let strategy = self.strategy
                Task {
                    let before = await TranslationPairStatus.current(for: requested, strategy: strategy)
                    preparing = Request(pair: requested, strategy: strategy, before: before, start: Date())
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: requested.source),
                        target: Locale.Language(identifier: requested.target.rawValue),
                        preferredStrategy: strategy == .lowLatency ? .lowLatency : .highFidelity
                    )
                }
            }
            .translationTask(configuration) { session in
                // A refusal or a failure is not surfaced to the user: the status read
                // below says what happened, and Translate works on Apple FM either way.
                var errorSlug = "-"
                do {
                    try await session.prepareTranslation()
                } catch {
                    errorSlug = TranslateRoutingPolishEngine.slug(of: error)
                }
                guard let request = await MainActor.run(body: { preparing }) else { return }
                let after = await TranslationPairStatus.current(for: request.pair, strategy: request.strategy)
                PersistentLog.log(.translationPairPrepared(
                    strategy: request.strategy.rawValue, source: request.pair.source,
                    target: request.pair.target.rawValue, before: request.before.rawValue,
                    after: after.rawValue, ms: Int(Date().timeIntervalSince(request.start) * 1000),
                    error: errorSlug
                ))
                await MainActor.run {
                    preparing = nil
                    configuration = nil
                    pair = nil
                    onFinished(request.pair, after)
                }
            }
    }
}
#endif

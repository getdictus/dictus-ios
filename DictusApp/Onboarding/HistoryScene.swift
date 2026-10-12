// DictusApp/Onboarding/HistoryScene.swift
// The history scene: the real History sheet, searched for a word (#680).
import SwiftUI
import DictusCore

/// The onboarding step that plays the history scene (#680, mock-up
/// `07c-scene-historique`).
struct HistoryScenePage: View {
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void

    /// The cards, built once: their dates are relative to today.
    private let records = HistorySceneText.records(now: Date())

    var body: some View {
        OnboardingScenePage(
            title: Text("Everything is easy to find",
                        comment: "Onboarding history scene: title (#680)."),
            line: Text("Every dictation stays on your iPhone. Search for a word, find the text.",
                       comment: "Onboarding history scene: the line under the title (#680)."),
            phoneEnd: .top,
            loopSeconds: HistorySceneScript.loopSeconds,
            stillSeconds: HistorySceneScript.stillSeconds,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) { time in
            HistoryScene(time: time, records: records)
        }
    }
}

/// The scene: the History sheet as `HistoryView` presents it from the home screen, its
/// cards, and the search bar at its bottom (`HistorySceneScript`).
///
/// WHAT IS REAL AND WHAT IS DRAWN (#649 decision 13): the cards are the app's own
/// `HistoryCard`, fed records built for the scene, and the cards that stay while a word is
/// typed are the ones `TranscriptionSearch` keeps, the screen's own filter. Not the view
/// itself: `HistoryView` reads the user's real history and its Pro gate, and a scene shows
/// the same cards to everyone. The sheet's grabber, its navigation bar and the search bar
/// are iOS's, so they are drawn.
///
/// Drawn for a 402 pt wide iPhone, then scaled to the card as one picture.
struct HistoryScene: View {
    /// Seconds into the loop.
    let time: Double
    /// Every card of the sheet, newest first.
    let records: [TranscriptionRecord]

    private typealias Target = HistorySceneScript.Target

    /// The width the mock-ups are drawn at.
    private static let screenWidth = SmartModesSceneMetrics.screenWidth
    /// The part of the screen the card shows: the sheet's top down to its search bar.
    static let screenHeight: CGFloat = 560

    var body: some View {
        let frame = HistorySceneScript.frame(at: time, word: HistorySceneText.searchedWord)
        GeometryReader { geometry in
            screen(frame)
                .frame(width: Self.screenWidth, height: Self.screenHeight, alignment: .top)
                .clipped()
                .scaleEffect(geometry.size.width / Self.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Self.screenWidth / Self.screenHeight, contentMode: .fit)
    }

    private func screen(_ frame: HistorySceneScript.Frame) -> some View {
        let visible = HistorySceneScript.visibleRecords(records, query: frame.query)
        return VStack(spacing: 0) {
            // The sheet's grabber (`presentationDragIndicator(.visible)`).
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            if !frame.isSearching {
                // While a search is active, iOS hides the bar to make room.
                SceneNavigationBar(title: Text("History"), leading: .close)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            // The cards hang from the top of the space left above the search bar, and the
            // ones that do not fit are cut, as a list scrolls them under the bar. An
            // overlay, so six cards cannot push the bar out of the crop.
            Color.clear
                .overlay(alignment: .top) {
                    VStack(spacing: 12) {
                        ForEach(visible) { record in
                            HistoryCard(record: record)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .clipped()

            searchBar(frame)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color.dictusBackground)
        .sceneFinger(frame.finger)
        .animation(.easeInOut(duration: 0.25), value: visible.map(\.id))
        .animation(.easeOut(duration: 0.25), value: frame.isSearching)
    }

    /// iOS 26's search bar at the bottom of a `.searchable` screen: a glass capsule with
    /// the prompt or the query, and the round close button beside it while searching.
    private func searchBar(_ frame: HistorySceneScript.Frame) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 1) {
                    if frame.query.isEmpty {
                        if frame.isSearching { cursor }
                        Text("Search transcriptions")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: frame.query)
                            .foregroundStyle(.primary)
                        cursor
                    }
                }
                .font(.system(size: 17))
                .lineLimit(1)
                Spacer(minLength: 0)
                if !frame.query.isEmpty {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .dictusGlass(in: Capsule())
            .sceneTapTarget(Target.searchField)

            if frame.isSearching {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .dictusGlass(in: Circle())
                    .sceneTapTarget(Target.closeSearch)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    /// The text cursor, blinking once a second like UIKit's.
    private var cursor: some View {
        Capsule()
            .fill(Color.dictusAccent)
            .frame(width: 2, height: 22)
            .opacity(time.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
    }
}

// MARK: - Text

/// The scene's cards and the word searched for, in the user's language.
enum HistorySceneText {
    /// The word typed in the search bar. Three of the six cards contain it.
    static var searchedWord: String {
        String(localized: "dentist",
               comment: "Onboarding history scene: the word typed in the drawn search bar. It must appear in three of the scene's six transcriptions: the dentist reminder, the shopping list and the check-up (#680).")
    }

    /// The six cards of mock-up 07c and of the captures of the real app, newest first:
    /// two from today, the rest from the previous weeks. The third is the voice note the
    /// voice notes scene shared, as History keeps it (#620).
    static func records(now: Date) -> [TranscriptionRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let language = String((Bundle.main.preferredLocalizations.first ?? "en").prefix(2))
        func record(_ text: String, seconds: Int, at createdAt: Date,
                    source: TranscriptionSource = .dictation) -> TranscriptionRecord {
            TranscriptionRecord(text: text, language: language, durationSeconds: seconds, createdAt: createdAt,
                                sttProvider: SpeechEngine.parakeet.rawValue, source: source)
        }
        return [
            record(String(localized: "Remember to call the dentist to move Thursday's appointment.",
                          comment: "Onboarding history scene: a saved dictation, today. Contains the searched word 'dentist' (#680)."),
                   seconds: 9, at: date(daysAgo: 0, hour: 20, minute: 42)),
            record(String(localized: "Hi! Yes, we're still having dinner together tonight. I booked a table at Nonna's for 7:30, but my train is running about ten minutes late.",
                          comment: "Onboarding history scene: a saved dictation, today. Must NOT contain the searched word 'dentist' (#680)."),
                   seconds: 14, at: date(daysAgo: 0, hour: 19, minute: 42)),
            record(VoiceNotesSceneText.transcript, seconds: 252, at: date(daysAgo: 7, hour: 18, minute: 42),
                   source: .sharedFile),
            record(String(localized: "Shopping list: pharmacy, dentist, dry cleaner, and the groceries for the weekend.",
                          comment: "Onboarding history scene: a saved dictation. Contains the searched word 'dentist' (#680)."),
                   seconds: 8, at: date(daysAgo: 8, hour: 12, minute: 0)),
            record(String(localized: "Hello Mrs Kowalczyk, I'm confirming our appointment on Tuesday at 10 a.m.",
                          comment: "Onboarding history scene: a saved dictation. Must NOT contain the searched word 'dentist' (#680)."),
                   seconds: 11, at: date(daysAgo: 9, hour: 12, minute: 0)),
            record(String(localized: "The dentist said to come back in six months for a check-up.",
                          comment: "Onboarding history scene: a saved dictation. Contains the searched word 'dentist' (#680)."),
                   seconds: 6, at: date(daysAgo: 14, hour: 12, minute: 0))
        ]
    }
}

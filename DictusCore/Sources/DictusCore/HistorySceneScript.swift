// DictusCore/Sources/DictusCore/HistorySceneScript.swift
// What the onboarding's history scene shows at each moment of its loop (#680).
import Foundation

/// The script of the history scene (#680, #649 decision 9.4, #621, mock-up
/// `07c-scene-historique`): the real History sheet, searched for a word from the search
/// bar at its bottom.
///
/// THE STORY: the sheet shows its cards, newest first, under the title. The finger taps
/// the search bar; the title goes, as iOS does while a search is active, and the bar
/// gains its close button. A word is typed one letter at a time, and the cards narrow
/// down with each letter. The cards that stay are the ones the app itself would keep:
/// the scene filters them with `TranscriptionSearch`, the History screen's own rule. The
/// finger then closes the search and every card comes back, which is where the loop
/// started.
public enum HistorySceneScript {

    /// What the drawn finger taps.
    public enum Target: Hashable, Sendable {
        /// The search bar at the bottom of the sheet.
        case searchField
        /// The round close button beside it while a search is active.
        case closeSearch
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// Whether the search is active: no title, the cursor in the bar, the close
        /// button beside it.
        public let isSearching: Bool
        /// What the search bar holds so far.
        public let query: String
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    enum Beat {
        static let tapSearch = SceneTap(Target.searchField, press: 1.3, release: 1.5)
        static let typing: ClosedRange<Double> = 1.8...3.4
        static let tapClose = SceneTap(Target.closeSearch, press: 7.3, release: 7.5)
    }

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [Beat.tapSearch, Beat.tapClose]

    /// One pass: 10 s, decision 14's lower bound. One gesture, one result: a longer
    /// loop would only hold the same cards on screen.
    public static let loopSeconds: Double = 10

    /// The moment shown with Reduce Motion on: the word typed and the cards it found,
    /// the frame mock-up 07c draws.
    public static let stillSeconds: Double = 5.5

    /// The scene at `time` seconds into the loop.
    ///
    /// - Parameter word: the word searched for, localized by the caller.
    public static func frame(at time: Double, word: String) -> Frame {
        let isSearching = time >= Beat.tapSearch.release && time < Beat.tapClose.release
        return Frame(
            isSearching: isSearching,
            query: isSearching
                ? SceneTyping.typed(word, from: Beat.typing.lowerBound, to: Beat.typing.upperBound, at: time)
                : "",
            finger: taps.finger(at: time)
        )
    }

    /// The cards the sheet shows for `query`: the History screen's own filter.
    public static func visibleRecords(_ records: [TranscriptionRecord], query: String) -> [TranscriptionRecord] {
        TranscriptionSearch.filter(records, query: query)
    }
}

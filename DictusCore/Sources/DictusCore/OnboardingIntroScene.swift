// DictusCore/Sources/DictusCore/OnboardingIntroScene.swift
// The three scenes of the onboarding intro carousel and the files that play them (#676).
import Foundation

/// One page of the intro carousel that opens the onboarding (#649 decision 15, #676).
///
/// The three scenes tell one story, the voice goes into the phone and comes out as text:
/// walking, the metro without network, the keyboard in a note. Each page loops a silent
/// video rendered by #667 (`assets/onboarding/intro/`), one light and one dark render, under
/// a localized headline and subtitle that are SwiftUI text, never baked into the video.
///
/// WHY IN DICTUSCORE: the order of the pages and the names of the files are what the app
/// and the render script have to agree on. A rename on one side would silently drop the
/// page to its still frame; the tests pin both to the files that exist.
public enum OnboardingIntroScene: String, CaseIterable, Sendable {
    /// A, walking: *Parlez. Dictus écrit.*
    case walking = "a"
    /// B, the metro with no network: *Même sans réseau.*
    case metro = "b"
    /// C, the Dictus keyboard in a note: *Dans votre clavier.*
    case keyboard = "c"

    /// Extension of every intro video.
    public static let videoExtension = "mp4"

    /// The bundle resource name of this scene's video for one appearance, without the
    /// extension: `intro-a-light`, `intro-a-dark`, and so on.
    ///
    /// WHY THE APPEARANCE PICKS THE FILE: the videos are opaque and each carries its page
    /// colour (#F2F2F7 light, #0A1628 dark), so the edge of the video only disappears
    /// against the background it was rendered for.
    public func videoResourceName(dark: Bool) -> String {
        "intro-\(rawValue)-\(dark ? "dark" : "light")"
    }

    /// The asset catalog image shown in place of the video: under it until the first frame
    /// is ready, and alone when the video file is not in the bundle. One image set per
    /// scene, with a light and a dark appearance.
    public var stillImageName: String {
        "intro-\(rawValue)-still"
    }

    /// Length of one pass of the scene's loop, in seconds (#667, `assets/onboarding/intro/README.md`).
    ///
    /// It is also how long the carousel stays on the page before moving on by itself
    /// (`IntroAutoAdvance`), so each scene is seen once in full. A page showing only its
    /// still keeps the same rhythm.
    public var loopSeconds: Double {
        switch self {
        case .walking: return 5.5
        case .metro: return 5.5
        case .keyboard: return 6.5
        }
    }

    /// The page the carousel moves to after this one: the next scene, and the first one
    /// again after the last.
    public var nextPage: OnboardingIntroScene {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// Whether moving on from this page goes back to the first one rather than forward.
    public var wrapsToFirstPage: Bool {
        nextPage == Self.allCases.first && self != Self.allCases.first
    }

    /// Where in the video the still was taken, in seconds. The video's first play starts
    /// here, so the hand-over from the still to the moving picture shows no jump.
    ///
    /// WHY THESE MOMENTS: each is the frame that tells the scene on its own, for the page
    /// that has no video: A's reply fully written, B's mail draft fully written, C's
    /// keyboard recording (the waveform with ✕ and ✓, as mock-up 01c draws it).
    /// The PNGs in the asset catalog were taken at these times (see `stillImageName`); a
    /// new time needs new PNGs.
    public var stillFrameSeconds: Double {
        switch self {
        case .walking: return 4.5
        case .metro: return 4.5
        case .keyboard: return 3.0
        }
    }
}

// DictusApp/Views/TestDictationView.swift
// In-app test screen wrapping the shared RecordingView in standalone mode.
import SwiftUI
import DictusCore

/// Test dictation screen accessible from HomeView's "Tester la dictee" button.
///
/// WHY a thin wrapper instead of navigating to RecordingView directly:
/// HomeView already has a NavigationLink to TestDictationView. Keeping this wrapper
/// avoids changing the navigation contract. The shared RecordingView handles all
/// recording UI, state management, and haptics.
struct TestDictationView: View {
    var body: some View {
        RecordingView(mode: .standalone)
    }
}

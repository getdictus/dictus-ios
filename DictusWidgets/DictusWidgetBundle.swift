// DictusWidgets/DictusWidgetBundle.swift
// Entry point for the Dictus Widget Extension (Live Activity only for now).
import SwiftUI
import WidgetKit

/// WHY a WidgetBundle even with one widget:
/// Apple requires a @main entry point for Widget Extensions. WidgetBundle
/// is the standard pattern — it lets us add home screen widgets later
/// without restructuring the extension.
@main
struct DictusWidgetBundle: WidgetBundle {
    var body: some Widget {
        DictusLiveActivity()
    }
}

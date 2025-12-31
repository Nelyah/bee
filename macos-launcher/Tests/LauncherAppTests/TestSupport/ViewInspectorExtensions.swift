@testable import LauncherApp
import SwiftUI
import ViewInspector

// MARK: - Inspectable Conformances

// ViewInspector requires views to conform to Inspectable for testing.
// This is done via extensions in the test target to avoid polluting production code.

// MARK: - Core Views

extension TaskRow: Inspectable {}
extension TaskListView: Inspectable {}
extension ContentView: Inspectable {}
extension TaskDetailView: Inspectable {}
extension CommandPaletteView: Inspectable {}

// MARK: - Component Views

extension CompletionMenuView: Inspectable {}
extension CriteriaStripView: Inspectable {}
extension ToastView: Inspectable {}
extension ReportMenuButton: Inspectable {}
extension BottomHintBar: Inspectable {}
extension HoverableButton: Inspectable {}
extension QuietLinkButton: Inspectable {}
extension FlowLayout: Inspectable {}
extension DetailRow: Inspectable {}
extension GroupHeaderRow: Inspectable {}
extension ExternalLinkRow: Inspectable {}
extension LinkStatusBadge: Inspectable {}
extension SaveReportSheet: Inspectable {}
extension TaskRowLinksPreview: Inspectable {}
extension TaskRowAnnotationsPreview: Inspectable {}
extension ProjectScopeChipView: Inspectable {}
extension TimelineRow: Inspectable {}

// MARK: - Token Highlight Views

extension TokenHighlightTextView: Inspectable {}
extension KeyHandlingTextView: Inspectable {}

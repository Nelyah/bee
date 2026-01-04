import AppKit
import QuickLookUI

/// Coordinator that manages Quick Look preview panel data source.
///
/// Quick Look on macOS requires a data source that conforms to `QLPreviewPanelDataSource`.
/// This coordinator:
/// - Provides the preview URL to the panel
/// - Handles panel setup and teardown
/// - Can be used from SwiftUI via the ViewModel
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource {
    /// The URL to preview. Set this before showing the panel.
    var previewURL: URL?

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        previewURL != nil ? 1 : 0
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt _: Int) -> (any QLPreviewItem)! {
        previewURL as? any QLPreviewItem
    }

    // MARK: - Panel Management

    /// Shows the Quick Look panel with the current preview URL.
    func showPanel() {
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

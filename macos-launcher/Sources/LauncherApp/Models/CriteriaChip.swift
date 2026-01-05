import SwiftUI

enum CriteriaChipKind: String, Hashable {
    case filter
    case property
}

/// Tracks where a filter chip originated from
enum CriteriaChipSource: String, Hashable {
    /// From a saved report definition (baseline filters)
    case report
    /// User-added via input field (active refinement)
    case manual
}

enum CriteriaChipTone: String, Hashable {
    case blue
    case teal
    case green
    case yellow
    case peach
    case mauve
    case lavender
    case pink
    case sky
    case rosewater
    case red

    var color: Color {
        switch self {
        case .blue:
            ThemeManager.current.blue
        case .teal:
            ThemeManager.current.teal
        case .green:
            ThemeManager.current.green
        case .yellow:
            ThemeManager.current.yellow
        case .peach:
            ThemeManager.current.peach
        case .mauve:
            ThemeManager.current.mauve
        case .lavender:
            ThemeManager.current.lavender
        case .pink:
            ThemeManager.current.pink
        case .sky:
            ThemeManager.current.sky
        case .rosewater:
            ThemeManager.current.rosewater
        case .red:
            ThemeManager.current.red
        }
    }
}

struct CriteriaChip: Identifiable, Hashable {
    let id: String
    let kind: CriteriaChipKind
    let source: CriteriaChipSource
    let label: String
    let systemImage: String
    let tone: CriteriaChipTone
    /// For report-sourced chips, the name of the report (used for tooltips)
    let reportName: String?

    init(
        kind: CriteriaChipKind,
        source: CriteriaChipSource = .manual,
        label: String,
        systemImage: String,
        tone: CriteriaChipTone,
        reportName: String? = nil
    ) {
        self.kind = kind
        self.source = source
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
        self.reportName = reportName
        id = "\(kind.rawValue)-\(source.rawValue)-\(systemImage)-\(label)"
    }
}

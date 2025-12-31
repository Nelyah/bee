import SwiftUI

enum CriteriaChipKind: String, Hashable {
    case filter
    case property
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
            return ThemeManager.current.blue
        case .teal:
            return ThemeManager.current.teal
        case .green:
            return ThemeManager.current.green
        case .yellow:
            return ThemeManager.current.yellow
        case .peach:
            return ThemeManager.current.peach
        case .mauve:
            return ThemeManager.current.mauve
        case .lavender:
            return ThemeManager.current.lavender
        case .pink:
            return ThemeManager.current.pink
        case .sky:
            return ThemeManager.current.sky
        case .rosewater:
            return ThemeManager.current.rosewater
        case .red:
            return ThemeManager.current.red
        }
    }
}

struct CriteriaChip: Identifiable, Hashable {
    let id: String
    let kind: CriteriaChipKind
    let label: String
    let systemImage: String
    let tone: CriteriaChipTone

    init(kind: CriteriaChipKind, label: String, systemImage: String, tone: CriteriaChipTone) {
        self.kind = kind
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
        self.id = "\(kind.rawValue)-\(systemImage)-\(label)"
    }
}

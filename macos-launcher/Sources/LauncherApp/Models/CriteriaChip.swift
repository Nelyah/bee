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
    let label: String
    let systemImage: String
    let tone: CriteriaChipTone

    init(kind: CriteriaChipKind, label: String, systemImage: String, tone: CriteriaChipTone) {
        self.kind = kind
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
        id = "\(kind.rawValue)-\(systemImage)-\(label)"
    }
}

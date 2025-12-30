struct TokenClassifier {
    static let tagPrefixes: Set<String> = [
        "TagPlusPrefix",
        "TagMinusPrefix"
    ]
    static let projectPrefixes: Set<String> = [
        "ProjectPrefix"
    ]
    static let dateFilters: Set<String> = [
        "FilterTokDateDue",
        "FilterTokDateDueBefore",
        "FilterTokDateDueAfter",
        "FilterTokDateCreatedBefore",
        "FilterTokDateCreatedAfter",
        "FilterTokDateEndBefore",
        "FilterTokDateEndAfter"
    ]
    static let statusFilters: Set<String> = [
        "FilterStatus"
    ]
    static let dependencies: Set<String> = [
        "DependsOn"
    ]
    static let logicalOperators: Set<String> = [
        "OperatorAnd",
        "OperatorOr",
        "OperatorXor"
    ]
    static let parentheses: Set<String> = [
        "LeftParenthesis",
        "RightParenthesis"
    ]
    static let identifiers: Set<String> = [
        "Uuid",
        "Int"
    ]

    static func isTagPrefix(_ tokenType: String) -> Bool {
        tagPrefixes.contains(tokenType)
    }

    static func isProjectPrefix(_ tokenType: String) -> Bool {
        projectPrefixes.contains(tokenType)
    }

    static func isDateFilter(_ tokenType: String) -> Bool {
        dateFilters.contains(tokenType)
    }

    static func isStatusFilter(_ tokenType: String) -> Bool {
        statusFilters.contains(tokenType)
    }

    static func isDependency(_ tokenType: String) -> Bool {
        dependencies.contains(tokenType)
    }

    static func isLogicalOperator(_ tokenType: String) -> Bool {
        logicalOperators.contains(tokenType)
    }

    static func isParenthesis(_ tokenType: String) -> Bool {
        parentheses.contains(tokenType)
    }

    static func isIdentifier(_ tokenType: String) -> Bool {
        identifiers.contains(tokenType)
    }
}

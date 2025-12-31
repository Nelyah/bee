enum TokenClassifier {
    static let tagPrefixes: Set<TokenType> = [
        .tagPlusPrefix,
        .tagMinusPrefix,
    ]
    static let projectPrefixes: Set<TokenType> = [
        .projectPrefix,
    ]
    static let dateFilters: Set<TokenType> = [
        .filterTokDateDue,
        .filterTokDateDueBefore,
        .filterTokDateDueAfter,
        .filterTokDateCreatedBefore,
        .filterTokDateCreatedAfter,
        .filterTokDateEndBefore,
        .filterTokDateEndAfter,
    ]
    static let statusFilters: Set<TokenType> = [
        .filterStatus,
    ]
    static let dependencies: Set<TokenType> = [
        .dependsOn,
    ]
    static let logicalOperators: Set<TokenType> = [
        .operatorAnd,
        .operatorOr,
        .operatorXor,
    ]
    static let parentheses: Set<TokenType> = [
        .leftParenthesis,
        .rightParenthesis,
    ]
    static let identifiers: Set<TokenType> = [
        .uuid,
        .int,
    ]

    static func isTagPrefix(_ tokenType: TokenType) -> Bool {
        tagPrefixes.contains(tokenType)
    }

    static func isProjectPrefix(_ tokenType: TokenType) -> Bool {
        projectPrefixes.contains(tokenType)
    }

    static func isDateFilter(_ tokenType: TokenType) -> Bool {
        dateFilters.contains(tokenType)
    }

    static func isStatusFilter(_ tokenType: TokenType) -> Bool {
        statusFilters.contains(tokenType)
    }

    static func isDependency(_ tokenType: TokenType) -> Bool {
        dependencies.contains(tokenType)
    }

    static func isLogicalOperator(_ tokenType: TokenType) -> Bool {
        logicalOperators.contains(tokenType)
    }

    static func isParenthesis(_ tokenType: TokenType) -> Bool {
        parentheses.contains(tokenType)
    }

    static func isIdentifier(_ tokenType: TokenType) -> Bool {
        identifiers.contains(tokenType)
    }
}

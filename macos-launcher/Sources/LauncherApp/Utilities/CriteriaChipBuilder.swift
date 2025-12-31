import Foundation

enum CriteriaChipBuilder {
    static func reportFilterChips(from reportConfig: ReportConfig?) -> [CriteriaChip] {
        guard let reportConfig, !reportConfig.filters.isEmpty else {
            return []
        }
        return reportConfig.filters.map {
            CriteriaChip(
                kind: .filter,
                label: $0,
                systemImage: "line.3.horizontal.decrease.circle",
                tone: .teal
            )
        }
    }

    static func filterChips(from value: JSONValue?) -> [CriteriaChip] {
        guard let value else { return [] }
        return parseFilterValue(value)
    }

    static func filterChips(from tokens: [TokenSpan], actionName: String) -> [CriteriaChip] {
        var chips: [CriteriaChip] = []
        let lowerAction = actionName.lowercased()
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            let tokenType = token.tokenType

            if TokenClassifier.isTagPrefix(tokenType) {
                var end = token.end
                var nextIndex = index + 1
                var tagValue = ""

                while nextIndex < tokens.count,
                      tokens[nextIndex].tokenType == .wordString,
                      tokens[nextIndex].start == end
                {
                    tagValue += tokens[nextIndex].literal
                    end = tokens[nextIndex].end
                    nextIndex += 1
                }

                if !tagValue.isEmpty {
                    let prefix = tokenType == .tagMinusPrefix ? "-" : "+"
                    let icon = tokenType == .tagMinusPrefix ? "tag.slash" : "tag"
                    chips.append(CriteriaChip(
                        kind: .filter,
                        label: "Tag \(prefix)\(tagValue)",
                        systemImage: icon,
                        tone: .peach
                    ))
                }

                index = nextIndex
                continue
            }

            if TokenClassifier.isProjectPrefix(tokenType) {
                var end = token.end
                var nextIndex = index + 1
                var projectValue = ""

                while nextIndex < tokens.count,
                      tokens[nextIndex].tokenType == .wordString,
                      tokens[nextIndex].start == end
                {
                    projectValue += tokens[nextIndex].literal
                    end = tokens[nextIndex].end
                    nextIndex += 1
                }

                if !projectValue.isEmpty {
                    chips.append(CriteriaChip(
                        kind: .filter,
                        label: "Project: \(projectValue)",
                        systemImage: "folder",
                        tone: .mauve
                    ))
                }

                index = nextIndex
                continue
            }

            if TokenClassifier.isDateFilter(tokenType) {
                var end = token.end
                var nextIndex = index + 1
                var value = ""

                while nextIndex < tokens.count,
                      tokens[nextIndex].start == end,
                      tokens[nextIndex].tokenType != .blank
                {
                    value += tokens[nextIndex].literal
                    end = tokens[nextIndex].end
                    nextIndex += 1
                }

                let labelPrefix = dateLabelPrefix(for: tokenType)
                let label = value.isEmpty ? labelPrefix : "\(labelPrefix): \(value)"
                chips.append(CriteriaChip(kind: .filter, label: label, systemImage: "calendar", tone: .teal))
                index = nextIndex
                continue
            }

            if TokenClassifier.isStatusFilter(tokenType) {
                var end = token.end
                var nextIndex = index + 1
                var value = ""

                while nextIndex < tokens.count,
                      tokens[nextIndex].start == end,
                      tokens[nextIndex].tokenType == .wordString
                {
                    value += tokens[nextIndex].literal
                    end = tokens[nextIndex].end
                    nextIndex += 1
                }

                let label = value.isEmpty ? "Status" : "Status: \(value)"
                chips.append(CriteriaChip(kind: .filter, label: label, systemImage: "circle.fill", tone: .pink))
                index = nextIndex
                continue
            }

            if TokenClassifier.isDependency(tokenType) {
                var end = token.end
                var nextIndex = index + 1
                var value = ""

                while nextIndex < tokens.count,
                      tokens[nextIndex].start == end,
                      tokens[nextIndex].tokenType != .blank
                {
                    value += tokens[nextIndex].literal
                    end = tokens[nextIndex].end
                    nextIndex += 1
                }

                let label = value.isEmpty ? "Depends on" : "Depends: \(truncate(value, limit: 10))"
                chips.append(CriteriaChip(kind: .filter, label: label, systemImage: "link", tone: .lavender))
                index = nextIndex
                continue
            }

            if TokenClassifier.isIdentifier(tokenType) {
                let labelPrefix = tokenType == .uuid ? "UUID" : "ID"
                chips.append(CriteriaChip(
                    kind: .filter,
                    label: "\(labelPrefix): \(truncate(token.literal, limit: 10))",
                    systemImage: "number",
                    tone: .rosewater
                ))
                index += 1
                continue
            }

            if tokenType == .wordString {
                if !lowerAction.isEmpty, token.literal.lowercased() == lowerAction {
                    index += 1
                    continue
                }
                chips.append(CriteriaChip(
                    kind: .filter,
                    label: "Text: \(truncate(token.literal))",
                    systemImage: "text.magnifyingglass",
                    tone: .blue
                ))
                index += 1
                continue
            }

            index += 1
        }

        return chips
    }

    static func propertyChips(from value: JSONValue?) -> [CriteriaChip] {
        guard let value,
              case let .object(obj) = value
        else {
            return []
        }
        var chips: [CriteriaChip] = []

        if let summary = obj["summary"]?.stringValue, !summary.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Summary: \(truncate(summary))",
                systemImage: "text.alignleft",
                tone: .blue
            ))
        }

        if let tagsAdd = obj["tags_add"]?.stringArray {
            for tag in tagsAdd {
                chips.append(CriteriaChip(kind: .property, label: "Tag +\(tag)", systemImage: "tag", tone: .peach))
            }
        }

        if let tagsRemove = obj["tags_remove"]?.stringArray {
            for tag in tagsRemove {
                chips.append(CriteriaChip(
                    kind: .property,
                    label: "Tag -\(tag)",
                    systemImage: "tag.slash",
                    tone: .peach
                ))
            }
        }

        if let status = obj["status"]?.stringValue, !status.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Status: \(status)",
                systemImage: "circle.fill",
                tone: .pink
            ))
        }

        if let annotation = obj["annotation"]?.stringValue, !annotation.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Note: \(truncate(annotation))",
                systemImage: "note.text",
                tone: .yellow
            ))
        }

        if let annotations = obj["annotations"]?.arrayValue {
            let count = annotations.count
            if count > 0 {
                chips.append(CriteriaChip(
                    kind: .property,
                    label: "Annotations: \(count)",
                    systemImage: "note.text",
                    tone: .yellow
                ))
            }
        }

        if let active = obj["active_status"]?.boolValue {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Active: \(active ? "true" : "false")",
                systemImage: "bolt.fill",
                tone: .green
            ))
        }

        if let projectValue = obj["project"] {
            let label = switch projectValue {
            case let .string(name):
                if name.lowercased() == "none" {
                    "Project: none"
                } else {
                    "Project: \(name)"
                }
            case let .object(projectObj):
                "Project: \(projectObj["name"]?.stringValue ?? "unknown")"
            case .null:
                ""
            default:
                ""
            }
            if !label.isEmpty {
                chips.append(CriteriaChip(kind: .property, label: label, systemImage: "folder", tone: .mauve))
            }
        }

        if let due = obj["date_due"]?.stringValue, !due.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Due: \(formatDate(due))",
                systemImage: "calendar",
                tone: .teal
            ))
        }

        if let depends = obj["depends_on"]?.arrayValue, !depends.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Depends on: \(depends.count)",
                systemImage: "link",
                tone: .lavender
            ))
        }

        if let blocks = obj["blocks"]?.arrayValue, !blocks.isEmpty {
            chips.append(CriteriaChip(
                kind: .property,
                label: "Blocks: \(blocks.count)",
                systemImage: "arrow.triangle.branch",
                tone: .lavender
            ))
        }

        return chips
    }

    private static func parseFilterValue(_ value: JSONValue) -> [CriteriaChip] {
        switch value {
        case let .string(text):
            return [CriteriaChip(
                kind: .filter,
                label: text,
                systemImage: "line.3.horizontal.decrease.circle",
                tone: .teal
            )]
        case let .array(values):
            return values.flatMap { parseFilterValue($0) }
        case let .object(obj):
            if let type = obj["type"]?.stringValue {
                let valueObj = obj["value"]?.objectValue ?? obj
                switch type {
                case "AndFilter", "OrFilter", "XorFilter", "RootFilter":
                    return valueObj["children"]?.arrayValue?.flatMap { parseFilterValue($0) } ?? []
                case "TagFilter":
                    let include = valueObj["include"]?.boolValue ?? true
                    let tag = valueObj["tag_name"]?.stringValue ?? "tag"
                    let prefix = include ? "+" : "-"
                    let icon = include ? "tag" : "tag.slash"
                    return [CriteriaChip(kind: .filter, label: "Tag \(prefix)\(tag)", systemImage: icon, tone: .peach)]
                case "ProjectFilter":
                    let projectName = valueObj["name"]?.objectValue?["name"]?.stringValue
                        ?? valueObj["name"]?.stringValue
                        ?? "project"
                    return [CriteriaChip(
                        kind: .filter,
                        label: "Project: \(projectName)",
                        systemImage: "folder",
                        tone: .mauve
                    )]
                case "DateDueFilter":
                    let when = valueObj["type_when"]?.stringValue?.lowercased() ?? "day"
                    let time = valueObj["time"]?.stringValue.map(formatDate) ?? "date"
                    return [CriteriaChip(
                        kind: .filter,
                        label: "Due \(when): \(time)",
                        systemImage: "calendar",
                        tone: .teal
                    )]
                case "DateCreatedFilter":
                    let before = valueObj["before"]?.boolValue ?? false
                    let time = valueObj["time"]?.stringValue.map(formatDate) ?? "date"
                    let label = "Created \(before ? "before" : "after"): \(time)"
                    return [CriteriaChip(kind: .filter, label: label, systemImage: "calendar.badge.clock", tone: .teal)]
                case "DateEndFilter":
                    let before = valueObj["before"]?.boolValue ?? false
                    let time = valueObj["time"]?.stringValue.map(formatDate) ?? "date"
                    let label = "End \(before ? "before" : "after"): \(time)"
                    return [CriteriaChip(kind: .filter, label: label, systemImage: "calendar.badge.minus", tone: .teal)]
                case "StatusFilter":
                    let status = valueObj["status"]?.stringValue ?? "status"
                    return [CriteriaChip(
                        kind: .filter,
                        label: "Status: \(status)",
                        systemImage: "circle.fill",
                        tone: .pink
                    )]
                case "StringFilter":
                    let value = valueObj["value"]?.stringValue ?? "text"
                    return [CriteriaChip(
                        kind: .filter,
                        label: "Text: \(truncate(value))",
                        systemImage: "text.magnifyingglass",
                        tone: .blue
                    )]
                case "UuidFilter":
                    let uuid = valueObj["uuid"]?.stringValue ?? "uuid"
                    return [CriteriaChip(
                        kind: .filter,
                        label: "UUID: \(truncate(uuid, limit: 10))",
                        systemImage: "number",
                        tone: .rosewater
                    )]
                case "TaskIdFilter":
                    let id = valueObj["id"]?.stringValue ?? valueObj["id"]?.numberValue.map { String(Int($0)) } ?? "id"
                    return [CriteriaChip(kind: .filter, label: "ID: \(id)", systemImage: "number", tone: .rosewater)]
                case "DependsOnFilter":
                    if let uuid = valueObj["uuid"]?.stringValue {
                        return [CriteriaChip(
                            kind: .filter,
                            label: "Depends: \(truncate(uuid, limit: 10))",
                            systemImage: "link",
                            tone: .lavender
                        )]
                    }
                    if let id = valueObj["id"]?.numberValue {
                        return [CriteriaChip(
                            kind: .filter,
                            label: "Depends: \(Int(id))",
                            systemImage: "link",
                            tone: .lavender
                        )]
                    }
                    return [CriteriaChip(kind: .filter, label: "Depends on", systemImage: "link", tone: .lavender)]
                default:
                    break
                }
            }
            if let value = obj["value"]?.stringValue {
                return [CriteriaChip(
                    kind: .filter,
                    label: value,
                    systemImage: "line.3.horizontal.decrease.circle",
                    tone: .teal
                )]
            }
            return []
        default:
            return []
        }
    }

    private static func dateLabelPrefix(for tokenType: TokenType) -> String {
        switch tokenType {
        case .filterTokDateDue:
            "Due"
        case .filterTokDateDueBefore:
            "Due before"
        case .filterTokDateDueAfter:
            "Due after"
        case .filterTokDateCreatedBefore:
            "Created before"
        case .filterTokDateCreatedAfter:
            "Created after"
        case .filterTokDateEndBefore:
            "End before"
        case .filterTokDateEndAfter:
            "End after"
        default:
            "Date"
        }
    }

    private static func truncate(_ value: String, limit: Int = 28) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 1)) + "…"
    }

    private static func formatDate(_ value: String) -> String {
        if let datePart = value.split(separator: "T").first {
            return String(datePart)
        }
        return value
    }
}

private extension JSONValue {
    var stringValue: String? {
        if case let .string(value) = self { return value }
        if case let .number(value) = self { return String(value) }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    var stringArray: [String]? {
        guard case let .array(values) = self else { return nil }
        let strings = values.compactMap(\.stringValue)
        return strings.isEmpty ? nil : strings
    }
}

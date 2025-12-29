import AppKit
import Foundation
import SwiftUI
import OSLog

@main
struct LauncherApp: App {
    @StateObject private var viewModel = LauncherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Close Detail") {
                    viewModel.closeDetail()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        ZStack {
            launcherBackground

            if viewModel.mode == .detail, let task = viewModel.selectedTask {
                TaskDetailView(task: task)
                    .padding(24)
            } else {
                TaskListView(viewModel: viewModel)
                    .padding(20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(minWidth: 680, minHeight: 440)
        .onAppear {
            DispatchQueue.main.async {
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                configureWindowAppearance()
            }
        }
    }

    private var launcherBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.14, green: 0.14, blue: 0.15),
                Color(red: 0.1, green: 0.1, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Apply Raycast-style window appearance (no title bar, clear background).
    private func configureWindowAppearance() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

struct TaskListView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TokenHighlightTextView(
                    text: $viewModel.input,
                    tokens: viewModel.tokens,
                    isFocused: true,
                    onSubmit: {
                        viewModel.handleSubmit()
                    },
                    onMoveSelection: { delta in
                        viewModel.moveSelection(delta: delta)
                    }
                )
                .frame(height: 22)
                .onChange(of: viewModel.input) { _, newValue in
                    viewModel.handleInputChange(newValue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.19))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(viewModel.tasks.enumerated()), id: \.offset) { index, task in
                            TaskRow(task: task, isSelected: viewModel.selectedIndex == index)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .onChange(of: viewModel.selectedIndex) { _, newValue in
                    guard let index = newValue else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: ApiTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(task.status))
                .frame(width: 8, height: 8)
            Text(task.summary)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(task.status)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
        )
    }
}

struct TaskDetailView: View {
    let task: ApiTask

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(task.summary)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(2)
                Spacer()
                Text(task.status.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }

            DetailRow(label: "UUID", value: task.uuid)
            DetailRow(label: "Project", value: task.project ?? "None")
            DetailRow(label: "Tags", value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "))
            DetailRow(label: "Created", value: task.dateCreated)
            DetailRow(label: "Completed", value: task.dateCompleted ?? "Not completed")
            DetailRow(label: "Due", value: task.dateDue ?? "Not set")
            DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None")

            Spacer()

            Text("Press Esc to go back")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

private func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "active":
        return Color(red: 0.45, green: 0.82, blue: 0.44)
    case "completed":
        return Color(red: 0.33, green: 0.72, blue: 0.88)
    case "deleted":
        return Color(red: 0.78, green: 0.36, blue: 0.36)
    default:
        return Color(red: 0.85, green: 0.78, blue: 0.4)
    }
}

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var tasks: [ApiTask] = []
    @Published var selectedIndex: Int?
    @Published var tokens: [TokenSpan] = []
    @Published var mode: LauncherMode = .list

    private let apiClient = ApiClient()
    private var requestCounter: Int = 0
    private var latestParse: ParseResponse?
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "view-model")

    /// Handle text input changes and trigger parsing/actions on each keystroke.
    func handleInputChange(_ newValue: String) {
        requestCounter += 1
        let requestId = requestCounter

        logger.debug("Input change -> parse only. id=\(requestId), text=\(newValue, privacy: .private)")
        print("[launcher] input change -> parse only id=\(requestId)")
        selectedIndex = nil
        mode = .list

        Task {
            await parseOnly(for: newValue, requestId: requestId)
        }
    }

    /// Parse input for highlighting and action preview without executing.
    func parseOnly(for query: String, requestId: Int) async {
        do {
            logger.debug("Parse request start. id=\(requestId)")
            print("[launcher] parse start id=\(requestId)")
            let parsed = try await apiClient.parse(input: query)
            guard requestId == requestCounter else { return }
            latestParse = parsed
            tokens = parsed.tokens
            logger.debug("Parse request done. id=\(requestId), action=\(parsed.action)")
            print("[launcher] parse done id=\(requestId) action=\(parsed.action)")
        } catch {
            guard requestId == requestCounter else { return }
            latestParse = nil
            tokens = []
            logger.error("Parse request failed. id=\(requestId), error=\(error.localizedDescription, privacy: .public)")
            print("[launcher] parse failed id=\(requestId) error=\(error)")
        }
    }

    /// Execute the current parse result when the user submits.
    func handleSubmit() {
        if let _ = selectedIndex {
            openDetail()
        } else {
            requestCounter += 1
            let requestId = requestCounter
            let snapshot = latestParse

            logger.info("Submit -> run action. id=\(requestId)")
            print("[launcher] submit -> action id=\(requestId)")

            Task {
                await runAction(from: snapshot, requestId: requestId)
            }
        }
    }

    /// Run the action derived from the latest parse response.
    func runAction(from parsed: ParseResponse?, requestId: Int) async {
        do {
            let parsed = parsed ?? apiClient.emptyParse()
            let actionName = parsed.action.isEmpty ? "list" : parsed.action
            logger.debug("Action request start. id=\(requestId), action=\(actionName)")
            print("[launcher] action start id=\(requestId) action=\(actionName)")
            let response = try await apiClient.runAction(
                action: actionName,
                properties: parsed.properties,
                filter: parsed.filter
            )
            guard requestId == requestCounter else { return }
            tasks = response.tasks
            syncSelectionAfterTasksUpdate()
            logger.debug("Action request done. id=\(requestId), tasks=\(response.tasks.count)")
            print("[launcher] action done id=\(requestId) tasks=\(response.tasks.count)")
        } catch {
            guard requestId == requestCounter else { return }
            tasks = []
            logger.error("Action request failed. id=\(requestId), error=\(error.localizedDescription, privacy: .public)")
            print("[launcher] action failed id=\(requestId) error=\(error)")
        }
    }

    /// Move the selection by a delta, wrapping around the list.
    func moveSelection(delta: Int) {
        guard !tasks.isEmpty else { return }
        let count = tasks.count
        if let current = selectedIndex {
            let next = (current + delta + count) % count
            selectedIndex = next
        } else {
            selectedIndex = delta >= 0 ? 0 : count - 1
        }
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        guard let current = selectedIndex else { return }
        if tasks.isEmpty {
            selectedIndex = nil
            return
        }
        if current >= tasks.count {
            selectedIndex = tasks.count - 1
        }
    }

    /// Open the detail view for the currently selected task.
    func openDetail() {
        guard selectedIndex != nil else { return }
        mode = .detail
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = .list
    }

    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        guard let index = selectedIndex, tasks.indices.contains(index) else { return nil }
        return tasks[index]
    }
}

enum LauncherMode {
    case list
    case detail
}

struct TokenHighlightTextView: NSViewRepresentable {
    @Binding var text: String
    let tokens: [TokenSpan]
    let isFocused: Bool
    let onSubmit: () -> Void
    let onMoveSelection: (Int) -> Void

    /// Create the underlying AppKit view.
    func makeNSView(context: Context) -> NSScrollView {
        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textView.textColor = NSColor.white
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.onSubmit = onSubmit
        textView.onMoveSelection = onMoveSelection

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        return scrollView
    }

    /// Update the AppKit view when state changes.
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? KeyHandlingTextView else { return }
        if context.coordinator.isUpdating {
            return
        }

        let selectedRange = textView.selectedRange()
        context.coordinator.isUpdating = true
        let attributed = highlightedText(text: text, tokens: tokens)
        textView.textStorage?.setAttributedString(attributed)
        textView.setSelectedRange(selectedRange)
        context.coordinator.isUpdating = false

        if isFocused, let window = textView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    /// Build the coordinator for text updates.
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var isUpdating = false

        init(text: Binding<String>) {
            _text = text
        }

        /// Propagate text changes back to SwiftUI.
        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onMoveSelection: ((Int) -> Void)?

    /// Handle key presses for navigation and submit.
    override func keyDown(with event: NSEvent) {
        if let delta = selectionDelta(for: event) {
            onMoveSelection?(delta)
            return
        }

        if isSubmitEvent(event) {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }

    /// Return selection delta for keyboard navigation shortcuts.
    private func selectionDelta(for event: NSEvent) -> Int? {
        if event.modifierFlags.contains(.control) {
            if event.charactersIgnoringModifiers == "p" {
                return -1
            }
            if event.charactersIgnoringModifiers == "n" {
                return 1
            }
        }

        switch event.keyCode {
        case 126:
            return -1
        case 125:
            return 1
        default:
            return nil
        }
    }

    /// Return true when the event should submit the current input.
    private func isSubmitEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76:
            return true
        default:
            return false
        }
    }
}

/// Build an attributed string with token highlights.
private func highlightedText(text: String, tokens: [TokenSpan]) -> NSAttributedString {
    let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: NSColor.white
    ]
    let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)

    for token in tokens {
        guard let range = nsRange(for: token, in: text) else { continue }
        let background = tokenColor(for: token.tokenType).withAlphaComponent(0.25)
        attributed.addAttributes(
            [.backgroundColor: background],
            range: range
        )
    }
    return attributed
}

/// Convert token spans to UTF-16 ranges for attributed strings.
private func nsRange(for token: TokenSpan, in text: String) -> NSRange? {
    guard token.start <= token.end else { return nil }
    guard let startIndex = text.index(text.startIndex, offsetBy: token.start, limitedBy: text.endIndex),
          let endIndex = text.index(text.startIndex, offsetBy: token.end, limitedBy: text.endIndex) else {
        return nil
    }
    return NSRange(startIndex..<endIndex, in: text)
}

/// Map token types to highlight colors.
private func tokenColor(for tokenType: String) -> NSColor {
    switch tokenType.lowercased() {
    case "action":
        return NSColor.systemBlue
    case "tag":
        return NSColor.systemOrange
    case "project":
        return NSColor.systemPurple
    case "filter":
        return NSColor.systemGreen
    default:
        return NSColor.systemTeal
    }
}

struct ApiTask: Decodable, Identifiable {
    let dbId: Int?
    let uuid: String
    let status: String
    let summary: String
    let project: String?
    let tags: [String]
    let dateCreated: String
    let dateCompleted: String?
    let dateDue: String?
    let urgency: Int?

    var id: String { uuid }

    private enum CodingKeys: String, CodingKey {
        case dbId = "id"
        case uuid
        case status
        case summary
        case project
        case tags
        case dateCreated = "date_created"
        case dateCompleted = "date_completed"
        case dateDue = "date_due"
        case urgency
    }
}

struct ParseResponse: Decodable {
    let action: String
    let properties: JSONValue?
    let filter: JSONValue?
    let tokens: [TokenSpan]
}

struct TokenSpan: Decodable {
    let tokenType: String
    let literal: String
    let start: Int
    let end: Int

    private enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case literal
        case start
        case end
    }
}

struct ActionResponse: Decodable {
    let action: String
    let tasks: [ApiTask]
}

struct ActionRequest: Encodable {
    let action: String
    let properties: JSONValue?
    let filter: JSONValue?
}

struct ParseRequest: Encodable {
    let input: String
}

final class ApiClient {
    private let baseURL: URL
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "api")

    /// Initialize the API client, optionally using BEE_API_BASE_URL.
    init() {
        let defaultURL = URL(string: "http://127.0.0.1:3000")!
        if let env = ProcessInfo.processInfo.environment["BEE_API_BASE_URL"],
           let url = URL(string: env) {
            baseURL = url
        } else {
            baseURL = defaultURL
        }
    }

    /// Send input to the parse endpoint and decode the response.
    func parse(input: String) async throws -> ParseResponse {
        let request = ParseRequest(input: input)
        return try await send(request, path: "/v1/parse")
    }

    /// Return an empty parse response when no parse has completed yet.
    func emptyParse() -> ParseResponse {
        ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
    }

    /// Execute an action with optional properties and filter.
    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse {
        let request = ActionRequest(action: action, properties: properties, filter: filter)
        return try await send(request, path: "/v1/action")
    }

    /// Send a JSON request to the API and decode the response type.
    func send<Request: Encodable, Response: Decodable>(
        _ body: Request,
        path: String
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP request \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        print("[launcher] http request path=\(path) url=\(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            logger.error("HTTP error \(path, privacy: .public)")
            print("[launcher] http error path=\(path)")
            throw URLError(.badServerResponse)
        }
        logger.debug("HTTP response \(path, privacy: .public) status=\(http.statusCode)")
        print("[launcher] http response path=\(path) status=\(http.statusCode)")
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

/// Codable wrapper for arbitrary JSON values.
indirect enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    /// Decode an arbitrary JSON value.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
        }
    }

    /// Encode an arbitrary JSON value.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

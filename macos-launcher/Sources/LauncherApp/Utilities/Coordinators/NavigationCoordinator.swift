enum NavigationCoordinator {
    static func modeForInputChange() -> LauncherMode {
        .list
    }

    static func modeForOpenDetail(selectedIndex: Int?) -> LauncherMode? {
        guard selectedIndex != nil else { return nil }
        return .detail
    }

    static func modeForCloseDetail() -> LauncherMode {
        .list
    }
}

enum ThemeManager {
    static var current: Theme = OneDarkTheme()
    static let available: [Theme] = [
        OneDarkTheme(),
        CatppuccinTheme(),
    ]
}

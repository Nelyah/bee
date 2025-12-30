import AppKit
import SwiftUI

enum AssetIcon {
    static func gitlab() -> Image? {
        if let image = loadImage(named: "gitlab", extension: "svg") {
            return image
        }
        return loadImage(named: "gitlab", extension: "png")
    }

    static func jira() -> Image? {
        if let image = loadImage(named: "jira-icon", extension: "svg") {
            return image
        }
        return loadImage(named: "jira-icon", extension: "png")
    }

    static func image(named name: String) -> Image? {
        if let image = loadImage(named: name, extension: "svg") {
            return image
        }
        return loadImage(named: name, extension: "png")
    }

    private static func loadImage(named name: String, extension ext: String) -> Image? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        guard let nsImage = NSImage(contentsOf: url) else {
            return nil
        }
        return Image(nsImage: nsImage)
    }
}

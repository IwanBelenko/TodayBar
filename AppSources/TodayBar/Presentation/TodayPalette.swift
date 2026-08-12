import AppKit
import SwiftUI

enum TodayPalette {
    static let surface = dynamicColor(
        light: NSColor(calibratedRed: 247 / 255, green: 247 / 255, blue: 248 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 33 / 255, green: 33 / 255, blue: 33 / 255, alpha: 1)
    )

    static let raised = dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 1),
        dark: NSColor(calibratedRed: 47 / 255, green: 47 / 255, blue: 47 / 255, alpha: 1)
    )

    static let hover = dynamicColor(
        light: NSColor(calibratedRed: 236 / 255, green: 236 / 255, blue: 236 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 56 / 255, green: 56 / 255, blue: 56 / 255, alpha: 1)
    )

    static let line = dynamicColor(
        light: NSColor(calibratedWhite: 0, alpha: 0.08),
        dark: NSColor(calibratedWhite: 1, alpha: 0.09)
    )

    static let border = dynamicColor(
        light: NSColor(calibratedWhite: 0, alpha: 0.12),
        dark: NSColor(calibratedWhite: 1, alpha: 0.13)
    )

    static let accent = dynamicColor(
        light: NSColor(calibratedRed: 35 / 255, green: 131 / 255, blue: 226 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 82 / 255, green: 156 / 255, blue: 227 / 255, alpha: 1)
    )

    static let actionFill = dynamicColor(
        light: NSColor(calibratedRed: 33 / 255, green: 33 / 255, blue: 33 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 236 / 255, green: 236 / 255, blue: 236 / 255, alpha: 1)
    )

    static let actionForeground = dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 1),
        dark: NSColor(calibratedRed: 33 / 255, green: 33 / 255, blue: 33 / 255, alpha: 1)
    )

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

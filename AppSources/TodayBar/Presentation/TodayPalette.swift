import AppKit
import SwiftUI

enum TodayPalette {
    static let surface = dynamicColor(
        light: NSColor(calibratedRed: 250 / 255, green: 250 / 255, blue: 248 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 31 / 255, green: 31 / 255, blue: 30 / 255, alpha: 1)
    )

    static let raised = dynamicColor(
        light: NSColor(calibratedRed: 1, green: 1, blue: 253 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 40 / 255, green: 40 / 255, blue: 39 / 255, alpha: 1)
    )

    static let hover = dynamicColor(
        light: NSColor(calibratedRed: 239 / 255, green: 239 / 255, blue: 236 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 48 / 255, green: 48 / 255, blue: 47 / 255, alpha: 1)
    )

    static let line = dynamicColor(
        light: NSColor(calibratedWhite: 0.2, alpha: 0.1),
        dark: NSColor(calibratedWhite: 1, alpha: 0.09)
    )

    static let border = dynamicColor(
        light: NSColor(calibratedWhite: 0.2, alpha: 0.14),
        dark: NSColor(calibratedWhite: 1, alpha: 0.13)
    )

    static let accent = dynamicColor(
        light: NSColor(calibratedRed: 35 / 255, green: 131 / 255, blue: 226 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 82 / 255, green: 156 / 255, blue: 227 / 255, alpha: 1)
    )

    static let actionFill = dynamicColor(
        light: NSColor(calibratedRed: 55 / 255, green: 53 / 255, blue: 47 / 255, alpha: 1),
        dark: NSColor(calibratedRed: 235 / 255, green: 235 / 255, blue: 233 / 255, alpha: 1)
    )

    static let actionForeground = dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 1),
        dark: NSColor(calibratedRed: 31 / 255, green: 31 / 255, blue: 30 / 255, alpha: 1)
    )

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

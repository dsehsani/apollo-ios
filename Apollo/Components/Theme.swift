//
//  Theme.swift
//  Apollo
//
//  Apollo design system tokens. Colors and font helpers used throughout the app.
//

import SwiftUI

extension Color {
    static let apolloBackground = Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x08 / 255)
    static let apolloText = Color(red: 0xe8 / 255, green: 0xe8 / 255, blue: 0xe8 / 255)
    static let apolloMuted = Color(red: 0x25 / 255, green: 0x25 / 255, blue: 0x25 / 255)
    static let apolloDanger = Color(red: 0x5a / 255, green: 0x20 / 255, blue: 0x20 / 255)
    static let apolloSkeleton = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)
    static let apolloBorder = Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255)
    static let apolloSurface = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
    static let apolloStroke = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255)
    static let apolloIconStroke = Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x55 / 255)
    static let apolloReactionCount = Color(red: 0x44 / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let apolloErrorToastBackground = Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255)
    static let apolloErrorToastBody = Color(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255)
    static let apolloQuote = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255)

    // Figma restyle tokens.
    static let apolloPrimaryText = Color(red: 0xf3 / 255, green: 0xf3 / 255, blue: 0xf3 / 255)
    static let apolloUsername = Color(red: 0xe6 / 255, green: 0xe6 / 255, blue: 0xe6 / 255)
    static let apolloCaption = Color(red: 0xb5 / 255, green: 0xb5 / 255, blue: 0xb5 / 255)
    static let apolloTimeStreak = Color(red: 0x52 / 255, green: 0x52 / 255, blue: 0x52 / 255)
    static let apolloTabInactive = Color(red: 0x6b / 255, green: 0x6b / 255, blue: 0x6b / 255)
    static let apolloWinsValue = Color(red: 0x83 / 255, green: 0x83 / 255, blue: 0x83 / 255)
    static let apolloWinsLabel = Color(red: 0x6b / 255, green: 0x6b / 255, blue: 0x6b / 255)
    static let apolloReactor = Color(red: 0x9c / 255, green: 0x9c / 255, blue: 0x9c / 255)
    static let apolloReactorMuted = Color(red: 0x83 / 255, green: 0x83 / 255, blue: 0x83 / 255)
    static let apolloAvatarBorder = Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x08 / 255)

    // Win List tokens (Figma node 12839-5903)
    static let apolloSheetSurface = Color(red: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255)
    static let apolloWinInputBorder = Color(red: 0x6b / 255, green: 0x6b / 255, blue: 0x6b / 255)

    // Win Details sheet tokens (PRD §05)
    static let apolloWinDetailsDragPill   = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x22 / 255)
    static let apolloWinDetailsXButton    = Color(red: 0x1c / 255, green: 0x1c / 255, blue: 0x1c / 255)
    static let apolloWinDetailsPillBorder = Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x1e / 255)
    static let apolloWinDetailsPillText   = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255)
    static let apolloWinDetailsRepeatMuted = Color(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255)
    static let apolloWinDetailsDeleteText = Color(red: 0x3d / 255, green: 0x15 / 255, blue: 0x15 / 255)
}

extension Font {
    // TODO: bundle GoudyBookletter1911-Italic.ttf and register it in Info.plist (UIAppFonts).
    // Until then this falls back to the system serif italic so the layout still reads correctly.
    static func goudyItalic(_ size: CGFloat) -> Font {
        Font.custom("GoudyBookletter1911-Italic", size: size, relativeTo: .body)
    }

    // TODO: bundle GoudyBookletter1911-Regular.ttf and register it in Info.plist (UIAppFonts).
    // Until then this falls back to the system serif so the layout still reads correctly.
    static func goudyRegular(_ size: CGFloat) -> Font {
        Font.custom("GoudyBookletter1911-Regular", size: size, relativeTo: .body)
    }

    static func sfPro(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

enum ApolloSpacing {
    static let postHeaderHorizontal: CGFloat = 12
    static let captionHorizontal: CGFloat = 16
    static let tabHorizontalSpacing: CGFloat = 16
    static let tabRowLeading: CGFloat = 16
    static let towerGap: CGFloat = 1
}

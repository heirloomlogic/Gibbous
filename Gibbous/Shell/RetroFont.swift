//
//  RetroFont.swift
//  Gibbous
//
//  Registers any bundled fonts at launch so the retro skin can use a licensed
//  Chicago-style bitmap face. Until `ChiKareGo2.ttf` (or similar) is added to
//  Resources/Fonts, this is a no-op and `RetroTheme.font` falls back gracefully.
//

import AppKit
import CoreText

enum RetroFont {
    static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            for subdir in [nil, "Fonts"] as [String?] {
                let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdir) ?? []
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }
}

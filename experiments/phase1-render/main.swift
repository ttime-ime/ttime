#!/usr/bin/env swift
/// Renders Stacker/Symbols panels for Phase 2.1 validation screenshots.

import AppKit
import Foundation

final class App: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { self.run() }
    }

    private func run() {
        let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
                      ? CommandLine.arguments[1]
                      : FileManager.default.currentDirectoryPath)
            .appendingPathComponent("out", isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        func save(_ view: NSView, name: String, appearance: NSAppearance?, size: NSSize? = nil) {
            view.appearance = appearance
            view.wantsLayer = true
            view.layoutSubtreeIfNeeded()
            let sz = size ?? (view.bounds.size.width > 1 ? view.bounds.size : view.fittingSize)
            // Pin the frame so a shorter capture does not crop a taller bottom-origin layout
            // from the top (header / composition). Auto Layout then reflows into `sz`.
            view.frame = NSRect(origin: .zero, size: sz)
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: NSRect(origin: .zero, size: sz)) else {
                print("fail bitmap \(name)"); return
            }
            view.cacheDisplay(in: NSRect(origin: .zero, size: sz), to: rep)
            let img = NSImage(size: sz)
            img.addRepresentation(rep)
            guard let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            let url = out.appendingPathComponent(name)
            try? png.write(to: url)
            print("wrote \(url.path) \(Int(sz.width))×\(Int(sz.height))")
        }

        func measureStacker() -> (natural: CGFloat, minimum: CGFloat) {
            StackerPanel.shared = StackerPanel()
            return (StackerPanel.shared.naturalHeight, StackerPanel.shared.minimumHeight)
        }

        // —— Bubblegum regression ——
        Prefs.style = .bubblegum
        GlyphCaptionLayout.clearCaches()
        let gum = measureStacker()
        StackerPanel.shared.refresh()
        if let v = StackerPanel.shared.contentView {
            save(v, name: "bubblegum_stacker.png", appearance: NSAppearance(named: .aqua))
        }
        SymbolsPanel.shared = SymbolsPanel()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "bubblegum_symbols.png", appearance: NSAppearance(named: .aqua))
        }

        // —— Brutalist light ——
        Prefs.style = .brutal
        NSApp.appearance = NSAppearance(named: .aqua)
        GlyphCaptionLayout.clearCaches()
        let brutal = measureStacker()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: brutal.natural)
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_light_empty.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: brutal.natural))
        }

        // Ordinary Tibetan: ཀ
        func saveStacker(_ name: String, appearance: NSAppearance?, height: CGFloat) {
            StackerPanel.shared.adaptLettersHeight(panelHeight: height)
            if let v = StackerPanel.shared.contentView {
                save(v, name: name, appearance: appearance,
                     size: NSSize(width: PanelTabs.width, height: height))
            }
        }

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.addLayer("k")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_ordinary.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.type("r")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_prefix.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        StackerPanel.shared.model.clear()
        for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.model.setVowel("i")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_sanskrit.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        // Tall multi-consonant: ch+g+ng+ny
        StackerPanel.shared.model.clear()
        for key in ["ch", "g", "ng", "ny"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_tall.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        // Inherent vowel selected (empty layers, vowel "").
        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.setVowel("")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_inherent_a.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        // Unavailable subjoined (no layers yet — W/Y disabled).
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.model.clear()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: brutal.natural)
        StackerPanel.shared.scrollAlphabetToEnd()
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_light_unavailable_subjoined.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: brutal.natural))
        }

        // Scrolled to first row (Velar) and last row (Marks) at a constrained height.
        // Match the constrained-shot setup: adaptLettersHeight already pins scroll to top.
        let shortH: CGFloat = 700
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.model.clear()
        StackerPanel.shared.refresh()
        let floor = StackerPanel.shared.minimumHeight
        let target = max(floor, shortH)
        StackerPanel.shared.adaptLettersHeight(panelHeight: target)
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_scrolled_top.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: target))
        }
        StackerPanel.shared.scrollAlphabetToEnd()
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_scrolled_marks.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: target))
        }

        SymbolsPanel.shared = SymbolsPanel()
        let symbolsNatural = SymbolsPanel.shared.naturalHeight
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "brutal_symbols_light.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: symbolsNatural))
        }

        // Constrained displays (include 600 when above the floor)
        for h in [600, 700, 800, 900, 1000] as [CGFloat] {
            StackerPanel.shared = StackerPanel()
            StackerPanel.shared.model.clear()
            for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
            StackerPanel.shared.model.setVowel("ai")
            StackerPanel.shared.refresh()
            let floor = StackerPanel.shared.minimumHeight
            let target = max(floor, min(h, brutal.natural))
            StackerPanel.shared.adaptLettersHeight(panelHeight: target)
            if let v = StackerPanel.shared.contentView {
                save(v, name: "brutal_stacker_constrained_\(Int(h)).png", appearance: NSAppearance(named: .aqua),
                     size: NSSize(width: PanelTabs.width, height: target))
            }
            print("CONSTRAINED h=\(Int(h)) floor=\(Int(floor)) target=\(Int(target))")
        }

        // —— Brutalist dark ——
        NSApp.appearance = NSAppearance(named: .darkAqua)
        GlyphCaptionLayout.clearCaches()
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: brutal.natural)
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_dark_empty.png", appearance: NSAppearance(named: .darkAqua),
                 size: NSSize(width: PanelTabs.width, height: brutal.natural))
        }
        for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.model.setVowel("ai")
        StackerPanel.shared.refresh()
        if let v = StackerPanel.shared.contentView {
            save(v, name: "brutal_stacker_dark_sanskrit.png", appearance: NSAppearance(named: .darkAqua),
                 size: NSSize(width: PanelTabs.width, height: brutal.natural))
        }
        SymbolsPanel.shared = SymbolsPanel()
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "brutal_symbols_dark.png", appearance: NSAppearance(named: .darkAqua),
                 size: NSSize(width: PanelTabs.width, height: symbolsNatural))
        }
        NSApp.appearance = nil

        let screen = PanelTabs.availableHeight()
        let t = Theme.current
        print("NATURAL_HEIGHT bubblegum=\(gum.natural) brutal_stacker=\(brutal.natural) brutalMin=\(brutal.minimum) brutal_symbols=\(symbolsNatural)")
        print("SCREEN_AVAILABLE=\(screen)")
        print("PANEL_WIDTH=\(PanelTabs.width) inner=\(PanelTabs.innerWidth)")
        print("COMPOSE_COL=\(t.composeColumnWidth) GUTTER=\(t.composeGutter) ART_H=\(t.stackerArtHeight)")
        print("SYMBOLS_BANNER_H=\(t.symbolsBannerHeight) gapX=\(t.symbolsGapX)")
        print("RAIL_W=\(t.railWidth) STACKER_GAP_X=\(t.stackerGapX)")
        print("STACKER_CELL=\(Int(t.stackerCell.width))x\(Int(t.stackerCell.height)) SYMBOLS_CELL=\(Int(t.symbolsCell.width))x\(Int(t.symbolsCell.height))")
        print("TAB_HEIGHTS symbols=\(PanelTabs.height(for: .symbols)) stacker=\(PanelTabs.height(for: .stacker)) dictionary=\(PanelTabs.height(for: .dictionary))")

        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

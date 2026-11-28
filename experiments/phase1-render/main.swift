#!/usr/bin/env swift
/// Renders Stacker/Symbols panels for Phase 3 Bubblegum + Brutalist regression screenshots.

import AppKit
import Foundation

final class App: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { self.run() }
    }

    private func run() {
        BubblegumFonts.registerIfNeeded()
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

        func saveStacker(_ name: String, appearance: NSAppearance?, height: CGFloat, adapt: Bool = true) {
            // `adaptLettersHeight` pins the alphabet to the top — skip it when capturing a scrolled state.
            if adapt { StackerPanel.shared.adaptLettersHeight(panelHeight: height) }
            if let v = StackerPanel.shared.contentView {
                save(v, name: name, appearance: appearance,
                     size: NSSize(width: PanelTabs.width, height: height))
            }
        }

        // —— Bubblegum light ——
        Prefs.style = .bubblegum
        NSApp.appearance = NSAppearance(named: .aqua)
        GlyphCaptionLayout.clearCaches()
        let gum = measureStacker()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: gum.natural)
        saveStacker("bubblegum_stacker_light_empty.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.addLayer("k")
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_light_ordinary.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.type("r")
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_light_prefix.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared.model.clear()
        for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.model.setVowel("i")
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_light_sanskrit.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared.model.clear()
        for key in ["ch", "g", "ng", "ny"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_light_tall.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.setVowel("")
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_light_inherent_a.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.model.clear()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: gum.natural)
        StackerPanel.shared.scrollAlphabetToEnd()
        saveStacker("bubblegum_stacker_light_marks.png", appearance: NSAppearance(named: .aqua), height: gum.natural)
        saveStacker("bubblegum_stacker_light_unavailable_subjoined.png", appearance: NSAppearance(named: .aqua), height: gum.natural)

        let shortH: CGFloat = 700
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.model.clear()
        StackerPanel.shared.refresh()
        let gumFloor = StackerPanel.shared.minimumHeight
        let gumTarget = max(gumFloor, shortH)
        StackerPanel.shared.adaptLettersHeight(panelHeight: gumTarget)
        saveStacker("bubblegum_stacker_scrolled_top.png", appearance: NSAppearance(named: .aqua), height: gumTarget, adapt: false)
        StackerPanel.shared.scrollAlphabetToEnd()
        saveStacker("bubblegum_stacker_scrolled_marks.png", appearance: NSAppearance(named: .aqua), height: gumTarget, adapt: false)

        for h in [700, 800, 900] as [CGFloat] {
            StackerPanel.shared = StackerPanel()
            StackerPanel.shared.model.clear()
            for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
            StackerPanel.shared.model.setVowel("ai")
            StackerPanel.shared.refresh()
            let floor = StackerPanel.shared.minimumHeight
            let target = max(floor, min(h, gum.natural))
            StackerPanel.shared.adaptLettersHeight(panelHeight: target)
            saveStacker("bubblegum_stacker_constrained_\(Int(h)).png", appearance: NSAppearance(named: .aqua), height: target)
            print("GUM_CONSTRAINED h=\(Int(h)) floor=\(Int(floor)) target=\(Int(target))")
        }

        SymbolsPanel.shared = SymbolsPanel()
        let gumSymbolsNatural = SymbolsPanel.shared.naturalHeight
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "bubblegum_symbols_light.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: gumSymbolsNatural))
        }
        if !SymbolsPanel.shared.model.results.isEmpty {
            SymbolsPanel.shared.model.select(0)
            SymbolsPanel.shared.refresh()
            if let v = SymbolsPanel.shared.contentView {
                save(v, name: "bubblegum_symbols_light_selected.png", appearance: NSAppearance(named: .aqua),
                     size: NSSize(width: PanelTabs.width, height: gumSymbolsNatural))
            }
        }

        // Bubblegum dark
        NSApp.appearance = NSAppearance(named: .darkAqua)
        GlyphCaptionLayout.clearCaches()
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: gum.natural)
        saveStacker("bubblegum_stacker_dark_empty.png", appearance: NSAppearance(named: .darkAqua), height: gum.natural)
        for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.model.setVowel("ai")
        StackerPanel.shared.refresh()
        saveStacker("bubblegum_stacker_dark_sanskrit.png", appearance: NSAppearance(named: .darkAqua), height: gum.natural)
        SymbolsPanel.shared = SymbolsPanel()
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "bubblegum_symbols_dark.png", appearance: NSAppearance(named: .darkAqua),
                 size: NSSize(width: PanelTabs.width, height: gumSymbolsNatural))
        }
        NSApp.appearance = nil

        // —— Brutalist regression ——
        Prefs.style = .brutal
        NSApp.appearance = NSAppearance(named: .aqua)
        GlyphCaptionLayout.clearCaches()
        let brutal = measureStacker()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: brutal.natural)
        saveStacker("brutal_stacker_light_empty.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        StackerPanel.shared.model.clear()
        StackerPanel.shared.model.addLayer("k")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_ordinary.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        StackerPanel.shared.model.clear()
        for key in ["k", "Sh"] { StackerPanel.shared.model.addLayer(key) }
        StackerPanel.shared.model.setVowel("i")
        StackerPanel.shared.refresh()
        saveStacker("brutal_stacker_light_sanskrit.png", appearance: NSAppearance(named: .aqua), height: brutal.natural)

        SymbolsPanel.shared = SymbolsPanel()
        let symbolsNatural = SymbolsPanel.shared.naturalHeight
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "brutal_symbols_light.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: symbolsNatural))
        }

        NSApp.appearance = NSAppearance(named: .darkAqua)
        GlyphCaptionLayout.clearCaches()
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: brutal.natural)
        saveStacker("brutal_stacker_dark_empty.png", appearance: NSAppearance(named: .darkAqua), height: brutal.natural)
        SymbolsPanel.shared = SymbolsPanel()
        SymbolsPanel.shared.refresh()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "brutal_symbols_dark.png", appearance: NSAppearance(named: .darkAqua),
                 size: NSSize(width: PanelTabs.width, height: symbolsNatural))
        }
        NSApp.appearance = nil

        // —— Phase 3.6 decorative comparisons (Bubblegum only; flags off afterward) ——
        Prefs.style = .bubblegum
        NSApp.appearance = NSAppearance(named: .aqua)
        Theme.bubblegumBiscuitEdge = false
        Theme.bubblegumPawMotif = false
        GlyphCaptionLayout.clearCaches()
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: 700)
        saveStacker("p36_tiles_flat.png", appearance: NSAppearance(named: .aqua), height: 700)

        Theme.bubblegumBiscuitEdge = true
        GlyphCaptionLayout.clearCaches()
        StackerPanel.shared = StackerPanel()
        StackerPanel.shared.refresh()
        StackerPanel.shared.adaptLettersHeight(panelHeight: 700)
        saveStacker("p36_tiles_biscuit.png", appearance: NSAppearance(named: .aqua), height: 700)
        Theme.bubblegumBiscuitEdge = false

        Theme.bubblegumPawMotif = false
        SymbolsPanel.shared = SymbolsPanel()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "p36_header_plain.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: min(220, SymbolsPanel.shared.naturalHeight)))
        }
        Theme.bubblegumPawMotif = true
        SymbolsPanel.shared = SymbolsPanel()
        if let v = SymbolsPanel.shared.contentView {
            save(v, name: "p36_header_paw.png", appearance: NSAppearance(named: .aqua),
                 size: NSSize(width: PanelTabs.width, height: min(220, SymbolsPanel.shared.naturalHeight)))
        }
        Theme.bubblegumPawMotif = false

        Prefs.style = .bubblegum
        let t = Theme.current
        let screen = PanelTabs.availableHeight()
        let nunito = BubblegumFonts.ui(13, weight: .bold)
        let symbolsGap = (PanelTabs.innerWidth - 7 * t.symbolsCell.width) / 6
        let composeSpan = t.composeColumnWidth * 2 + t.composeGutter
        print("NATURAL_HEIGHT bubblegum=\(gum.natural) gumMin=\(gum.minimum) gum_symbols=\(gumSymbolsNatural) brutal_stacker=\(brutal.natural) brutalMin=\(brutal.minimum) brutal_symbols=\(symbolsNatural)")
        print("SCREEN_AVAILABLE=\(screen)")
        print("PANEL_WIDTH=\(PanelTabs.width) inner=\(PanelTabs.innerWidth)")
        print("COMPOSE_COL=\(t.composeColumnWidth) GUTTER=\(t.composeGutter) ART_H=\(t.stackerArtHeight) COMPOSE_SPAN=\(composeSpan)")
        print("SYMBOLS_BANNER_H=\(t.symbolsBannerHeight) symbolsGapX_derived=\(symbolsGap)")
        print("RAIL_W=\(t.railWidth) STACKER_GAP_X=\(t.stackerGapX) STACKER_GAP_Y=\(t.stackerGapY)")
        print("STACKER_CELL=\(Int(t.stackerCell.width))x\(Int(t.stackerCell.height)) SYMBOLS_CELL=\(Int(t.symbolsCell.width))x\(Int(t.symbolsCell.height)) CELL_RADIUS=\(t.cellRadius)")
        print("ROOT_SPACING=\(t.rootSpacing) SECTION_SPACING=\(t.sectionSpacing) ACTION_H=\(t.actionButtonHeight)")
        print("TAB_HEIGHTS symbols=\(PanelTabs.height(for: .symbols)) stacker=\(PanelTabs.height(for: .stacker)) dictionary=\(PanelTabs.height(for: .dictionary))")
        print("UI_FONT=\(nunito.fontName) family=\(nunito.familyName ?? "?")")
        print("DELTA_NATURAL_STACKER phase3=\(1092) phase36=\(Int(gum.natural)) saved=\(1092 - Int(gum.natural))")

        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

//
//  FilterTextField.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 8/29/21.
//

import Foundation

@objc(iTermFilterTextField)
class FilterTextField: NSSearchField {
    private var iconSet = false

    @objc override func mouseUp(with event: NSEvent) {
        // See comment in iTermFocusReportingTextField.
    }

    @objc override func viewDidMoveToWindow() {
        if let searchFieldCell = self.cell as? NSSearchFieldCell,
           let cell = searchFieldCell.searchButtonCell, !iconSet {
            changeIcon(cell)
        }
    }

    private func changeIcon(_ cell: NSButtonCell) {
        cell.setButtonType(.toggle)
        let filterImage = NSImage(systemSymbolName: SFSymbol.lineHorizontal3DecreaseCircle.rawValue,
                                  accessibilityDescription: String(localized: "ui.swift.searchingfiltering.filtertextfield.filter.638e249f", defaultValue: "Filter", bundle: .main, comment: "User-facing text in FilterTextField."))
        cell.image = filterImage
        cell.alternateImage = filterImage
    }
}

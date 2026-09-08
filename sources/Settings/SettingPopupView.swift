//
//  SettingPopupView.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 10/29/25.
//

import Foundation
import SearchableComboListView

private extension SearchableComboViewGroup {
    static func fromSettings() -> [SearchableComboViewGroup] {
        let settings = PreferencePanel.sharedInstance().allSettings()
        var nextTag = 1
        let tagProvider = { () -> Int in
            defer {
                nextTag += 1
            }
            return nextTag
        }
        return groupsFromSettings(settings, ancestors: [], tagProvider: tagProvider)
    }

    private static func groupsFromSettings(_ settings: [iTermSetting],
                                            ancestors: [NSMenuItem],
                                            tagProvider: () -> (Int)) -> [SearchableComboViewGroup] {
        let groupsDict: [[String]: [iTermSetting]] = Dictionary(grouping: settings) { setting in
            setting.pathComponents
        }
        return groupsDict.keys.map { pathComponents in
            let settings = groupsDict[pathComponents]!
            let items = settings.compactMap { setting -> SearchableComboViewItem? in
                guard (setting.info.type == .checkbox || setting.info.type == .invertedCheckbox),
                        let button = setting.info.control as? NSButton,
                      !button.hiddenFromActions else {
                    return nil
                }
                let label = button.accessibilityLabel() ?? button.title
                let identifier = iTermKeyBindingAction.toggleSettingParameter(
                    forKey: setting.info.key,
                    isProfile: setting.isProfile,
                    label: label)
                return SearchableComboViewItem(label,
                                               tag: tagProvider(),
                                               identifier: identifier)
            }.sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return SearchableComboViewGroup(pathComponents.joined(separator: " > "),
                                            items: items)
        }.sorted { lhs, rhs in
            lhs.label < rhs.label
        }.filter { group in
            !group.items.isEmpty
        }
    }
}


@objc(iTermSettingPopupView)
class SettingPopupView: NSView {
    private struct SettingIdentity: Equatable {
        let key: String
        let isProfile: Bool

        init?(identifier: String) {
            guard let data = identifier.data(using: .utf8),
                  let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let key = dictionary["key"] as? String,
                  !key.isEmpty,
                  let isProfile = dictionary["isProfile"] as? Bool,
                  dictionary["label"] is String else {
                return nil
            }
            self.key = key
            self.isProfile = isProfile
        }
    }

    private var items: [SearchableComboViewItem] = []
    // An existing binding may contain a label in another UI language. Keep its
    // original bytes while the corresponding current-language item is selected.
    private var restoredSelection: (tag: Int, identifier: String)?
    @objc private(set) var comboView: SearchableComboView? = nil
    @IBOutlet var delegate: SearchableComboViewDelegate? {
        set {
            comboView?.delegate = newValue
        }
        get {
            return comboView?.delegate
        }
    }

    init() {
        super.init(frame: NSRect.zero)
        reloadData()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        reloadData()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        reloadData()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        comboView?.frame = self.bounds
    }

    @objc func reloadData() {
        let identifier = selectedIdentifier
        restoredSelection = nil
        comboView?.removeFromSuperview()
        let groups = SearchableComboViewGroup.fromSettings()
        items = groups.flatMap { $0.items }
        let newComboView = SearchableComboView(groups,
                                               defaultTitle: "Select Setting…")
        newComboView.frame = self.bounds
        newComboView.delegate = comboView?.delegate
        addSubview(newComboView)
        comboView = newComboView
        if let identifier = identifier {
            _ = select(identifier: identifier)
        }
    }

    @objc var selectedTitle: String? {
        return comboView?.selectedItem?.title
    }

    @objc var selectedIdentifier: String? {
        if let restored = restoredSelection, comboView?.selectedTag() == restored.tag {
            return restored.identifier
        }
        return comboView?.selectedItem?.identifier.map { $0 as NSString as String }
    }

    @objc(selectItemWithTitle:) func select(title: String) {
        restoredSelection = nil
        _ = comboView?.selectItem(withTitle: title)
    }

    @discardableResult
    @objc(selectItemWithIdentifier:) func select(identifier: String) -> Bool {
        restoredSelection = nil
        if comboView?.selectItem(withIdentifier: NSUserInterfaceItemIdentifier(identifier)) == true {
            return true
        }
        guard let identity = SettingIdentity(identifier: identifier),
              let item = items.first(where: { item in
                  guard let current = item.identifier else { return false }
                  return SettingIdentity(identifier: current) == identity
              }),
              let current = item.identifier,
              comboView?.selectItem(withIdentifier: NSUserInterfaceItemIdentifier(current)) == true else {
            return false
        }
        restoredSelection = (item.tag, identifier)
        return true
    }
}

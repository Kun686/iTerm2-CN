//
//  ChatToolbar.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 9/25/25.
//

import Foundation

@objc class WebSearchButton: NSButton { }
@objc class ThinkingButton: NSButton { }

struct ChatProviderOption: Equatable {
    private static let manualPrefix = "manual:"

    let identifier: String
    let title: String
    // Separators and headers are shown but can't be chosen.
    var isSelectable: Bool = true
    var isSeparator: Bool = false

    static func vendor(_ vendor: iTermAIVendor) -> ChatProviderOption {
        ChatProviderOption(identifier: vendorIdentifier(vendor),
                           title: vendorTitle(vendor))
    }

    // Each manually-configured model is its own selectable item.
    static func manualModel(name: String) -> ChatProviderOption {
        ChatProviderOption(identifier: manualPrefix + name, title: name)
    }

    static func separator() -> ChatProviderOption {
        ChatProviderOption(identifier: "", title: "", isSelectable: false, isSeparator: true)
    }

    static func vendorIdentifier(_ vendor: iTermAIVendor) -> String {
        return "vendor:\(vendor.rawValue)"
    }

    static func vendor(from identifier: String) -> iTermAIVendor? {
        guard identifier.hasPrefix("vendor:"),
              let rawValue = UInt(identifier.dropFirst("vendor:".count)) else {
            return nil
        }
        return iTermAIVendor(rawValue: rawValue)
    }

    static func manualName(from identifier: String) -> String? {
        guard identifier.hasPrefix(manualPrefix) else {
            return nil
        }
        return String(identifier.dropFirst(manualPrefix.count))
    }

    private static func vendorTitle(_ provider: iTermAIVendor) -> String {
        switch provider {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .gemini:
            return "Gemini"
        case .deepSeek:
            return "DeepSeek"
        case .llama:
            return String(localized: "ui.swift.aiterm.chattoolbar.llama_local.2933c0ec", defaultValue: "Llama (Local)", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .apple:
            return "Apple"
        @unknown default:
            return String(localized: "ui.swift.aiterm.chattoolbar.provider.472590ae", defaultValue: "Provider", bundle: .main, comment: "User-facing text in ChatToolbar.")
        }
    }
}

protocol ChatToolbarDataSource: AnyObject {
    var provider: LLMProvider? { get }
    var availableProviderOptions: [ChatProviderOption] { get }
    var effectiveProviderIdentifier: String? { get }
    var canChangeProvider: Bool { get }
    var canChangeModel: Bool { get }
    var webSearchEnabled: Bool { get }
    var thinkingEnabled: Bool { get }
    var selectedReasoningEffort: ResponsesRequestBody.ReasoningOptions.Effort? { get }
    var selectedServiceTier: ResponsesRequestBody.ServiceTier? { get }
    var effectiveModel: String? { get }
    var availableModels: [AIMetadata.Model] { get }

    func showSessionButtonMenu(_ sender: NSButton)
    func toggleWebSearch()
    func toggleThinking()
    func toolbarDidUpdate()
    func selectedProviderDidChange()
    func selectedModelDidChange()
    func selectedReasoningEffortDidChange()
    func selectedServiceTierDidChange()
}

class ChatToolbar {
    private(set) var providerSelectorButton: NSPopUpButton?
    private(set) var modelSelectorButton: NSPopUpButton?
    private(set) var sessionButton: NSButton!
    private(set) var webSearchButton: WebSearchButton?
    private(set) var thinkingButton: ThinkingButton?
    private(set) var reasoningEffortButton: NSPopUpButton?
    private(set) var serviceTierButton: NSPopUpButton?
    private(set) var titleLabel: NSTextField!

    private let userDefaultsObserver = iTermUserDefaultsObserver()

    weak var dataSource: ChatToolbarDataSource?

    init(dataSource: ChatToolbarDataSource) {
        self.dataSource = dataSource

        let label = NSTextField(labelWithString: String(localized: "ui.swift.aiterm.chattoolbar.ai_chat.fe98f42c", defaultValue: "AI Chat", bundle: .main, comment: "User-facing text in ChatToolbar."))
        label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        self.titleLabel = label

        sessionButton = ChatToolbar.makeSessionInfoButton()
        sessionButton.imageScaling = .scaleProportionallyUpOrDown
        sessionButton.controlSize = .large
        sessionButton.target = self
        sessionButton.action = #selector(showSessionButtonMenu(_:))
        sessionButton.sizeToFit()

        do {
            let webSearchButton = WebSearchButton(image: NSImage.it_image(forSymbolName: SFSymbol.globe.rawValue,
                                                                          accessibilityDescription: String(localized: "ui.swift.aiterm.chattoolbar.web_search_image.40377dd4", defaultValue: "Web search image", bundle: .main, comment: "User-facing text in ChatToolbar."),
                                                                          fallbackImageName: "globe",
                                                                          for: Self.self)!,
                                                  target: nil,
                                                  action: nil)
            webSearchButton.imageScaling = .scaleProportionallyUpOrDown
            webSearchButton.controlSize = .large
            webSearchButton.contentTintColor = dataSource.webSearchEnabled ? .controlAccentColor : nil
            webSearchButton.isBordered = false
            webSearchButton.bezelStyle = .badge
            webSearchButton.isBordered = false
            webSearchButton.target = self
            webSearchButton.action = #selector(toggleWebSearch(_:))
            webSearchButton.sizeToFit()
            webSearchButton.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.allow_ai_to_perform_web_search.a202d37f", defaultValue: "Allow AI to perform web search?", bundle: .main, comment: "User-facing text in ChatToolbar.")
            self.webSearchButton = webSearchButton
            webSearchButton.isEnabled = (dataSource.provider?.supportsHostedWebSearch == true)
        }

        do {
            let smallerConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

            let image = NSImage(
                systemSymbolName: SFSymbol.lightbulb.rawValue,
                accessibilityDescription: String(localized: "ui.swift.aiterm.chattoolbar.enable_high_effort_reasoning.b3166298", defaultValue: "Enable high-effort reasoning?", bundle: .main, comment: "User-facing text in ChatToolbar."))?.withSymbolConfiguration(smallerConfig)
            let thinkingButton = ThinkingButton(image: image!,
                                                  target: nil,
                                                action: nil)
            thinkingButton.imageScaling = .scaleNone
            thinkingButton.controlSize = .large
            thinkingButton.contentTintColor = dataSource.thinkingEnabled ? .controlAccentColor : nil
            thinkingButton.isBordered = false
            thinkingButton.bezelStyle = .badge
            thinkingButton.isBordered = false
            thinkingButton.target = self
            thinkingButton.action = #selector(toggleThinking(_:))
            thinkingButton.sizeToFit()
            thinkingButton.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.enable_high_effort_reasoning_slower_but_may_produce.f727d05f", defaultValue: "Enable high-effort reasoning? Slower but may produce better results.", bundle: .main, comment: "User-facing text in ChatToolbar.")
            self.thinkingButton = thinkingButton
            thinkingButton.isEnabled = (dataSource.provider?.model.features.contains(.configurableThinking) == true)
        }
        createOrUpdateProviderSelector()
        createOrUpdateModelSelector()
        createOrUpdateReasoningEffortSelector()
        createOrUpdateServiceTierSelector()

        userDefaultsObserver.observeKey(kPreferenceKeyAIFeatureHostedWebSearch) { [weak self] in
            self?.update()
        }
        userDefaultsObserver.observeKey(kPreferenceKeyUseRecommendedAIModel) { [weak self] in
            self?.update()
        }
        userDefaultsObserver.observeKey(kPreferenceKeyAIVendor) { [weak self] in
            self?.update()
        }
        userDefaultsObserver.observeKey(ChatViewController.reasoningEffortUserDefaultsKey) { [weak self] in
            self?.update()
        }
        userDefaultsObserver.observeKey(ChatViewController.serviceTierUserDefaultsKey) { [weak self] in
            self?.update()
        }
        update()
    }
}

// Container for the macOS 26 floating bar. Hosts a translucent NSVisualEffect
// background plus a manually-laid-out row of controls. Replaces the previous
// NSGlassEffectView+NSStackView constraint-driven implementation so the chat
// UI is auto-layout-free.
final class FloatingChatToolbarView: NSView {
    static let controlHeight: CGFloat = 22
    static let buttonMinWidth: CGFloat = 22
    static let providerSelectorMinWidth: CGFloat = 96
    static let modelSelectorMinWidth: CGFloat = 120
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 20

    private let backdrop: NSVisualEffectView
    private let row: ChatManualStackView
    private let providerSelectorButton: NSPopUpButton?
    private let modelSelectorButton: NSPopUpButton?
    private let reasoningEffortButton: NSPopUpButton?
    private let serviceTierButton: NSPopUpButton?
    private let thinkingButton: NSButton?
    private let webSearchButton: NSButton?
    private let sessionButton: NSButton?

    private let layoutJoiner = IdempotentOperationJoiner.asyncJoiner(.main)

    func setNeedsLayoutNow() {
        layoutJoiner.setNeedsUpdate { [weak self] in
            self?.performLayoutNow()
        }
    }

    init(providerSelectorButton: NSPopUpButton?,
         modelSelectorButton: NSPopUpButton?,
         reasoningEffortButton: NSPopUpButton?,
         serviceTierButton: NSPopUpButton?,
         thinkingButton: NSButton?,
         webSearchButton: NSButton?,
         sessionButton: NSButton?) {
        self.providerSelectorButton = providerSelectorButton
        self.modelSelectorButton = modelSelectorButton
        self.reasoningEffortButton = reasoningEffortButton
        self.serviceTierButton = serviceTierButton
        self.thinkingButton = thinkingButton
        self.webSearchButton = webSearchButton
        self.sessionButton = sessionButton

        backdrop = NSVisualEffectView()
        backdrop.wantsLayer = true
        backdrop.material = .hudWindow
        backdrop.blendingMode = .withinWindow
        backdrop.state = .active

        row = ChatManualStackView(orientation: .horizontal,
                                  spacing: 12,
                                  alignment: .center)

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true

        addSubview(backdrop)
        addSubview(row)

        if let providerSelectorButton {
            providerSelectorButton.controlSize = .large
            row.addArrangedSubview(providerSelectorButton)
        }
        if let modelSelectorButton {
            modelSelectorButton.controlSize = .large
            row.addArrangedSubview(modelSelectorButton)
        }
        if let reasoningEffortButton {
            reasoningEffortButton.controlSize = .large
            row.addArrangedSubview(reasoningEffortButton)
        }
        if let serviceTierButton {
            serviceTierButton.controlSize = .large
            row.addArrangedSubview(serviceTierButton)
        }
        if let thinkingButton {
            thinkingButton.controlSize = .large
            row.addArrangedSubview(thinkingButton)
        }
        if let webSearchButton {
            webSearchButton.controlSize = .large
            row.addArrangedSubview(webSearchButton)
        }
        if let sessionButton {
            sessionButton.controlSize = .large
            row.addArrangedSubview(sessionButton)
        }

        // Override per-control sizing so the row reads the same minimums the
        // old constraint cascade enforced.
        row.sizeOverride = { [weak self] view, _ in
            guard let self else { return nil }
            if view === self.providerSelectorButton {
                let intrinsic = view.intrinsicContentSize
                return NSSize(width: max(Self.providerSelectorMinWidth, intrinsic.width),
                              height: Self.controlHeight)
            }
            if view === self.modelSelectorButton {
                let intrinsic = view.intrinsicContentSize
                return NSSize(width: max(Self.modelSelectorMinWidth, intrinsic.width),
                              height: Self.controlHeight)
            }
            if view === self.reasoningEffortButton ||
               view === self.serviceTierButton {
                let intrinsic = view.intrinsicContentSize
                return NSSize(width: max(94, intrinsic.width),
                              height: Self.controlHeight)
            }
            if view === self.thinkingButton ||
               view === self.webSearchButton ||
               view === self.sessionButton {
                let intrinsic = view.intrinsicContentSize
                return NSSize(width: max(Self.buttonMinWidth, intrinsic.width),
                              height: Self.controlHeight)
            }
            return nil
        }
    }

    required init?(coder: NSCoder) {
        it_fatalError("init(coder:) not implemented")
    }

    // Manual-layout helper (don't override intrinsicContentSize — it would
    // activate the constraint engine for the surrounding view tree).
    func preferredSize() -> NSSize {
        let rowSize = row.fittingSize(crossAxisLimit: Self.controlHeight)
        let height = max(Self.controlHeight, rowSize.height) + Self.verticalPadding * 2
        let width = rowSize.width + Self.horizontalPadding * 2
        return NSSize(width: width, height: height)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize {
            setNeedsLayoutNow()
        }
    }

    override func layout() {
        super.layout()
        performLayoutNow()
    }

    private func performLayoutNow() {
        let backdropFrame = bounds
        if backdrop.frame != backdropFrame {
            backdrop.frame = backdropFrame
        }
        let rowX = Self.horizontalPadding
        let rowY = Self.verticalPadding
        let rowWidth = max(0, bounds.width - Self.horizontalPadding * 2)
        let rowHeight = max(0, bounds.height - Self.verticalPadding * 2)
        let rowFrame = NSRect(x: rowX, y: rowY, width: rowWidth, height: rowHeight)
        if row.frame != rowFrame {
            row.frame = rowFrame
        }
    }
}

extension ChatToolbar {
    // Shared construction of the info-circle "session" button so the chat
    // window toolbar and the inline panel toolbar build the same control and
    // don't drift. Callers set their own control size, image scaling, tooltip,
    // and target/action.
    static func makeSessionInfoButton() -> NSButton {
        let image = NSImage(systemSymbolName: SFSymbol.infoCircle.rawValue,
                            accessibilityDescription: nil)!
        let button = NSButton(image: image, target: nil, action: nil)
        button.bezelStyle = .badge
        // Setting bezelStyle resets isBordered to true, so clear it after (the
        // same dance the sibling web-search/thinking buttons do).
        button.isBordered = false
        return button
    }

    @available(macOS 26, *)
    func createFloatingView() -> NSView {
        return FloatingChatToolbarView(providerSelectorButton: providerSelectorButton,
                                       modelSelectorButton: modelSelectorButton,
                                       reasoningEffortButton: reasoningEffortButton,
                                       serviceTierButton: serviceTierButton,
                                       thinkingButton: thinkingButton,
                                       webSearchButton: webSearchButton,
                                       sessionButton: sessionButton)
    }

    func createOrUpdateProviderSelector() {
        let options = dataSource?.availableProviderOptions ?? []
        let selector = providerSelectorButton ?? NSPopUpButton()
        providerSelectorButton = selector
        selector.removeAllItems()
        selector.target = self
        selector.action = #selector(selectProvider(_:))
        selector.isBordered = false
        selector.bezelStyle = .inline
        selector.font = NSFont.systemFont(ofSize: 16)

        for option in options {
            if option.isSeparator {
                selector.menu?.addItem(.separator())
                continue
            }
            selector.addItem(withTitle: option.title)
            selector.lastItem?.representedObject = option.identifier
            selector.lastItem?.isEnabled = option.isSelectable
        }

        let selectableCount = options.filter { $0.isSelectable && !$0.isSeparator }.count
        selector.isHidden = selectableCount <= 1
        selector.isEnabled = !options.isEmpty && (dataSource?.canChangeProvider == true)
        selector.toolTip = selector.isEnabled
            ? String(localized: "ui.swift.aiterm.chattoolbar.select_the_ai_provider_for_this_chat_before.3d2d7349", defaultValue: "Select the AI provider for this chat before sending the first message.", bundle: .main, comment: "User-facing text in ChatToolbar.")
            : String(localized: "ui.swift.aiterm.chattoolbar.the_provider_is_fixed_after_the_first_real.dfb1dccf", defaultValue: "The provider is fixed after the first real message in a chat.", bundle: .main, comment: "User-facing text in ChatToolbar.")
        if let selectedIdentifier = dataSource?.effectiveProviderIdentifier {
            select(selector, representedObject: selectedIdentifier)
        } else if !options.isEmpty {
            selector.selectItem(at: 0)
        }
    }

    func createOrUpdateModelSelector() {
        modelSelectorButton?.removeAllItems()

        let availableModels = dataSource?.availableModels ?? []
        let modelSelector = modelSelectorButton ?? NSPopUpButton()
        modelSelectorButton = modelSelector
        modelSelector.target = self
        modelSelector.action = #selector(selectModel(_:))
        modelSelector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.select_a_model_for_this_chat_the_provider.1f104d49", defaultValue: "Select a model for this chat. The provider is fixed after the chat is created.", bundle: .main, comment: "User-facing text in ChatToolbar.")

        modelSelector.isBordered = false
        modelSelector.bezelStyle = .inline
        modelSelector.font = NSFont.systemFont(ofSize: 16)

        for model in availableModels {
            modelSelector.addItem(withTitle: model.name)
            modelSelector.lastItem?.representedObject = model.name
        }

        let canChangeModel = dataSource?.canChangeModel ?? false
        modelSelector.isEnabled = canChangeModel && availableModels.count > 1
        // With a single available model (e.g. a manually configured model) the
        // popup would just show a fixed, grayed-out title, so hide it entirely.
        modelSelector.isHidden = availableModels.count <= 1
        if !canChangeModel {
            modelSelector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.the_model_is_fixed_after_the_chat_starts.06ea7078", defaultValue: "The model is fixed after the chat starts.", bundle: .main, comment: "User-facing text in ChatToolbar.")
        } else if availableModels.count > 1 {
            modelSelector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.select_a_model_for_this_chat.d19285c6", defaultValue: "Select a model for this chat.", bundle: .main, comment: "User-facing text in ChatToolbar.")
        } else {
            modelSelector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.only_one_model_is_available_for_this_chat.f1d8eb69", defaultValue: "Only one model is available for this chat.", bundle: .main, comment: "User-facing text in ChatToolbar.")
        }
        if let selectedModel = dataSource?.effectiveModel {
            modelSelector.selectItem(withTitle: selectedModel)
        } else if !availableModels.isEmpty {
            modelSelector.selectItem(at: 0)
        }
    }

    func createOrUpdateReasoningEffortSelector() {
        let selector = reasoningEffortButton ?? NSPopUpButton()
        reasoningEffortButton = selector
        selector.removeAllItems()
        selector.target = self
        selector.action = #selector(selectReasoningEffort(_:))
        selector.isBordered = false
        selector.bezelStyle = .inline
        selector.font = NSFont.systemFont(ofSize: 13)
        selector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.select_reasoning_effort_for_models_that_support_it.4d6280cd", defaultValue: "Select reasoning effort for models that support it", bundle: .main, comment: "User-facing text in ChatToolbar.")

        let efforts = dataSource?.provider?.model.reasoningEfforts ?? []
        for effort in efforts {
            selector.addItem(withTitle: Self.reasoningEffortTitle(effort))
            selector.lastItem?.representedObject = effort.rawValue
        }
        selector.isHidden = efforts.isEmpty
        selector.isEnabled = !efforts.isEmpty
        if let selectedEffort = dataSource?.selectedReasoningEffort,
           efforts.contains(selectedEffort) {
            select(selector, representedObject: selectedEffort.rawValue)
        } else if !efforts.isEmpty {
            selector.selectItem(at: 0)
        }
    }

    func createOrUpdateServiceTierSelector() {
        let selector = serviceTierButton ?? NSPopUpButton()
        serviceTierButton = selector
        selector.removeAllItems()
        selector.target = self
        selector.action = #selector(selectServiceTier(_:))
        selector.isBordered = false
        selector.bezelStyle = .inline
        selector.font = NSFont.systemFont(ofSize: 13)
        selector.toolTip = String(localized: "ui.swift.aiterm.chattoolbar.select_openai_service_tier_priority_is_faster_flex.3840cf4e", defaultValue: "Select OpenAI service tier. Priority is faster; Flex is lower-cost and slower.", bundle: .main, comment: "User-facing text in ChatToolbar.")

        let tiers = dataSource?.provider?.model.serviceTiers ?? []
        for tier in tiers {
            selector.addItem(withTitle: Self.serviceTierTitle(tier))
            selector.lastItem?.representedObject = tier.rawValue
        }
        selector.isHidden = tiers.isEmpty
        selector.isEnabled = !tiers.isEmpty
        let selectedTier = dataSource?.selectedServiceTier ?? .auto
        if tiers.contains(selectedTier) {
            select(selector, representedObject: selectedTier.rawValue)
        } else if !tiers.isEmpty {
            selector.selectItem(at: 0)
        }
    }

    func update() {
        let provider = dataSource?.provider
        webSearchButton?.isEnabled = provider?.supportsHostedWebSearch == true
        thinkingButton?.isEnabled = (provider?.model.features.contains(.configurableThinking) == true)
        thinkingButton?.contentTintColor = dataSource?.thinkingEnabled == true ? .controlAccentColor : nil
        createOrUpdateProviderSelector()
        createOrUpdateModelSelector()
        createOrUpdateReasoningEffortSelector()
        createOrUpdateServiceTierSelector()

        dataSource?.toolbarDidUpdate()
    }

    var selectedModelIdentifier: String? {
        return modelSelectorButton?.selectedItem?.representedObject as? String
    }

    var selectedProviderIdentifier: String? {
        return providerSelectorButton?.selectedItem?.representedObject as? String
    }

    @objc private func showSessionButtonMenu(_ sender: NSButton) {
        dataSource?.showSessionButtonMenu(sender)
    }

    @objc private func toggleWebSearch(_ sender: Any) {
        dataSource?.toggleWebSearch()
        webSearchButton?.contentTintColor = dataSource?.webSearchEnabled == true ? .controlAccentColor : nil
    }

    @objc private func toggleThinking(_ sender: Any) {
        dataSource?.toggleThinking()
        thinkingButton?.contentTintColor = dataSource?.thinkingEnabled == true ? .controlAccentColor : nil
    }

    @objc private func selectModel(_ sender: Any?)  {
        dataSource?.selectedModelDidChange()
        update()
    }

    @objc private func selectProvider(_ sender: Any?) {
        dataSource?.selectedProviderDidChange()
        update()
    }

    @objc private func selectReasoningEffort(_ sender: Any?) {
        dataSource?.selectedReasoningEffortDidChange()
        update()
    }

    @objc private func selectServiceTier(_ sender: Any?) {
        dataSource?.selectedServiceTierDidChange()
        update()
    }

    private func select(_ selector: NSPopUpButton, representedObject: String) {
        for item in selector.itemArray where item.representedObject as? String == representedObject {
            selector.select(item)
            return
        }
    }

    private static func reasoningEffortTitle(_ effort: ResponsesRequestBody.ReasoningOptions.Effort) -> String {
        let value = switch effort {
        case .none: String(localized: "ui.swift.aiterm.chattoolbar.none.dc937b59", defaultValue: "None", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .minimal: String(localized: "ui.swift.aiterm.chattoolbar.minimal.057b5de4", defaultValue: "Minimal", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .low: String(localized: "ui.swift.aiterm.chattoolbar.low.f793de20", defaultValue: "Low", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .medium: String(localized: "ui.swift.aiterm.chattoolbar.medium.8e588cd1", defaultValue: "Medium", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .high: String(localized: "ui.swift.aiterm.chattoolbar.high.c4ebc6d4", defaultValue: "High", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .xhigh: String(localized: "ui.swift.aiterm.chattoolbar.xhigh.0704c8f3", defaultValue: "XHigh", bundle: .main, comment: "User-facing text in ChatToolbar.")
        }
        return String(localized: "ui.swift.aiterm.chattoolbar.effort_0.f683123a", defaultValue: "Effort: \(value)", bundle: .main, comment: "User-facing text in ChatToolbar.")
    }

    private static func serviceTierTitle(_ tier: ResponsesRequestBody.ServiceTier) -> String {
        let value = switch tier {
        case .auto: String(localized: "ui.swift.aiterm.chattoolbar.auto.02862497", defaultValue: "Auto", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .default: String(localized: "ui.swift.aiterm.chattoolbar.standard.ef669154", defaultValue: "Standard", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .priority: String(localized: "ui.swift.aiterm.chattoolbar.priority_fast.d263dd37", defaultValue: "Priority (Fast)", bundle: .main, comment: "User-facing text in ChatToolbar.")
        case .flex: String(localized: "ui.swift.aiterm.chattoolbar.flex_slow.56d9fb37", defaultValue: "Flex (Slow)", bundle: .main, comment: "User-facing text in ChatToolbar.")
        }
        return String(localized: "ui.swift.aiterm.chattoolbar.tier_0.cce1cfac", defaultValue: "Tier: \(value)", bundle: .main, comment: "User-facing text in ChatToolbar.")
    }
}

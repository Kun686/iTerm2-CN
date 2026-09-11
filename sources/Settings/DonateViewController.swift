//
//  DonateViewController.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 2/27/22.
//

import Foundation

@objc
private class DonateView: NSView {
}

@objc(iTermDonateViewController)
class DonateViewController: NSTitlebarAccessoryViewController {
    private static func textString() -> String {
        return [String(localized: "ui.swift.settings.donateviewcontroller.donate.c91ee0f2", defaultValue: "Donate", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.support_iterm2.f8b2d6dd", defaultValue: "Support iTerm2", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.iterm2_is_one_person_s_project_donate_now.e7cdcfaf", defaultValue: "iTerm2 is one person’s project. Donate now!", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.keep_iterm2_alive_donate_today.a145f6d2", defaultValue: "Keep iTerm2 alive — Donate today!", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.love_using_iterm2_help_keep_it_thriving.d58a2ec0", defaultValue: "Love using iTerm2? Help keep it thriving!", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.iterm2_needs_your_support_donate_here.7b99ffda", defaultValue: "iTerm2 needs your support – Donate here.", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.help_iterm2_grow_consider_donating.4c165315", defaultValue: "Help iTerm2 grow – Consider donating.", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.keep_the_iterm2_dream_alive_donate.11906be7", defaultValue: "Keep the iTerm2 dream alive – Donate!", bundle: .main, comment: "User-facing donation prompt."),
                String(localized: "ui.swift.settings.donateviewcontroller.support_the_creator_of_iterm2_donate_now.6ce8fa13", defaultValue: "Support the creator of iTerm2 – Donate now!", bundle: .main, comment: "User-facing donation prompt."),
        ].randomElement()!
    }

    let innerVC = DismissableLinkViewController(userDefaultsKey: "NoSyncHideDonateLabel",
                                                text: DonateViewController.textString(),
                                                url: URL(string: "https://iterm2.com/donate.html")!,
                                                clickToHide: true)
    init() {
        super.init(nibName: nil, bundle: nil)
        layoutAttribute = .right
    }

    required init?(coder: NSCoder) {
        it_fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DonateView()

        let subview = innerVC.view
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)

        view.frame = subview.frame

        view.addConstraint(NSLayoutConstraint(item: view,
                                              attribute: .width,
                                              relatedBy: .equal,
                                              toItem: subview,
                                              attribute: .width,
                                              multiplier: 1,
                                              constant: 0))
        view.addConstraint(NSLayoutConstraint(item: view,
                                              attribute: .height,
                                              relatedBy: .greaterThanOrEqual,
                                              toItem: subview,
                                              attribute: .height,
                                              multiplier: 1,
                                              constant: 7.5))
        view.addConstraint(NSLayoutConstraint(item: view,
                                              attribute: .leading,
                                              relatedBy: .equal,
                                              toItem: subview,
                                              attribute: .leading,
                                              multiplier: 1,
                                              constant: 0))
        view.addConstraint(NSLayoutConstraint(item: view,
                                              attribute: .top,
                                              relatedBy: .equal,
                                              toItem: subview,
                                              attribute: .top,
                                              multiplier: 1,
                                              constant: -4
                                             ))
    }
}

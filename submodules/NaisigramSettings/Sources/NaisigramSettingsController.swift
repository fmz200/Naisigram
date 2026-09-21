import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AdFilterStore

private final class NaisigramSettingsScreenArguments {
    let toggleAdFilterEnabled: (Bool) -> Void
    let toggleFoldAds: (Bool) -> Void
    let openGlobalRules: () -> Void

    init(
        toggleAdFilterEnabled: @escaping (Bool) -> Void,
        toggleFoldAds: @escaping (Bool) -> Void,
        openGlobalRules: @escaping () -> Void
    ) {
        self.toggleAdFilterEnabled = toggleAdFilterEnabled
        self.toggleFoldAds = toggleFoldAds
        self.openGlobalRules = openGlobalRules
    }
}

private enum NaisigramSettingsScreenSection: Int32 {
    case adFilter = 0
    case about = 1
}

private enum NaisigramSettingsScreenEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case adFilterHeader
        case enable
        case fold
        case globalRules
        case aboutHeader
        case version
    }

    case adFilterHeader
    case enable(value: Bool)
    case fold(value: Bool)
    case globalRules
    case aboutHeader
    case version(text: String)

    var section: ItemListSectionId {
        switch self {
        case .adFilterHeader, .enable, .fold, .globalRules:
            return NaisigramSettingsScreenSection.adFilter.rawValue
        case .aboutHeader, .version:
            return NaisigramSettingsScreenSection.about.rawValue
        }
    }

    var sortIndex: Int {
        switch self {
        case .adFilterHeader:
            return 0
        case .enable:
            return 1
        case .fold:
            return 2
        case .globalRules:
            return 3
        case .aboutHeader:
            return 10
        case .version:
            return 11
        }
    }

    var stableId: StableId {
        switch self {
        case .adFilterHeader:
            return .adFilterHeader
        case .enable:
            return .enable
        case .fold:
            return .fold
        case .globalRules:
            return .globalRules
        case .aboutHeader:
            return .aboutHeader
        case .version:
            return .version
        }
    }

    static func < (lhs: NaisigramSettingsScreenEntry, rhs: NaisigramSettingsScreenEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NaisigramSettingsScreenArguments
        switch self {
        case .adFilterHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Ad Filter", sectionId: self.section)
        case let .enable(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.dataAndStorage, title: "Enable Ad Filter", text: "Hide or fold messages matching your ad filter rules.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAdFilterEnabled(value)
            })
        case let .fold(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.chatFolders, title: "Fold Ads", text: "Fold matched messages into a summary row. Disable to hide them completely.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleFoldAds(value)
            })
        case .globalRules:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.channels, title: "Global Rules", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openGlobalRules()
            })
        case .aboutHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "About", sectionId: self.section)
        case let .version(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Version", label: text, sectionId: self.section, style: .blocks, action: nil)
        }
    }
}

private func naisigramSettingsScreenEntries(presentationData: PresentationData, settings: AdFilterSettings) -> [NaisigramSettingsScreenEntry] {
    var entries: [NaisigramSettingsScreenEntry] = []

    entries.append(.adFilterHeader)
    entries.append(.enable(value: settings.isEnabled))
    entries.append(.fold(value: settings.foldEnabled))
    entries.append(.globalRules)

    entries.append(.aboutHeader)
    let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    entries.append(.version(text: "\(version) (\(build))"))

    return entries
}

public func naisigramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let _ = pushControllerImpl

    let settingsPromise = ValuePromise<AdFilterSettings>(AdFilterStore.shared.currentSettings(), ignoreRepeated: true)

    let arguments = NaisigramSettingsScreenArguments(
        toggleAdFilterEnabled: { value in
            AdFilterStore.shared.updateSettings { settings in
                var updated = settings
                updated.isEnabled = value
                return updated
            }
            settingsPromise.set(AdFilterStore.shared.currentSettings())
        },
        toggleFoldAds: { value in
            AdFilterStore.shared.updateSettings { settings in
                var updated = settings
                updated.foldEnabled = value
                return updated
            }
            settingsPromise.set(AdFilterStore.shared.currentSettings())
        },
        openGlobalRules: {
            pushControllerImpl?(AdFilterSettingsController(context: context, peerId: nil as EnginePeer.Id?, peerTitle: "All Channels", isGlobalMode: true))
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        settingsPromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Naisigram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: naisigramSettingsScreenEntries(presentationData: presentationData, settings: settings),
            style: .blocks,
            emptyStateItem: nil,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }

    return controller
}

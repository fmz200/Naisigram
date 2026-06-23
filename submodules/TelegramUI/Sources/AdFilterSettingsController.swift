import Foundation
import UIKit
import UniformTypeIdentifiers
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AsyncDisplayKit

final class AdFilterSettingsController: ViewController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id?
    private let peerTitle: String
    private let isGlobalMode: Bool

    private var didSetRules: (([AdFilterRule]) -> Void)?

    private var controllerNode: AdFilterSettingsControllerNode {
        return self.displayNode as! AdFilterSettingsControllerNode
    }

    init(context: AccountContext, peerId: EnginePeer.Id?, peerTitle: String, isGlobalMode: Bool = false, didSetRules: (([AdFilterRule]) -> Void)? = nil) {
        self.context = context
        self.peerId = peerId
        self.peerTitle = peerTitle
        self.isGlobalMode = isGlobalMode
        self.didSetRules = didSetRules

        let title = isGlobalMode ? "Ad Filter Rules" : "Ad Filter - \(peerTitle)"
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            presentationData: context.sharedContext.currentPresentationData.with { $0 },
            title: title,
            back: true
        ))

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .modal
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = AdFilterSettingsControllerNode(
            context: self.context,
            peerId: self.peerId,
            peerTitle: self.peerTitle,
            isGlobalMode: self.isGlobalMode,
            navigationController: self.navigationController
        )
        node.weakViewController = self
        self.displayNode = node

        self.displayNodeLoaded()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.controllerNode.didUpdateRules = { [weak self] rules in
            self?.didSetRules?(rules)
        }
    }
}

private final class AdFilterSettingsControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: EnginePeer.Id?
    private let peerTitle: String
    private let isGlobalMode: Bool
    private weak var navigationController: UINavigationController?
    fileprivate weak var weakViewController: ViewController?

    private let scrollView: UIScrollView
    private let containerNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let descriptionNode: ASTextNode
    private let inputBackgroundNode: ASDisplayNode
    private let inputTextField: UITextField
    private let addButton: UIButton
    private let rulesContainerNode: ASDisplayNode
    private let exportButton: UIButton
    private let importButton: UIButton
    private let globalInfoNode: ASTextNode

    private var rules: [AdFilterRule] = []
    private var ruleNodes: [AdFilterRuleNode] = []

    var didUpdateRules: (([AdFilterRule]) -> Void)?

    init(context: AccountContext, peerId: EnginePeer.Id?, peerTitle: String, isGlobalMode: Bool, navigationController: UINavigationController?) {
        self.context = context
        self.peerId = peerId
        self.peerTitle = peerTitle
        self.isGlobalMode = isGlobalMode
        self.navigationController = navigationController

        self.scrollView = UIScrollView()
        self.containerNode = ASDisplayNode()
        self.titleNode = ASTextNode()
        self.descriptionNode = ASTextNode()
        self.inputBackgroundNode = ASDisplayNode()
        self.inputTextField = UITextField()
        self.addButton = UIButton(type: .system)
        self.rulesContainerNode = ASDisplayNode()
        self.exportButton = UIButton(type: .system)
        self.importButton = UIButton(type: .system)
        self.globalInfoNode = ASTextNode()

        super.init()

        self.backgroundColor = context.sharedContext.currentPresentationData.with { $0 }.theme.list.plainBackgroundColor

        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.descriptionNode)
        self.containerNode.addSubnode(self.inputBackgroundNode)
        self.containerNode.addSubnode(self.globalInfoNode)
        self.containerNode.addSubnode(self.rulesContainerNode)

        self.setupUI()
        self.loadRules()
    }

    override func didLoad() {
        super.didLoad()

        self.view.addSubview(self.scrollView)
        self.scrollView.addSubview(self.containerNode.view)
    }

    private func setupUI() {
        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme

        if self.isGlobalMode {
            self.titleNode.attributedText = NSAttributedString(
                string: "Global Ad Filter Rules",
                font: Font.semibold(20),
                textColor: theme.list.itemPrimaryTextColor
            )

            self.descriptionNode.attributedText = NSAttributedString(
                string: "Rules added here apply to all channels and groups. You can also add per-channel rules from the channel info page.",
                font: Font.regular(14),
                textColor: theme.list.itemSecondaryTextColor
            )

            let allSettings = AdFilterStore.shared.currentSettings()
            let totalRules = allSettings.configs.reduce(0) { $0 + $1.rules.count }
            let totalChannels = allSettings.configs.count
            self.globalInfoNode.attributedText = NSAttributedString(
                string: "Total: \(totalRules) rules across \(totalChannels) channels/groups",
                font: Font.regular(13),
                textColor: theme.list.itemAccentColor
            )
        } else {
            self.titleNode.attributedText = NSAttributedString(
                string: "Ad Filter Rules",
                font: Font.semibold(20),
                textColor: theme.list.itemPrimaryTextColor
            )

            self.descriptionNode.attributedText = NSAttributedString(
                string: "Enter a regular expression. Messages matching the pattern in \(self.peerTitle) will be collapsed.",
                font: Font.regular(14),
                textColor: theme.list.itemSecondaryTextColor
            )

            self.globalInfoNode.attributedText = NSAttributedString(string: "", font: Font.regular(1), textColor: .clear)
        }

        self.inputBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.inputBackgroundNode.cornerRadius = 10

        self.inputTextField.font = Font.regular(16)
        self.inputTextField.textColor = theme.list.itemPrimaryTextColor
        self.inputTextField.backgroundColor = .clear
        self.inputTextField.autocorrectionType = .no
        self.inputTextField.autocapitalizationType = .none
        self.inputTextField.placeholder = "Enter regex pattern..."
        self.inputTextField.keyboardType = .asciiCapable
        self.inputTextField.returnKeyType = .done

        self.addButton.setTitle("Add Rule", for: .normal)
        self.addButton.titleLabel?.font = Font.semibold(16)
        self.addButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.addButton.addTarget(self, action: #selector(self.addRuleTapped), for: .touchUpInside)

        self.exportButton.setTitle("Export All Rules (JSON)", for: .normal)
        self.exportButton.titleLabel?.font = Font.regular(15)
        self.exportButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.exportButton.addTarget(self, action: #selector(self.exportTapped), for: .touchUpInside)

        self.importButton.setTitle("Import Rules (JSON)", for: .normal)
        self.importButton.titleLabel?.font = Font.regular(15)
        self.importButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.importButton.addTarget(self, action: #selector(self.importTapped), for: .touchUpInside)

        self.containerNode.view.addSubview(self.inputTextField)
        self.containerNode.view.addSubview(self.addButton)
        self.containerNode.view.addSubview(self.exportButton)
        self.containerNode.view.addSubview(self.importButton)
    }

    private func loadRules() {
        if self.isGlobalMode {
            // Show all rules from all peers
            let allSettings = AdFilterStore.shared.currentSettings()
            self.rules = allSettings.configs.flatMap { $0.rules }
        } else if let peerId = self.peerId {
            self.rules = AdFilterStore.shared.getRulesForPeer(peerId.toInt64())
        } else {
            self.rules = []
        }
        self.rebuildRuleNodes()
    }

    private func rebuildRuleNodes() {
        for node in self.ruleNodes {
            node.removeFromSupernode()
        }
        self.ruleNodes.removeAll()

        let theme = self.context.sharedContext.currentPresentationData.with { $0 }.theme

        for rule in self.rules {
            let node = AdFilterRuleNode(
                rule: rule,
                theme: theme,
                showPeerLabel: self.isGlobalMode,
                peerId: self.peerId?.toInt64(),
                onToggle: { [weak self] in
                    if let peerId = self?.peerId {
                        AdFilterStore.shared.toggleRule(id: rule.id, forPeer: peerId.toInt64())
                    }
                    self?.loadRules()
                    self?.didSetRules?(self?.rules ?? [])
                },
                onDelete: { [weak self] in
                    if let peerId = self?.peerId {
                        AdFilterStore.shared.removeRule(id: rule.id, forPeer: peerId.toInt64())
                    }
                    self?.loadRules()
                    self?.didSetRules?(self?.rules ?? [])
                }
            )
            self.rulesContainerNode.addSubnode(node)
            self.ruleNodes.append(node)
        }

        self.setNeedsLayout()
    }

    override func layout() {
        super.layout()

        let size = self.bounds.size
        let insets = self.view.safeAreaInsets

        self.scrollView.frame = CGRect(origin: .zero, size: size)

        let padding: CGFloat = 16
        var y: CGFloat = insets.top + padding

        self.titleNode.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: 28)
        y += 36

        let descHeight = self.descriptionNode.measure(CGSize(width: size.width - padding * 2, height: .greatestFiniteMagnitude)).height
        self.descriptionNode.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: descHeight)
        y += descHeight + 8

        let infoHeight = self.globalInfoNode.measure(CGSize(width: size.width - padding * 2, height: .greatestFiniteMagnitude)).height
        if infoHeight > 1 {
            self.globalInfoNode.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: infoHeight)
            y += infoHeight + 16
        }

        let inputHeight: CGFloat = 44
        self.inputBackgroundNode.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: inputHeight)
        self.inputTextField.frame = self.inputBackgroundNode.frame.insetBy(dx: 12, dy: 4)
        y += inputHeight + 8

        self.addButton.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: 44)
        y += 52

        for node in self.ruleNodes {
            let nodeHeight: CGFloat = 60
            node.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: nodeHeight)
            y += nodeHeight + 8
        }

        y += 16
        self.exportButton.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: 44)
        y += 44 + 8

        self.importButton.frame = CGRect(x: padding, y: y, width: size.width - padding * 2, height: 44)
        y += 44 + insets.bottom

        self.containerNode.frame = CGRect(x: 0, y: 0, width: size.width, height: y)
        self.scrollView.contentSize = CGSize(width: size.width, height: y)
    }

    @objc private func addRuleTapped() {
        guard let text = self.inputTextField.text, !text.isEmpty else { return }

        guard (try? NSRegularExpression(pattern: text, options: [])) != nil else {
            let alert = UIAlertController(title: "Invalid Pattern", message: "The regular expression is not valid.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.weakViewController?.present(alert, animated: true)
            return
        }

        let rule = AdFilterRule(pattern: text, isEnabled: true)
        if let peerId = self.peerId {
            AdFilterStore.shared.addRule(rule, forPeer: peerId.toInt64())
        }
        self.inputTextField.text = ""
        self.loadRules()
        self.didSetRules?(self.rules)
    }

    @objc private func exportTapped() {
        guard let data = AdFilterStore.shared.exportAllSettings() else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("naisigram_ad_filter.json")
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        self.weakViewController?.present(activityVC, animated: true)
    }

    @objc private func importTapped() {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import)
        }
        picker.delegate = self
        self.weakViewController?.present(picker, animated: true)
    }

    fileprivate func handleImport(data: Data) {
        if AdFilterStore.shared.importSettings(from: data) {
            self.loadRules()
            self.didSetRules?(self.rules)

            let alert = UIAlertController(title: "Import Successful", message: "Rules have been imported.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.weakViewController?.present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Import Failed", message: "The file format is invalid.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.weakViewController?.present(alert, animated: true)
        }
    }
}

extension AdFilterSettingsControllerNode: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
        self.handleImport(data: data)
    }
}

private final class AdFilterRuleNode: ASDisplayNode {
    private let rule: AdFilterRule
    private let onToggle: () -> Void
    private let onDelete: () -> Void

    private let backgroundNode: ASDisplayNode
    private let patternNode: ASTextNode
    private let toggleSwitch: UISwitch
    private let deleteButton: UIButton

    init(rule: AdFilterRule, theme: PresentationTheme, showPeerLabel: Bool = false, peerId: Int64? = nil, onToggle: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.onToggle = onToggle
        self.onDelete = onDelete

        self.backgroundNode = ASDisplayNode()
        self.patternNode = ASTextNode()
        self.toggleSwitch = UISwitch()
        self.deleteButton = UIButton(type: .system)

        super.init()

        self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.backgroundNode.cornerRadius = 8
        self.addSubnode(self.backgroundNode)

        self.patternNode.attributedText = NSAttributedString(
            string: rule.pattern,
            font: Font.regular(15),
            textColor: rule.isEnabled ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor
        )
        self.patternNode.maximumNumberOfLines = 1
        self.patternNode.truncationMode = .byTruncatingTail
        self.addSubnode(self.patternNode)

        self.toggleSwitch.isOn = rule.isEnabled
        self.toggleSwitch.addTarget(self, action: #selector(self.toggleTapped), for: .valueChanged)
        self.view.addSubview(self.toggleSwitch)

        self.deleteButton.setTitle("Delete", for: .normal)
        self.deleteButton.titleLabel?.font = Font.regular(14)
        self.deleteButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.deleteButton.addTarget(self, action: #selector(self.deleteTapped), for: .touchUpInside)
        self.view.addSubview(self.deleteButton)
    }

    override func layout() {
        super.layout()

        let size = self.bounds.size
        self.backgroundNode.frame = CGRect(origin: .zero, size: size)

        let padding: CGFloat = 12
        self.toggleSwitch.frame = CGRect(x: size.width - 51 - padding, y: (size.height - 31) / 2, width: 51, height: 31)

        self.deleteButton.frame = CGRect(x: size.width - 51 - padding - 60, y: 0, width: 60, height: size.height)

        let patternWidth = size.width - 51 - padding - 60 - padding - padding
        self.patternNode.frame = CGRect(x: padding, y: (size.height - 20) / 2, width: max(0, patternWidth), height: 20)
    }

    @objc private func toggleTapped() {
        self.onToggle()
    }

    @objc private func deleteTapped() {
        self.onDelete()
    }
}

import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageItemCommon

private let titleFont = UIFont.systemFont(ofSize: 13.0, weight: .medium)

public class ChatAdFoldedItem: ListViewItem {
    public let count: Int
    public let index: MessageIndex
    public let presentationData: ChatPresentationData
    public let controllerInteraction: ChatControllerInteraction
    public let isExpanded: Bool
    public let toggleExpand: (() -> Void)?

    public init(count: Int, index: MessageIndex, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction, isExpanded: Bool, toggleExpand: (() -> Void)? = nil) {
        self.count = count
        self.index = index
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.isExpanded = isExpanded
        self.toggleExpand = toggleExpand
    }

    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatAdFoldedItemNode()

            let (layout, apply) = node.asyncLayout()(self, params)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { context in
                        apply(context)
                    })
                })
            }
        }
    }

    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatAdFoldedItemNode {
                let nodeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { context in
                            apply(context)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

public class ChatAdFoldedItemNode: ListViewItemNode {
    public var item: ChatAdFoldedItem?
    private let backgroundNode: ASDisplayNode
    private let labelNode: ASTextNode
    private let chevronNode: ASImageNode
    private let tapButton: UIButton

    public init() {
        self.backgroundNode = ASDisplayNode()
        self.labelNode = ASTextNode()
        self.chevronNode = ASImageNode()
        self.tapButton = UIButton()

        super.init(layerBacked: true)

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.chevronNode)

        self.tapButton.addTarget(self, action: #selector(self.handleTap), for: .touchUpInside)
        self.view.addSubview(self.tapButton)
    }

    func asyncLayout() -> (_ item: ChatAdFoldedItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemApply) -> Void) {
        return { [weak self] item, params in
            let contentWidth = params.width - params.leftInset - params.rightInset

            let chevronImage = PresentationResourcesItemList.downArrowImage(item.presentationData.theme.theme)
            let chevronSize = chevronImage?.size ?? CGSize(width: 12, height: 7)

            let text: String
            if item.isExpanded {
                text = "Collapse \(item.count) ad messages"
            } else {
                text = "-------- \(item.count) ad messages folded --------"
            }
            let attributedText = NSAttributedString(
                string: text,
                font: titleFont,
                textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor
            )

            let labelSize = attributedText.boundingRect(
                with: CGSize(width: contentWidth - 32 - chevronSize.width - 8, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            )

            let height: CGFloat = 40
            let contentSize = CGSize(width: params.width, height: height)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))

            return (layout, { [weak self] animation in
                guard let strongSelf = self else { return }

                strongSelf.item = item

                strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                strongSelf.backgroundNode.cornerRadius = 8

                strongSelf.labelNode.attributedText = attributedText

                let labelFrame = CGRect(
                    x: params.leftInset + 16,
                    y: (height - labelSize.height) / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                strongSelf.labelNode.frame = labelFrame

                strongSelf.chevronNode.image = chevronImage
                let chevronX = params.leftInset + 16 + labelSize.width + 8
                strongSelf.chevronNode.frame = CGRect(
                    x: chevronX,
                    y: (height - chevronSize.height) / 2,
                    width: chevronSize.width,
                    height: chevronSize.height
                )
                if item.isExpanded {
                    strongSelf.chevronNode.transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
                } else {
                    strongSelf.chevronNode.transform = CATransform3DIdentity
                }

                strongSelf.backgroundNode.frame = CGRect(
                    x: params.leftInset + 8,
                    y: 0,
                    width: contentWidth - 16,
                    height: height
                )

                strongSelf.tapButton.frame = CGRect(
                    x: params.leftInset,
                    y: 0,
                    width: contentWidth,
                    height: height
                )
            })
        }
    }

    @objc func handleTap() {
        guard let item = self.item else { return }
        item.toggleExpand?()
    }
}

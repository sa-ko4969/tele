import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

struct UserInfoEditingPhoneItemEditing {
    let editable: Bool
    let hasActiveRevealControls: Bool
}

class UserInfoEditingPhoneItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let id: Int64
    let label: String
    let value: String
    let editing: UserInfoEditingPhoneItemEditing
    let sectionId: ItemListSectionId
    let setPhoneIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let updated: (String) -> Void
    let selectLabel: (() -> Void)?
    let delete: () -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, id: Int64, label: String, value: String, editing: UserInfoEditingPhoneItemEditing, sectionId: ItemListSectionId, setPhoneIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, updated: @escaping (String) -> Void, selectLabel: (() -> Void)?, delete: @escaping () -> Void, tag: ItemListItemTag?) {
        self.theme = theme
        self.strings = strings
        self.id = id
        self.label = label
        self.value = value
        self.editing = editing
        self.sectionId = sectionId
        self.setPhoneIdWithRevealedOptions = setPhoneIdWithRevealedOptions
        self.updated = updated
        self.selectLabel = selectLabel
        self.delete = delete
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = UserInfoEditingPhoneItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? UserInfoEditingPhoneItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = false
}

private let titleFont = Font.regular(15.0)

class UserInfoEditingPhoneItemNode: ItemListRevealOptionsItemNode, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let labelNode: TextNode
    private let labelButtonNode: HighlightTrackingButtonNode
    private let editableControlNode: ItemListEditableControlNode
    private let labelSeparatorNode: ASDisplayNode
    private let phoneNode: SinglePhoneInputNode
    
    private var item: UserInfoEditingPhoneItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.editableControlNode = ItemListEditableControlNode()
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.labelButtonNode = HighlightTrackingButtonNode()
        
        self.labelSeparatorNode = ASDisplayNode()
        self.labelSeparatorNode.isLayerBacked = true
        
        self.phoneNode = SinglePhoneInputNode(fontSize: 17.0)
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.editableControlNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.labelButtonNode)
        self.addSubnode(self.labelSeparatorNode)
        self.addSubnode(self.phoneNode)
        
        self.labelButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.labelNode.alpha = 0.4
                } else {
                    strongSelf.labelNode.alpha = 1.0
                    strongSelf.labelNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.labelButtonNode.addTarget(self, action: #selector(self.labelPressed), forControlEvents: .touchUpInside)
        
        self.editableControlNode.tapped = { [weak self] in
            if let strongSelf = self {
                strongSelf.setRevealOptionsOpened(true, animated: true)
                strongSelf.revealOptionsInteractivelyOpened()
            }
        }
        
        self.phoneNode.numberUpdated = { [weak self] number in
            self?.item?.updated(number)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let item = self.item {
            self.phoneNode.numberField?.textField.textColor = item.theme.list.itemPrimaryTextColor
            self.phoneNode.numberField?.textField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
        }
    }
    
    func asyncLayout() -> (_ item: UserInfoEditingPhoneItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let controlSizeAndApply = editableControlLayout(44.0, item.theme, false)
            
            let textColor = item.theme.list.itemAccentColor
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: titleFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            itemBackgroundColor = item.theme.list.plainBackgroundColor
            itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
            contentSize = CGSize(width: params.width, height: 44.0)
            insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let updatedTheme = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.labelSeparatorNode.backgroundColor = itemSeparatorColor
                        
                        strongSelf.phoneNode.numberField?.textField.textColor = updatedTheme.list.itemPrimaryTextColor
                        strongSelf.phoneNode.numberField?.textField.keyboardAppearance = updatedTheme.chatList.searchBarKeyboardColor.keyboardAppearance
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let _ = labelApply()
                    
                    let leftInset: CGFloat
                    
                    leftInset = 16.0 + params.leftInset
                    
                    if strongSelf.backgroundNode.supernode != nil {
                        strongSelf.backgroundNode.removeFromSupernode()
                    }
                    if strongSelf.topStripeNode.supernode != nil {
                        strongSelf.topStripeNode.removeFromSupernode()
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                    }
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    let _ = controlSizeAndApply.1()
                    let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + 4.0 + revealOffset, y: 0.0), size: controlSizeAndApply.0)
                    strongSelf.editableControlNode.frame = editableControlFrame
                    
                    let labelFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset + 30.0, y: 12.0), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    strongSelf.labelButtonNode.frame = labelFrame
                    strongSelf.labelButtonNode.isUserInteractionEnabled = item.selectLabel != nil
                    strongSelf.labelSeparatorNode.frame = CGRect(origin: CGPoint(x: labelFrame.maxX + 8.0, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.contentSize.height))
                    
                    let phoneX = labelFrame.maxX + 16.0
                    let phoneFrame = CGRect(origin: CGPoint(x: phoneX, y: 0.0), size: CGSize(width: max(1.0, params.width - params.rightInset - phoneX), height: layout.contentSize.height))
                    strongSelf.phoneNode.frame = phoneFrame
                    strongSelf.phoneNode.updateLayout(size: phoneFrame.size)
                    strongSelf.phoneNode.number = item.value
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                }
            })
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams else {
            return
        }
        
        let revealOffset = offset
        let leftInset = 16.0 + params.leftInset
        
        var controlFrame = self.editableControlNode.frame
        controlFrame.origin.x = params.leftInset + 4.0 + revealOffset
        transition.updateFrame(node: self.editableControlNode, frame: controlFrame)
        
        var labelFrame = self.labelNode.frame
        labelFrame.origin.x = revealOffset + leftInset + 30.0
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        var labelSeparatorFrame = self.labelSeparatorNode.frame
        labelSeparatorFrame.origin.x = labelFrame.maxX + 8.0
        transition.updateFrame(node: self.labelSeparatorNode, frame: labelSeparatorFrame)
        
        var phoneFrame = self.phoneNode.frame
        phoneFrame.origin.x = labelFrame.maxX + 16.0
        transition.updateFrame(node: self.phoneNode, frame: phoneFrame)
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.item?.delete()
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc func labelPressed() {
        self.item?.selectLabel?()
    }
    
    func focus() {
        self.phoneNode.numberField?.becomeFirstResponder()
    }
}

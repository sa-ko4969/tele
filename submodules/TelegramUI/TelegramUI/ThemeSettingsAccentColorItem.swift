import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.fillEllipse(in: bounds)
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat
        if selected {
            var accentColor = theme.list.itemAccentColor
            if accentColor.rgb == UIColor.white.rgb {
                accentColor = UIColor(rgb: 0x999999)
            }
            context.setStrokeColor(accentColor.cgColor)
            lineWidth = 2.0
        } else {
            context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
            lineWidth = 1.0
        }
        
        if bordered || selected {
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
        }
    })?.stretchableImage(withLeftCapWidth: 15, topCapHeight: 15)
}

class ThemeSettingsAccentColorItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let colors: [UIColor]
    let currentColor: UIColor
    let updated: (UIColor) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, colors: [UIColor], currentColor: UIColor, updated: @escaping (UIColor) -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.strings = strings
        self.colors = colors
        self.currentColor = currentColor
        self.updated = updated
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAccentColorItemNode()
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
            if let nodeValue = node() as? ThemeSettingsAccentColorItemNode {
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
}

private final class ThemeSettingsAccentColorNode : ASDisplayNode {
    private let iconNode: ASImageNode
    private let overlayNode: ASImageNode
    private let textNode: ASTextNode
    private var action: (() -> Void)?
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.iconNode.isLayerBacked = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.overlayNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.overlayNode)
        self.addSubnode(self.textNode)
    }
    
    func setup(theme: PresentationTheme, icon: UIImage, title: NSAttributedString, bordered: Bool, selected: Bool, action: @escaping () -> Void) {
        self.iconNode.image = icon
        self.textNode.attributedText = title
        self.overlayNode.image = generateBorderImage(theme: theme, bordered: bordered, selected: selected)
        self.action = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action?()
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.iconNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: CGSize(width: 62.0, height: 62.0))
        self.overlayNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: CGSize(width: 62.0, height: 62.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 14.0 + 60.0 + 4.0 + 9.0), size: CGSize(width: bounds.size.width, height: 16.0))
    }
}


private let textFont = Font.regular(11.0)
private let itemSize = Font.regular(11.0)

class ThemeSettingsAccentColorItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    private var nodes: [ThemeSettingsAccentColorNode] = []
    
    private var item: ThemeSettingsAccentColorItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.scrollNode = ASScrollNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsAccentColorItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
                
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: params.width, height: 116.0)
            insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.scrollNode.view.contentInset = UIEdgeInsetsMake(0.0, params.leftInset, 0.0, params.rightInset)
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                    case .sameSection(false):
                        strongSelf.topStripeNode.isHidden = true
                    default:
                        strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = params.leftInset + 16.0
                        bottomStripeOffset = -separatorHeight
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: layoutSize.width, height: layoutSize.height))
                    
                    let nodeInset: CGFloat = 4.0
                    let nodeSize = CGSize(width: 80.0, height: 112.0)
                    var nodeOffset = nodeInset
                    
                    var i = 0
                    for icon in item.colors {
                        let imageNode: ThemeSettingsAccentColorNode
                        if strongSelf.nodes.count > i {
                            imageNode = strongSelf.nodes[i]
                        } else {
                            imageNode = ThemeSettingsAccentColorNode()
                            strongSelf.nodes.append(imageNode)
                            strongSelf.scrollNode.addSubnode(imageNode)
                        }
                        
//                        if let image = UIImage(named: icon.imageName, in: Bundle.main, compatibleWith: nil) {
//                            let selected = icon.name == item.currentIconName
//                            
//                            var name = "Icon"
//                            var bordered = true
//                            switch icon.name {
//                            case "Blue":
//                                name = item.strings.Appearance_AppIconDefault
//                            case "Black":
//                                name = item.strings.Appearance_AppIconDefaultX
//                            case "BlueClassic":
//                                name = item.strings.Appearance_AppIconClassic
//                            case "BlackClassic":
//                                name = item.strings.Appearance_AppIconClassicX
//                            case "BlueFilled":
//                                name = item.strings.Appearance_AppIconFilled
//                                bordered = false
//                            case "BlackFilled":
//                                name = item.strings.Appearance_AppIconFilledX
//                                bordered = false
//                            case "WhiteFilled":
//                                name = "⍺ White"
//                            default:
//                                break
//                            }
//                            
//                            imageNode.setup(theme: item.theme, icon: image, title: NSAttributedString(string: name, font: textFont, textColor: selected  ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center), bordered: bordered, selected: selected, action: {
//                                item.updated(icon.name)
//                            })
//                        }
                        
                        imageNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 0.0), size: nodeSize)
                        nodeOffset += nodeSize.width + 15.0
                        
                        i += 1
                    }
                    
                    if let lastNode = strongSelf.nodes.last {
                        let contentSize = CGSize(width: lastNode.frame.maxX + nodeInset, height: strongSelf.scrollNode.frame.height)
                        if strongSelf.scrollNode.view.contentSize != contentSize {
                            strongSelf.scrollNode.view.contentSize = contentSize
                        }
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}


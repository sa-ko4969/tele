import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class ItemListEditableControlNode: ASDisplayNode {
    var tapped: (() -> Void)?
    private let iconNode: ASImageNode
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    static func asyncLayout(_ node: ItemListEditableControlNode?) -> (_ height: CGFloat, _ theme: PresentationTheme, _ hidden: Bool) -> (CGSize, () -> ItemListEditableControlNode) {
        return { height, theme, hidden in
            let image = PresentationResourcesItemList.itemListDeleteIndicatorIcon(theme)
            
            let resultNode: ItemListEditableControlNode
            if let node = node {
                resultNode = node
            } else {
                resultNode = ItemListEditableControlNode()
            }
            resultNode.iconNode.image = image
            
            return (CGSize(width: 38.0, height: height), {
                if let image = image {
                    resultNode.iconNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((height - image.size.height) / 2.0)), size: image.size)
                    resultNode.iconNode.isHidden = hidden
                }
                return resultNode
            })
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
}

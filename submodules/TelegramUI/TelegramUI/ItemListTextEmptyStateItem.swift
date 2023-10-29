import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class ItemListTextEmptyStateItem: ItemListControllerEmptyStateItem {
    let text: String
    
    init(text: String) {
        self.text = text
    }
    
    func isEqual(to: ItemListControllerEmptyStateItem) -> Bool {
        if let to = to as? ItemListTextEmptyStateItem {
            return self.text == to.text
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerEmptyStateItemNode?) -> ItemListControllerEmptyStateItemNode {
        let result: ItemListTextEmptyStateItemNode
        if let current = current as? ItemListTextEmptyStateItemNode {
            result = current
        } else {
            result = ItemListTextEmptyStateItemNode()
        }
        result.updateText(text: self.text)
        return result
    }
}

final class ItemListTextEmptyStateItemNode: ItemListControllerEmptyStateItemNode {
    private let textNode: ASTextNode
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var text: String?
    
    override init() {
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func updateText(text: String) {
        if self.text != text {
            self.text = text
            
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .gray, paragraphAlignment: .center)
            if let validLayout = self.validLayout {
                self.updateLayout(layout: validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
            }
        }
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - 40.0 - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - insets.top - insets.bottom)))
        self.textNode.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - textSize.width) / 2.0), y: insets.top + floor((layout.size.height - insets.top - insets.bottom - textSize.height) / 2.0)), size: textSize)
    }
}

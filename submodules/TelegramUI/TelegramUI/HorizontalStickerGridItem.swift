import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class HorizontalStickerGridItem: GridItem {
    let account: Account
    let file: TelegramMediaFile
    let stickersInteraction: HorizontalStickersChatContextPanelInteraction
    let interfaceInteraction: ChatPanelInterfaceInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, file: TelegramMediaFile, stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) {
        self.account = account
        self.file = file
        self.stickersInteraction = stickersInteraction
        self.interfaceInteraction = interfaceInteraction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = HorizontalStickerGridItemNode()
        node.setup(account: self.account, item: self)
        node.interfaceInteraction = self.interfaceInteraction
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? HorizontalStickerGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, item: self)
        node.interfaceInteraction = self.interfaceInteraction
    }
}

final class HorizontalStickerGridItemNode: GridItemNode {
    private var currentState: (Account, HorizontalStickerGridItem, CGSize)?
    private let imageNode: TransformImageNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private var currentIsPreviewing: Bool = false
    
    var stickerItem: StickerPackItem? {
        if let (_, item, _) = self.currentState {
            return StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: 0), file: item.file, indexKeys: [])
        } else {
            return nil
        }
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, item: HorizontalStickerGridItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1.file.id != item.file.id {
            if let dimensions = item.file.dimensions {
                self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: true))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: chatMessageStickerResource(file: item.file, small: true)).start())
                
                self.currentState = (account, item, dimensions)
                self.setNeedsLayout()
            }
        }
        
        self.updatePreviewing(animated: false)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundingSize = bounds.insetBy(dx: 2.0, dy: 2.0).size
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interfaceInteraction.sendSticker(.standalone(media: item.file))
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState {
            isPreviewing = item.stickersInteraction.previewedStickerItem == self.stickerItem
        }
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                self.layer.sublayerTransform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            } else {
                self.layer.sublayerTransform = CATransform3DIdentity
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5)
                }
            }
        }
    }
}

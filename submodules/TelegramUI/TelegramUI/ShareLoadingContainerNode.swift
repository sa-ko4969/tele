import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramPresentationData

enum ShareLoadingState {
    case preparing
    case progress(Float)
    case done
}

final class ShareLoadingContainerNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let theme: PresentationTheme
    private let activityIndicator: ActivityIndicator
    private let statusNode: RadialStatusNode
    private let doneStatusNode: RadialStatusNode
    
    var state: ShareLoadingState = .preparing {
        didSet {
            switch self.state {
                case .preparing:
                    self.activityIndicator.isHidden = false
                    self.statusNode.isHidden = true
                case let .progress(value):
                    self.activityIndicator.isHidden = true
                    self.statusNode.isHidden = false
                    self.statusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: max(0.12, CGFloat(value)), cancelEnabled: false), completion: {})
                case .done:
                    self.activityIndicator.isHidden = true
                    self.statusNode.isHidden = false
                    self.statusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: 1.0, cancelEnabled: false), completion: {})
                    self.doneStatusNode.transitionToState(.check(self.theme.actionSheet.controlAccentColor), completion: {})
            }
        }
    }
    
    init(theme: PresentationTheme, forceNativeAppearance: Bool) {
        self.theme = theme
        self.activityIndicator = ActivityIndicator(type: .custom(theme.actionSheet.controlAccentColor, !forceNativeAppearance ? 22.0 : 50.0, 2.0, forceNativeAppearance))
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.doneStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.doneStatusNode)
        self.doneStatusNode.transitionToState(.progress(color: self.theme.actionSheet.controlAccentColor, lineWidth: 2.0, value: 0.0, cancelEnabled: false), completion: {})
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = 125.0
        
        let indicatorSize = self.activityIndicator.calculateSizeThatFits(size)
        let indicatorFrame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: size.height - nodeHeight + floor((nodeHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        transition.updateFrame(node: self.activityIndicator, frame: indicatorFrame)
        let statusFrame = indicatorFrame
        transition.updateFrame(node: self.statusNode, frame: statusFrame)
        transition.updateFrame(node: self.doneStatusNode, frame: statusFrame)
        
        self.contentOffsetUpdated?(-size.height + 64.0, transition)
    }
    
    func updateSelectedPeers() {
    }
}

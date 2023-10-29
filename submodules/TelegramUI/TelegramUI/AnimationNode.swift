import Foundation
import UIKit
import AsyncDisplayKit
import Lottie

final class AnimationNode : ASDisplayNode {
    private let scale: CGFloat
    var speed: CGFloat = 1.0 {
        didSet {
            if let animationView = animationView() {
                animationView.animationSpeed = speed
            }
        }
    }
    
    private var colorCallbacks: [LOTColorValueCallback] = []
    
    var played = false
    var completion: (() -> Void)?
    
    init(animation: String? = nil, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let animation = animation, let url = frameworkBundle.url(forResource: animation, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                let view = LOTAnimationView(model: composition, in: frameworkBundle)
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                
                view.logHierarchyKeypaths()
                
                if let colors = colors {
                    for (key, value) in colors {
                        let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return LOTAnimationView()
            }
        })
    }
    
    func setAnimation(name: String) {
        if let url = frameworkBundle.url(forResource: name, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
            self.animationView()?.sceneModel = composition
        }
    }
    
    func setAnimation(json: [AnyHashable: Any]) {
        self.animationView()?.setAnimation(json: json)
    }
    
    func animationView() -> LOTAnimationView? {
        return self.view as? LOTAnimationView
    }
    
    func play() {
        if let animationView = animationView(), !animationView.isAnimationPlaying, !self.played {
            self.played = true
            animationView.play { [weak self] _ in
                self?.completion?()
            }
        }
    }
    
    func loop() {
        if let animationView = animationView() {
            animationView.loopAnimation = true
            animationView.play()
        }
    }
    
    func reset() {
        if self.played, let animationView = animationView() {
            self.played = false
            animationView.stop()
        }
    }
    
    func preferredSize() -> CGSize? {
        if let animationView = animationView(), let sceneModel = animationView.sceneModel {
            return CGSize(width: sceneModel.compBounds.width * self.scale, height: sceneModel.compBounds.height * self.scale)
        } else {
            return nil
        }
    }
}

import UIKit

public func dumpViews(_ view: UIView) {
    dumpViews(view, indent: "")
}

private func dumpViews(_ view: UIView, indent: String = "") {
    print("\(indent)\(view)")
    let nextIndent = indent + "-"
    for subview in view.subviews {
        dumpViews(subview as UIView, indent: nextIndent)
    }
}

public func dumpLayers(_ layer: CALayer) {
    dumpLayers(layer, indent: "")
}

private func dumpLayers(_ layer: CALayer, indent: String = "") {
    print("\(indent)\(layer)(frame: \(layer.frame), bounds: \(layer.bounds))")
    if layer.sublayers != nil {
        let nextIndent = indent + ".."
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                dumpLayers(sublayer as CALayer, indent: nextIndent)
            }
        }
    }
}

public let UIScreenScale = UIScreen.main.scale
public func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}
public func ceilToScreenPixels(_ value: CGFloat) -> CGFloat {
    return ceil(value * UIScreenScale) / UIScreenScale
}

public let UIScreenPixel = 1.0 / UIScreenScale

public extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
    }
    
    convenience init(argb: UInt32) {
        self.init(red: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
    }
    
    convenience init?(hexString: String) {
        let scanner = Scanner(string: hexString)
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var num: UInt32 = 0
        if scanner.scanHexInt32(&num) {
            self.init(rgb: num)
        } else {
            return nil
        }
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0.0
        if self.getRed(nil, green: nil, blue: nil, alpha: &alpha) {
            return alpha
        } else if self.getWhite(nil, alpha: &alpha) {
            return alpha
        } else {
            return 0.0
        }
    }
    
    var rgb: UInt32 {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        self.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        return (UInt32(red * 255.0) << 16) | (UInt32(green * 255.0) << 8) | (UInt32(blue * 255.0))
    }
    
    var argb: UInt32 {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (UInt32(alpha * 255.0) << 24) | (UInt32(red * 255.0) << 16) | (UInt32(green * 255.0) << 8) | (UInt32(blue * 255.0))
    }
    
    var hsv: (CGFloat, CGFloat, CGFloat) {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var value: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &value, alpha: nil) {
            return (hue, saturation, value)
        } else {
            return (0.0, 0.0, 0.0)
        }
    }
    
    func withMultipliedBrightnessBy(_ factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return UIColor(hue: hue, saturation: saturation, brightness: max(0.0, min(1.0, brightness * factor)), alpha: alpha)
    }
    
    func mixedWith(_ other: UIColor, alpha: CGFloat) -> UIColor {
        let alpha = min(1.0, max(0.0, alpha))
        let oneMinusAlpha = 1.0 - alpha
        
        var r1: CGFloat = 0.0
        var r2: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var g2: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var b2: CGFloat = 0.0
        var a1: CGFloat = 0.0
        var a2: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) &&
            other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        {
            let r = r1 * oneMinusAlpha + r2 * alpha
            let g = g1 * oneMinusAlpha + g2 * alpha
            let b = b1 * oneMinusAlpha + b2 * alpha
            let a = a1 * oneMinusAlpha + a2 * alpha
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return self
    }
}

public extension CGSize {
    public func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
    
    public func cropped(_ size: CGSize) -> CGSize {
        return CGSize(width: min(size.width, self.width), height: min(size.height, self.height))
    }
    
    public func fittedToArea(_ area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: floor(width), height: floor(height))
    }
    
    public func aspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFitted(_ size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFittedOrSmaller(_ size: CGSize) -> CGSize {
        let scale = min(1.0, min(size.width / max(1.0, self.width), size.height / max(1.0, self.height)))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFittedWithOverflow(_ size: CGSize, leeway: CGFloat) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        var result = CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
        if result.width < size.width && result.width > size.width - leeway {
            result.height += size.width - result.width
            result.width = size.width
        }
        if result.height < size.height && result.height > size.height - leeway {
            result.width += size.height - result.height
            result.height = size.height
        }
        return result
    }
    
    public func fittedToWidthOrSmaller(_ width: CGFloat) -> CGSize {
        let scale = min(1.0, width / max(1.0, self.width))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func multipliedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
    
    public func dividedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width / scale, height: self.height / scale)
    }
    
    public var integralFloor: CGSize {
        return CGSize(width: floor(self.width), height: floor(self.height))
    }
}

public func assertNotOnMainThread(_ file: String = #file, line: Int = #line) {
    assert(!Thread.isMainThread, "\(file):\(line) running on main thread")
}

public extension UIImage {
    public func precomposed() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: CGPoint())
        let result = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        if !UIEdgeInsetsEqualToEdgeInsets(self.capInsets, UIEdgeInsets()) {
            return result.resizableImage(withCapInsets: self.capInsets, resizingMode: self.resizingMode)
        }
        return result
    }
}

private func makeSubtreeSnapshot(layer: CALayer, keepTransform: Bool = false) -> UIView? {
    let view = UIView()
    view.layer.isHidden = layer.isHidden
    view.layer.opacity = layer.opacity
    view.layer.contents = layer.contents
    view.layer.contentsRect = layer.contentsRect
    view.layer.contentsScale = layer.contentsScale
    view.layer.contentsCenter = layer.contentsCenter
    view.layer.contentsGravity = layer.contentsGravity
    view.layer.masksToBounds = layer.masksToBounds
    if let mask = layer.mask {
        let maskLayer = CALayer()
        maskLayer.contents = mask.contents
        maskLayer.contentsRect = mask.contentsRect
        maskLayer.contentsScale = mask.contentsScale
        maskLayer.contentsCenter = mask.contentsCenter
        maskLayer.contentsGravity = mask.contentsGravity
        view.layer.mask = maskLayer
    }
    view.layer.cornerRadius = layer.cornerRadius
    view.layer.backgroundColor = layer.backgroundColor
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeSubtreeSnapshot(layer: sublayer, keepTransform: keepTransform)
            if let subtree = subtree {
                if keepTransform {
                    subtree.layer.transform = sublayer.transform
                }
                subtree.frame = sublayer.frame
                subtree.bounds = sublayer.bounds
                if let maskLayer = subtree.layer.mask {
                    maskLayer.frame = sublayer.bounds
                }
                view.addSubview(subtree)
            } else {
                return nil
            }
        }
    }
    return view
}

private func makeLayerSubtreeSnapshot(layer: CALayer) -> CALayer? {
    let view = CALayer()
    view.isHidden = layer.isHidden
    view.opacity = layer.opacity
    view.contents = layer.contents
    view.contentsRect = layer.contentsRect
    view.contentsScale = layer.contentsScale
    view.contentsCenter = layer.contentsCenter
    view.contentsGravity = layer.contentsGravity
    view.masksToBounds = layer.masksToBounds
    view.cornerRadius = layer.cornerRadius
    view.backgroundColor = layer.backgroundColor
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeLayerSubtreeSnapshot(layer: sublayer)
            if let subtree = subtree {
                subtree.frame = sublayer.frame
                subtree.bounds = sublayer.bounds
                layer.addSublayer(subtree)
            } else {
                return nil
            }
        }
    }
    return view
}

public extension UIView {
    public func snapshotContentTree(unhide: Bool = false, keepTransform: Bool = false) -> UIView? {
        let wasHidden = self.isHidden
        if unhide && wasHidden {
            self.isHidden = false
        }
        let snapshot = makeSubtreeSnapshot(layer: self.layer, keepTransform: keepTransform)
        if unhide && wasHidden {
            self.isHidden = true
        }
        if let snapshot = snapshot {
            snapshot.frame = self.frame
            return snapshot
        }
        
        return nil
    }
}

public extension CALayer {
    public func snapshotContentTree(unhide: Bool = false) -> CALayer? {
        let wasHidden = self.isHidden
        if unhide && wasHidden {
            self.isHidden = false
        }
        let snapshot = makeLayerSubtreeSnapshot(layer: self)
        if unhide && wasHidden {
            self.isHidden = true
        }
        if let snapshot = snapshot {
            snapshot.frame = self.frame
            return snapshot
        }
        
        return nil
    }
}

public extension CGRect {
    public var topLeft: CGPoint {
        return self.origin
    }
    
    public var topRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.minY)
    }
    
    public var bottomLeft: CGPoint {
        return CGPoint(x: self.minX, y: self.maxY)
    }
    
    public var bottomRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.maxY)
    }
    
    public var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

public extension CGPoint {
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}

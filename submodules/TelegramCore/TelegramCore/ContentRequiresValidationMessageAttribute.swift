import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

public class ContentRequiresValidationMessageAttribute: MessageAttribute {
    public init() {
    }
    
    required public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

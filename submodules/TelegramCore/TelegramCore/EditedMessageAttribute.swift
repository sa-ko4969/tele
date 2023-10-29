import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class EditedMessageAttribute: MessageAttribute {
    public let date: Int32
    
    init(date: Int32) {
        self.date = date
    }
    
    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

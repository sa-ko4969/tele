import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class ForwardSourceInfoAttribute: MessageAttribute {
    public let messageId: MessageId
    
    init(messageId: MessageId) {
        self.messageId = messageId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: decoder.decodeInt32ForKey("n", orElse: 0), id: decoder.decodeInt32ForKey("i", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
        encoder.encodeInt32(self.messageId.namespace, forKey: "n")
        encoder.encodeInt32(self.messageId.id, forKey: "i")
    }
}

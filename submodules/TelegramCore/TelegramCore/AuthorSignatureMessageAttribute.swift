import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class AuthorSignatureMessageAttribute: MessageAttribute {
    public let signature: String
    
    public let associatedPeerIds: [PeerId] = []
    
    init(signature: String) {
        self.signature = signature
    }
    
    required public init(decoder: PostboxDecoder) {
        self.signature = decoder.decodeStringForKey("s", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.signature, forKey: "s")
    }
}

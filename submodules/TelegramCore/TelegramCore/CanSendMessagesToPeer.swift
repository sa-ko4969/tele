import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public func canSendMessagesToPeer(_ peer: Peer) -> Bool {
    if peer is TelegramUser || peer is TelegramGroup {
        return !peer.isDeleted
    } else if let peer = peer as? TelegramSecretChat {
        return peer.embeddedState == .active
    } else if let peer = peer as? TelegramChannel {
        return peer.hasPermission(.sendMessages)
    } else {
        return false
    }
}

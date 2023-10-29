import Foundation
import Postbox
import TelegramCore

extension Message {
    func effectivelyIncoming(_ accountPeerId: PeerId) -> Bool {
        if self.id.peerId == accountPeerId {
            if self.forwardInfo != nil {
                return true
            } else {
                return false
            }
        } else if self.flags.contains(.Incoming) {
            return true
        } else if let channel = self.peers[self.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return true
        } else {
            return false
        }
    }
    
    var elligibleForLargeEmoji: Bool {
        if self.media.isEmpty && !self.text.isEmpty && self.text.containsOnlyEmoji && self.text.emojis.count < 4 {
            return true
        } else {
            return false
        }
    }
}

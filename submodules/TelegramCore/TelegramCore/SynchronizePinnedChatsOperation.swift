import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private struct PreviousPeerItemId: PostboxCoding {
    let id: PinnedItemId
    
    init(_ id: PinnedItemId) {
        self.id = id
    }
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self.id = .peer(PeerId(decoder.decodeInt64ForKey("i", orElse: 0)))
            default:
                preconditionFailure()
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self.id {
            case let .peer(peerId):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeInt64(peerId.toInt64(), forKey: "i")
        }
    }
}

final class SynchronizePinnedChatsOperation: PostboxCoding {
    let previousItemIds: [PinnedItemId]
    
    init(previousItemIds: [PinnedItemId]) {
        self.previousItemIds = previousItemIds
    }
    
    init(decoder: PostboxDecoder) {
        let wrappedIds: [PreviousPeerItemId] = decoder.decodeObjectArrayWithDecoderForKey("previousItemIds")
        self.previousItemIds = wrappedIds.map { $0.id }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.previousItemIds.map(PreviousPeerItemId.init), forKey: "previousItemIds")
    }
}

func addSynchronizePinnedChatsOperation(transaction: Transaction, groupId: PeerGroupId) {
    let rawId: Int32 = groupId.rawValue
    var previousItemIds = transaction.getPinnedItemIds(groupId: groupId)
    var updateLocalIndex: Int32?
    
    transaction.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: rawId), tag: OperationLogTags.SynchronizePinnedChats, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let contents = entry.contents as? SynchronizePinnedChatsOperation {
            previousItemIds = contents.previousItemIds
        }
        return false
    })
    let operationContents = SynchronizePinnedChatsOperation(previousItemIds: previousItemIds)
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: rawId), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: PeerId(namespace: 0, id: rawId), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}

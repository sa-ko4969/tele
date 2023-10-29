import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class CachedStickerPack: PostboxCoding {
    let info: StickerPackCollectionInfo?
    let items: [StickerPackItem]
    let hash: Int32
    
    init(info: StickerPackCollectionInfo?, items: [StickerPackItem], hash: Int32) {
        self.info = info
        self.items = items
        self.hash = hash
    }
    
    init(decoder: PostboxDecoder) {
        self.info = decoder.decodeObjectForKey("in", decoder: { StickerPackCollectionInfo(decoder: $0) }) as? StickerPackCollectionInfo
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! StickerPackItem }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let info = self.info {
            encoder.encodeObject(info, forKey: "in")
        } else {
            encoder.encodeNil(forKey: "in")
        }
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    static func cacheKey(_ id: ItemCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

public enum CachedStickerPackResult {
    case none
    case fetching
    case result(StickerPackCollectionInfo, [ItemCollectionItem], Bool)
}

func cacheStickerPack(transaction: Transaction, info: StickerPackCollectionInfo, items: [ItemCollectionItem]) {
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(info.id)), entry: CachedStickerPack(info: info, items: items.map { $0 as! StickerPackItem }, hash: info.hash), collectionSpec: collectionSpec)
}

public func cachedStickerPack(postbox: Postbox, network: Network, reference: StickerPackReference, forceRemote: Bool) -> Signal<CachedStickerPackResult, NoError> {
    return postbox.transaction { transaction -> CachedStickerPackResult? in
        if let (info, items, local) = cachedStickerPack(transaction: transaction, reference: reference) {
            if local {
                return .result(info, items, true)
            }
        }
        return nil
    } |> mapToSignal { value -> Signal<CachedStickerPackResult, NoError> in
        if let value = value {
            return .single(value)
        } else {
            return postbox.transaction { transaction -> (CachedStickerPackResult, Bool, Int32?) in
                var loadRemote = false
                let namespace = Namespaces.ItemCollection.CloudStickerPacks
                var previousHash: Int32?
                if case let .id(id, _) = reference, let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
                    previousHash = cached.hash
                    let current: CachedStickerPackResult = .result(info, cached.items, false)
                    if cached.hash != info.hash {
                        return (current, true, previousHash)
                    } else {
                        return (current, false, previousHash)
                    }
                } else {
                    return (.fetching, true, nil)
                }
            } |> mapToSignal { result, loadRemote, previousHash in
                if loadRemote || forceRemote {
                    let appliedRemote = updatedRemoteStickerPack(postbox: postbox, network: network, reference: reference)
                        |> mapToSignal { result -> Signal<CachedStickerPackResult, NoError> in
                            if let result = result, result.0.hash == previousHash {
                                return .complete()
                            }
                            return postbox.transaction { transaction -> CachedStickerPackResult in
                                if let result = result {
                                    cacheStickerPack(transaction: transaction, info: result.0, items: result.1)
                                    
                                    let currentInfo = transaction.getItemCollectionInfo(collectionId: result.0.id) as? StickerPackCollectionInfo
                                    
                                    return .result(result.0, result.1, currentInfo != nil)
                                } else {
                                    return .none
                                }
                            }
                    }
                    return .single(result) |> then(appliedRemote)
                } else {
                    return .single(result)
                }
            }
        }
    }
}
    
func cachedStickerPack(transaction: Transaction, reference: StickerPackReference) -> (StickerPackCollectionInfo, [ItemCollectionItem], Bool)? {
    let namespace = Namespaces.ItemCollection.CloudStickerPacks
    if case let .id(id, _) = reference, let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
        let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
        return (currentInfo, items, true)
    } else {
        if case let .id(id, _) = reference, let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
            return (info, cached.items, false)
        }
        return nil
    }
}

import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
    import SwiftSignalKit
#endif

public func applyMaxReadIndexInteractively(postbox: Postbox, stateManager: AccountStateManager, index: MessageIndex) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        applyMaxReadIndexInteractively(transaction: transaction, stateManager: stateManager, index: index)
    }
}
    
func applyMaxReadIndexInteractively(transaction: Transaction, stateManager: AccountStateManager, index: MessageIndex)  {
    let messageIds = transaction.applyInteractiveReadMaxIndex(index)
    if index.id.peerId.namespace == Namespaces.Peer.SecretChat {
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        for id in messageIds {
            if let message = transaction.getMessage(id) {
                for attribute in message.attributes {
                    if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                        if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && !message.containsSecretMedia {
                            transaction.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                }
                                let updatedAttributes = currentMessage.attributes.map({ currentAttribute -> MessageAttribute in
                                    if let currentAttribute = currentAttribute as? AutoremoveTimeoutMessageAttribute {
                                        return AutoremoveTimeoutMessageAttribute(timeout: currentAttribute.timeout, countdownBeginTime: timestamp)
                                    } else {
                                        return currentAttribute
                                    }
                                })
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                            })
                            transaction.addTimestampBasedMessageAttribute(tag: 0, timestamp: timestamp + attribute.timeout, messageId: id)
                        }
                        break
                    }
                }
            }
        }
    } else if index.id.peerId.namespace == Namespaces.Peer.CloudUser || index.id.peerId.namespace == Namespaces.Peer.CloudGroup || index.id.peerId.namespace == Namespaces.Peer.CloudChannel {
        stateManager.notifyAppliedIncomingReadMessages([index.id])
    }
}

func applyOutgoingReadMaxIndex(transaction: Transaction, index: MessageIndex, beginCountdownAt timestamp: Int32) {
    let messageIds = transaction.applyOutgoingReadMaxIndex(index)
    if index.id.peerId.namespace == Namespaces.Peer.SecretChat {
        for id in messageIds {
            applySecretOutgoingMessageReadActions(transaction: transaction, id: id, beginCountdownAt: timestamp)
        }
    }
}

func maybeReadSecretOutgoingMessage(transaction: Transaction, index: MessageIndex) {
    guard index.id.peerId.namespace == Namespaces.Peer.SecretChat else {
        assertionFailure()
        return
    }
    guard index.id.namespace == Namespaces.Message.Local else {
        assertionFailure()
        return
    }
    
    guard let combinedState = transaction.getCombinedPeerReadState(index.id.peerId) else {
        return
    }
    
    if combinedState.isOutgoingMessageIndexRead(index) {
        applySecretOutgoingMessageReadActions(transaction: transaction, id: index.id, beginCountdownAt: index.timestamp)
    }
}

func applySecretOutgoingMessageReadActions(transaction: Transaction, id: MessageId, beginCountdownAt timestamp: Int32) {
    guard id.peerId.namespace == Namespaces.Peer.SecretChat else {
        assertionFailure()
        return
    }
    guard id.namespace == Namespaces.Message.Local else {
        assertionFailure()
        return
    }
    
    if let message = transaction.getMessage(id), !message.flags.contains(.Incoming) {
        if message.flags.intersection([.Unsent, .Sending, .Failed]).isEmpty {
            for attribute in message.attributes {
                if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                    if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && !message.containsSecretMedia {
                        transaction.updateMessage(message.id, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                            }
                            let updatedAttributes = currentMessage.attributes.map({ currentAttribute -> MessageAttribute in
                                if let currentAttribute = currentAttribute as? AutoremoveTimeoutMessageAttribute {
                                    return AutoremoveTimeoutMessageAttribute(timeout: currentAttribute.timeout, countdownBeginTime: timestamp)
                                } else {
                                    return currentAttribute
                                }
                            })
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                        })
                        transaction.addTimestampBasedMessageAttribute(tag: 0, timestamp: timestamp + attribute.timeout, messageId: id)
                    }
                    break
                }
            }
        }
    }
}

public func togglePeerUnreadMarkInteractively(postbox: Postbox, viewTracker: AccountViewTracker, peerId: PeerId, setToValue: Bool? = nil) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        togglePeerUnreadMarkInteractively(transaction: transaction, viewTracker: viewTracker, peerId: peerId, setToValue: setToValue)
    }
}

public func togglePeerUnreadMarkInteractively(transaction: Transaction, viewTracker: AccountViewTracker, peerId: PeerId, setToValue: Bool? = nil) {
    let namespace: MessageId.Namespace
    if peerId.namespace == Namespaces.Peer.SecretChat {
        namespace = Namespaces.Message.SecretIncoming
    } else {
        namespace = Namespaces.Message.Cloud
    }
    if let states = transaction.getPeerReadStates(peerId) {
        for i in 0 ..< states.count {
            if states[i].0 == namespace {
                if states[i].1.isUnread {
                    if setToValue == nil || !(setToValue!) {
                        if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: namespace) {
                            let _ = transaction.applyInteractiveReadMaxIndex(index)
                        } else {
                            transaction.applyMarkUnread(peerId: peerId, namespace: namespace, value: false, interactive: true)
                        }
                        viewTracker.updateMarkAllMentionsSeen(peerId: peerId)
                    }
                } else if namespace == Namespaces.Message.Cloud || namespace == Namespaces.Message.SecretIncoming {
                    if setToValue == nil || setToValue! {
                        transaction.applyMarkUnread(peerId: peerId, namespace: namespace, value: true, interactive: true)
                    }
                }
            }
        }
    }
}

public func clearPeerUnseenPersonalMessagesInteractively(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return
        }
        account.viewTracker.updateMarkAllMentionsSeen(peerId: peerId)
    }
    |> ignoreValues
}

public func markAllChatsAsReadInteractively(transaction: Transaction, viewTracker: AccountViewTracker, groupId: PeerGroupId) {
    for peerId in transaction.getUnreadChatListPeerIds(groupId: groupId) {
        togglePeerUnreadMarkInteractively(transaction: transaction, viewTracker: viewTracker, peerId: peerId, setToValue: false)
    }
}

import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

public enum EarliestUnseenPersonalMentionMessageResult: Equatable {
    case loading
    case result(MessageId?)
}

public func earliestUnseenPersonalMentionMessage(account: Account, peerId: PeerId) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
    return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .lowerBound, anchorIndex: .lowerBound, count: 4, fixedCombinedReadStates: nil, tagMask: .unseenPersonalMessage, additionalData: [.peerChatState(peerId)])
    |> mapToSignal { view -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
        if view.0.isLoading {
            return .single(.loading)
        }
        if let message = view.0.entries.first?.message {
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                var invalidatedPts: Int32?
                for data in view.0.additionalData {
                    switch data {
                        case let .peerChatState(_, state):
                            if let state = state as? ChannelState {
                                invalidatedPts = state.invalidatedPts
                            }
                        default:
                            break
                    }
                }
                if let invalidatedPts = invalidatedPts {
                    var messagePts: Int32?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                            messagePts = attribute.pts
                            break
                        }
                    }
                    
                    if let messagePts = messagePts {
                        if messagePts < invalidatedPts {
                            return .single(.loading)
                        }
                    }
                }
                return .single(.result(message.id))
            } else {
                return .single(.result(message.id))
            }
        } else {
            return .single(.result(nil))
        }
    }
    |> distinctUntilChanged
    |> take(until: { value in
        if case .result = value {
            return SignalTakeAction(passthrough: true, complete: true)
        } else {
            return SignalTakeAction(passthrough: true, complete: false)
        }
    })
}

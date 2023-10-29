import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

public struct BotCommand: PostboxCoding, Equatable {
    public let text: String
    public let description: String
    
    init(text: String, description: String) {
        self.text = text
        self.description = description
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.description = decoder.decodeStringForKey("d", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeString(self.description, forKey: "d")
    }
    
    public static func ==(lhs: BotCommand, rhs: BotCommand) -> Bool {
        return lhs.text == rhs.text && lhs.description == rhs.description
    }
}

public final class BotInfo: PostboxCoding, Equatable {
    public let description: String
    public let commands: [BotCommand]
    
    init(description: String, commands: [BotCommand]) {
        self.description = description
        self.commands = commands
    }
    
    public init(decoder: PostboxDecoder) {
        self.description = decoder.decodeStringForKey("d", orElse: "")
        self.commands = decoder.decodeObjectArrayWithDecoderForKey("c")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.description, forKey: "d")
        encoder.encodeObjectArray(self.commands, forKey: "c")
    }
    
    public static func ==(lhs: BotInfo, rhs: BotInfo) -> Bool {
        return lhs.description == rhs.description && lhs.commands == rhs.commands
    }
}

extension BotInfo {
    convenience init(apiBotInfo: Api.BotInfo) {
        switch apiBotInfo {
        case let .botInfo(_, description, commands):
            self.init(description: description, commands: commands.map { command in
                switch command {
                case let .botCommand(command, description):
                    return BotCommand(text: command, description: description)
                }
            })
        }
    }
}

import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import UIKit
    import TelegramApi
#endif


private let typeFileName: Int32 = 0
private let typeSticker: Int32 = 1
private let typeImageSize: Int32 = 2
private let typeAnimated: Int32 = 3
private let typeVideo: Int32 = 4
private let typeAudio: Int32 = 5
private let typeHasLinkedStickers: Int32 = 6

public enum StickerPackReference: PostboxCoding, Hashable, Equatable {
    case id(id: Int64, accessHash: Int64)
    case name(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .id(id: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case 1:
                self = .name(decoder.decodeStringForKey("n", orElse: ""))
            default:
                self = .name("")
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .id(id, accessHash):
                encoder.encodeInt32(0, forKey: "r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case let .name(name):
                encoder.encodeInt32(1, forKey: "r")
                encoder.encodeString(name, forKey: "n")
        }
    }
    
    public static func ==(lhs: StickerPackReference, rhs: StickerPackReference) -> Bool {
        switch lhs {
            case let .id(id, accessHash):
                if case .id(id, accessHash) = rhs {
                    return true
                } else {
                    return false
                }
            case let .name(name):
                if case .name(name) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct TelegramMediaVideoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let instantRoundVideo = TelegramMediaVideoFlags(rawValue: 1 << 0)
    public static let supportsStreaming = TelegramMediaVideoFlags(rawValue: 1 << 1)
}

public struct StickerMaskCoords: PostboxCoding {
    public let n: Int32
    public let x: Double
    public let y: Double
    public let zoom: Double
    
    public init(n: Int32, x: Double, y: Double, zoom: Double) {
        self.n = n
        self.x = x
        self.y = y
        self.zoom = zoom
    }
    
    public init(decoder: PostboxDecoder) {
        self.n = decoder.decodeInt32ForKey("n", orElse: 0)
        self.x = decoder.decodeDoubleForKey("x", orElse: 0.0)
        self.y = decoder.decodeDoubleForKey("y", orElse: 0.0)
        self.zoom = decoder.decodeDoubleForKey("z", orElse: 0.0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.n, forKey: "n")
        encoder.encodeDouble(self.x, forKey: "x")
        encoder.encodeDouble(self.y, forKey: "y")
        encoder.encodeDouble(self.zoom, forKey: "z")
    }
}

public enum TelegramMediaFileAttribute: PostboxCoding {
    case FileName(fileName: String)
    case Sticker(displayText: String, packReference: StickerPackReference?, maskData: StickerMaskCoords?)
    case ImageSize(size: CGSize)
    case Animated
    case Video(duration: Int, size: CGSize, flags: TelegramMediaVideoFlags)
    case Audio(isVoice: Bool, duration: Int, title: String?, performer: String?, waveform: MemoryBuffer?)
    case HasLinkedStickers
    
    public init(decoder: PostboxDecoder) {
        let type: Int32 = decoder.decodeInt32ForKey("t", orElse: 0)
        switch type {
            case typeFileName:
                self = .FileName(fileName: decoder.decodeStringForKey("fn", orElse: ""))
            case typeSticker:
                self = .Sticker(displayText: decoder.decodeStringForKey("dt", orElse: ""), packReference: decoder.decodeObjectForKey("pr", decoder: { StickerPackReference(decoder: $0) }) as? StickerPackReference, maskData: decoder.decodeObjectForKey("mc", decoder: { StickerMaskCoords(decoder: $0) }) as? StickerMaskCoords)
            case typeImageSize:
                self = .ImageSize(size: CGSize(width: CGFloat(decoder.decodeInt32ForKey("w", orElse: 0)), height: CGFloat(decoder.decodeInt32ForKey("h", orElse: 0))))
            case typeAnimated:
                self = .Animated
            case typeVideo:
                self = .Video(duration: Int(decoder.decodeInt32ForKey("du", orElse: 0)), size: CGSize(width: CGFloat(decoder.decodeInt32ForKey("w", orElse: 0)), height: CGFloat(decoder.decodeInt32ForKey("h", orElse: 0))), flags: TelegramMediaVideoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0)))
            case typeAudio:
                let waveformBuffer = decoder.decodeBytesForKeyNoCopy("wf")
                var waveform: MemoryBuffer?
                if let waveformBuffer = waveformBuffer {
                    waveform = MemoryBuffer(copyOf: waveformBuffer)
                }
                self = .Audio(isVoice: decoder.decodeInt32ForKey("iv", orElse: 0) != 0, duration: Int(decoder.decodeInt32ForKey("du", orElse: 0)), title: decoder.decodeOptionalStringForKey("ti"), performer: decoder.decodeOptionalStringForKey("pe"), waveform: waveform)
            case typeHasLinkedStickers:
                self = .HasLinkedStickers
            default:
                preconditionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .FileName(fileName):
                encoder.encodeInt32(typeFileName, forKey: "t")
                encoder.encodeString(fileName, forKey: "fn")
            case let .Sticker(displayText, packReference, maskCoords):
                encoder.encodeInt32(typeSticker, forKey: "t")
                encoder.encodeString(displayText, forKey: "dt")
                if let packReference = packReference {
                    encoder.encodeObject(packReference, forKey: "pr")
                } else {
                    encoder.encodeNil(forKey: "pr")
                }
                if let maskCoords = maskCoords {
                    encoder.encodeObject(maskCoords, forKey: "mc")
                } else {
                    encoder.encodeNil(forKey: "mc")
                }
            case let .ImageSize(size):
                encoder.encodeInt32(typeImageSize, forKey: "t")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
            case .Animated:
                encoder.encodeInt32(typeAnimated, forKey: "t")
            case let .Video(duration, size, flags):
                encoder.encodeInt32(typeVideo, forKey: "t")
                encoder.encodeInt32(Int32(duration), forKey: "du")
                encoder.encodeInt32(Int32(size.width), forKey: "w")
                encoder.encodeInt32(Int32(size.height), forKey: "h")
                encoder.encodeInt32(flags.rawValue, forKey: "f")
            case let .Audio(isVoice, duration, title, performer, waveform):
                encoder.encodeInt32(typeAudio, forKey: "t")
                encoder.encodeInt32(isVoice ? 1 : 0, forKey: "iv")
                encoder.encodeInt32(Int32(duration), forKey: "du")
                if let title = title {
                    encoder.encodeString(title, forKey: "ti")
                }
                if let performer = performer {
                    encoder.encodeString(performer, forKey: "pe")
                }
                if let waveform = waveform {
                    encoder.encodeBytes(waveform, forKey: "wf")
                }
            case .HasLinkedStickers:
                encoder.encodeInt32(typeHasLinkedStickers, forKey: "t")
        }
    }
}

func dimensionsForFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> CGSize? {
    for attribute in attributes {
        switch attribute {
            case let .Video(_, size, _):
                return size
            case let .ImageSize(size):
                return size
            default:
                break
        }
    }
    return nil
}

func durationForFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> Int32? {
    for attribute in attributes {
        switch attribute {
            case let .Video(duration, _, _):
                return Int32(duration)
            case let .Audio(_, duration, _, _, _):
                return Int32(duration)
            default:
                break
        }
    }
    return nil
}

public enum TelegramMediaFileReference: PostboxCoding, Equatable {
    case cloud(fileId: Int64, accessHash: Int64, fileReference: Data?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .cloud(fileId: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeBytesForKey("fr")?.makeData())
            default:
                self = .cloud(fileId: 0, accessHash: 0, fileReference: nil)
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .cloud(imageId, accessHash, fileReference):
                encoder.encodeInt32(0, forKey: "_v")
                encoder.encodeInt64(imageId, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
        }
    }
}

public final class TelegramMediaFile: Media, Equatable {
    public let fileId: MediaId
    public let partialReference: PartialMediaReference?
    public let resource: TelegramMediaResource
    public let previewRepresentations: [TelegramMediaImageRepresentation]
    public let immediateThumbnailData: Data?
    public let mimeType: String
    public let size: Int?
    public let attributes: [TelegramMediaFileAttribute]
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.fileId
    }
    
    public init(fileId: MediaId, partialReference: PartialMediaReference?, resource: TelegramMediaResource, previewRepresentations: [TelegramMediaImageRepresentation], immediateThumbnailData: Data?, mimeType: String, size: Int?, attributes: [TelegramMediaFileAttribute]) {
        self.fileId = fileId
        self.partialReference = partialReference
        self.resource = resource
        self.previewRepresentations = previewRepresentations
        self.immediateThumbnailData = immediateThumbnailData
        self.mimeType = mimeType
        self.size = size
        self.attributes = attributes
    }
    
    public init(decoder: PostboxDecoder) {
        self.fileId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.partialReference = decoder.decodeAnyObjectForKey("prf", decoder: { PartialMediaReference(decoder: $0) }) as? PartialMediaReference
        self.resource = decoder.decodeObjectForKey("r") as? TelegramMediaResource ?? EmptyMediaResource()
        self.previewRepresentations = decoder.decodeObjectArrayForKey("pr")
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
        self.mimeType = decoder.decodeStringForKey("mt", orElse: "")
        if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
        self.attributes = decoder.decodeObjectArrayForKey("at")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.fileId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        if let partialReference = self.partialReference {
            encoder.encodeObjectWithEncoder(partialReference, encoder: partialReference.encode, forKey: "prf")
        } else {
            encoder.encodeNil(forKey: "prf")
        }
        encoder.encodeObject(self.resource, forKey: "r")
        encoder.encodeObjectArray(self.previewRepresentations, forKey: "pr")
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "itd")
        } else {
            encoder.encodeNil(forKey: "itd")
        }
        encoder.encodeString(self.mimeType, forKey: "mt")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeObjectArray(self.attributes, forKey: "at")
    }
    
    public var fileName: String? {
        get {
            for attribute in self.attributes {
                switch attribute {
                    case let .FileName(fileName):
                        return fileName
                    case _:
                        break
                }
            }
            return nil
        }
    }
    
    public var isSticker: Bool {
        for attribute in self.attributes {
            if case .Sticker = attribute {
                return true
            }
        }
        return false
    }
    
    public var isVideo: Bool {
        for attribute in self.attributes {
            if case .Video = attribute {
                return true
            }
        }
        return false
    }
    
    public var isInstantVideo: Bool {
        for attribute in self.attributes {
            if case .Video(_, _, let flags) = attribute {
                return flags.contains(.instantRoundVideo)
            }
        }
        return false
    }
    
    public var isAnimated: Bool {
        for attribute in self.attributes {
            if case .Animated = attribute {
                return true
            }
        }
        return false
    }
    
    public var isMusic: Bool {
        for attribute in self.attributes {
            if case .Audio(false, _, _, _, _) = attribute {
                return true
            }
        }
        return false
    }
    
    public var isVoice: Bool {
        for attribute in self.attributes {
            if case .Audio(true, _, _, _, _) = attribute {
                return true
            }
        }
        return false
    }
    
    public var dimensions: CGSize? {
        return dimensionsForFileAttributes(self.attributes)
    }
    
    public var duration: Int32? {
        return durationForFileAttributes(self.attributes)
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaFile else {
            return false
        }
        
        if self.fileId != other.fileId {
            return false
        }
        
        if self.partialReference != other.partialReference {
            return false
        }
        
        if !self.resource.isEqual(to: other.resource) {
            return false
        }
        
        if self.previewRepresentations != other.previewRepresentations {
            return false
        }
        
        if self.immediateThumbnailData != other.immediateThumbnailData {
            return false
        }
        
        if self.size != other.size {
            return false
        }
        
        if self.mimeType != other.mimeType {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaFile else {
            return false
        }
        
        if self.fileId != other.fileId {
            return false
        }
        
        if self.partialReference != other.partialReference {
            return false
        }
        
        if !self.resource.id.isEqual(to: other.resource.id) {
            return false
        }
        
        if self.previewRepresentations.count != other.previewRepresentations.count {
            return false
        }
        
        for i in 0 ..< self.previewRepresentations.count {
            if !self.previewRepresentations[i].isSemanticallyEqual(to: other.previewRepresentations[i]) {
                return false
            }
        }
        
        if self.immediateThumbnailData != other.immediateThumbnailData {
            return false
        }
        
        if self.size != other.size {
            return false
        }
        
        if self.mimeType != other.mimeType {
            return false
        }
        
        return true
    }
    
    public func withUpdatedPartialReference(_ partialReference: PartialMediaReference?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
    
    public func withUpdatedSize(_ size: Int?) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: size, attributes: self.attributes)
    }
    
    public func withUpdatedPreviewRepresentations(_ previewRepresentations: [TelegramMediaImageRepresentation]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: previewRepresentations, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
    
    public func withUpdatedAttributes(_ attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: attributes)
    }
}

public func ==(lhs: TelegramMediaFile, rhs: TelegramMediaFile) -> Bool {
    return lhs.isEqual(to: rhs)
}

extension StickerPackReference {
    init?(apiInputSet: Api.InputStickerSet) {
        switch apiInputSet {
            case .inputStickerSetEmpty:
                return nil
            case let .inputStickerSetID(id, accessHash):
                self = .id(id: id, accessHash: accessHash)
            case let .inputStickerSetShortName(shortName):
                self = .name(shortName)
        }
    }
}

extension StickerMaskCoords {
    init(apiMaskCoords: Api.MaskCoords) {
        switch apiMaskCoords {
            case let .maskCoords(n, x, y, zoom):
                self.init(n: n, x: x, y: y, zoom: zoom)
        }
    }
}

func telegramMediaFileAttributesFromApiAttributes(_ attributes: [Api.DocumentAttribute]) -> [TelegramMediaFileAttribute] {
    var result: [TelegramMediaFileAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .documentAttributeFilename(fileName):
                result.append(.FileName(fileName: fileName))
            case let .documentAttributeSticker(_, alt, stickerSet, maskCoords):
                result.append(.Sticker(displayText: alt, packReference: StickerPackReference(apiInputSet: stickerSet), maskData: maskCoords.flatMap(StickerMaskCoords.init)))
            case .documentAttributeHasStickers:
                result.append(.HasLinkedStickers)
            case let .documentAttributeImageSize(w, h):
                result.append(.ImageSize(size: CGSize(width: CGFloat(w), height: CGFloat(h))))
            case .documentAttributeAnimated:
                result.append(.Animated)
            case let .documentAttributeVideo(flags, duration, w, h):
                var videoFlags = TelegramMediaVideoFlags()
                if (flags & (1 << 0)) != 0 {
                    videoFlags.insert(.instantRoundVideo)
                }
                if (flags & (1 << 1)) != 0 {
                    videoFlags.insert(.supportsStreaming)
                }
                result.append(.Video(duration: Int(duration), size: CGSize(width: CGFloat(w), height: CGFloat(h)), flags: videoFlags))
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                var waveformBuffer: MemoryBuffer?
                if let waveform = waveform {
                    let memory = malloc(waveform.size)!
                    memcpy(memory, waveform.data, waveform.size)
                    waveformBuffer = MemoryBuffer(memory: memory, capacity: waveform.size, length: waveform.size, freeWhenDone: true)
                }
                result.append(.Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer))
        }
    }
    return result
}

public func fileNameFromFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> String? {
    for attribute in attributes {
        if case let .FileName(value) = attribute {
            return value
        }
    }
    return nil
}

func telegramMediaFileThumbnailRepresentationsFromApiSizes(datacenterId: Int32, documentId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudDocumentSizeMediaResource(datacenterId: datacenterId, documentId: documentId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudDocumentSizeMediaResource(datacenterId: datacenterId, documentId: documentId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoStrippedSize(_, data):
                immediateThumbnailData = data.makeData()
            case .photoSizeEmpty:
                break
        }
    }
    return (immediateThumbnailData, representations)
}

func telegramMediaFileFromApiDocument(_ document: Api.Document) -> TelegramMediaFile? {
    switch document {
        case let .document(_, id, accessHash, fileReference, _, mimeType, size, thumbs, dcId, attributes):
            let parsedAttributes = telegramMediaFileAttributesFromApiAttributes(attributes)
            let (immediateThumbnail, previewRepresentations) = telegramMediaFileThumbnailRepresentationsFromApiSizes(datacenterId: dcId, documentId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: thumbs ?? [])
            
            return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size), fileReference: fileReference.makeData(), fileName: fileNameFromFileAttributes(parsedAttributes)), previewRepresentations: previewRepresentations, immediateThumbnailData: immediateThumbnail, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
        case .documentEmpty:
            return nil
    }
}

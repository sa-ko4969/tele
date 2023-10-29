import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import ImageIO
import MobileCoreServices
import Display
import AVFoundation
#if BUCK
import WebPImage
#else
import WebP
#endif
import Lottie
import TelegramUIPrivateModule

public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedScaledImageRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledImageRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let _ = representation as? CachedVideoFirstFrameRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if data.complete {
                return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data)
                |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return .complete()
                }
            } else if let size = resource.size {
                return videoFirstFrameData(account: account, resource: resource, chunkSize: min(size, 192 * 1024))
            } else {
                return .complete()
            }
        }
    } else if let representation = representation as? CachedScaledVideoFirstFrameRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedBlurredWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperMaskRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperMaskRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedAlbumArtworkRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if data.complete, let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                return fetchCachedAlbumArtworkRepresentation(account: account, resource: resource, data: fileData, representation: representation)
                |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return .complete()
                }
            } else if let size = resource.size {
                return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, 256 * 1024))
                |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return fetchCachedAlbumArtworkRepresentation(account: account, resource: resource, data: data, representation: representation)
                    |> `catch` { error -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                        switch error {
                            case let .moreDataNeeded(targetSize):
                                return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, targetSize))
                                |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                                    return fetchCachedAlbumArtworkRepresentation(account: account, resource: resource, data: data, representation: representation)
                                    |> `catch` { error -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                                        return .complete()
                                    }
                                }
                        }
                    }
                }
            } else {
                return .complete()
            }
        }
    } else if let representation = representation as? CachedEmojiThumbnailRepresentation {
        return fetchEmojiThumbnailRepresentation(account: account, resource: resource, representation: representation)
    } else if let representation = representation as? CachedEmojiRepresentation {
        return fetchEmojiRepresentation(account: account, resource: resource, representation: representation)
    } else if let representation = representation as? CachedAnimatedStickerRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchAnimatedStickerRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    }
    return .never()
}

private func videoFirstFrameData(account: Account, resource: MediaResource, chunkSize: Int) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let size = resource.size {
        return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, chunkSize))
        |> mapToSignal { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return account.postbox.mediaBox.resourceData(resource, option: .incremental(waitUntilFetchStatus: false), attemptSynchronously: false)
                |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data)
                    |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                        if chunkSize > size {
                            return .complete()
                        } else {
                            return videoFirstFrameData(account: account, resource: resource, chunkSize: chunkSize + chunkSize)
                        }
                    }
            }
        }
    } else {
        return .complete()
    }
}

private func fetchCachedStickerAJpegRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = WebP.convert(fromWebP: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let colorData = NSMutableData()
                let alphaData = NSMutableData()
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let colorImage: UIImage?
                if let _ = representation.size {
                    colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    }, scale: 1.0)
                } else {
                    colorImage = image
                }
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    if let colorImage = colorImage {
                        context.clip(to: CGRect(origin: CGPoint(), size: size), mask: colorImage.cgImage!)
                    }
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                
                if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float
                    let alphaQuality: Float
                    if representation.size == nil {
                        colorQuality = 0.6
                        alphaQuality = 0.6
                    } else {
                        colorQuality = 0.5
                        alphaQuality = 0.4
                    }
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    let optionsAlpha = NSMutableDictionary()
                    optionsAlpha.setObject(alphaQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    if let colorImage = colorImage {
                        CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    }
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, optionsAlpha as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) && CGImageDestinationFinalize(alphaDestination) {
                        let finalData = NSMutableData()
                        var colorSize: Int32 = Int32(colorData.length)
                        finalData.append(&colorSize, length: 4)
                        finalData.append(colorData as Data)
                        var alphaSize: Int32 = Int32(alphaData.length)
                        finalData.append(&alphaSize, length: 4)
                        finalData.append(alphaData as Data)
                        
                        let _ = try? finalData.write(to: url, options: [.atomic])
                        
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedScaledImageRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledImageRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)

                let size: CGSize
                switch representation.mode {
                    case .fill:
                        size = representation.size
                    case .aspectFit:
                        size = image.size.fitted(representation.size)
                }
                
                let colorImage = generateImage(size, contextGenerator: { size, context in
                    context.setBlendMode(.copy)
                    drawImage(context: context, image: image.cgImage!, orientation: image.imageOrientation, in: CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)!
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

func generateVideoFirstFrame(_ path: String, maxDimensions: CGSize) -> UIImage? {
    let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
    
    do {
        let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        try FileManager.default.linkItem(atPath: path, toPath: tempFilePath)
        
        let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.maximumSize = maxDimensions
        imageGenerator.appliesPreferredTrackTransform = true
        let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
        let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        return UIImage(cgImage: fullSizeImage)
    } catch {
        return nil
    }
}

public enum FetchVideoFirstFrameError {
    case generic
}

private func fetchCachedVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData) -> Signal<CachedMediaResourceRepresentationResult, FetchVideoFirstFrameError> {
    return Signal { subscriber in
            let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
            do {
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                try FileManager.default.linkItem(atPath: resourceData.path, toPath: tempFilePath)
                
                let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
                
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.6
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
                
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            } catch  _ {
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                subscriber.putError(.generic)
                subscriber.putCompletion()
            }
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedScaledVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), complete: true)
    |> mapToSignal { firstFrame -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return Signal({ subscriber in
                if let data = try? Data(contentsOf: URL(fileURLWithPath: firstFrame.path), options: [.mappedIfSafe]) {
                    if let image = UIImage(data: data) {
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        let path = NSTemporaryDirectory() + "\(randomId)"
                        let url = URL(fileURLWithPath: path)
                        
                        let size = representation.size
                        
                        let colorImage = generateImage(size, contextGenerator: { size, context in
                            context.setBlendMode(.copy)
                            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        }, scale: 1.0)!
                        
                        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                            
                            let colorQuality: Float = 0.5
                            
                            let options = NSMutableDictionary()
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                                subscriber.putCompletion()
                            }
                        }
                    }
                }
                return EmptyDisposable
            }) |> runOn(Queue.concurrentDefaultQueue())
    }
}

private func fetchCachedBlurredWallpaperRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedBlurredWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 45.0), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperMaskRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperMaskRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: image.cgImage!)
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                   
                if let alphaImage = alphaImage, let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.87
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(alphaDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let backgroundColor = UIColor(rgb: UInt32(bitPattern: representation.color))
                let foregroundColor = patternColor(for: backgroundColor, intensity: CGFloat(representation.intensity) / 100.0)
                
                let colorImage = generateImage(size, contextGenerator: { size, c in
                    let rect = CGRect(origin: CGPoint(), size: size)
                    c.setBlendMode(.copy)
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(rect)
                    
                    c.setBlendMode(.normal)
                    if let cgImage = image.cgImage {
                        c.clip(to: rect, mask: cgImage)
                    }
                    c.setFillColor(foregroundColor.cgColor)
                    c.fill(rect)
                }, scale: 1.0)
                
                if let colorImage = colorImage, let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.9
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

public func fetchCachedSharedResourceRepresentation(accountManager: AccountManager, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedScaledImageRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledImageRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedBlurredWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperMaskRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperMaskRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else {
        return .never()
    }
}

private func fetchCachedBlurredWallpaperRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedBlurredWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 45.0), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperMaskRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperMaskRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: image.cgImage!)
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                
                if let alphaImage = alphaImage, let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.87
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(alphaDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let backgroundColor = UIColor(rgb: UInt32(bitPattern: representation.color))
                let foregroundColor = patternColor(for: backgroundColor, intensity: CGFloat(representation.intensity) / 100.0)
                
                let colorImage = generateImage(size, contextGenerator: { size, c in
                    let rect = CGRect(origin: CGPoint(), size: size)
                    c.setBlendMode(.copy)
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(rect)
                    
                    c.setBlendMode(.normal)
                    if let cgImage = image.cgImage {
                        c.clip(to: rect, mask: cgImage)
                    }
                    c.setFillColor(foregroundColor.cgColor)
                    c.fill(rect)
                }, scale: 1.0)
                
                if let colorImage = colorImage, let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.9
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

public enum FetchAlbumArtworkError {
    case moreDataNeeded(Int)
}

private func fetchCachedAlbumArtworkRepresentation(account: Account, resource: MediaResource, data: Data, representation: CachedAlbumArtworkRepresentation) -> Signal<CachedMediaResourceRepresentationResult, FetchAlbumArtworkError> {
    return Signal({ subscriber in
        let result = readAlbumArtworkData(data)
        switch result {
            case let .artworkData(data):
                if let image = UIImage(data: data) {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    let path = NSTemporaryDirectory() + "\(randomId)"
                    let url = URL(fileURLWithPath: path)
                    
                    var size = image.size
                    if let targetSize = representation.size {
                        size = size.aspectFilled(targetSize)
                    }
                    
                    let colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        drawImage(context: context, image: image.cgImage!, orientation: image.imageOrientation, in: CGRect(origin: CGPoint(), size: size))
                    })!
                    
                    if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                        
                        let colorQuality: Float = 0.5
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        }
                    }
                }
            case let .moreDataNeeded(size):
                subscriber.putError(.moreDataNeeded(size))
            default:
                break
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchEmojiThumbnailRepresentation(account: Account, resource: MediaResource, representation: CachedEmojiThumbnailRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    guard let resource = resource as? EmojiThumbnailResource else {
        return .never()
    }
    return Signal({ subscriber in
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        let path = NSTemporaryDirectory() + "\(randomId)"
        let url = URL(fileURLWithPath: path)
        
        let nsString = (resource.emoji as NSString)
        let font = Font.regular(52.0)
        let stringAttributes = [NSAttributedStringKey.font: font]
        var textSize = nsString.size(withAttributes: stringAttributes)
        textSize = CGSize(width: ceil(textSize.width) + 1.0, height: ceil(textSize.height) + 1.0)
        
        let emojiSize = CGSize(width: 52.0, height: 52.0)
        let context = DrawingContext(size: emojiSize, clear: true)
        context.withFlippedContext { context in
            let size = textSize
            let bounds = CGRect(origin: CGPoint(), size: size)
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.textMatrix = .identity
            
            let path = CGMutablePath()
            path.addRect(bounds.offsetBy(dx: -2.0 + UIScreenPixel, dy: -6.5))
            let string = NSAttributedString(string: resource.emoji, font: font, textColor: .black)
            let framesetter = CTFramesetterCreateWithAttributedString(string as CFAttributedString)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, string.length), path, nil)
            CTFrameDraw(frame, context)
        }
        
        let image = context.generateImage()!
        let borderImage = generateTintedImage(image: image, color: .white)!
        
        let lineWidth: CGFloat = 1.0
        let colorImage = generateImage(CGSize(width: emojiSize.width + lineWidth * 2.0, height: emojiSize.height + lineWidth * 2.0), contextGenerator: { size, context in
            guard let image = image.cgImage else {
                return
            }
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let rect = CGRect(x: lineWidth, y: lineWidth, width: emojiSize.width, height: emojiSize.height)
            if representation.outline {
                let vectors: [CGPoint] = [CGPoint(x: -1.0, y: -1.0), CGPoint(x: -1.0, y: 0.0), CGPoint(x: -1.0, y: 1.0), CGPoint(x: 0.0, y: 1.0), CGPoint(x: 1.0, y: 1.0), CGPoint(x: 1.0, y: 0.0), CGPoint(x: 1.0, y: -1.0), CGPoint(x: 0.0, y: -1.0)]
                if let borderImage = borderImage.cgImage {
                    let step = UIScreenPixel
                    for vector in vectors {
                        for i in stride(from: step, through: lineWidth, by: step) {
                            drawImage(context: context, image: borderImage, orientation: .up, in: rect.offsetBy(dx: vector.x * i, dy: vector.y * i))
                        }
                    }
                    drawImage(context: context, image: image, orientation: .up, in: rect)
                }
            } else {
                drawImage(context: context, image: image, orientation: .up, in: rect)
            }
        })!
        
        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
            let options = NSMutableDictionary()
            CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
            if CGImageDestinationFinalize(colorDestination) {
                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
            }
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func emojiSpriteData(postbox: Postbox, resource: EmojiSpriteResource) -> Signal<(Data?), NoError> {
    let spriteResource = postbox.mediaBox.resourceData(resource)
    
    let signal = spriteResource |> take(1) |> mapToSignal { maybeData -> Signal<(Data?), NoError> in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single((loadedData))
        } else {
            let fetchedThumbnail = postbox.mediaBox.fetchedResource(resource, parameters: nil)
            let thumbnail = Signal<Data?, NoError> { subscriber in
                let fetchedDisposable = fetchedThumbnail.start()
                let thumbnailDisposable = spriteResource.start(next: { next in
                    subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                }, error: subscriber.putError, completed: subscriber.putCompletion)
                
                return ActionDisposable {
                    fetchedDisposable.dispose()
                    thumbnailDisposable.dispose()
                }
            }
            
            return thumbnail
        }
        } |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs == nil && rhs == nil {
                return true
            } else {
                return false
            }
        })
    
    return signal
}

private func fetchEmojiRepresentation(account: Account, resource: MediaResource, representation: CachedEmojiRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    guard let resource = resource as? EmojiSpriteResource else {
        return .never()
    }
    
    return emojiSpriteData(postbox: account.postbox, resource: resource)
    |> mapToSignal { data in
        return Signal({ subscriber in
            if let data = data, let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = CGSize(width: 160.0, height: 160.0)
                let spacing: CGFloat = 16.0
                let context = DrawingContext(size: size, clear: true)
                context.withFlippedContext { context in
                    let origin: CGPoint
                    switch representation.tile {
                        case 0:
                            origin = CGPoint(x: 0.0, y: size.height * 2.0 + spacing * 2.0)
                        case 1:
                            origin = CGPoint(x: size.width + spacing, y: size.height * 2.0 + spacing * 2.0)
                        case 2:
                            origin = CGPoint(x: size.width * 2.0 + spacing * 2.0, y: size.height * 2.0 + spacing * 2.0)
                        case 3:
                            origin = CGPoint(x: 0.0, y: size.height + spacing)
                        case 4:
                            origin = CGPoint(x: size.width + spacing, y: size.height + spacing)
                        case 5:
                            origin = CGPoint(x: size.width * 2.0 + spacing * 2.0, y: size.height + spacing)
                        case 6:
                            origin = CGPoint(x: 0.0, y: 0.0)
                        case 7:
                            origin = CGPoint(x: size.width + spacing, y: 0.0)
                        case 8:
                            origin = CGPoint(x: size.width * 2.0 + spacing * 2.0, y: 0.0)
                        default:
                            origin = CGPoint()
                    }

                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: origin.x * -1.0, y: origin.y * -1.0), size: image.size))
                }
                
                let emojiSize = CGSize(width: 52.0, height: 52.0)
                let scaledImage = generateScaledImage(image: context.generateImage(), size: emojiSize, opaque: false)!
                let borderImage = generateTintedImage(image: scaledImage, color: .white)!
                
                let lineWidth: CGFloat = 1.0
                let colorImage = generateImage(CGSize(width: emojiSize.width + lineWidth * 2.0, height: emojiSize.height + lineWidth * 2.0), contextGenerator: { size, context in
                    guard let image = scaledImage.cgImage else {
                        return
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    let rect = CGRect(x: lineWidth, y: lineWidth, width: emojiSize.width, height: emojiSize.height)
                    if representation.outline {
                        let vectors: [CGPoint] = [CGPoint(x: -1.0, y: -1.0), CGPoint(x: -1.0, y: 0.0), CGPoint(x: -1.0, y: 1.0), CGPoint(x: 0.0, y: 1.0), CGPoint(x: 1.0, y: 1.0), CGPoint(x: 1.0, y: 0.0), CGPoint(x: 1.0, y: -1.0), CGPoint(x: 0.0, y: -1.0)]
                        if let borderImage = borderImage.cgImage {
                            let step = UIScreenPixel
                            for vector in vectors {
                                for i in stride(from: step, through: lineWidth, by: step) {
                                    drawImage(context: context, image: borderImage, orientation: .up, in: rect.offsetBy(dx: vector.x * i, dy: vector.y * i))
                                }
                            }
                            drawImage(context: context, image: image, orientation: .up, in: rect)
                        }
                    } else {
                        drawImage(context: context, image: image, orientation: .up, in: rect)
                    }
                })!
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                    let options = NSMutableDictionary()
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                    }
                }
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }) |> runOn(Queue.concurrentDefaultQueue())
    }
}

private func fetchAnimatedStickerRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedAnimatedStickerRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            return convertCompressedLottieToCombinedMp4(data: data, size: CGSize(width: 400.0, height: 400.0)).start(next: { path in
                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                subscriber.putCompletion()
            })
        } else {
            return EmptyDisposable
        }
    }) |> runOn(Queue.concurrentDefaultQueue())
}

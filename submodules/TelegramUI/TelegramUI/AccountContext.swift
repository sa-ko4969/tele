import Foundation
import SwiftSignalKit
import UIKit
import Postbox
import TelegramCore
import Display
import DeviceAccess
import TelegramPresentationData

public final class TelegramApplicationOpenUrlCompletion {
    public let completion: (Bool) -> Void
    
    public init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
}

private final class DeviceSpecificContactImportContext {
    let disposable = MetaDisposable()
    var reference: DeviceContactBasicDataWithReference?
    
    init() {
    }
    
    deinit {
        self.disposable.dispose()
    }
}

private final class DeviceSpecificContactImportContexts {
    private let queue: Queue
    
    private var contexts: [PeerId: DeviceSpecificContactImportContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func update(account: Account, deviceContactDataManager: DeviceContactDataManager, references: [PeerId: DeviceContactBasicDataWithReference]) {
        var validIds = Set<PeerId>()
        for (peerId, reference) in references {
            validIds.insert(peerId)
            
            let context: DeviceSpecificContactImportContext
            if let current = self.contexts[peerId] {
                context = current
            } else {
                context = DeviceSpecificContactImportContext()
                self.contexts[peerId] = context
            }
            if context.reference != reference {
                context.reference = reference
                
                let key: PostboxViewKey = .basicPeer(peerId)
                let signal = account.postbox.combinedView(keys: [key])
                |> map { view -> String? in
                    if let user = (view.views[key] as? BasicPeerView)?.peer as? TelegramUser {
                        return user.phone
                    } else {
                        return nil
                    }
                }
                |> distinctUntilChanged
                |> mapToSignal { phone -> Signal<Never, NoError> in
                    guard let phone = phone else {
                        return .complete()
                    }
                    var found = false
                    let formattedPhone = formatPhoneNumber(phone)
                    for number in reference.basicData.phoneNumbers {
                        if formatPhoneNumber(number.value) == formattedPhone {
                            found = true
                            break
                        }
                    }
                    if !found {
                        return deviceContactDataManager.appendPhoneNumber(DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: formattedPhone), to: reference.stableId)
                        |> ignoreValues
                    } else {
                        return .complete()
                    }
                }
                context.disposable.set(signal.start())
            }
        }
        
        var removeIds: [PeerId] = []
        for peerId in self.contexts.keys {
            if !validIds.contains(peerId) {
                removeIds.append(peerId)
            }
        }
        for peerId in removeIds {
            self.contexts.removeValue(forKey: peerId)
        }
    }
}

public final class TelegramApplicationBindings {
    public let isMainApp: Bool
    public let containerPath: String
    public let appSpecificScheme: String
    public let openUrl: (String) -> Void
    public let openUniversalUrl: (String, TelegramApplicationOpenUrlCompletion) -> Void
    public let canOpenUrl: (String) -> Bool
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    public let applicationInForeground: Signal<Bool, NoError>
    public let applicationIsActive: Signal<Bool, NoError>
    public let clearMessageNotifications: ([MessageId]) -> Void
    public let pushIdleTimerExtension: () -> Disposable
    public let openSettings: () -> Void
    public let openAppStorePage: () -> Void
    public let registerForNotifications: (@escaping (Bool) -> Void) -> Void
    public let requestSiriAuthorization: (@escaping (Bool) -> Void) -> Void
    public let siriAuthorization: () -> AccessType
    public let getWindowHost: () -> WindowHost?
    public let presentNativeController: (UIViewController) -> Void
    public let dismissNativeController: () -> Void
    public let getAvailableAlternateIcons: () -> [PresentationAppIcon]
    public let getAlternateIconName: () -> String?
    public let requestSetAlternateIconName: (String?, @escaping (Bool) -> Void) -> Void
    
    public init(isMainApp: Bool, containerPath: String, appSpecificScheme: String, openUrl: @escaping (String) -> Void, openUniversalUrl: @escaping (String, TelegramApplicationOpenUrlCompletion) -> Void, canOpenUrl: @escaping (String) -> Bool, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>, clearMessageNotifications: @escaping ([MessageId]) -> Void, pushIdleTimerExtension: @escaping () -> Disposable, openSettings: @escaping () -> Void, openAppStorePage: @escaping () -> Void, registerForNotifications: @escaping (@escaping (Bool) -> Void) -> Void, requestSiriAuthorization: @escaping (@escaping (Bool) -> Void) -> Void, siriAuthorization: @escaping () -> AccessType, getWindowHost: @escaping () -> WindowHost?, presentNativeController: @escaping (UIViewController) -> Void, dismissNativeController: @escaping () -> Void, getAvailableAlternateIcons: @escaping () -> [PresentationAppIcon], getAlternateIconName: @escaping () -> String?, requestSetAlternateIconName: @escaping (String?, @escaping (Bool) -> Void) -> Void) {
        self.isMainApp = isMainApp
        self.containerPath = containerPath
        self.appSpecificScheme = appSpecificScheme
        self.openUrl = openUrl
        self.openUniversalUrl = openUniversalUrl
        self.canOpenUrl = canOpenUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
        self.applicationInForeground = applicationInForeground
        self.applicationIsActive = applicationIsActive
        self.clearMessageNotifications = clearMessageNotifications
        self.pushIdleTimerExtension = pushIdleTimerExtension
        self.openSettings = openSettings
        self.openAppStorePage = openAppStorePage
        self.registerForNotifications = registerForNotifications
        self.requestSiriAuthorization = requestSiriAuthorization
        self.siriAuthorization = siriAuthorization
        self.presentNativeController = presentNativeController
        self.dismissNativeController = dismissNativeController
        self.getWindowHost = getWindowHost
        self.getAvailableAlternateIcons = getAvailableAlternateIcons
        self.getAlternateIconName = getAlternateIconName
        self.requestSetAlternateIconName = requestSetAlternateIconName
    }
}

public final class AccountContext {
    public let sharedContext: SharedAccountContext
    public let account: Account
    
    public let fetchManager: FetchManager
    private let prefetchManager: PrefetchManager?
    
    public var keyShortcutsController: KeyShortcutsController?
    
    let downloadedMediaStoreManager: DownloadedMediaStoreManager
    
    public let liveLocationManager: LiveLocationManager?
    let wallpaperUploadManager: WallpaperUploadManager?
    
    let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    
    public let currentLimitsConfiguration: Atomic<LimitsConfiguration>
    private let _limitsConfiguration = Promise<LimitsConfiguration>()
    public var limitsConfiguration: Signal<LimitsConfiguration, NoError> {
        return self._limitsConfiguration.get()
    }
    
    public var watchManager: WatchManager?
    
    private var storedPassword: (String, CFAbsoluteTime, SwiftSignalKit.Timer)?
    private var limitsConfigurationDisposable: Disposable?
    
    private let deviceSpecificContactImportContexts: QueueLocalObject<DeviceSpecificContactImportContexts>
    private var managedAppSpecificContactsDisposable: Disposable?
    
    public init(sharedContext: SharedAccountContext, account: Account, limitsConfiguration: LimitsConfiguration) {
        self.sharedContext = sharedContext
        self.account = account
        
        self.downloadedMediaStoreManager = DownloadedMediaStoreManager(postbox: account.postbox, accountManager: sharedContext.accountManager)
        
        if let locationManager = self.sharedContext.locationManager {
            self.liveLocationManager = LiveLocationManager(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, viewTracker: account.viewTracker, stateManager: account.stateManager, locationManager: locationManager, inForeground: self.sharedContext.applicationBindings.applicationInForeground)
        } else {
            self.liveLocationManager = nil
        }
        self.fetchManager = FetchManager(postbox: account.postbox, storeManager: self.downloadedMediaStoreManager)
        if sharedContext.applicationBindings.isMainApp {
            self.prefetchManager = PrefetchManager(sharedContext: sharedContext, account: account, fetchManager: fetchManager)
            self.wallpaperUploadManager = WallpaperUploadManager(sharedContext: sharedContext, account: account, presentationData: sharedContext.presentationData)
        } else {
            self.prefetchManager = nil
            self.wallpaperUploadManager = nil
        }
        
        let updatedLimitsConfiguration = account.postbox.preferencesView(keys: [PreferencesKeys.limitsConfiguration])
        |> map { preferences -> LimitsConfiguration in
            return preferences.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        }
        
        self.currentLimitsConfiguration = Atomic(value: limitsConfiguration)
        self._limitsConfiguration.set(.single(limitsConfiguration) |> then(updatedLimitsConfiguration))
        
        let currentLimitsConfiguration = self.currentLimitsConfiguration
        self.limitsConfigurationDisposable = (self._limitsConfiguration.get()
        |> deliverOnMainQueue).start(next: { value in
            let _ = currentLimitsConfiguration.swap(value)
        })
        
        let queue = Queue()
        self.deviceSpecificContactImportContexts = QueueLocalObject(queue: queue, generate: {
            return DeviceSpecificContactImportContexts(queue: queue)
        })
        
        if let contactDataManager = sharedContext.contactDataManager {
            let deviceSpecificContactImportContexts = self.deviceSpecificContactImportContexts
            self.managedAppSpecificContactsDisposable = (contactDataManager.appSpecificReferences()
            |> deliverOn(queue)).start(next: { appSpecificReferences in
                deviceSpecificContactImportContexts.with { context in
                    context.update(account: account, deviceContactDataManager: contactDataManager, references: appSpecificReferences)
                }
            })
        }
    }
    
    deinit {
        self.limitsConfigurationDisposable?.dispose()
        self.managedAppSpecificContactsDisposable?.dispose()
    }
    
    public func storeSecureIdPassword(password: String) {
        self.storedPassword?.2.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 1.0 * 60.0 * 60.0, repeat: false, completion: { [weak self] in
            self?.storedPassword = nil
        }, queue: Queue.mainQueue())
        self.storedPassword = (password, CFAbsoluteTimeGetCurrent(), timer)
        timer.start()
    }
    
    public func getStoredSecureIdPassword() -> String? {
        if let (password, timestamp, timer) = self.storedPassword {
            if CFAbsoluteTimeGetCurrent() > timestamp + 1.0 * 60.0 * 60.0 {
                timer.invalidate()
                self.storedPassword = nil
            }
            return password
        } else {
            return nil
        }
    }
}

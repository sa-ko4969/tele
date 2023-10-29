import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramCallsUI

private struct AccountTasks {
    let stateSynchronization: Bool
    let importantTasks: AccountRunningImportantTasks
    let backgroundLocation: Bool
    let backgroundDownloads: Bool
    let backgroundAudio: Bool
    let activeCalls: Bool
    let watchTasks: Bool
    let userInterfaceInUse: Bool
    
    var isEmpty: Bool {
        if self.stateSynchronization {
            return false
        }
        if !self.importantTasks.isEmpty {
            return false
        }
        if self.backgroundLocation {
            return false
        }
        if self.backgroundDownloads {
            return false
        }
        if self.backgroundAudio {
            return false
        }
        if self.activeCalls {
            return false
        }
        if self.watchTasks {
            return false
        }
        if self.userInterfaceInUse {
            return false
        }
        return true
    }
}

public final class SharedWakeupManager {
    private let beginBackgroundTask: (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?
    private let endBackgroundTask: (UIBackgroundTaskIdentifier) -> Void
    private let backgroundTimeRemaining: () -> Double
    
    private var inForeground: Bool = false
    private var hasActiveAudioSession: Bool = false
    private var activeExplicitExtensionTimer: SwiftSignalKit.Timer?
    private var allowBackgroundTimeExtensionDeadline: Double?
    private var isInBackgroundExtension: Bool = false
    
    private var inForegroundDisposable: Disposable?
    private var hasActiveAudioSessionDisposable: Disposable?
    private var tasksDisposable: Disposable?
    private var currentTask: (UIBackgroundTaskIdentifier, Double, SwiftSignalKit.Timer)?
    
    private var accountsAndTasks: [(Account, Bool, AccountTasks)] = []
    
    public init(beginBackgroundTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?, endBackgroundTask: @escaping (UIBackgroundTaskIdentifier) -> Void, backgroundTimeRemaining: @escaping () -> Double, activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, liveLocationPolling: Signal<AccountRecordId?, NoError>, watchTasks: Signal<AccountRecordId?, NoError>, inForeground: Signal<Bool, NoError>, hasActiveAudioSession: Signal<Bool, NoError>, notificationManager: SharedNotificationManager?, mediaManager: MediaManager, callManager: PresentationCallManager?, accountUserInterfaceInUse: @escaping (AccountRecordId) -> Signal<Bool, NoError>) {
        assert(Queue.mainQueue().isCurrent())
        
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.backgroundTimeRemaining = backgroundTimeRemaining
        
        self.inForegroundDisposable = (inForeground
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inForeground = value
            if value {
                strongSelf.activeExplicitExtensionTimer?.invalidate()
                strongSelf.activeExplicitExtensionTimer = nil
            }
            strongSelf.checkTasks()
        })
        
        self.hasActiveAudioSessionDisposable = (hasActiveAudioSession
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.hasActiveAudioSession = value
            strongSelf.checkTasks()
        })
        
        self.tasksDisposable = (activeAccounts
        |> deliverOnMainQueue
        |> mapToSignal { primary, accounts -> Signal<[(Account, Bool, AccountTasks)], NoError> in
            let signals: [Signal<(Account, Bool, AccountTasks), NoError>] = accounts.map { _, account in
                let hasActiveMedia = mediaManager.activeGlobalMediaPlayerAccountId
                |> map { id -> Bool in
                    return id == account.id
                }
                |> distinctUntilChanged
                let isPlayingBackgroundAudio = combineLatest(queue: .mainQueue(), hasActiveMedia, hasActiveAudioSession)
                |> map { hasActiveMedia, hasActiveAudioSession -> Bool in
                    return hasActiveMedia && hasActiveAudioSession
                }
                |> distinctUntilChanged
                
                let hasActiveCalls = (callManager?.currentCallSignal ?? .single(nil))
                |> map { call in
                    return call?.account.id == account.id
                }
                |> distinctUntilChanged
                let isPlayingBackgroundActiveCall = combineLatest(queue: .mainQueue(), hasActiveCalls, hasActiveAudioSession)
                |> map { hasActiveCalls, hasActiveAudioSession -> Bool in
                    return hasActiveCalls && hasActiveAudioSession
                }
                |> distinctUntilChanged
                
                let hasActiveAudio = combineLatest(queue: .mainQueue(), isPlayingBackgroundAudio, isPlayingBackgroundActiveCall)
                |> map { isPlayingBackgroundAudio, isPlayingBackgroundActiveCall in
                    return isPlayingBackgroundAudio || isPlayingBackgroundActiveCall
                }
                |> distinctUntilChanged
                
                let hasActiveLiveLocationPolling = liveLocationPolling
                |> map { id in
                    return id == account.id
                }
                |> distinctUntilChanged
                
                let hasWatchTasks = watchTasks
                |> map { id in
                    return id == account.id
                }
                |> distinctUntilChanged
                
                let userInterfaceInUse = accountUserInterfaceInUse(account.id)
                
                return combineLatest(queue: .mainQueue(), account.importantTasksRunning, notificationManager?.isPollingState(accountId: account.id) ?? .single(false), hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse)
                |> map { importantTasksRunning, isPollingState, hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse -> (Account, Bool, AccountTasks) in
                    return (account, primary?.id == account.id, AccountTasks(stateSynchronization: isPollingState, importantTasks: importantTasksRunning, backgroundLocation: hasActiveLiveLocationPolling, backgroundDownloads: false, backgroundAudio: hasActiveAudio, activeCalls: hasActiveCalls, watchTasks: hasWatchTasks, userInterfaceInUse: userInterfaceInUse))
                }
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).start(next: { [weak self] accountsAndTasks in
            guard let strongSelf = self else {
                return
            }
            strongSelf.accountsAndTasks = accountsAndTasks
            strongSelf.checkTasks()
        })
    }
    
    deinit {
        self.inForegroundDisposable?.dispose()
        self.hasActiveAudioSessionDisposable?.dispose()
        self.tasksDisposable?.dispose()
        if let (taskId, _, timer) = self.currentTask {
            timer.invalidate()
            self.endBackgroundTask(taskId)
        }
    }
    
    func allowBackgroundTimeExtension(timeout: Double, extendNow: Bool = false) {
        let shouldCheckTasks = self.allowBackgroundTimeExtensionDeadline == nil
        self.allowBackgroundTimeExtensionDeadline = CACurrentMediaTime() + timeout
        if extendNow {
            if self.activeExplicitExtensionTimer == nil {
                self.activeExplicitExtensionTimer = SwiftSignalKit.Timer(timeout: 20.0, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.activeExplicitExtensionTimer?.invalidate()
                    strongSelf.activeExplicitExtensionTimer = nil
                    strongSelf.checkTasks()
                }, queue: .mainQueue())
                self.activeExplicitExtensionTimer?.start()
            }
        }
        if shouldCheckTasks || extendNow {
            self.checkTasks()
        }
    }
    
    func checkTasks() {
        if self.inForeground || self.hasActiveAudioSession {
            if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                timer.invalidate()
                self.endBackgroundTask(taskId)
                self.isInBackgroundExtension = false
            }
        } else {
            var hasTasksForBackgroundExtension = false
            for (_, _, tasks) in self.accountsAndTasks {
                if !tasks.isEmpty {
                    hasTasksForBackgroundExtension = true
                    break
                }
            }
            if self.activeExplicitExtensionTimer != nil {
                hasTasksForBackgroundExtension = true
            }
            
            let canBeginBackgroundExtensionTasks = self.allowBackgroundTimeExtensionDeadline.flatMap({ CACurrentMediaTime() < $0 }) ?? false
            if hasTasksForBackgroundExtension {
                if canBeginBackgroundExtensionTasks {
                    var endTaskId: UIBackgroundTaskIdentifier?
                    
                    let currentTime = CACurrentMediaTime()
                    if let (taskId, startTime, timer) = self.currentTask {
                        if startTime < currentTime + 1.0 {
                            self.currentTask = nil
                            timer.invalidate()
                            endTaskId = taskId
                        }
                    }
                    
                    if self.currentTask == nil {
                        let handleExpiration:() -> Void = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.isInBackgroundExtension = false
                            strongSelf.checkTasks()
                        }
                        if let taskId = self.beginBackgroundTask("background-wakeup", {
                            handleExpiration()
                        }) {
                            let timer = SwiftSignalKit.Timer(timeout: min(30.0, self.backgroundTimeRemaining()), repeat: false, completion: {
                                handleExpiration()
                            }, queue: Queue.mainQueue())
                            self.currentTask = (taskId, currentTime, timer)
                            timer.start()
                            
                            endTaskId.flatMap(self.endBackgroundTask)
                            
                            self.isInBackgroundExtension = true
                        }
                    }
                }
            } else if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                timer.invalidate()
                self.endBackgroundTask(taskId)
                self.isInBackgroundExtension = false
            }
        }
        self.updateAccounts()
    }
    
    private func updateAccounts() {
        if self.inForeground || self.hasActiveAudioSession || self.isInBackgroundExtension || self.activeExplicitExtensionTimer != nil {
            for (account, primary, tasks) in self.accountsAndTasks {
                if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) {
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                } else {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
                account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio))
                account.shouldKeepOnlinePresence.set(.single(primary && self.inForeground))
                account.shouldKeepBackgroundDownloadConnections.set(.single(tasks.backgroundDownloads))
            }
        } else {
            for (account, _, _) in self.accountsAndTasks {
                account.shouldBeServiceTaskMaster.set(.single(.never))
                account.shouldKeepOnlinePresence.set(.single(false))
                account.shouldKeepBackgroundDownloadConnections.set(.single(false))
            }
        }
    }
}

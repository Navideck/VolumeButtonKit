import AVFoundation
import MediaPlayer
import UIKit

private let systemVolumeDidChange = Notification.Name("SystemVolumeDidChange")
private let volumeChangeReasonKey = "Reason"
private let explicitVolumeChangeReason = "ExplicitVolumeChange"
private let mpVolumeSliderClassName = "MPVolumeSlider"

public enum VolumeButtonKitError: Error {
    case noKeyWindow
}

public final class VolumeButtonListener {
    public var onVolumeButtonPressed: ((Bool) -> Void)?
    public var onVolumeButtonReleased: ((Bool) -> Void)?

    public var showsVolumeUi = false {
        didSet {
            if isListening {
                setHiddenVolumeViewVisibility(!showsVolumeUi)
            }
        }
    }

    private let hiddenVolumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    private var previousVolume: Float = 0
    private var isListening = false
    private var notificationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private let debounceInterval: TimeInterval = 0.25
    private var lastPressTime: Date = .distantPast
    private let releaseInactivityInterval: TimeInterval = 0.4
    private let programmaticChangeIgnoreInterval: TimeInterval = 0.3
    private var releaseWorkItem: DispatchWorkItem?
    private var ignoreVolumeChangesUntil: Date = .distantPast

    public init() {
        hiddenVolumeView.subviews.first(where: { $0 is UIButton })?.isHidden = true
        hiddenVolumeView.isUserInteractionEnabled = false
    }

    deinit {
        try? stopListening()
    }

    public func startListening() throws {
        setHiddenVolumeViewVisibility(!showsVolumeUi)
        activateAudioSession()
        previousVolume = AVAudioSession.sharedInstance().outputVolume
        isListening = true

        notificationObserver = NotificationCenter.default.addObserver(
            forName: systemVolumeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSystemVolumeDidChange(notification)
        }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isListening else { return }
            self.activateAudioSession()
            self.previousVolume = AVAudioSession.sharedInstance().outputVolume
        }
    }

    public func stopListening() throws {
        guard isListening else { return }
        isListening = false
        releaseWorkItem?.cancel()
        releaseWorkItem = nil

        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        didBecomeActiveObserver = nil

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObserver = nil
        setHiddenVolumeViewVisibility(false)
    }

    public func listening() -> Bool {
        isListening
    }

    public func getVolume() -> Double {
        Double(AVAudioSession.sharedInstance().outputVolume)
    }

    public func setVolume(_ volume: Double) {
        let vol = Float(min(1, max(0, volume)))
        setSystemVolume(vol)
        if isListening {
            previousVolume = vol
        }
    }

    private var volumeSlider: UISlider? {
        hiddenVolumeView.subviews.first { NSStringFromClass(type(of: $0)) == mpVolumeSliderClassName } as? UISlider
    }

    private func setHiddenVolumeViewVisibility(_ isVisible: Bool) {
        guard let window = keyWindow() else { return }
        if isVisible {
            window.addSubview(hiddenVolumeView)
            hiddenVolumeView.isHidden = false
        } else {
            hiddenVolumeView.removeFromSuperview()
        }
    }

    private func keyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        return UIApplication.shared.windows.first
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("VolumeButtonKit: Failed to activate audio session: \(error)")
        }
    }

    private func handleSystemVolumeDidChange(_ notification: Notification) {
        guard shouldProcessVolumeChange(notification) else { return }
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        guard let isUp = volumeDirection(current: currentVolume, previous: previousVolume) else { return }
        recordPress(isUp: isUp)
        releaseWorkItem?.cancel()
        let isUpForRelease = isUp
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isListening else { return }
            self.onVolumeButtonReleased?(isUpForRelease)
            self.setSystemVolume(self.previousVolume)
        }
        releaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + releaseInactivityInterval, execute: workItem)
    }

    private func shouldProcessVolumeChange(_ notification: Notification) -> Bool {
        guard isListening else { return false }
        if Date() < ignoreVolumeChangesUntil { return false }
        guard let reason = notification.userInfo?[volumeChangeReasonKey] as? String,
              reason == explicitVolumeChangeReason else { return false }
        return true
    }

    private func volumeDirection(current: Float, previous: Float) -> Bool? {
        if current > previous { return true }
        if current < previous { return false }
        if current >= 1.0 { return true }
        if current <= 0 { return false }
        return nil
    }

    private func setSystemVolume(_ volume: Float) {
        ignoreVolumeChangesUntil = Date().addingTimeInterval(programmaticChangeIgnoreInterval)
        volumeSlider?.setValue(volume, animated: false)
    }

    private func recordPress(isUp: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastPressTime) >= debounceInterval else { return }
        lastPressTime = now
        DispatchQueue.main.async { [weak self] in
            self?.onVolumeButtonPressed?(isUp)
        }
    }
}

import AppKit
import UserNotifications

/// Posts a notification whenever a transfer finishes.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Only called once the transfers present at launch are known, so that
    /// transfers which were already finished don't trigger a notification
    func notifyChanges(from old: [Transfer], to new: [Transfer]) {
        let previous = Dictionary(old.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        for transfer in new where transfer.isFinished {
            // Transfers can fail before they are ever seen in progress (e.g.
            // when the device can't be reached), so new ones count as well
            if let state = previous[transfer.id], state == transfer.state { continue }
            post(for: transfer)
        }
    }

    private func post(for transfer: Transfer) {
        let content = UNMutableNotificationContent()
        let device = transfer.displayDeviceName
        switch (transfer.direction, transfer.state) {
        case (.receive, .succeeded):
            content.title = String(localized: "Files received")
            content.body = String(localized: "\(device) sent you some files.")
            content.userInfo = ["reveal": true]
        case (.send, .succeeded):
            content.title = String(localized: "Files sent")
            content.body = String(localized: "\(device) received your files.")
        case (.receive, _):
            content.title = String(localized: "Transfer from \(device) failed")
            content.body = transfer.displayError
        case (.send, _):
            content.title = String(localized: "Transfer to \(device) failed")
            content.body = transfer.displayError
        }
        content.sound = .default
        center.add(UNNotificationRequest(identifier: transfer.id, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.userInfo["reveal"] != nil else { return }
        await MainActor.run {
            AppModel.shared.revealReceivedFiles()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

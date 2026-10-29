import EventKitUI
import SwiftUI

/// Apple's read-only event detail screen.
struct EventDetailView: UIViewControllerRepresentable {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = EKEventViewController()
        controller.event = event
        controller.allowsEditing = false
        controller.allowsCalendarPreview = false
        let dismiss = dismiss
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in dismiss() })
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

/// Sheet item wrapper, since EKEvent isn't Identifiable.
struct ShownEvent: Identifiable {
    let id = UUID()
    let event: EKEvent
}

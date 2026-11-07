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
        // The controller swaps in its own Done button after some interactions, which reports to the delegate.
        controller.delegate = context.coordinator
        let dismiss = dismiss
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in dismiss() })
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        context.coordinator.dismiss = dismiss
        // UIKit doesn't see SwiftUI's tint.
        controller.view.tintColor = context.environment.theme.uiColor(\.accent)
    }

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, EKEventViewDelegate {
        var dismiss: DismissAction

        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            dismiss()
        }
    }
}

/// Sheet item wrapper, since EKEvent isn't Identifiable.
struct ShownEvent: Identifiable {
    let id = UUID()
    let event: EKEvent
}

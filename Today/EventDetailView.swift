import EventKitUI
import SwiftUI

/// Apple's event detail screen, with its own Edit and Delete for events the user can change.
struct EventDetailView: UIViewControllerRepresentable {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = EKEventViewController()
        controller.event = event
        controller.allowsEditing = true
        controller.allowsCalendarPreview = false
        // The controller swaps in its own Done button after some interactions, which reports to the delegate.
        controller.delegate = context.coordinator
        let dismiss = dismiss
        // On the left: the controller puts its Edit button on the right.
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in dismiss() })
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

/// Apple's event editor, for adding an event.
struct EventEditView: UIViewControllerRepresentable {
    let event: EKEvent
    let store: EKEventStore
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {
        context.coordinator.dismiss = dismiss
        // UIKit doesn't see SwiftUI's tint.
        controller.view.tintColor = context.environment.theme.uiColor(\.accent)
    }

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        var dismiss: DismissAction

        init(dismiss: DismissAction) { self.dismiss = dismiss }

        /// The editor has already saved the event, or dropped it on Cancel.
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Sheet item wrapper, since EKEvent isn't Identifiable.
struct ShownEvent: Identifiable {
    let id = UUID()
    let event: EKEvent
}

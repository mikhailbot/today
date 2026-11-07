import SwiftUI
import UIKit

/// Light status bar text over the slab, in light mode too. SwiftUI has no modifier for this while the
/// navigation bar is hidden, but its hosting controller takes the status bar style from a child
/// view controller, so this one sits invisibly in the day view and asks for light content.
struct LightStatusBar: UIViewControllerRepresentable {
    final class Controller: UIViewController {
        override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}
}

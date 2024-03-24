import UIKit
import SwiftUI

struct NavigationControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        // Assuming "Main" is the name of your storyboard and "NavigationController" is the storyboard ID of your UINavigationController
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let navigationController = storyboard.instantiateViewController(withIdentifier: "NavigationController") as! UINavigationController
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Perform any updates to the UINavigationController if necessary
    }
}

import UIKit
import CoreML
import Vision
import ImageIO



@available(iOS 17.0, *)
class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, GuessViewControllerDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var View3: UITextView!
    @IBOutlet weak var scoreLabel: UILabel!
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: recyclingClassifier_3().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { 
                [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    @IBAction func testPhoto(sender: UIButton) {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        present(vc, animated: true)
        DispatchQueue.main.async {
            self.textView.text = "Classifying object. Please wait."
        }
    }
    
    @IBAction func cameraBtn(_ sender: Any) {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        present(vc, animated: true)
        DispatchQueue.main.async {
            self.textView.text = "Classifying object. Please wait."
        }
    }
    
    private func updateDetections(for image: UIImage) {
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                DispatchQueue.main.async {
                    self.textView.text = "Failed to perform detection.\n\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.textView.text = "Unable to detect anything.\n\(error?.localizedDescription ?? "Error")"
                return
            }
            
            if let classifications = results as? [VNClassificationObservation] {
                let topClassifications = classifications.prefix(1) // Taking top 1 results
                let descriptions = topClassifications.map { 
                    classification in
                    return "\(classification.identifier)"
                }
                self.textView.text = "Classification:\n" + descriptions.joined(separator: "\n")
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            // Perform segue and pass the selected image
            self.performSegue(withIdentifier: "showGuessViewController", sender: image)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "showGuessViewController",
               let destinationVC = segue.destination as? GuessViewController,
               let image = sender as? UIImage {
                destinationVC.selectedImage = image
                destinationVC.delegate = self // Set MainViewController as the delegate
            }
        }
    
    func didUpdateScore(score: Int) {
            scoreLabel.text = "Current score: \(score)"
        }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let currentScore = UserDefaults.standard.integer(forKey: "score")
        
        // Update the UI on the main thread
        DispatchQueue.main.async { 
            [weak self] in
            guard let self = self else {
                return
            }
            // Safely unwrapping scoreLabel
            if let scoreLabel = self.scoreLabel {
                scoreLabel.text = "Current score: \(currentScore)"
            }
            
            self.textView?.text = "Tap the photo below to choose an image or use the camera to take a photo and classify objects."
            self.textView?.layer.cornerRadius = 10
            self.View3?.layer.cornerRadius = 10
        }
    }

}

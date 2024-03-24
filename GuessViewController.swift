//
//  ARViewController.swift
//  RecyclingGame
//
//  Created by Ethan Kong on 14/2/2024.
//

import UIKit
import Vision
import CoreML
import SceneKit
import ARKit

protocol GuessViewControllerDelegate: AnyObject {
    func didUpdateScore(score: Int)
}

@available(iOS 17.0, *)
class GuessViewController: UIViewController, ARSCNViewDelegate {
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView! // Connect this IBOutlet to your ARSCNView in the storyboard

    
    var correctClassification: String?
    var selectedImage: UIImage?
    weak var delegate: GuessViewControllerDelegate?
    var imageNode: SCNNode?
    let binNames = ["general", "metal", "plastic", "paper", "organic"]

    
    var score: Int = UserDefaults.standard.integer(forKey: "score") {
        didSet {
            UserDefaults.standard.set(score, forKey: "score")
            delegate?.didUpdateScore(score: score) // Notify the delegate of the score update
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        updateUI()
    }
    
    func setupAR() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        let scene = SCNScene()
        sceneView.scene = scene
        setupBins(scene: scene)

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        // Changed to pan gesture for dragging functionality
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
    }
    
    func setupBins(scene: SCNScene) {
            
            // Define the positions for each bin in the AR space
            let binPositions = [
                SCNVector3(x: -2, y: 0.5, z: -1.5),
                SCNVector3(x: -1, y: 0.5, z: -1.5),
                SCNVector3(x: 0, y: 0.5, z: -1.5),
                SCNVector3(x: 1, y: 0.5, z: -1.5),
                SCNVector3(x: 2, y: 0.5, z: -1.5)
            ]

            for (index, binName) in binNames.enumerated() {
                let binNode = createBinNode(named: binName)
                binNode.position = binPositions[index]
                scene.rootNode.addChildNode(binNode)
            }
        }
    
    func createBinNode(named binName: String) -> SCNNode {
        // Create the visual bin node (unchanged size)
        let plane = SCNPlane(width: 1, height: 1)
        plane.firstMaterial?.diffuse.contents = UIImage(named: binName)
        let binNode = SCNNode(geometry: plane)
        binNode.name = binName // Use this for hit testing

        
        return binNode
    }

    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        switch gesture.state {
        case .began:
            // Attempt to find an existing image node if touched
            let hitResults = sceneView.hitTest(location, options: nil)
            if hitResults.first(where: { $0.node == imageNode }) != nil {
                // Node is already set from when the image was classified
                return
            }
        case .changed:
            guard let node = imageNode, let currentFrame = sceneView.session.currentFrame else { return }
            let location = gesture.location(in: sceneView)

            // Use the camera's transform to calculate the position in 3D space.
            let cameraTransform = currentFrame.camera.transform
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            
            // Convert the 2D touch location to 3D using the depth of the current node position.
            // This assumes the sceneView has been properly configured to track the AR session.
            let projectedOrigin = sceneView.projectPoint(SCNVector3(x: 0, y: 0, z: node.position.z))
            let locationIn3D = sceneView.unprojectPoint(SCNVector3(Float(location.x), Float(location.y), projectedOrigin.z))

            // Update the node's position. This operation should be fast enough to be done directly without needing to dispatch to the main queue.
            node.position = SCNVector3(1.5*locationIn3D.x, 1.5*locationIn3D.y, node.position.z)

        case .ended:
            if let node = imageNode {
                let binHitTestResults = sceneView.hitTest(location, options: nil)
                var touchedBinName: String? = nil

                // Check if the image is over any bin
                for hitResult in binHitTestResults {
                    if let binName = hitResult.node.name, binNames.contains(binName.lowercased()) {
                        touchedBinName = binName
                        break
                    }
                }

                if let touchedBinName = touchedBinName {
                    // Check if it's the correct bin
                    if touchedBinName.lowercased() == correctClassification?.lowercased() {
                        score += 1
                        classificationLabel.text = "Correct! +1 point"
                        node.removeFromParentNode()
                        imageNode = nil
                    } else {
                        // Incorrect bin
                        let correctAnswer = correctClassification ?? "unknown"
                        classificationLabel.text = "Sorry, that is incorrect. Try again."
                        // Optionally reset the node's position or provide other feedback
                        node.position = SCNVector3(x: 0, y: -0.5, z: -1.5)
                    }
                    delegate?.didUpdateScore(score: score)
                } else {
                    // No bin was touched; provide feedback or reset position as needed
                    classificationLabel.text = "Try to place the item in a bin."
                    node.position = SCNVector3(x: 0, y: -0.5, z: -1.5)
                }
            }
        default:
            break

        }
    }

    func createImageNode(for image: UIImage) -> SCNNode {
        let plane = SCNPlane(width: 0.2, height: 0.2) // Adjust the size as needed
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.lightingModel = .constant // Prevents the image from being affected by scene lighting

        let imageNode = SCNNode(geometry: plane)
        imageNode.position = SCNVector3(x: 0, y: -0.5, z: -1.5) // Place the node in front of the camera
        imageNode.name = "classifiedImage"
        
        return imageNode
    }

    
    func updateUI() {
        if let image = selectedImage {
            classifyImage(image: image)
            // This creates an AR node for the selected image and adds it to the scene
            imageNode = createImageNode(for: image)
            if let imageNode = imageNode {
                sceneView.scene.rootNode.addChildNode(imageNode)
            }
        } else {
            print("Selected image is nil.")
        }
    }
    
    private func classifyImage(image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            fatalError("Couldn't convert UIImage to CIImage")
        }

        // Ensure you have a Core ML model configured correctly as a VNCoreMLModel
        guard let model = try? VNCoreMLModel(for: recyclingClassifier_3().model) else {
            fatalError("Can't load ML model")
        }

        // Create the request with the model and completion handler
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let results = request.results as? [VNClassificationObservation],
                   let topResult = results.first {
                    self.correctClassification = topResult.identifier
                    self.classificationLabel.text = "Drag your garbage into the bin you think is correct."
                } else {
                    self.classificationLabel.text = "Classification: Unknown"
                }
            }
        }


        // Create a handler to perform the request on the image
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.classificationLabel.text = "Error performing request: \(error.localizedDescription)"
                }
            }
        }
    }


    
    
    // Add more functions here for AR interactions, bin setup, and game logic...
}

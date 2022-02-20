import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: - Outlest
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    /// Array of placed objects
    var objectsPlaced = [SCNNode]()
    
    /// Array of planes found
    var planeNodes = [SCNNode]()
    
    /// The node for the object currently selected by the user
    var selectedNode: SCNNode?
    
    // MARK: - Methods
    /// Adds an object in 20 cm in front of the camera
    /// - Parameter node: node of the object to add
    func addNodeInFront(_ node: SCNNode) {
        // Get current camera frame
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Get transform property of the camera
        let transform = frame.camera.transform
        
        // Create translation matrix
        var translation = matrix_identity_float4x4
        
        // Translate by 20 cm in front of the camera
        translation.columns.3.z = -0.2
        
        // Rotate by pi/2 on z axis
        translation.columns.0.x = 0
        translation.columns.1.x = -1
        translation.columns.0.y = 1
        translation.columns.1.y = 0
        
        // Assign transform to the node
        node.simdTransform = matrix_multiply(transform, translation)
        
        // Add node to the scene
        addNodeToSceneRoot(node)
    }
    
    /// Adds a node at user's touch location represented by point
    /// - Parameters:
    ///   - node: node to be added
    ///   - point: point at which user touched the screen
    func addNode(_ node: SCNNode, at point: CGPoint) {
        guard let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else { return }
        guard let anchor = hitResult.anchor as? ARPlaneAnchor, anchor.alignment == .horizontal else { return }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    // Add object on scene
    func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        // Clone node for creating separate copies of the object
        let clonedNode = node.clone()
        
        // Remember object placed for undo
        objectsPlaced.append(clonedNode)

        // Add cloned node to the scene
        parentNode.addChildNode(clonedNode)
    }
    
    func addNodeToSceneRoot(_ node: SCNNode) {
        addNode(node, to: sceneView.scene.rootNode)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func reloadConfiguration() {
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, let selectedNode = selectedNode else { return }
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .plane:
            addNode(selectedNode, at: point)
        case .image:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Actions
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
    }
}

// MARK: - OptionsViewControllerDelegate
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
        
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
}

extension ViewController: ARSCNViewDelegate {
    
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        // Get estimated plane size
        let extent = planeAnchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 0.5)
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi/2
        
        return planeNode
    }
    
    // Add plane node found
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let planeNode = createFloor(planeAnchor: anchor)
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let planeAnchor as ARPlaneAnchor:
            nodeAdded(node, for: planeAnchor)
        default:
            print("Unknown anchor type is found")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let planeAnchor as ARPlaneAnchor:
            updateFloor(for: node, anchor: planeAnchor)
        default:
            print("Unknown anchor type is updated")
        }
    }
    
    func updateFloor(for node: SCNNode, anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            print("Can't find SCNPlane at node \(node)")
            return
        }
        
        // Get estimated plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
        // Position the plane in the center
        planeNode.simdPosition = anchor.center
    }
}

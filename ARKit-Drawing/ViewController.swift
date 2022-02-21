import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: - Outlest
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    /// Visualize planes
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach { $0.isHidden = arePlanesHidden }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Last node placed by user
    var lastNode: SCNNode?
    
    /// Minimum distance between objects placed when moving
    let minimumDistance: Float = 0.01 //Можно использовать SCNBoundingVolume для опред размеров объекта, чтобы ставить след объект
                                      // вне границ предыдущего
    var minDist: Float {
        if lastNode != nil {
            let min = lastNode!.boundingBox.min
            let max = lastNode!.boundingBox.max
            let x = max.x - min.x
            let y = max.y - min.y
            let z = max.z - min.z
           
            return (x*x + y*y + z*z)
        } else {
            return 0
        }
    }
    
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
        
        // Check that the object is not too close to the previous one when moving
        if let lastNode = lastNode {
            let lastPosition = lastNode.position
            let newPosition = node.position
            
            let x = lastPosition.x - newPosition.x
            let y = lastPosition.y - newPosition.y
            let z = lastPosition.z - newPosition.z
            
            let distanceSquare = sqrtf(x*x + y*y + z*z)
            let minimumDistanceSquare = minimumDistance*minimumDistance
            let minDistSquare = sqrtf(minDist)
            guard minDistSquare <= distanceSquare else { return }
//            print(minDistSquare, distanceSquare)
//            guard minimumDistanceSquare < distanceSquare else { return }
        }
        
        // Clone node for creating separate copies of the object
        let clonedNode = node.clone()
        
        // Remember last node to make minimum distance between it and next node when moving
        lastNode = clonedNode
//        let bxmax = lastNode?.boundingBox.max
//        let bxmin = lastNode?.boundingBox.min
//        let dif = CGFloat(bxmax!.x - bxmin!.x)
//        print(dif)
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
    
    func process(_ touches: Set<UITouch>) {
        
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
    
    func reloadConfiguration() {
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        lastNode = nil
        process(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        process(touches)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
//        sceneView.debugOptions = .showBoundingBoxes
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
            arePlanesHidden = true
        case 1:
            objectMode = .plane
            arePlanesHidden = false
        case 2:
            objectMode = .image
            arePlanesHidden = true
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
        guard objectMode == .plane else { return }
        arePlanesHidden.toggle()
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
        planeNode.isHidden = arePlanesHidden
        
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

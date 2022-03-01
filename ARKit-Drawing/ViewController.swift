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
    
    var choosedNode: SCNNode?
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Last node placed by user
    var lastNode: SCNNode?
    
    /// Minimum distance between objects placed when moving
    var minimumDistance: Float = 0.05
    
    enum ObjectPlacementMode {
        case freeform, plane, image, move
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
    private func addNodeInFront(_ node: SCNNode) {
        // Get current camera frame
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Get transform property of the camera
        let transform = frame.camera.transform
        
        // Create translation matrix
        var translation = matrix_identity_float4x4
        
        // Translate by 40 cm in front of the camera
        translation.columns.3.z = -0.4
        
        // Rotate by pi/2 on z axis
        translation.columns.0.x = 0
        translation.columns.1.x = -1
        translation.columns.0.y = 1
        translation.columns.1.y = 0
        
        // Assign transform to the node
        node.simdTransform = matrix_multiply(transform, translation)
        
        node.name = "space"
        // Add node to the scene
        addNodeToSceneRoot(node)
    }
    
    /// Adds a node at user's touch location represented by point
    /// - Parameters:
    ///   - node: node to be added
    ///   - point: point at which user touched the screen
    private func addNode(_ node: SCNNode, at point: CGPoint) {
        guard let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else { return }
        guard let anchor = hitResult.anchor as? ARPlaneAnchor, anchor.alignment == .horizontal else { return }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    // Add object on scene
    private func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        
        // Check that the object is not too close to the previous one when moving
        if let lastNode = lastNode {
            // Geting distance between last node and current node
            let lastPosition = lastNode.position
            let newPosition = node.position
            let distanceBetweenNodes = newPosition.distance(to: lastPosition)
            
            guard minimumDistance < distanceBetweenNodes else { return }
            
        }
        
        // Clone node for creating separate copies of the object
        let clonedNode = node.clone()
        
        // Remember last node to make minimum distance between it and next node when moving
        lastNode = clonedNode
        
        // Remember object placed for undo
        objectsPlaced.append(clonedNode)
        
        // Add cloned node to the scene
        parentNode.addChildNode(clonedNode)
        
    }
    
    private func addNodeToImage(_ node: SCNNode, at point: CGPoint) {
        
        guard let result = sceneView.hitTest(point, options: [:]).first else { return }
        guard result.node.name == "image" else { return }
        node.eulerAngles.x = .pi/2
        addNode(node, to: result.node)
    }
    
    private func addNodeToSceneRoot(_ node: SCNNode) {
        
        addNode(node, to: sceneView.scene.rootNode)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    private func process(_ touches: Set<UITouch>) {
        
        guard let touch = touches.first, let selectedNode = selectedNode else { return }
        let point = touch.location(in: sceneView)
        
        let previousLocation = touch.previousLocation(in: sceneView)
        let transformX = point.x - previousLocation.x
        let transformY = point.y - previousLocation.y
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .plane:
            addNode(selectedNode, at: point)
        case .image:
            addNodeToImage(selectedNode, at: point)
        case .move:
            
            getNode(at: point)
            
            guard let foundNode = choosedNode else { return }
            
            moveNode(foundNode, at: point, vector: SCNVector3(transformX, 0, transformY))
            
        }
    }
    
    // Get node of existing object to move
    private func getNode(at point: CGPoint) {
        
        let results = sceneView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        guard let result = results.first else { return }
        guard result.node.name != "floor", result.node.name != "image" else { return }
        
        if objectsPlaced.contains(result.node) {
            
            choosedNode = result.node
        
        } else {
            
            choosedNode = result.node.parent
        }
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        choosedNode = nil
    }
    
    
    private func moveNode(_ node: SCNNode, at point: CGPoint, vector: SCNVector3) {
        let name1 = node.name
        let name2 = node.parent?.name
        
        if name1 == "space" || name2 == "space" {
            // Moving object in space
            guard sceneView.session.currentFrame != nil else { return }
            
            // Get current camera frame
            guard let frame = sceneView.session.currentFrame else { return }
            
            // Get transform property of the camera
            let transform = frame.camera.transform
            
            let k: Float = 300
            
            // Create translation matrix
            var translation = matrix_identity_float4x4
            
            // Rotate by pi/2 on z axis
            translation.columns.0.x = 0
            translation.columns.1.x = -1
            translation.columns.0.y = 1
            translation.columns.1.y = 0
            
            translation.columns.3.x = vector.x / k
            //translation.columns.3.y = vector.y / k
            translation.columns.3.z = -0.4
            //translation.columns.3.z = vector.z / k
            
            node.simdWorldTransform = matrix_multiply(transform , translation)
            
        } else {
            // Moving object on a plane
            guard let hitResult = sceneView.hitTest(point, types: .existingPlane).first else { return }
            node.simdWorldTransform = hitResult.worldTransform
        }
    }
    
    private func reloadConfiguration(reset: Bool = false) {
        // Clear objects placed
        objectsPlaced.forEach { $0.removeFromParentNode() }
        objectsPlaced.removeAll()
        
        // Clear planes placed
        planeNodes.forEach { $0.removeFromParentNode() }
        planeNodes.removeAll()
        
        // Remove existing anchors if reset is true
        let options: ARSession.RunOptions = reset ? .removeExistingAnchors : []
        
        // Reload configuration
        configuration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: options)
    }
    
    override internal func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        lastNode = nil
        process(touches)
    }
    
    override internal func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        process(touches)
    }
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override internal func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override internal func viewWillDisappear(_ animated: Bool) {
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
        case 3:
            objectMode = .move
        default:
            break
        }
    }
}

// MARK: - OptionsViewControllerDelegate
extension ViewController: OptionsViewControllerDelegate {
    
    internal func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
        
        // Defining minimum distance by bounding box X axis of selected object
        if let child = selectedNode?.childNodes.first {
            
            let childX = child.boundingBox.max.x - child.boundingBox.min.x
            let parentX = selectedNode!.boundingBox.max.x - selectedNode!.boundingBox.min.x
            
            minimumDistance = childX <= parentX ? childX : parentX
        } else {
            minimumDistance = selectedNode!.boundingBox.max.x - selectedNode!.boundingBox.min.x
        }
        
    }
    
    internal func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        guard objectMode == .plane else { return }
        arePlanesHidden.toggle()
    }
    
    internal func undoLastObject() {
        
        if let lastObject = objectsPlaced.last {
            lastObject.removeFromParentNode()
            objectsPlaced.removeLast()
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    internal func resetScene() {
        reloadConfiguration(reset: true)
        dismiss(animated: true, completion: nil)
        
    }
}

extension ViewController: ARSCNViewDelegate {
    
    private func createFloor(with size: CGSize, opacity: CGFloat = 0.5) -> SCNNode {
        
        let plane = SCNPlane(width: size.width, height: size.height)
        //        plane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: opacity)
        plane.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(opacity)
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi/2
        
        return planeNode
    }
    
    
    private func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        
        // Put a plane at the image
        let size = anchor.referenceImage.physicalSize
        let coverNode = createFloor(with: size, opacity: 0.01)
        coverNode.name = "image"
        node.addChildNode(coverNode)
    }
    
    // Add plane node found
    private func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let extent = anchor.extent
        let size = CGSize(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = createFloor(with: size)
        planeNode.isHidden = arePlanesHidden
        planeNode.name = "floor"
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            nodeAdded(node, for: imageAnchor)
        case let planeAnchor as ARPlaneAnchor:
            nodeAdded(node, for: planeAnchor)
        default:
            print("Unknown anchor type is found")
        }
    }
    
    internal func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case is ARImageAnchor:
            break
        case let planeAnchor as ARPlaneAnchor:
            updateFloor(for: node, anchor: planeAnchor)
        default:
            print("Unknown anchor type is updated")
        }
    }
    
    private func updateFloor(for node: SCNNode, anchor: ARPlaneAnchor) {
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

extension SCNVector3 {
    func distance(to vector: SCNVector3) -> Float {
        return simd_distance(simd_float3(self), simd_float3(vector))
    }
}

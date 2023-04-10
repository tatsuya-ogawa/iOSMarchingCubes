//
//  ViewController.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/09.
//

import UIKit
import SceneKit
import ModelIO
import SceneKit.ModelIO
import SwiftEaglePly
import SwiftStanfordBunny
import MetalKit

struct ModelPoint:EaglePointProtocol,BunnyPointProtocol,GridInput{
    var pos: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD4<UInt8>
    init(pos: SIMD3<Float>, normal: SIMD3<Float>, color: SIMD4<UInt8>) {
        self.pos = pos
        self.normal = normal
        self.color = color
    }
}
class ViewController: UIViewController {
    var grid:Grid?
    func compute(){
        let model = SwiftStanfordBunny<ModelPoint>.instance()
        let points = try! model.load()
        grid = Grid(inputs:points)
        if let grid = grid{
            let computeShader = ComputeShader()
            try! computeShader.run(grid: grid)
        }
    }
    var cameraNode: SCNNode!
    var modelNode: SCNNode!
    var sceneView:SCNView?
    func setup(asset:MDLAsset){
        sceneView = SCNView(frame: view.frame)
        if let sceneView = sceneView{
            view.addSubview(sceneView)
            let scene = SCNScene(mdlAsset: asset)
            sceneView.scene = scene
            
            cameraNode = SCNNode()
            let camera = SCNCamera()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
            scene.rootNode.addChildNode(cameraNode)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            sceneView.addGestureRecognizer(pinchGesture)
//            let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
//            sceneView.addGestureRecognizer(rotationGesture)
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            sceneView.addGestureRecognizer(panGesture)
            
            let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(x: 0, y: 5, z: 5)
            scene.rootNode.addChildNode(lightNode)
            
            
            modelNode = scene.rootNode.childNode(withName: "model", recursively: true)!
//            // ボックスを作成する
            let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.red
            box.materials = [material]
            let boxNode = SCNNode(geometry: box)
            scene.rootNode.addChildNode(boxNode)
        }
    }
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = Float(gesture.scale)
        cameraNode.position.z /= scale
        gesture.scale = 1
    }
    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        let angle = Float(gesture.rotation)
        cameraNode.eulerAngles.y -= angle
        gesture.rotation = 0
    }
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view!)
        modelNode.eulerAngles.y +=  Float(translation.x) * .pi / 360
        modelNode.eulerAngles.x +=  Float(translation.y) * .pi / 360
        gestureRecognizer.setTranslation(CGPoint.zero, in: sceneView)
    }
    @objc func exportAsset(sender:Any) {
        if let grid = grid{
//            let fileName = "marchingCube.usda"
            let fileName = "marchingCube.obj"
            let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            try! grid.asset?.export(to: filePath)
            
            let activityItems = [filePath]
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            let excludedActivityTypes = [
                UIActivity.ActivityType.postToFacebook,
                UIActivity.ActivityType.postToTwitter,
                UIActivity.ActivityType.message,
                //                UIActivity.ActivityType.saveToCameraRoll,
                UIActivity.ActivityType.print
            ]
            activityVC.excludedActivityTypes = excludedActivityTypes
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    func setupButton(){
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        view.addSubview(stackView)
        stackView.spacing = UIStackView.spacingUseSystem
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            //            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        let exportButton = UIButton()
        exportButton.setTitle("Export", for: .normal)
        exportButton.backgroundColor = UIColor.blue
        exportButton.layer.cornerRadius = 10.0
        exportButton.addTarget(self, action: #selector(exportAsset), for: .touchUpInside)
        stackView.addArrangedSubview(exportButton)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        DispatchQueue.global().async {
            self.compute()
            DispatchQueue.main.async {
                self.setup(asset: self.grid!.asset!)
                self.setupButton()
            }
        }
    }
}


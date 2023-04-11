//
//  Renderer.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/10.
//

import Foundation
import SceneKit
import Metal
class Renderer{
    var cameraNode: SCNNode!
    var modelNode: SCNNode!
    var sceneView:SCNView?
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = Float(gesture.scale)
        cameraNode.position.z /= scale
        gesture.scale = 1
    }
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view!)
        modelNode.eulerAngles.y +=  Float(translation.x) * .pi / 360
        modelNode.eulerAngles.x +=  Float(translation.y) * .pi / 360
        gestureRecognizer.setTranslation(CGPoint.zero, in: sceneView)
    }
    func render(sceneView:SCNView,asset:MDLAsset){
        let scene = SCNScene(mdlAsset: asset)
        sceneView.scene = scene
        
        cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 5, z: 5)
        scene.rootNode.addChildNode(lightNode)
        
        modelNode = scene.rootNode.childNode(withName: "model", recursively: true)!
        let boundingBox = modelNode.boundingBox
        
        
        let scale = 1/max(boundingBox.max.x - boundingBox.min.x, boundingBox.max.y - boundingBox.min.y, boundingBox.max.z - boundingBox.min.z)
        modelNode.scale = SCNVector3(scale, scale, scale)        
    }
}

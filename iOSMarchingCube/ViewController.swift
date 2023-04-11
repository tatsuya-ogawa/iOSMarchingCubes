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
    let renderer = Renderer()
    func compute(){
        let model = SwiftStanfordBunny<ModelPoint>.instance()
        let points = try! model.load()
        grid = Grid(inputs:points,dimensions: SIMD3<Int>(50,50,50))
        if let grid = grid{
            let computeShader = ComputeShader()
            try! computeShader.run(grid: grid)
        }
    }
    func setup(asset:MDLAsset){
        let sceneView = SCNView(frame: view.frame)
        view.addSubview(sceneView)
        renderer.render(sceneView: sceneView, asset: asset)
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
                UIActivity.ActivityType.saveToCameraRoll,
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


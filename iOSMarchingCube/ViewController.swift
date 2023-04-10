//
//  ViewController.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/09.
//

import UIKit
import SwiftStanfordBunny
struct BunnyPoint:BunnyPointProtocol,GridInput{
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
    func load(){
        let bunny = SwiftStanfordBunny<BunnyPoint>.instance()
        let points = try! bunny.load()
        let grid = Grid(points)
        let computeShader = ComputeShader()
        try! computeShader.run(grid: grid)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        load()
    }
}


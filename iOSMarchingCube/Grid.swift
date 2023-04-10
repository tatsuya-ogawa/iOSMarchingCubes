//
//  Grid.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/10.
//

import Foundation
import simd
import Metal
public protocol GridInput{
    var pos:SIMD3<Float> { get set }
    var normal:SIMD3<Float>{ get set }
    var color: SIMD4<UInt8>{ get set }
}
class Grid{
    let maxVertexPerGrid = 12
    let gridSize:Int=20
    let isoValue:Float = 0.5
    var points:[TableVertex] = []
    func initialize(_ inputs:[GridInput]){
        let corner = inputs.reduce((min:SIMD3<Float>(Float.greatestFiniteMagnitude,Float.greatestFiniteMagnitude,Float.greatestFiniteMagnitude),max:SIMD3<Float>(Float.leastNormalMagnitude,Float.leastNormalMagnitude,Float.leastNormalMagnitude))){ (tuple,item) in
            let min = SIMD3<Float>(min(item.pos.x,tuple.min.x),min(item.pos.y,tuple.min.y),min(item.pos.z,tuple.min.z))
            let max = SIMD3<Float>(max(item.pos.x,tuple.max.x),max(item.pos.y,tuple.max.y),max(item.pos.z,tuple.max.z))
            return (min:min,max:max)
        }
        let step = (corner.max - corner.min) / Float(gridSize-1)
        points = (0..<self.gridSize).flatMap{z in
            (0..<self.gridSize).flatMap{y in
                (0..<self.gridSize).map{x in
                    let pos = corner.min + SIMD3<Float>(step.x*Float(x),step.y*Float(y),step.z*Float(z))
                    return TableVertex(pos: pos, normal: SIMD3<Float>.one, color: SIMD4<Float>.one, weight: 0)
                }
            }
        }
        for input in inputs {
            let gridOffset = (input.pos - corner.min)/step
            let indice = Int(gridOffset.x) + Int(gridOffset.y)*Int(gridSize) + Int(gridOffset.z)*Int(gridSize)*Int(gridSize)
            points[indice].weight = 1.0
        }
    }
    init(_ inputs:[GridInput]){
        self.initialize(inputs)
    }
    
    var buffers:[MTLBuffer] {
        get {
            [gridBuffer!,controlBuffer!,verticesBuffer!,vCounterBuffer!,indicesBuffer!,iCounterBuffer!]
        }
    }
    var gridBuffer:MTLBuffer?
    var controlBuffer:MTLBuffer?
    var verticesBuffer:MTLBuffer?
    var vCounterBuffer:MTLBuffer?
    var indicesBuffer:MTLBuffer?
    var iCounterBuffer:MTLBuffer?
    func update(device:MTLDevice){
        gridBuffer = device.makeBuffer(bytes: self.points, length: self.points.count * MemoryLayout<TableVertex>.size, options: [])
        var control = MarchingCubeControl(isoValue: self.isoValue, GSPAN: UInt32(self.gridSize))
        controlBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<MarchingCubeControl>.size, options: [])
        verticesBuffer = device.makeBuffer(length: self.points.count * MemoryLayout<TableVertex>.size * maxVertexPerGrid, options: [.storageModeShared])
        var vCounter:Int32 = 0
        vCounterBuffer = device.makeBuffer(bytes: &vCounter , length: MemoryLayout<UInt32>.stride, options: [])
        indicesBuffer = device.makeBuffer(length: self.points.count * MemoryLayout<UInt32>.size * maxVertexPerGrid, options: [.storageModeShared])
        var iCounter:Int32 = 0
        iCounterBuffer = device.makeBuffer(bytes: &iCounter , length: MemoryLayout<UInt32>.stride, options: [])
    }
    func finish(){
        let iCounter = iCounterBuffer?.contents().assumingMemoryBound(to: UInt32.self).pointee
        let indicesPointer = indicesBuffer?.contents().bindMemory(to: UInt32.self, capacity: Int(iCounter!))
        let indices = Array(UnsafeBufferPointer(start: indicesPointer, count: Int(iCounter!)))
        let vCounter = vCounterBuffer?.contents().assumingMemoryBound(to: UInt32.self).pointee
        let verticesPointer = verticesBuffer?.contents().bindMemory(to: TableVertex.self, capacity: Int(vCounter!))
        let vertices = Array(UnsafeBufferPointer(start: verticesPointer, count: Int(vCounter!)))
    }
}

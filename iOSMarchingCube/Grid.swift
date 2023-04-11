//
//  Grid.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/10.
//

import Foundation
import simd
import Metal
import ModelIO
public protocol GridInput{
    var pos:SIMD3<Float> { get set }
    var normal:SIMD3<Float>{ get set }
    var color: SIMD4<UInt8>{ get set }
}
class Grid{
    let maxVertexPerGrid = 12
    let dimensions:SIMD3<Int>
    let isoValue:Float
    var points:[TableVertex] = []
    var scale:SIMD3<Float> = SIMD3<Float>.zero
    var corner:(min:SIMD3<Float>,max:SIMD3<Float>) = (min:SIMD3<Float>(Float.greatestFiniteMagnitude,Float.greatestFiniteMagnitude,Float.greatestFiniteMagnitude),max:SIMD3<Float>(Float.leastNormalMagnitude,Float.leastNormalMagnitude,Float.leastNormalMagnitude))
    init(inputs:[GridInput],dimensions:SIMD3<Int>,isoValue:Float = 0.4){
        self.dimensions = dimensions
        self.isoValue = isoValue
        corner = inputs.reduce(corner){ (tuple,item) in
            let min = SIMD3<Float>(min(item.pos.x,tuple.min.x),min(item.pos.y,tuple.min.y),min(item.pos.z,tuple.min.z))
            let max = SIMD3<Float>(max(item.pos.x,tuple.max.x),max(item.pos.y,tuple.max.y),max(item.pos.z,tuple.max.z))
            return (min:min,max:max)
        }
        scale = (corner.max - corner.min) / SIMD3<Float>(Float(dimensions.x-1),Float(dimensions.y-1),Float(dimensions.z-1))
        points = (0..<dimensions.z).flatMap{z in
            (0..<self.dimensions.y).flatMap{y in
                (0..<self.dimensions.x).map{x in
                    let pos = corner.min + SIMD3<Float>(scale.x*Float(x),scale.y*Float(y),scale.z*Float(z))
                    return TableVertex(pos: pos, normal: SIMD3<Float>.zero, color: SIMD4<Float>.zero, weight: 0)
                }
            }
        }
        for input in inputs {
            let gridOffset = (input.pos - corner.min)/scale
            for i in -1...1 {
                for j in -1...1 {
                    for k in -1...1 {
                        let x:Int = Int(gridOffset.x)+k
                        let y:Int = Int(gridOffset.y)+j
                        let z:Int = Int(gridOffset.z)+i
                        if 0..<dimensions.x ~= x && 0..<dimensions.y ~= y && 0..<dimensions.z ~= z  {
                            let indice = x + y*dimensions.x + z*dimensions.x*dimensions.y
                            // grid space distance
                            let distance=simd_distance(input.pos/scale,points[indice].pos/scale+SIMD3<Float>(Float(k),Float(j),Float(i))) / sqrtf(3)
                            if points[indice].weight < 1-distance {
                                points[indice].weight = 1-distance
                                points[indice].normal = input.normal
                                points[indice].color = SIMD4<Float>(0,0,1,1)
                            }
                        }
                    }
                }
            }
        }
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
    func clear(blitCommandEncoder:MTLBlitCommandEncoder){
        blitCommandEncoder.fill(buffer: verticesBuffer!, range: 0..<self.points.count * MemoryLayout<TableVertex>.size * maxVertexPerGrid, value: 0)
    }
    func update(device:MTLDevice){
        gridBuffer = device.makeBuffer(bytes: self.points, length: self.points.count * MemoryLayout<TableVertex>.size, options: [])
        var control = MarchingCubeControl(isoValue: self.isoValue, GSPAN: UInt32(self.dimensions.x))
        controlBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<MarchingCubeControl>.size, options: [])
        verticesBuffer = device.makeBuffer(length: self.points.count * MemoryLayout<TableVertex>.size * maxVertexPerGrid, options: [.storageModeShared])
        var vCounter:Int32 = 0
        vCounterBuffer = device.makeBuffer(bytes: &vCounter , length: MemoryLayout<UInt32>.stride, options: [])
        indicesBuffer = device.makeBuffer(length: self.points.count * MemoryLayout<UInt32>.size * maxVertexPerGrid, options: [.storageModeShared])
        var iCounter:Int32 = 0
        iCounterBuffer = device.makeBuffer(bytes: &iCounter , length: MemoryLayout<UInt32>.stride, options: [])
    }
    var asset:MDLAsset?
    func finish(){
        let iCounter = iCounterBuffer?.contents().assumingMemoryBound(to: UInt32.self).pointee
        let indicesPointer = indicesBuffer?.contents().bindMemory(to: UInt32.self, capacity: Int(iCounter!))
        let indices = Array(UnsafeBufferPointer(start: indicesPointer, count: Int(iCounter!)))
        let vCounter = vCounterBuffer?.contents().assumingMemoryBound(to: UInt32.self).pointee
        let verticesPointer = verticesBuffer?.contents().bindMemory(to: TableVertex.self, capacity: Int(vCounter!))
        let vertices = Array(UnsafeBufferPointer(start: verticesPointer, count: Int(vCounter!)))
        
        let allocator = MDLMeshBufferDataAllocator()
        let triangleIndicesBuffer = allocator.newBuffer(
            with: Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.stride),
            type: .index
        )
        let subMesh = MDLSubmesh(
            indexBuffer: triangleIndicesBuffer,
            indexCount: indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil
        )
        let vertexDescriptor = MDLVertexDescriptor()
        let positionAttribute = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        let normalAttribute = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: MemoryLayout<SIMD3<Float>>.stride,
            bufferIndex: 0
        )
        let colorAttribute = MDLVertexAttribute(
            name: MDLVertexAttributeColor,
            format: .float4,
            offset: MemoryLayout<SIMD3<Float>>.stride*2,
            bufferIndex: 0
        )
        vertexDescriptor.attributes = [positionAttribute,normalAttribute,colorAttribute]
        vertexDescriptor.layouts = [MDLVertexBufferLayout(stride: MemoryLayout<TableVertex>.stride)]
        
        let verticesBuffer = allocator.newBuffer(
            with: Data(bytes: vertices, count: vertices.count * MemoryLayout<TableVertex>.stride),
            type: .vertex
        )
        let mdlMesh = MDLMesh(
            vertexBuffer: verticesBuffer,
            vertexCount: vertices.count,
            descriptor: vertexDescriptor,
            submeshes: [subMesh]
        )
        mdlMesh.name = "model"
        asset = MDLAsset()
        asset?.add(mdlMesh)
    }
}

//
//  ComputeShader.swift
//  iOSMarchingCube
//
//  Created by Tatsuya Ogawa on 2023/04/10.
//

import Foundation
import Metal
import MetalKit
class ComputeShader{
   
    func run(grid:Grid)throws{
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        grid.update(device: device)
        
        let library = device.makeDefaultLibrary()
        guard let function = library?.makeFunction(name: "computeShader")else{
            fatalError("library?.makeFunction")
        }
        let pipelineState = try device.makeComputePipelineState(function: function)
        let commandQueue = device.makeCommandQueue()
        let commandBuffer = commandQueue?.makeCommandBuffer()
        if let blitCommandEncoder = commandBuffer?.makeBlitCommandEncoder() {
            grid.clear(blitCommandEncoder: blitCommandEncoder)
            blitCommandEncoder.endEncoding()
        }
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(pipelineState)
        for (index,buffer) in grid.buffers.enumerated(){
            commandEncoder?.setBuffer(buffer, offset: 0, index: index)
        }        
        let threadSize = 8
        let threadGroupSize = MTLSize(width: threadSize, height: threadSize, depth: threadSize)
        let gridSize = MTLSize(width: (grid.dimensions.x + threadSize-1) / threadSize, height: (grid.dimensions.y + threadSize-1) / threadSize, depth: (grid.dimensions.z + threadSize-1) / threadSize)
        
        commandEncoder?.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadGroupSize)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        grid.finish()
    }
}

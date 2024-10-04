
//
//  SECP256k1.swift
//  SECP256k1
//
//  Created by Nicky Reinert on 26.09.24.
//

@preconcurrency import Metal
import MetalPerformanceShaders
import Foundation
import CoreGraphics
import Accelerate
import MetalKit


struct UInt256 {
    var values: [UInt8] // Assuming a 256-bit value can be represented as an array of 32 UInt8 (bytes)
    
    init() {
        self.values = Array(repeating: 0, count: 32) // Initialize with 32 zeros
    }
    
    init(values: [UInt8]) {
        assert(values.count == 32, "Array must have 32 bytes for UInt256")
        self.values = values
    }
    
    // Add other necessary initializers or methods as needed
}

let metallib =  "\(#file.replacingOccurrences(of: "/wrapper.swift", with: ""))/../computation.metallib"

@available(macOS 10.13, *)
let device = MTLCreateSystemDefaultDevice()!

// Function to create a compressed public key
func compressedPublicKey(x: UInt256, y: UInt256) -> [UInt8] {
    var compressedKey = [UInt8]()
    
    // Determine the prefix based on the parity of the Y coordinate
    if (y.values[31] & 0x01) == 0 { // Check if Y is even
        compressedKey.append(0x02) // Prefix for even Y
    } else {
        compressedKey.append(0x03) // Prefix for odd Y
    }
    
    // Append the X coordinate (32 bytes)
    compressedKey.append(contentsOf: x.values)
    
    return compressedKey
}

@available(macOS 10.13, *)
@_cdecl("runMetalComputation")
public func runMetalComputation(privateKeys: UnsafePointer<UInt8>, numKeys: Int) -> UnsafeMutablePointer<UInt8>? {
    
    do {
        // Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Unable to create Metal device.")
            return nil
        }
        
        print("Device name: \(device.name), isLowPower: \(device.isLowPower), isRemovable: \(device.isRemovable)")
        
        // Metal library
        guard let library = try? device.makeLibrary(filepath: metallib) else {
            print("Error: Unable to create Metal library from \(metallib).")
            return nil
        }

        print("Library loaded.")

        // Load the 'calculatePublicKeys' function from the Metal library
        guard let kernelFunction = library.makeFunction(name: "calculatePublicKeys") else {
            print("Error: Unable to load calculatePublicKeys function.")
            return nil
        }

        print("Metal function initialized.")

        let computePipelineState = try device.makeComputePipelineState(function: kernelFunction)

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Unable to create command queue.")
            return nil
        }

        print("Compute queue initialized.")

        // Create a command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Error: Unable to create command buffer or encoder.")
            return nil
        }

        print("Command buffer initialized.")

        // Create the compute pipeline state
        encoder.setComputePipelineState(computePipelineState)
        
        print("Compute pipeline initialized.")

        // Create Metal buffer for private keys
        let privateKeyBuffer = device.makeBuffer(bytes: privateKeys, length: numKeys * 32, options: .storageModeShared)

        // Create Metal buffers for the public keys (64 bytes per public key for X and Y)
        let publicKeyBufferX = device.makeBuffer(length: numKeys * 32, options: .storageModeShared)
        let publicKeyBufferY = device.makeBuffer(length: numKeys * 32, options: .storageModeShared)

        // Set the buffers (private keys, public keys X, public keys Y)
        encoder.setBuffer(privateKeyBuffer, offset: 0, index: 0)
        encoder.setBuffer(publicKeyBufferX, offset: 0, index: 1)
        encoder.setBuffer(publicKeyBufferY, offset: 0, index: 2)

        print("Buffer initialized.")

        // TESTING
        let maxTotalThreadsPerThreadgroup = computePipelineState.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth = computePipelineState.threadExecutionWidth
        let width = maxTotalThreadsPerThreadgroup / threadExecutionWidth * threadExecutionWidth
        let threadgroups = MTLSize(width: (numKeys + width - 1) / width, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: width, height: 1, depth: 1)
        
        // Dispatch threads
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)

        print("Parallel threads initialized.")

        encoder.endEncoding()
        // Commit the command buffer and wait until completed
        commandBuffer.commit()
        print("Computing started.")
        
        commandBuffer.waitUntilCompleted()

        let publicKeyPointerX = publicKeyBufferX!.contents().bindMemory(to: UInt32.self, capacity: numKeys * 8)
        let publicKeyPointerY = publicKeyBufferY!.contents().bindMemory(to: UInt32.self, capacity: numKeys * 8)

        // Create publicKeysArray with correct byte order
        var publicKeysArray = [UInt8]()
        for i in 0..<numKeys {
            for j in 0..<8 {
                let xValue = publicKeyPointerX[i * 8 + j].bigEndian
                publicKeysArray.append(UInt8((xValue >> 24) & 0xFF))
                publicKeysArray.append(UInt8((xValue >> 16) & 0xFF))
                publicKeysArray.append(UInt8((xValue >> 8) & 0xFF))
                publicKeysArray.append(UInt8(xValue & 0xFF))
            }
            for j in 0..<8 {
                let yValue = publicKeyPointerY[i * 8 + j].bigEndian
                publicKeysArray.append(UInt8((yValue >> 24) & 0xFF))
                publicKeysArray.append(UInt8((yValue >> 16) & 0xFF))
                publicKeysArray.append(UInt8((yValue >> 8) & 0xFF))
                publicKeysArray.append(UInt8(yValue & 0xFF))
            }
        }

        // Allocate and return the public keys
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: publicKeysArray.count)
        result.initialize(from: publicKeysArray, count: publicKeysArray.count)

        return result
        
    } catch {
        print("Error: \(error)")
        return nil
    }
    
}

/*
    BENCHMARK
 
 */
@available(macOS 10.13, *)
@_cdecl("benchmark")
public func benchmark(inputData: UnsafePointer<Float>,
                      outputData: UnsafeMutablePointer<Float>,
                      numItems: Int) -> Int {
    
    do {
        // Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Error: Unable to create Metal device.")
            return 0
        }

        // Metal library (assuming the .metallib path is known and available)
        guard let library = try? device.makeLibrary(filepath: metallib) else {
            print("Error: Unable to create Metal library from \(metallib).")
            return 0
        }

        // Load the 'benchmark' function from the Metal library
        guard let kernelFunction = library.makeFunction(name: "benchmark") else {
            print("Error: Unable to load benchmark function.")
            return 0
        }

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Unable to create command queue.")
            return 0
        }

        // Create a command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Error: Unable to create command buffer or encoder.")
            return 0
        }

        // Create the compute pipeline state
        let computePipelineState = try device.makeComputePipelineState(function: kernelFunction)

        // Set the compute pipeline state
        encoder.setComputePipelineState(computePipelineState)

        // Create input buffer for GPU
        let inputByteLength = numItems * MemoryLayout<Float>.size
        let inputBuffer = device.makeBuffer(bytes: inputData, length: inputByteLength, options: [])
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)

        // Create output buffer for GPU
        let outVectorBuffer = device.makeBuffer(length: inputByteLength, options: .storageModeShared)
        encoder.setBuffer(outVectorBuffer, offset: 0, index: 1)

        // Configure threadgroups
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (numItems + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)

        // Finalize command encoding
        encoder.endEncoding()

        // Commit and wait for execution
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Copy the GPU results to the output buffer passed from Python
        if let outputPointer = outVectorBuffer?.contents().assumingMemoryBound(to: Float.self) {
            outputData.update(from: outputPointer, count: numItems)
        } else {
            print("Error: Unable to get contents from output buffer.")
            return 1
        }

        return 0
    } catch {
        print("Error in Metal execution: \(error)")
        return 1
    }
}


/*
    TESTING
 
 */

@available(macOS 10.13, *)
@_cdecl("runMetalTests")
public func runMetalTests() {
    
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("Metal is not supported on this device")
    }
    print("Device name: \(device.name), isLowPower: \(device.isLowPower), isRemovable: \(device.isRemovable)")
    
    guard let commandQueue = device.makeCommandQueue() else {
        fatalError("Failed to create command queue")
    }
    print("Command queue created successfully")

        
    let numTests = 1 // Increase this as you add more tests
    let resultBuffer = device.makeBuffer(length: MemoryLayout<Bool>.stride * numTests, options: [])!
    let debugBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * 40, options: [])!

    print("Result buffer length: \(resultBuffer.length)")
    print("Debug buffer length: \(debugBuffer.length)")

    let library = try! device.makeLibrary(filepath: metallib)
    guard let runTestsFunction = library.makeFunction(name: "runTests") else {
        print("Unable to create runTests function")
        return
    }
    
    let pipelineState = try! device.makeComputePipelineState(function: runTestsFunction)
    print("Compute pipeline state created successfully")

    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        fatalError("Failed to create command buffer")
    }
    print("Command buffer created successfully")
    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
        fatalError("Failed to create compute command encoder")
    }
    print("Compute encoder created successfully")

    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setBuffer(resultBuffer, offset: 0, index: 0)
    computeEncoder.setBuffer(debugBuffer, offset: 0, index: 1)
    print("Buffers set successfully")
    
    computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    print("Threads dispatched successfully")

    computeEncoder.endEncoding()
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    print("Command buffer executed successfully")

    let resultPointer = resultBuffer.contents().bindMemory(to: Bool.self, capacity: numTests)
    let debugPointer = debugBuffer.contents().bindMemory(to: UInt32.self, capacity: 40)

    print("Metal Test Results:")
    let testPassed = resultPointer.pointee
    print("addMod test: \(testPassed ? "PASSED" : "FAILED")")

    print("\nDebug Output:")
    let labels = ["a", "b", "m", "actual", "expected"]
    for i in 0..<5 {
        print("\(labels[i]):")
        for j in 0..<8 {
            print(String(format: "%08X", debugPointer[i * 8 + j]), terminator: " ")
        }
        print()
    }

    
}

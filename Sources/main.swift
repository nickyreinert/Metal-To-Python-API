import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders
import CoreGraphics
import Accelerate
import Wrapper  // Import the dynamic library

// swift package clean; swift build; .build/debug/TestMetalComputation

@available(macOS 10.13, *)
func runComputation() {
    let numKeys = 3
    let keyLength = 32
    
    // Create dummy private keys
    //
    // Private Key: 0000000000000000000000000000000000000000000000000000000000000001
    // Public Key X: 79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
    // Public Key Y: 483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
    // Compresed: 0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798

    var privateKeys = [UInt8](repeating: 0x00, count: numKeys * keyLength)
    // Set the first private key to 0x01
    privateKeys[keyLength - 1] = 0x01

    // Generate random private keys for the rest
    for i in 1..<numKeys {
        let startIndex = i * keyLength
        let endIndex = startIndex + keyLength
        
        // Generate random bytes
        var randomBytes = [UInt8](repeating: 0, count: keyLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, keyLength, &randomBytes)
        
        // Ensure the random key is less than the curve order
        let curveOrder: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                                   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
                                   0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
                                   0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41]
        
        var isLessThan = false
        for j in 0..<keyLength {
            if randomBytes[j] < curveOrder[j] {
                isLessThan = true
                break
            } else if randomBytes[j] > curveOrder[j] {
                break
            }
        }
        
        if !isLessThan {
            // If not less than, set to a value slightly less than the curve order
            randomBytes = curveOrder
            randomBytes[keyLength - 1] -= 1
        }
        
        // Copy the random bytes to the privateKeys array
        privateKeys.replaceSubrange(startIndex..<endIndex, with: randomBytes)
    }

    
    print("Calling computation library.")

    if let result = runMetalComputation(privateKeys: &privateKeys, numKeys: numKeys) {
        print("Public keys computed successfully.")

        // Convert result to array of UInt8
        let publicKeysArray = Array(UnsafeBufferPointer(start: result, count: numKeys * 64))
        
        // Display private and public keys
        for i in 0..<numKeys {
            // Print Private Key
            let privateKeyStartIndex = i * keyLength
            let privateKey = privateKeys[privateKeyStartIndex..<privateKeyStartIndex + keyLength]
            print("Private Key[\(i)]: \(privateKey.map { String(format: "%02X", $0) }.joined())")
            
            // Print Public Key
            let publicKeyStartIndex = i * 64
            let publicKeyX = publicKeysArray[publicKeyStartIndex..<publicKeyStartIndex + 32]  // X coordinate (32 bytes)
            let publicKeyY = publicKeysArray[publicKeyStartIndex + 32..<publicKeyStartIndex + 64]  // Y coordinate (32 bytes)
            
            print("Public Key[\(i)]:")
            
            // Convert X coordinate to hex string
            let hexX = publicKeyX.map { String(format: "%02X", $0) }.joined()
            print("X: \(hexX)")
            
            // Convert Y coordinate to hex string
            let hexY = publicKeyY.map { String(format: "%02X", $0) }.joined()
            print("Y: \(hexY)")
            
            // Check if Y is even or odd (look at the last byte of Y)
            let prefix = publicKeyY.last! & 1 == 0 ? "02" : "03"

            // Compressed public key
            let compressedPublicKey = prefix + hexX
            print("Compressed Public Key: \(compressedPublicKey)")
            
            print() // Add a blank line for readability between key pairs
        }

        
        // Free the result pointer
        result.deallocate()
        
    } else {
        print("Error: Metal computation failed.")
    }
}


@available(macOS 10.13, *)
@available(macOS 10.13, *)
func runBenchmark(numItems: Int) {
    print("\nRunning benchmark")
    
    // Step 1: Create an array of N 32-bit floats (Float)
    var inputData = [Float](repeating: 0.0, count: numItems)

    // Populate the array with sequential numbers
    for i in 0..<numItems {
        inputData[i] = Float(i) // Sequential floats
    }

    inputData.withUnsafeBufferPointer { bufferPointer in
        guard let baseAddress = bufferPointer.baseAddress else {
            print("Error: Unable to get base address of input data.")
            return
        }

        // Step 2: Create a separate output buffer
        var localOutputBuffer = [Float](repeating: 0.0, count: numItems)
        
        // Step 2.1: Create a mutable pointer for the output buffer
        let outputPointer = UnsafeMutablePointer<Float>.allocate(capacity: numItems)
        defer {
            outputPointer.deallocate()  // Ensure the pointer gets deallocated to avoid memory leaks
        }

        // Start time measurement
        let startTime = CFAbsoluteTimeGetCurrent()

        // Step 3: Call the benchmark function using the input and output pointers
        let result = benchmark(inputData: baseAddress, outputData: outputPointer, numItems: numItems)

        // End time measurement
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // Step 4: Copy the results from the output pointer into the localOutputBuffer array
        localOutputBuffer.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress?.update(from: outputPointer, count: numItems)
        }

        // Step 5: Check if the result indicates success
        if result == 0 {
            // Print the results if not in silent mode
            if !silentMode {
                print("Input and Output data:")
                for i in 0..<numItems {
                    let inputValue = inputData[i]
                    let outputValue = localOutputBuffer[i]
                    print("Input \(i): \(inputValue) -> Output \(i): \(outputValue)")
                }
            }
        } else {
            print("Error: Benchmark function returned failure.")
        }

        // Print elapsed time
        print("Elapsed time: \(elapsedTime) seconds")
    }

    print("Done.")
}



@available(macOS 10.13, *)
func runTests() {
    
    print("\nRunning Metal tests:")
    runMetalTests()
}

var silentMode: Bool = false
var numItems: Int = 10000

if #available(macOS 10.13, *) {
    
    // Check command line arguments
    let arguments = CommandLine.arguments
    silentMode = arguments.contains("--silent") || arguments.contains("-s")
    // Check for numItems flag and read the integer value
    if let numItemsIndex = arguments.firstIndex(of: "--numItems") ?? arguments.firstIndex(of: "-n") {
        if numItemsIndex + 1 < arguments.count, let num = Int(arguments[numItemsIndex + 1]) {
            numItems = num
        } else {
            print("Error: Please provide a valid integer value for numItems.")
            exit(1) // Exit if invalid value is provided
        }
    }
    
    // Ensure there is at least one argument for the function name
    if arguments.count > 1 {
        let functionToRun = arguments[1] // Get the first argument after the program name
        
        switch functionToRun {
        case "runComputation":
            runComputation()
        case "runBenchmark":
            runBenchmark(numItems: numItems) // Replace 100 with desired number of items
        case "runTests":
            runTests()
        default:
            print("Unknown function: \(functionToRun). Please specify 'runComputation', 'runBenchmark', or 'runTests'.")
        }
    } else {
        print("Please specify a function to run: 'runComputation', 'runBenchmark', or 'runTests'. runBechmark also takes --silent or -s to disable debug output or --numItems or -n to specify amount of numbers to calculate ")
    }
    
} else {
    
    print("Error: macOS 10.13 or later is required.")
    
}

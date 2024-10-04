// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MetalComputation",
    platforms: [
        .macOS(.v10_13)  // Specify the minimum macOS version required for Metal
    ],
    products: [
        // Define the dynamic library product
        .library(
            name: "Wrapper",
            type: .dynamic,
            targets: ["Wrapper"]
        ),
        // Define the executable product
        .executable(
            name: "MetalComputation",
            targets: ["MetalComputation"]
        ),
    ],
    targets: [
        // Dynamic library target
        .target(
            name: "Wrapper",
            path: "Sources",    // Same folder for simplicity
            exclude: ["main.swift"]  // Exclude main.swift from this target
        ),
        // Executable target
        .executableTarget(
            name: "MetalComputation",
            dependencies: ["Wrapper"],
            path: "Sources",    // Same folder for simplicity
            exclude: ["wrapper.swift"]  // Exclude SECP256k1.swift from this target
        ),
    ])

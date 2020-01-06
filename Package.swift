// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ssg",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "ssg", targets: ["ssg"]),
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.0.0"),
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.0.0"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.0.0")
    ],
    targets: [
        .target(name: "ssg", dependencies: []),
        .testTarget(name: "ssgTests", dependencies: ["ssg"]),
    ]
)

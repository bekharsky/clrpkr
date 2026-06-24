// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PipetkaCore",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "PipetkaCore", targets: ["PipetkaCore"])
  ],
  targets: [
    .target(name: "PipetkaCore", dependencies: [])
  ]
)

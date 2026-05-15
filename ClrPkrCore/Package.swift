// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ClrPkrCore",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "ClrPkrCore", targets: ["ClrPkrCore"])
  ],
  targets: [
    .target(name: "ClrPkrCore", dependencies: [])
  ]
)

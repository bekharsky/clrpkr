// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ClrPkrMCP",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(path: "../ClrPkrCore")
  ],
  targets: [
    .executableTarget(
      name: "clrpkr-mcp",
      dependencies: ["ClrPkrCore"],
      path: "Sources/ClrPkrMCP"
    )
  ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ClrPkrMCP",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "clrpkr-mcp",
      path: "Sources/ClrPkrMCP"
    )
  ]
)

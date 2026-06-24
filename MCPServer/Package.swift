// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "PipetkaMCP",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(path: "../PipetkaCore")
  ],
  targets: [
    .executableTarget(
      name: "pipetka-mcp",
      dependencies: ["PipetkaCore"],
      path: "Sources/PipetkaMCP"
    )
  ]
)

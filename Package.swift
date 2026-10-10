// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ClothesDock", platforms: [.macOS(.v14)], products: [.executable(name: "ClothesDock", targets: ["ClothesDock"])], targets: [.executableTarget(name: "ClothesDock"), .testTarget(name: "ClothesDockTests", dependencies: ["ClothesDock"])])

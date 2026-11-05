// swift-tools-version:5.9
import PackageDescription

// Foundation만 쓰는 순수 판단 로직. Linux(Docker swift 이미지)에서도 `swift test`로 검증한다.
let package = Package(
    name: "HockeyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HockeyCore", targets: ["HockeyCore"]),
    ],
    targets: [
        .target(name: "HockeyCore"),
        .testTarget(name: "HockeyCoreTests", dependencies: ["HockeyCore"]),
    ]
)

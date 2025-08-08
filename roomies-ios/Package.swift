// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Roomies",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Roomies",
            targets: ["Roomies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0"),
        .package(url: "https://github.com/realm/realm-swift", from: "10.45.0")
    ],
    targets: [
        .target(
            name: "Roomies",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "RealmSwift", package: "realm-swift")
            ]),
        .testTarget(
            name: "RoomiesTests",
            dependencies: ["Roomies"]),
    ]
)

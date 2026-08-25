// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacHealth",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacHealth",
            path: "MacHealth",
            exclude: [
                "Assets.xcassets",
                "MacHealth.entitlements",
                "MacHealthApp.swift",
                "Helpers",
                "Models/DeviceInfo.swift",
                "Services/MacDiagnosticService.swift",
                "Services/ReportGenerator.swift",
                "Services/iPhoneDiagnosticService.swift",
                "Views/ContentView.swift",
                "Views/MacDiagnosticsView.swift",
                "Views/iPhoneDiagnosticsView.swift",
                "Views/ReportView.swift"
            ],
            sources: [
                "App/MacHealthApp.swift",
                "Core/Extensions.swift",
                "Core/Shell.swift",
                "Models/CommonModels.swift",
                "Models/MacModels.swift",
                "Models/iPhoneModels.swift",
                "Models/NetworkModels.swift",
                "Services/MacDiagService.swift",
                "Services/NetworkService.swift",
                "Services/iPhoneService.swift",
                "Services/USBMonitorService.swift",
                "Services/HardwareTestService.swift",
                "Services/ReportService.swift",
                "Views/Sidebar/MainView.swift",
                "Views/Dashboard/DashboardView.swift",
                "Views/Mac/MacOverviewView.swift",
                "Views/Network/NetworkToolsView.swift",
                "Views/USB/USBMonitorView.swift",
                "Views/Tests/HardwareTestsView.swift",
                "Views/iPhone/iPhoneMainView.swift",
                "Views/Report/ReportView.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)

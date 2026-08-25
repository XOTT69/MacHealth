import Foundation

struct PhoneData {
    var deviceName: String = "—"
    var modelName: String = "—"
    var productType: String = "—"
    var serialNumber: String = "—"
    var imei: String = "—"
    var iosVersion: String = "—"
    var buildVersion: String = "—"
    var wifiMAC: String = "—"
    var bluetoothMAC: String = "—"
    var batteryLevel: Int = 0
    var batteryHealth: Int = 100
    var totalStorage: String = "—"
    var freeStorage: String = "—"
    var activationStatus: String = "—"
    var isConnected: Bool = false
    
    var batteryLevel_health: HealthLevel {
        if batteryHealth >= 85 { return .excellent }
        else if batteryHealth >= 70 { return .good }
        else if batteryHealth >= 50 { return .warning }
        else { return .critical }
    }
    
    static let modelMap: [String: String] = [
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone14,5": "iPhone 13",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone13,2": "iPhone 12",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone11,8": "iPhone XR",
        "iPhone11,2": "iPhone XS",
        "iPhone11,6": "iPhone XS Max",
        "iPhone10,6": "iPhone X",
    ]
}

struct USBDevice: Identifiable {
    let id = UUID()
    var name: String = "—"
    var vendorID: String = "—"
    var productID: String = "—"
    var serialNumber: String = "—"
    var speed: String = "—"
    var manufacturer: String = "—"
}

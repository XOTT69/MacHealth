import SwiftUI

// MARK: - Color Extensions

extension Color {
    static func statusColor(_ status: HealthLevel) -> Color {
        switch status {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Double Extensions

extension Double {
    var formattedGB: String {
        if self >= 1000 {
            return String(format: "%.1f ТБ", self / 1000)
        }
        return String(format: "%.1f ГБ", self)
    }
    
    var formattedPercent: String {
        String(format: "%.0f%%", self)
    }
    
    var formattedTemp: String {
        String(format: "%.1f°C", self)
    }
}

// MARK: - String Extensions

extension String {
    var notEmpty: String? {
        isEmpty ? nil : self
    }
    
    var orDash: String {
        isEmpty ? "—" : self
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
    
    func sectionCard() -> some View {
        self
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(.background))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

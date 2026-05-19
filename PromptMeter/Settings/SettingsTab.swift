enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case providers = "Providers"
    case display = "Display"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .providers:
            return "square.grid.2x2"
        case .display:
            return "eye"
        case .advanced:
            return "slider.horizontal.3"
        case .about:
            return "info.circle"
        }
    }
}

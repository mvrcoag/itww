import Foundation
import Observation

public enum ModelBackend: String, CaseIterable, Codable, Identifiable, Sendable {
    case onDevice
    case privateCloudCompute

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onDevice: "Apple Intelligence (On-Device)"
        case .privateCloudCompute: "Apple Intelligence (Private Cloud Compute)"
        }
    }

    public var subtitle: String {
        switch self {
        case .onDevice:
            "Runs locally on your Mac with SystemLanguageModel. Fast, private, works offline."
        case .privateCloudCompute:
            "Uses PrivateCloudComputeLanguageModel with automatic fallback to On-Device if unavailable."
        }
    }
}

@MainActor
@Observable
public final class AppSettings {
    private enum Keys {
        static let shortcut = "itww.shortcut"
        static let defaultMode = "itww.defaultMode"
        static let modelBackend = "itww.modelBackend"
        static let showDiff = "itww.showDiff"
        static let customStyleRules = "itww.customStyleRules"
        static let temperature = "itww.temperature"
        static let hasCompletedOnboarding = "itww.hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    public var shortcut: HotKeyShortcut {
        didSet { saveShortcut() }
    }

    public var defaultMode: RewriteMode {
        didSet { defaults.set(defaultMode.rawValue, forKey: Keys.defaultMode) }
    }

    public var modelBackend: ModelBackend {
        didSet { defaults.set(modelBackend.rawValue, forKey: Keys.modelBackend) }
    }

    public var showDiff: Bool {
        didSet { defaults.set(showDiff, forKey: Keys.showDiff) }
    }

    public var customStyleRules: String {
        didSet { defaults.set(customStyleRules, forKey: Keys.customStyleRules) }
    }

    public var temperature: Double {
        didSet { defaults.set(temperature, forKey: Keys.temperature) }
    }

    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.shortcut),
           let decoded = try? JSONDecoder().decode(HotKeyShortcut.self, from: data) {
            self.shortcut = decoded
        } else {
            self.shortcut = .default
        }

        if let rawMode = defaults.string(forKey: Keys.defaultMode),
           let mode = RewriteMode(rawValue: rawMode) {
            self.defaultMode = mode
        } else {
            self.defaultMode = .improve
        }

        if let rawBackend = defaults.string(forKey: Keys.modelBackend),
           let backend = ModelBackend(rawValue: rawBackend) {
            self.modelBackend = backend
        } else {
            self.modelBackend = .onDevice
        }

        if defaults.object(forKey: Keys.showDiff) != nil {
            self.showDiff = defaults.bool(forKey: Keys.showDiff)
        } else {
            self.showDiff = false
        }

        self.customStyleRules = defaults.string(forKey: Keys.customStyleRules) ?? ""

        if defaults.object(forKey: Keys.temperature) != nil {
            self.temperature = defaults.double(forKey: Keys.temperature)
        } else {
            self.temperature = 0.2
        }

        if defaults.object(forKey: Keys.hasCompletedOnboarding) != nil {
            self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        } else {
            self.hasCompletedOnboarding = false
        }
    }

    private func saveShortcut() {
        if let encoded = try? JSONEncoder().encode(shortcut) {
            defaults.set(encoded, forKey: Keys.shortcut)
        }
    }
}

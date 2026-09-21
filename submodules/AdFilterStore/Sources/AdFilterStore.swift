import Foundation
import TelegramCore
import AccountContext
import SwiftSignalKit

public struct AdFilterRule: Codable, Equatable, Identifiable {
    public var id: String
    public var pattern: String
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, pattern: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
    }
}

public struct AdFilterPeerConfig: Codable, Equatable {
    public var peerId: Int64
    public var rules: [AdFilterRule]

    public init(peerId: Int64, rules: [AdFilterRule] = []) {
        self.peerId = peerId
        self.rules = rules
    }
}

public struct AdFilterSettings: Codable, Equatable {
    public var configs: [AdFilterPeerConfig]
    public var isEnabled: Bool
    public var foldEnabled: Bool

    public init(configs: [AdFilterPeerConfig] = [], isEnabled: Bool = true, foldEnabled: Bool = true) {
        self.configs = configs
        self.isEnabled = isEnabled
        self.foldEnabled = foldEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case configs
        case isEnabled
        case foldEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.configs = try container.decodeIfPresent([AdFilterPeerConfig].self, forKey: .configs) ?? []
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.foldEnabled = try container.decodeIfPresent(Bool.self, forKey: .foldEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.configs, forKey: .configs)
        try container.encode(self.isEnabled, forKey: .isEnabled)
        try container.encode(self.foldEnabled, forKey: .foldEnabled)
    }

    public func configForPeer(_ peerId: Int64) -> AdFilterPeerConfig? {
        return self.configs.first { $0.peerId == peerId }
    }

    public func rulesForPeer(_ peerId: Int64) -> [AdFilterRule] {
        return self.configForPeer(peerId)?.rules ?? []
    }

    public func activeRulesForPeer(_ peerId: Int64) -> [AdFilterRule] {
        return self.rulesForPeer(peerId).filter { $0.isEnabled }
    }

    public func compiledRegexesForPeer(_ peerId: Int64) -> [NSRegularExpression] {
        return self.activeRulesForPeer(peerId).compactMap { rule in
            return try? NSRegularExpression(pattern: rule.pattern, options: [])
        }
    }
}

public final class AdFilterStore {
    private static let key = "naisigram_ad_filter_settings_v1"

    public static let shared = AdFilterStore()

    private var cachedSettings: AdFilterSettings?
    private var cachedRegexes: [Int64: [NSRegularExpression]] = [:]
    private let queue = Queue()

    private init() {
        self.cachedSettings = self.loadFromDefaults()
    }

    private func loadFromDefaults() -> AdFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: AdFilterStore.key),
              let settings = try? JSONDecoder().decode(AdFilterSettings.self, from: data) else {
            return AdFilterSettings()
        }
        return settings
    }

    private func saveToDefaults(_ settings: AdFilterSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: AdFilterStore.key)
            self.cachedSettings = settings
            self.cachedRegexes.removeAll()
        }
    }

    public func cachedCompiledRegexesForPeer(_ peerId: Int64) -> [NSRegularExpression] {
        if let cached = self.cachedRegexes[peerId] {
            return cached
        }
        let regexes = self.currentSettings().compiledRegexesForPeer(peerId)
        self.cachedRegexes[peerId] = regexes
        return regexes
    }

    public func currentSettings() -> AdFilterSettings {
        return self.cachedSettings ?? self.loadFromDefaults()
    }

    public func updateSettings(_ f: @escaping (AdFilterSettings) -> AdFilterSettings) {
        let current = self.currentSettings()
        let updated = f(current)
        self.saveToDefaults(updated)
    }

    public func setRulesForPeer(_ peerId: Int64, rules: [AdFilterRule]) {
        self.updateSettings { settings in
            var configs = settings.configs
            if let index = configs.firstIndex(where: { $0.peerId == peerId }) {
                configs[index] = AdFilterPeerConfig(peerId: peerId, rules: rules)
            } else {
                configs.append(AdFilterPeerConfig(peerId: peerId, rules: rules))
            }
            return AdFilterSettings(configs: configs)
        }
    }

    public func getRulesForPeer(_ peerId: Int64) -> [AdFilterRule] {
        return self.currentSettings().rulesForPeer(peerId)
    }

    public func addRule(_ rule: AdFilterRule, forPeer peerId: Int64) {
        var rules = self.getRulesForPeer(peerId)
        rules.append(rule)
        self.setRulesForPeer(peerId, rules: rules)
    }

    public func removeRule(id: String, forPeer peerId: Int64) {
        var rules = self.getRulesForPeer(peerId)
        rules.removeAll { $0.id == id }
        self.setRulesForPeer(peerId, rules: rules)
    }

    public func toggleRule(id: String, forPeer peerId: Int64) {
        var rules = self.getRulesForPeer(peerId)
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            self.setRulesForPeer(peerId, rules: rules)
        }
    }

    public func updateRule(id: String, pattern: String, forPeer peerId: Int64) {
        var rules = self.getRulesForPeer(peerId)
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].pattern = pattern
            self.setRulesForPeer(peerId, rules: rules)
        }
    }

    // MARK: - Import / Export

    public func exportAllSettings() -> Data? {
        let settings = self.currentSettings()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(settings)
    }

    public func importSettings(from data: Data) -> Bool {
        guard let settings = try? JSONDecoder().decode(AdFilterSettings.self, from: data) else {
            return false
        }
        self.saveToDefaults(settings)
        return true
    }
}

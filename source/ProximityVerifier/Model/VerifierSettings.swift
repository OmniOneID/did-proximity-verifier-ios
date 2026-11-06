//
/*
 * Copyright 2026 OmniOne.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import MdocReader

enum TransportKind: String, Codable, CaseIterable, Identifiable {
    case ble
    case nfc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ble: return "BLE"
        case .nfc: return "NFC"
        }
    }
}

enum BleTransferMode: String, Codable, CaseIterable, Identifiable {
    case central
    case peripheral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .central: return "Central client mode"
        case .peripheral: return "Peripheral server mode"
        }
    }
}

struct VerifierSettings: Codable, Equatable {
    var useL2CAP: Bool = false
    var skipIssuerAuth: Bool = MdocReaderConfiguration().skipIssuerAuth
    var bleTransferMode: BleTransferMode = .peripheral
    var transportOrder: [TransportKind] = TransportKind.allCases

    static let defaultTransportOrder: [TransportKind] = TransportKind.allCases

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        useL2CAP = (try? c.decode(Bool.self, forKey: .useL2CAP)) ?? false
        skipIssuerAuth = (try? c.decode(Bool.self, forKey: .skipIssuerAuth))
            ?? MdocReaderConfiguration().skipIssuerAuth
        bleTransferMode = (try? c.decode(String.self, forKey: .bleTransferMode))
            .flatMap(BleTransferMode.init(rawValue:)) ?? .peripheral
        let raw = (try? c.decode([String].self, forKey: .transportOrder)) ?? []
        let known = raw.compactMap(TransportKind.init(rawValue:))
        transportOrder = known.isEmpty ? Self.defaultTransportOrder : known
    }

    mutating func toggleTransport(_ kind: TransportKind) {
        if let index = transportOrder.firstIndex(of: kind) {
            guard transportOrder.count > 1 else { return }
            transportOrder.remove(at: index)
        } else {
            transportOrder.append(kind)
        }
    }

    var transportSummary: String {
        let names = transportOrder.map(\.label)
        if names.count == 1 { return "Only \(names[0]) is used." }
        return names.joined(separator: "  →  ")
    }
}

extension VerifierSettings {
    var readerConfiguration: MdocReaderConfiguration {
        var configuration = MdocReaderConfiguration()
        configuration.transmissionPriority = transportOrder.map(kind(of:))
        configuration.blePreferredMode = preference(for: bleTransferMode)
        configuration.l2capUpgrade = useL2CAP
        configuration.skipIssuerAuth = skipIssuerAuth
        return configuration
    }

    private func preference(for mode: BleTransferMode) -> BleModePreference {
        switch mode {
        case .central: return .central
        case .peripheral: return .peripheral
        }
    }

    private func kind(of transport: TransportKind) -> TransmissionKind {
        switch transport {
        case .ble: return .ble
        case .nfc: return .nfc
        }
    }
}

@MainActor
enum SettingsStore {
    private static let key = "verifier.settings"

    static func load() -> VerifierSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(VerifierSettings.self, from: data) else {
            return VerifierSettings()
        }
        return value
    }

    static func save(_ settings: VerifierSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

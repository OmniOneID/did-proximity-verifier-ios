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

/// The servers the trusted issuer cache is downloaded from (screen spec TI-E-13). Order is fixed.
enum ServerEndpoint: String, CaseIterable, Identifiable {
    /// Serves the trusted issuer list.
    case tas = "TAS_URL"
    /// Serves each issuer's DID Document.
    case apiGateway = "API_GW_URL"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tas: return "TAS"
        case .apiGateway: return "API Gateway"
        }
    }

    /// Build default, used while the endpoint is in the Default section.
    var defaultValue: String {
        switch self {
        case .tas: return "http://192.168.3.110:8090"
        case .apiGateway: return "http://192.168.3.110:8093"
        }
    }
}

/// Custom endpoint values saved by the Server URL screen (TI-E-16).
///
/// Only Custom entries are stored — key present means Custom, absent means Default. Storing just the effective URLs
/// would lose a Custom value that happens to equal the build default (TI-E-14), which must come back in the Custom
/// section on re-entry. Values are read on every request, so a save applies immediately without a restart.
enum ServerURLStore {
    private static let key = "serverURL.custom"

    static func value(_ endpoint: ServerEndpoint, defaults: UserDefaults = .standard) -> String {
        customValues(defaults: defaults)[endpoint] ?? endpoint.defaultValue
    }

    static func customValues(defaults: UserDefaults = .standard) -> [ServerEndpoint: String] {
        let stored = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        return stored.reduce(into: [:]) { acc, pair in
            guard let endpoint = ServerEndpoint(rawValue: pair.key) else { return }
            acc[endpoint] = pair.value
        }
    }

    /// Effective URL per endpoint for a Custom set — the basis for the cache-clear decision (TI-E-17).
    static func effectiveValues(for custom: [ServerEndpoint: String]) -> [ServerEndpoint: String] {
        ServerEndpoint.allCases.reduce(into: [:]) { acc, endpoint in
            acc[endpoint] = custom[endpoint].map(normalize) ?? endpoint.defaultValue
        }
    }

    /// Saves the whole Custom set, normalized. Returns false when the write can't be read back (TI-E-18).
    @discardableResult
    static func save(custom: [ServerEndpoint: String], defaults: UserDefaults = .standard) -> Bool {
        let normalized = custom.mapValues(normalize)
        if normalized.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            let raw = normalized.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
            defaults.set(raw, forKey: key)
        }
        return customValues(defaults: defaults) == normalized
    }

    /// TI-E-16: trim surrounding whitespace, then drop trailing `/` while the value is longer than one character.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        while value.count > 1 && value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// TI-E-14 format check. nil when valid, otherwise the inline message shown under the field.
    static func validate(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return "Enter a URL." }
        guard let match = value.wholeMatch(of: urlPattern) else {
            return "Enter a valid URL starting with http:// or https://."
        }
        if let port = match.output.1 {
            guard let number = Int(port), (1...65535).contains(number) else {
                return "Port must be between 1 and 65535."
            }
        }
        return nil
    }

    /// `http(s)://host[:port][/path]` — same pattern as the screen spec (`SERVER_URL_RE`).
    private static let urlPattern = #/https?://[^\s/:]+(?::(\d+))?(?:/\S*)?/#
}

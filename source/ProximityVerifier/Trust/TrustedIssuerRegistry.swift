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

struct TrustedIssuer: Codable, Equatable {
    let did: String
    let name: String
    let docTypes: [String]
}

protocol TrustedIssuerRegistry {
    func fetchTrustedIssuers() async throws -> [TrustedIssuer]
}

enum TrustedIssuerRegistryConfig {
    static let path = "list/api/v1/mdoc/issuers"

    /// Read on every request so a Server URL save applies immediately (TI-E-16).
    static var endpoint: URL? { URL(string: ServerURLStore.value(.tas))?.appending(path: path) }
}

final class StubTrustedIssuerRegistry: TrustedIssuerRegistry {
    var latency: TimeInterval = 1.6
    var sample: [TrustedIssuer] = [
        TrustedIssuer(did: "did:omn:issuer", name: "OpenDID Issuer",
                      docTypes: ["org.omnione.pid.1"]),
    ]

    func fetchTrustedIssuers() async throws -> [TrustedIssuer] {
        try await Task.sleep(for: .seconds(latency))
        return sample
    }
}

final class RemoteTrustedIssuerRegistry: TrustedIssuerRegistry {
    private struct Payload: Decodable { let items: [TrustedIssuer] }

    private let endpoint: () -> URL?
    private let session: URLSession

    init(endpoint: @escaping () -> URL? = { TrustedIssuerRegistryConfig.endpoint },
         session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchTrustedIssuers() async throws -> [TrustedIssuer] {
        guard let url = endpoint() else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Payload.self, from: data).items
    }
}

enum TrustedIssuerRegistryFactory {
    static func make() -> TrustedIssuerRegistry {
        if TrustedIssuerRegistryConfig.endpoint != nil {
            return RemoteTrustedIssuerRegistry()
        }
        return StubTrustedIssuerRegistry()
    }
}

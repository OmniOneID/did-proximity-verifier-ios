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
import Observation

@MainActor
@Observable
final class TrustedIssuerStore {
    private(set) var issuers: [TrustedIssuer]
    private(set) var updatedAt: Date?
    private(set) var isRefreshing = false

    private let registry: TrustedIssuerRegistry
    private let documents: DIDDocumentFetching
    private let documentCache: DIDDocumentCache
    private let defaults: UserDefaults

    private enum Key {
        static let issuers = "trustedIssuers.items"
        static let updatedAt = "trustedIssuers.updatedAt"
        static let legacyDIDs = "trustedIssuers.dids"
    }

    init(registry: TrustedIssuerRegistry = TrustedIssuerRegistryFactory.make(),
         documents: DIDDocumentFetching = IssuerKeyStoreFactory.makeFetcher(
            listIsRemote: TrustedIssuerRegistryConfig.endpoint != nil),
         documentCache: DIDDocumentCache = DIDDocumentCache(),
         defaults: UserDefaults = .standard) {
        self.registry = registry
        self.documents = documents
        self.documentCache = documentCache
        self.defaults = defaults
        defaults.removeObject(forKey: Key.legacyDIDs)
        self.issuers = defaults.data(forKey: Key.issuers)
            .flatMap { try? JSONDecoder().decode([TrustedIssuer].self, from: $0) } ?? []
        self.updatedAt = issuers.isEmpty ? nil : defaults.object(forKey: Key.updatedAt) as? Date
    }

    var isEmpty: Bool { issuers.isEmpty }

    var updatedAtText: String? { updatedAt.map(DateStyle.stamp) }

    func refresh() async -> VerifierError? {
        if isRefreshing { return nil }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetched = try await registry.fetchTrustedIssuers()
            var fetchedDocuments: [String: Data] = [:]
            for issuer in fetched {
                let data = try await documents.fetchDocument(did: issuer.did)
                _ = try DIDDocument.decode(data)
                fetchedDocuments[issuer.did] = data
            }
            try documentCache.replaceAll(with: fetchedDocuments)
            issuers = fetched
            updatedAt = fetched.isEmpty ? nil : Date()
            persist()
            return nil
        } catch let error as URLError where error.code != .badServerResponse {
            return .connectionInterrupted
        } catch {
            return .sdk(message: nil)
        }
    }

    /// TI-E-17: drops the list, the issuer DID Documents and the stamp after a Server URL change. No auto refresh.
    func clearCache() {
        try? documentCache.replaceAll(with: [:])
        issuers = []
        updatedAt = nil
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(issuers) {
            defaults.set(data, forKey: Key.issuers)
        }
        if let updatedAt {
            defaults.set(updatedAt, forKey: Key.updatedAt)
        } else {
            defaults.removeObject(forKey: Key.updatedAt)
        }
    }
}

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

protocol IssuerKeyResolving: Sendable {
    func publicKey(did: String, keyId: String?) throws -> Data
}

protocol DIDDocumentFetching: Sendable {
    func fetchDocument(did: String) async throws -> Data
}

enum IssuerKeyError: LocalizedError, Equatable {
    case resolverNotConfigured
    case documentUnavailable(String)
    case malformedDocument
    case keyNotFound(String)
    case unsupportedKeyFormat

    var errorDescription: String? {
        switch self {
        case .resolverNotConfigured:
            return "No DID document source is configured for this build."
        case .documentUnavailable(let did):
            return "The DID document for \(did) could not be retrieved."
        case .malformedDocument:
            return "The DID document could not be read."
        case .keyNotFound(let keyId):
            return "The DID document has no verification method for '\(keyId)'."
        case .unsupportedKeyFormat:
            return "The verification key format is not supported."
        }
    }
}

enum IssuerKeyStoreConfig {
    static let path = "api-gateway/api/v1/did-doc"

    /// Read on every request so a Server URL save applies immediately (TI-E-16).
    static var endpoint: URL? { URL(string: ServerURLStore.value(.apiGateway))?.appending(path: path) }

    static let assertionKeyID: String? = "assert"

    static func request(did: String, versionId: String?) -> URLRequest? {
        guard let endpoint,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return nil }
        var query = components.queryItems ?? []
        query.append(URLQueryItem(name: "did", value: did))
        if let versionId { query.append(URLQueryItem(name: "versionId", value: versionId)) }
        components.queryItems = query
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

struct IssuerKeyStore: IssuerKeyResolving {
    let cache: DIDDocumentCache

    init(cache: DIDDocumentCache = DIDDocumentCache()) {
        self.cache = cache
    }

    func publicKey(did: String, keyId: String?) throws -> Data {
        guard let stored = cache.load(did: did) else { throw IssuerKeyError.documentUnavailable(did) }
        let document = try DIDDocument.decode(stored)
        if let keyId { return try document.verificationKey(id: keyId) }
        return try document.assertionKey(preferring: IssuerKeyStoreConfig.assertionKeyID)
    }
}

struct RemoteDIDDocumentFetcher: DIDDocumentFetching {
    var session: URLSession = .shared

    func fetchDocument(did: String) async throws -> Data {
        guard let request = IssuerKeyStoreConfig.request(did: did, versionId: nil) else {
            throw IssuerKeyError.resolverNotConfigured
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct StubDIDDocumentFetcher: DIDDocumentFetching {
    func fetchDocument(did: String) async throws -> Data {
        let object: [String: Any] = ["id": did, "verificationMethod": [Any](), "assertionMethod": [Any]()]
        return try JSONSerialization.data(withJSONObject: object)
    }
}

struct DIDDocumentCache: Sendable {
    private let directory: URL?

    init(directoryName: String = "TrustedIssuerDocuments") {
        directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    func load(did: String) -> Data? {
        guard let directory, let name = Self.fileName(did: did) else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    func replaceAll(with documents: [String: Data]) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let fileManager = FileManager.default
        let staging = directory.deletingLastPathComponent()
            .appendingPathComponent(directory.lastPathComponent + ".staging", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        for (did, data) in documents {
            guard let name = Self.fileName(did: did) else { throw CocoaError(.fileWriteInvalidFileName) }
            try data.write(to: staging.appendingPathComponent(name), options: .atomic)
        }
        if fileManager.fileExists(atPath: directory.path) {
            _ = try fileManager.replaceItemAt(directory, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: directory)
        }
    }

    private static func fileName(did: String) -> String? {
        did.addingPercentEncoding(withAllowedCharacters: .alphanumerics).map { "\($0).json" }
    }
}

enum IssuerKeyStoreFactory {
    static func make() -> IssuerKeyResolving { IssuerKeyStore() }

    static func makeFetcher(listIsRemote: Bool) -> DIDDocumentFetching {
        listIsRemote ? RemoteDIDDocumentFetcher() : StubDIDDocumentFetcher()
    }
}

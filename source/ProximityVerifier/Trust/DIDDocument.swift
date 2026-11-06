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

struct DIDDocument {
    struct VerificationMethod {
        let id: String
        let type: String?
        let publicKeyMultibase: String?
        let jwk: (x: String, y: String)?

        func sec1PublicKey() throws -> Data {
            if let publicKeyMultibase {
                return try IssuerPublicKey.sec1(fromMultibase: publicKeyMultibase)
            }
            if let jwk {
                return try IssuerPublicKey.sec1(fromJwkX: jwk.x, y: jwk.y)
            }
            throw IssuerKeyError.unsupportedKeyFormat
        }
    }

    let id: String?
    let verificationMethod: [VerificationMethod]
    let assertionMethod: [String]

    private static let wrapperKeys = ["didDoc", "didDocument", "document", "data", "result"]

    static func decode(_ data: Data) throws -> DIDDocument {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IssuerKeyError.malformedDocument
        }
        return DIDDocument(unwrapped(root))
    }

    private static func unwrapped(_ object: [String: Any]) -> [String: Any] {
        if object["verificationMethod"] != nil { return object }
        for key in wrapperKeys {
            if let inner = object[key] as? [String: Any] { return unwrapped(inner) }
            if let encoded = object[key] as? String,
               let data = try? Multibase.decode(encoded),
               let inner = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return unwrapped(inner)
            }
        }
        return object
    }

    private init(_ object: [String: Any]) {
        id = object["id"] as? String
        verificationMethod = (object["verificationMethod"] as? [Any] ?? []).compactMap { entry in
            guard let method = entry as? [String: Any], let id = method["id"] as? String else { return nil }
            var jwk: (x: String, y: String)?
            if let key = method["publicKeyJwk"] as? [String: Any],
               let x = key["x"] as? String, let y = key["y"] as? String {
                jwk = (x, y)
            }
            return VerificationMethod(id: id,
                                      type: method["type"] as? String,
                                      publicKeyMultibase: method["publicKeyMultibase"] as? String,
                                      jwk: jwk)
        }
        assertionMethod = (object["assertionMethod"] as? [Any] ?? []).compactMap { entry in
            if let reference = entry as? String { return reference }
            return (entry as? [String: Any])?["id"] as? String
        }
    }

    func assertionKey(preferring keyId: String?) throws -> Data {
        guard let method = method(for: keyId) else {
            throw IssuerKeyError.keyNotFound(keyId ?? "assertionMethod")
        }
        return try method.sec1PublicKey()
    }

    func verificationKey(id keyId: String) throws -> Data {
        guard let method = verificationMethod.first(where: { matches($0.id, keyId) }) else {
            throw IssuerKeyError.keyNotFound(keyId)
        }
        return try method.sec1PublicKey()
    }

    private func method(for keyId: String?) -> VerificationMethod? {
        if let keyId, let matched = verificationMethod.first(where: { matches($0.id, keyId) }) {
            return matched
        }
        for reference in assertionMethod {
            let fragment = reference.split(separator: "#").last.map(String.init) ?? reference
            if let matched = verificationMethod.first(where: { matches($0.id, fragment) }) {
                return matched
            }
        }
        return verificationMethod.first
    }

    private func matches(_ methodID: String, _ keyId: String) -> Bool {
        methodID == keyId || methodID.hasSuffix("#\(keyId)")
    }
}

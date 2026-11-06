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

extension ReceivedCredential {
    init(_ document: VerifiedDocument, issuerTrusted: IssuerTrustDisplay) {
        let catalog = ClaimCatalog.catalog(for: document.docType)

        let deviceAuth: DeviceAuthDisplay = document.mdocAuth.valid ? .yes : .no

        var claims: [ReceivedClaim] = []
        for (_, elements) in document.issuerSignedElements {
            for (elementID, value) in elements {
                claims.append(ReceivedClaim(id: elementID, label: elementID,
                                            value: ReceivedClaimValue(value, elementID: elementID)))
            }
        }
        claims.sort {
            (catalog?.order(of: $0.id) ?? .max, $0.id) < (catalog?.order(of: $1.id) ?? .max, $1.id)
        }

        self.init(docType: document.docType,
                  issuerTrusted: issuerTrusted,
                  deviceAuth: deviceAuth,
                  validFrom: document.issuerDataAuth.validity.map { DateStyle.date($0.validFrom) } ?? "—",
                  validUntil: document.issuerDataAuth.validity.map { DateStyle.date($0.validUntil) } ?? "—",
                  claims: claims)
    }
}

extension ReceivedClaimValue {
    private static let imageElements: Set<String> = ["portrait", "picture", "signature_usual_mark"]

    // Matched on the segment after the last "." so namespaced names
    // (org.omnione.pid.1.portrait) count too.
    static func isImageElement(_ elementID: String) -> Bool {
        let name = elementID.split(separator: ".").last.map(String.init) ?? elementID
        return imageElements.contains(name)
    }

    init(_ value: MdocValue, elementID: String) {
        let isImage = Self.isImageElement(elementID)
        switch value {
        case .bytes(let data):
            self = isImage ? .image(data) : .text("(\(data.count) bytes)")
        case .text(let s) where isImage:
            self = Self.base64Data(s).map(ReceivedClaimValue.image) ?? .text(s)
        default:
            self.init(value)
        }
    }

    private static func base64Data(_ string: String) -> Data? {
        var body = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("data:"), let comma = body.firstIndex(of: ",") {
            body = String(body[body.index(after: comma)...])
        }
        return Data(base64Encoded: body, options: .ignoreUnknownCharacters)
    }

    private init(_ value: MdocValue) {
        switch value {
        case .text(let s), .fullDate(let s), .dateTime(let s):
            self = .text(s)
        case .integer(let n):
            self = .text(String(n))
        case .boolean(let b):
            self = .text(b ? "Yes" : "No")
        case .bytes(let data):
            self = .text("(\(data.count) bytes)")
        case .map(let map):
            self = .group(map.sorted { $0.key < $1.key }
                             .map { (NestedClaimLabels.label(for: $0.key), Self.flatten($0.value)) })
        case .array(let items):
            let maps = items.compactMap { item -> [String: MdocValue]? in
                if case .map(let map) = item { return map }
                return nil
            }
            if !maps.isEmpty, maps.count == items.count {
                self = .group(maps.flatMap { map in
                    map.sorted { $0.key < $1.key }
                        .map { (NestedClaimLabels.label(for: $0.key), Self.flatten($0.value)) }
                })
            } else {
                self = .text(items.map(Self.flatten).joined(separator: ", "))
            }
        case .null:
            self = .text("—")
        case .unsupported:
            self = .text("(unsupported)")
        @unknown default:
            self = .text("(unsupported)")
        }
    }

    private static func flatten(_ value: MdocValue) -> String {
        switch value {
        case .text(let s), .fullDate(let s), .dateTime(let s): return s
        case .integer(let n): return String(n)
        case .boolean(let b): return b ? "Yes" : "No"
        case .bytes(let d): return "(\(d.count) bytes)"
        case .array(let a): return a.map(flatten).joined(separator: ", ")
        case .map(let m): return m.sorted { $0.key < $1.key }
                .map { "\(NestedClaimLabels.label(for: $0.key)): \(flatten($0.value))" }
                .joined(separator: ", ")
        case .null: return "—"
        case .unsupported: return "(unsupported)"
        @unknown default: return "(unsupported)"
        }
    }
}

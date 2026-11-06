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

struct ClaimDefinition: Identifiable, Hashable {
    let id: String
    let label: String

    init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

struct DocTypeCatalog {
    let docType: String
    let nameSpace: String
    let claims: [ClaimDefinition]

    func label(for elementID: String) -> String {
        claims.first { $0.id == elementID }?.label ?? elementID
    }

    func order(of elementID: String) -> Int {
        claims.firstIndex { $0.id == elementID } ?? Int.max
    }
}

enum ClaimCatalog {
    static let pid = DocTypeCatalog(
        docType: "org.omnione.pid.1",
        nameSpace: "org.omnione.pid.1",
        claims: [
            ClaimDefinition("family_name", "Family Name(s)"),
            ClaimDefinition("given_name", "Given Name(s)"),
            ClaimDefinition("birth_date", "Birth Date"),
            ClaimDefinition("portrait", "Portrait"),
        ])

    private static let all = [pid]

    static func catalog(for docType: String) -> DocTypeCatalog? {
        all.first { $0.docType == docType }
    }

    static func label(docType: String, elementID: String) -> String {
        catalog(for: docType)?.label(for: elementID) ?? elementID
    }
}

enum NestedClaimLabels {
    private static let table: [String: String] = [
        "country": "Country",
        "region": "Region",
        "locality": "Locality",
        "vehicle_category_code": "Vehicle Category Code",
        "issue_date": "Issue Date",
        "expiry_date": "Expiry Date",
        "codes": "Codes",
    ]

    static func label(for key: String) -> String {
        table[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

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

struct DocumentGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let documentName: String
    let customTitle: String
    let short: String
    let catalog: DocTypeCatalog

    var attributes: [ClaimDefinition] { catalog.claims }

    static func == (a: DocumentGroup, b: DocumentGroup) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DocumentCatalog {
    static let groups: [DocumentGroup] = [
        DocumentGroup(id: "pid",
                      title: "Request PID",
                      documentName: "Personal Identification Data (PID)",
                      customTitle: "Custom PID request",
                      short: "PID",
                      catalog: ClaimCatalog.pid),
    ]

    static func group(id: String) -> DocumentGroup? { groups.first { $0.id == id } }
    static func group(docType: String) -> DocumentGroup? { groups.first { $0.catalog.docType == docType } }
}

enum GroupSelection: Equatable {
    case full
    case custom(attributeIDs: [String])

    var isFull: Bool { if case .full = self { return true }; return false }
    var isCustom: Bool { if case .custom = self { return true }; return false }

    var customAttributeIDs: [String]? {
        if case .custom(let ids) = self { return ids }
        return nil
    }
}

struct VerificationRequestDraft: Equatable {
    private(set) var selections: [String: GroupSelection] = [:]

    var isEmpty: Bool { selections.isEmpty }

    subscript(groupID: String) -> GroupSelection? { selections[groupID] }

    mutating func toggleFull(_ groupID: String) {
        if selections[groupID]?.isFull == true {
            selections[groupID] = nil
        } else {
            selections[groupID] = .full
        }
    }

    mutating func clear(_ groupID: String) {
        selections[groupID] = nil
    }

    mutating func commitCustom(_ groupID: String, attributeIDs: [String]) {
        guard let group = DocumentCatalog.group(id: groupID) else { return }
        if attributeIDs.isEmpty {
            selections[groupID] = nil
        } else if attributeIDs.count == group.attributes.count {
            selections[groupID] = .full
        } else {
            selections[groupID] = .custom(attributeIDs: attributeIDs)
        }
    }

    mutating func reset() { selections.removeAll() }

    var scopeRows: [(label: String, scope: String)] {
        DocumentCatalog.groups.compactMap { group in
            guard let selection = selections[group.id] else { return nil }
            switch selection {
            case .full:
                return (group.short, "Full")
            case .custom(let ids):
                return (group.short, "\(ids.count) of \(group.attributes.count)")
            }
        }
    }

    func requestedElementIDs(for group: DocumentGroup) -> [String]? {
        switch selections[group.id] {
        case .none: return nil
        case .full: return group.attributes.map(\.id)
        case .custom(let ids): return group.attributes.map(\.id).filter { ids.contains($0) }
        }
    }

    func itemsRequestSpecs() -> [ItemsRequestSpec] {
        DocumentCatalog.groups.compactMap { group in
            guard let ids = requestedElementIDs(for: group), !ids.isEmpty else { return nil }
            let items = Dictionary(uniqueKeysWithValues: ids.map { ($0, false) })
            return ItemsRequestSpec(docType: group.catalog.docType,
                                    items: [group.catalog.nameSpace: items])
        }
    }
}

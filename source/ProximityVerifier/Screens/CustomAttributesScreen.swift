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

import SwiftUI

struct CustomAttributesScreen: View {
    @Environment(AppModel.self) private var model
    let groupID: String

    @State private var picked: Set<String>
    @State private var isOpen = true

    private let group: DocumentGroup

    init(groupID: String) {
        self.groupID = groupID
        let group = DocumentCatalog.group(id: groupID) ?? DocumentCatalog.groups[0]
        self.group = group
        _picked = State(initialValue: Set(group.attributes.map(\.id)))
    }

    private var allOn: Bool { picked.count == group.attributes.count }

    var body: some View {
        ScreenScaffold {
            AppBar(title: group.customTitle) {
                AppBarBackButton { model.pop() }
            }
        } content: {
            VStack(spacing: 0) {
                SectionTitle("Requested Attributes")
                CardView(padding: EdgeInsets(top: 4, leading: 16, bottom: isOpen ? 12 : 4, trailing: 16)) {
                    VStack(spacing: 0) {
                        Button { isOpen.toggle() } label: {
                            HStack(spacing: 8) {
                                (isOpen ? Icons.chevronUp(size: 20) : Icons.chevronDown(size: 20))
                                    .foregroundStyle(Color.Palette.primary)
                                Text(group.documentName)
                                    .font(AppFont.bold(15))
                                    .foregroundStyle(Color.Palette.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if isOpen {
                            VStack(spacing: 0) {
                                GroupHead(label: "Attributes", isFirst: true) {
                                    SelectAllControl(allOn: allOn) {
                                        picked = allOn ? [] : Set(group.attributes.map(\.id))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                ForEach(Array(group.attributes.enumerated()), id: \.element.id) { index, attribute in
                                    AttributeRow(label: attribute.label,
                                                 isChecked: picked.contains(attribute.id),
                                                 isLast: index == group.attributes.count - 1) {
                                        if picked.contains(attribute.id) {
                                            picked.remove(attribute.id)
                                        } else {
                                            picked.insert(attribute.id)
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        } bottom: {
            BottomBar {
                OutlineButton(title: "Cancel") { model.pop() }
                PrimaryButton(title: "Done", isEnabled: !picked.isEmpty) {
                    let ordered = group.attributes.map(\.id).filter { picked.contains($0) }
                    model.request.commitCustom(groupID, attributeIDs: ordered)
                    model.pop()
                }
            }
        }
    }
}

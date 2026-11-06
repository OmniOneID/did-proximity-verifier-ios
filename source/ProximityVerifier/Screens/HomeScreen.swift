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

struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isSheetOpen = false

    var body: some View {
        let isLocked = model.isSessionRunning
        ScreenScaffold {
            AppBar(title: "Proximity Verifier") {
                AppBarMenuButton { model.push(.settings) }
                    .disabled(isLocked)
            }
        } content: {
            VStack(spacing: Metrics.sectionGap) {
                ForEach(DocumentCatalog.groups) { group in
                    requestGroup(group)
                }
            }
            .disabled(isLocked)
        } bottom: {
            BottomBar {
                PrimaryButton(title: "Start Verification",
                              isEnabled: !model.request.isEmpty && !isLocked) {
                    isSheetOpen = true
                }
            }
        }
        .actionSheet(
            isPresented: $isSheetOpen,
            title: "Device engagement method",
            description: "Choose how to start the session with the holder's device.",
            actions: [
                SheetAction(label: "Scan QR", icon: { Icons.qr(size: 22) }) {
                    model.presentScanner()
                },
                SheetAction(label: "Tap NFC", icon: { Icons.nfc(size: 22) }) {
                    model.startSessionViaNFC()
                },
            ])
    }

    private func requestGroup(_ group: DocumentGroup) -> some View {
        let selection = model.request[group.id]
        return VStack(spacing: 0) {
            SectionTitle(group.title)
            CardView(padding: .all(16)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        SelectionChip(label: "Full", isSelected: selection?.isFull == true) {
                            model.request.toggleFull(group.id)
                        }
                        .accessibilityIdentifier("chipFull")
                        SelectionChip(label: "Custom", isSelected: selection?.isCustom == true) {
                            if selection?.isCustom == true {
                                model.request.clear(group.id)
                            } else {
                                model.push(.customAttributes(groupID: group.id))
                            }
                        }
                        .accessibilityIdentifier("chipCustom")
                    }
                    .animation(.easeInOut(duration: 0.15), value: selection)
                    if let ids = selection?.customAttributeIDs {
                        Text("\(ids.count) of \(group.attributes.count) attributes selected")
                            .font(AppFont.regular(12.5))
                            .foregroundStyle(Color.Palette.textSecondary)
                    }
                }
            }
        }
    }
}

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

struct ReceivedCredentialsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var snapshot: [ReceivedCredential]?

    var body: some View {
        let documents = snapshot ?? model.receivedCredentials
        ScreenScaffold {
            AppBar(title: "Received Credentials") {
                AppBarBackButton { model.finishResult() }
            }
        } content: {
            VStack(spacing: Metrics.sectionGap) {
                VStack(spacing: 0) {
                    SectionTitle("Result")
                    CardView(bordered: true, padding: .all(16)) {
                        Text("Number of credentials returned: \(documents.count)")
                            .font(AppFont.semibold(14))
                            .foregroundStyle(Color.Palette.textPrimary)
                    }
                }

                ForEach(Array(documents.enumerated()), id: \.offset) { _, document in
                    VStack(spacing: 0) {
                        SectionTitle(document.docType)
                        VStack(spacing: 12) {
                            CardView(padding: .symmetric(v: 4, h: 16)) {
                                VStack(spacing: 0) {
                                    GroupHead("Verification")
                                    let rows = document.validitySummary
                                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                        KeyValueRow(label: row.label, value: row.value, note: row.note,
                                                    isLast: index == rows.count - 1)
                                    }
                                }
                            }
                            CardView(padding: .symmetric(v: 4, h: 16)) {
                                VStack(spacing: 0) {
                                    GroupHead("Attributes")
                                    ForEach(Array(document.claims.enumerated()), id: \.offset) { index, claim in
                                        claimRow(claim, isLast: index == document.claims.count - 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } bottom: {
            BottomBar {
                PrimaryButton(title: "OK") { model.finishResult() }
            }
        }
        .onAppear { if snapshot == nil { snapshot = model.receivedCredentials } }
    }

    @ViewBuilder
    private func claimRow(_ claim: ReceivedClaim, isLast: Bool) -> some View {
        switch claim.value {
        case .text(let value):
            KeyValueRow(label: claim.label, value: value, isLast: isLast, rawLabel: true)
        case .group(let items):
            KeyValueGroupRow(label: claim.label, items: items, isLast: isLast)
        case .image(let data):
            ImageClaimRow(label: claim.label, data: data, isLast: isLast)
        }
    }
}

// Shown at the image's own size (px → pt); scaled down to the card width only
// when wider, never cropped or enlarged (RES-E-07).
private struct ImageClaimRow: View {
    let label: String
    let data: Data
    let isLast: Bool
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.medium(11))
                .kerning(0.3)
                .foregroundStyle(Color.Palette.textSecondary)
            if let image = UIImage(data: data, scale: displayScale) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: image.size.width)
                    .padding(.top, 8)
            } else {
                Text("(\(data.count) bytes)")
                    .font(AppFont.regular(14))
                    .foregroundStyle(Color.Palette.textPrimary)
                    .lineHeight(1.5, fontSize: 14)
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .rowDivider(isLast: isLast)
    }
}

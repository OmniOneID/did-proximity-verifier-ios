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

struct TrustedIssuersScreen: View {
    @Environment(AppModel.self) private var model
    @State private var dialog: DialogContent?

    private var store: TrustedIssuerStore { model.trustedIssuers }

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Trusted Issuers") {
                AppBarBackButton { model.pop() }
            } trailing: {
                AppBarSettingsButton { model.push(.serverURL) }
            }

            if store.isEmpty {
                emptyState
            } else {
                ScrollView {
                    cachedList
                        .padding(.horizontal, Metrics.screenHorizontal)
                        .padding(.top, Metrics.screenTop)
                        .padding(.bottom, Metrics.screenBottom)
                }
                .scrollIndicators(.hidden)
            }

            BottomBar {
                PrimaryButton(title: "Refresh Trusted Issuers", isEnabled: !store.isRefreshing) {
                    Task {
                        if let error = await store.refresh(), let message = error.message {
                            dialog = DialogContent(message: message)
                        }
                    }
                }
            }
        }
        .background(Color.Palette.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if store.isRefreshing { LoadingScrim() }
        }
        .errorDialog($dialog) { _ in }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Trusted Issuers yet")
                .font(AppFont.bold(18))
                .kerning(-0.2)
                .foregroundStyle(Color.Palette.textPrimary)
            (Text("Tap ")
             + Text("Refresh Trusted Issuers").foregroundColor(Color.Palette.primary).fontWeight(.semibold)
             + Text(" below to fetch the registry."))
                .font(AppFont.regular(14))
                .foregroundStyle(Color.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineHeight(1.6, fontSize: 14)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var cachedList: some View {
        VStack(spacing: 0) {
            SectionTitle(text: "Cached Issuers") {
                CountBadge(count: store.issuers.count)
            }
            if let updated = store.updatedAtText {
                Text("Last updated: \(updated)")
                    .font(AppFont.regular(12.5))
                    .foregroundStyle(Color.Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, -4)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("lastUpdated")
            }
            CardView(bordered: true, padding: .symmetric(v: 4, h: 16)) {
                VStack(spacing: 0) {
                    ForEach(Array(store.issuers.enumerated()), id: \.offset) { index, issuer in
                        VStack(alignment: .leading, spacing: 2) {
                            if !issuer.name.isEmpty {
                                Text(issuer.name)
                                    .font(AppFont.semibold(14))
                                    .foregroundStyle(Color.Palette.textPrimary)
                                    .lineHeight(1.4, fontSize: 14)
                                    .accessibilityIdentifier("issuerName")
                            }
                            Text(issuer.did)
                                .font(AppFont.mono(12.5))
                                .foregroundStyle(Color.Palette.textSecondary)
                                .lineHeight(1.55, fontSize: 12.5)
                                .accessibilityIdentifier("issuerDid")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .rowDivider(isLast: index == store.issuers.count - 1)
                    }
                }
            }
        }
    }
}

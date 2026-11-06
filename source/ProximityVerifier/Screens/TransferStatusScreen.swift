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

struct TransferStatusScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let rows = model.sessionRequest.scopeRows
        ScreenScaffold {
            AppBar(title: "Transfer Status") {
                AppBarBackButton { model.cancelSession() }
            }
        } content: {
            VStack(spacing: Metrics.sectionGap) {
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        SectionTitle("Request")
                        CardView(bordered: true, padding: .symmetric(v: 4, h: 16)) {
                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                    RequestScopeRow(label: row.label, scope: row.scope,
                                                    isLast: index == rows.count - 1)
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    SectionTitle("Connection State")
                    CardView(bordered: true, padding: .all(16)) {
                        HStack(spacing: 12) {
                            DotSpinner(size: 20)
                            Text(model.transferStatus.displayText)
                                .font(AppFont.medium(14))
                                .foregroundStyle(Color.Palette.textSecondary)
                                .lineHeight(1.4, fontSize: 14)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        } bottom: {
            BottomBar {
                OutlineButton(title: "Cancel") { model.cancelSession() }
            }
        }
    }
}

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

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isBleModeSheetPresented = false

    var body: some View {
        ScreenScaffold {
            AppBar(title: "Settings") {
                AppBarBackButton { model.pop() }
            }
        } content: {
            VStack(spacing: Metrics.sectionGap) {
                VStack(spacing: 0) {
                    SectionTitle("General")
                    CardView(bordered: true) {
                        VStack(spacing: 0) {
                            NavigationRow(title: "Trusted Issuers") {
                                model.push(.trustedIssuers)
                            }
                            SettingRow(title: "Skip issuer verification",
                                       isOn: model.settings.skipIssuerAuth,
                                       isLast: true) {
                                model.settings.skipIssuerAuth.toggle()
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    SectionTitle("Transport")
                    CardView(bordered: true) {
                        ChoiceRow(title: "Transports to use",
                                  caption: "Enabled transports are tried in order. Drag the handle to change the order.",
                                  footer: model.settings.transportSummary,
                                  isLast: true) {
                            TransportList(order: model.settings.transportOrder) { kind in
                                model.settings.toggleTransport(kind)
                            } onReorder: { next in
                                model.settings.transportOrder = next
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    SectionTitle("Data retrieval options")
                    CardView(bordered: true) {
                        VStack(spacing: 0) {
                            ValueRow(title: "BLE Transfer Mode",
                                     value: model.settings.bleTransferMode.label) {
                                isBleModeSheetPresented = true
                            }
                            SettingRow(title: "Use BLE L2CAP if available",
                                       isOn: model.settings.useL2CAP,
                                       isLast: true) {
                                model.settings.useL2CAP.toggle()
                            }
                        }
                    }
                }
            }
        }
        .selectionSheet(isPresented: $isBleModeSheetPresented,
                        title: "BLE Transfer Mode",
                        description: "Preferred BLE role for this reader. Applied only when the holder advertises both modes.",
                        options: BleTransferMode.allCases.map { mode in
                            SelectionOption(label: mode.label,
                                            isSelected: model.settings.bleTransferMode == mode) {
                                model.settings.bleTransferMode = mode
                            }
                        })
    }
}

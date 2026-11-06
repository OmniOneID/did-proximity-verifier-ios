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

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeScreen()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .tint(Color.Palette.primary)
        .fullScreenCover(isPresented: $model.isScannerPresented) {
            DeviceEngagementScreen()
        }
        .errorDialog($model.dialog) { model.dismissDialog($0) }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        Group {
            switch route {
            case .settings:
                SettingsScreen()
            case .trustedIssuers:
                TrustedIssuersScreen()
            case .serverURL:
                ServerURLScreen()
            case .customAttributes(let groupID):
                CustomAttributesScreen(groupID: groupID)
            case .transferStatus:
                TransferStatusScreen()
            case .receivedCredentials:
                ReceivedCredentialsScreen()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ScreenScaffold<Bar: View, Content: View, Bottom: View>: View {
    @ViewBuilder var bar: Bar
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                content
                    .padding(.horizontal, Metrics.screenHorizontal)
                    .padding(.top, Metrics.screenTop)
                    .padding(.bottom, Metrics.screenBottom)
            }
            .scrollIndicators(.hidden)
            bottom
        }
        .background(Color.Palette.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension ScreenScaffold where Bottom == EmptyView {
    init(@ViewBuilder bar: () -> Bar, @ViewBuilder content: () -> Content) {
        self.init(bar: bar, content: content, bottom: { EmptyView() })
    }
}

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
import Observation

/// Screen state of Server URL (TI-E-13 ~ TI-E-15).
///
/// The whole state is one map: which endpoints sit in the Custom section and their values. Endpoints without a key are
/// in the Default section and use the build default. Moving sections only changes this map; nothing is stored before Save.
@MainActor
@Observable
final class ServerURLViewModel {
    private let saved: [ServerEndpoint: String]
    private(set) var custom: [ServerEndpoint: String]
    private(set) var errors: [ServerEndpoint: String] = [:]

    init(saved: [ServerEndpoint: String] = ServerURLStore.customValues()) {
        self.saved = saved
        self.custom = saved
    }

    var customList: [ServerEndpoint] { ServerEndpoint.allCases.filter { custom[$0] != nil } }
    var defaultList: [ServerEndpoint] { ServerEndpoint.allCases.filter { custom[$0] == nil } }

    /// TI-E-15: the Custom set or a value differs from what is saved, and no Custom field has a format error.
    var canSave: Bool { custom != saved && !customList.contains { errors[$0] != nil } }

    /// TI-E-17: compares the effective URLs, not the Custom set — Save can be enabled while the address stays the same.
    var changesEffectiveURL: Bool {
        ServerURLStore.effectiveValues(for: saved) != ServerURLStore.effectiveValues(for: custom)
    }

    func toCustom(_ endpoint: ServerEndpoint) {
        custom[endpoint] = endpoint.defaultValue
        errors[endpoint] = nil
    }

    func toDefault(_ endpoint: ServerEndpoint) {
        custom[endpoint] = nil
        errors[endpoint] = nil
    }

    /// Leaves values already in Custom untouched.
    func allToCustom() {
        for endpoint in defaultList { toCustom(endpoint) }
    }

    func allToDefault() {
        custom = [:]
        errors = [:]
    }

    func binding(for endpoint: ServerEndpoint) -> Binding<String> {
        Binding(get: { self.custom[endpoint] ?? "" },
                set: { value in
                    self.custom[endpoint] = value
                    self.errors[endpoint] = ServerURLStore.validate(value)
                })
    }

    func save() -> Bool {
        ServerURLStore.save(custom: custom)
    }
}

struct ServerURLScreen: View {
    @Environment(AppModel.self) private var model
    @State private var state = ServerURLViewModel()
    @State private var dialog: DialogContent?

    var body: some View {
        ScreenScaffold {
            AppBar(title: "Server URL") {
                AppBarBackButton { model.pop() }
            }
        } content: {
            VStack(spacing: 14) {
                customSection
                defaultSection
            }
        } bottom: {
            BottomBar {
                OutlineButton(title: "Cancel") { model.pop() }
                    .accessibilityIdentifier("cancelButton")
                PrimaryButton(title: "Save", isEnabled: state.canSave) { save() }
                    .accessibilityIdentifier("saveButton")
            }
        }
        .errorDialog($dialog) { _ in }
    }

    private var customSection: some View {
        VStack(spacing: 0) {
            SectionTitle(text: "Custom") {
                SmallOutlineButton(title: "All Default", muted: true,
                                   isEnabled: !state.customList.isEmpty) { state.allToDefault() }
                    .accessibilityIdentifier("allDefaultButton")
            }
            CardView(bordered: true, padding: .symmetric(v: 4, h: 14)) {
                if state.customList.isEmpty {
                    emptyNote("No custom endpoints.\nTap Custom on an endpoint below to edit it.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(state.customList.enumerated()), id: \.element) { index, endpoint in
                            customRow(endpoint, isLast: index == state.customList.count - 1)
                        }
                    }
                }
            }
        }
    }

    private var defaultSection: some View {
        VStack(spacing: 0) {
            SectionTitle(text: "Default") {
                SmallOutlineButton(title: "All Custom",
                                   isEnabled: !state.defaultList.isEmpty) { state.allToCustom() }
                    .accessibilityIdentifier("allCustomButton")
            }
            CardView(bordered: true, padding: .symmetric(v: 4, h: 14)) {
                if state.defaultList.isEmpty {
                    emptyNote("All endpoints are set to custom.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(state.defaultList.enumerated()), id: \.element) { index, endpoint in
                            defaultRow(endpoint, isLast: index == state.defaultList.count - 1)
                        }
                    }
                }
            }
        }
    }

    private func customRow(_ endpoint: ServerEndpoint, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                rowLabel(endpoint.label)
                Spacer(minLength: 12)
                SmallOutlineButton(title: "Default", muted: true) { state.toDefault(endpoint) }
                    .accessibilityIdentifier("rowActionButton")
            }
            InputField(text: state.binding(for: endpoint), error: state.errors[endpoint],
                       accessibilityID: "rowInput")
        }
        .padding(.vertical, 12)
        .rowDivider(isLast: isLast)
    }

    private func defaultRow(_ endpoint: ServerEndpoint, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                rowLabel(endpoint.label)
                Text(endpoint.defaultValue)
                    .font(AppFont.regular(13))
                    .foregroundStyle(Color.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SmallOutlineButton(title: "Custom") { state.toCustom(endpoint) }
                .accessibilityIdentifier("rowActionButton")
        }
        .padding(.vertical, 12)
        .rowDivider(isLast: isLast)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.semibold(13))
            .foregroundStyle(Color.Palette.textPrimary)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(AppFont.regular(13))
            .foregroundStyle(Color.Palette.textSecondary)
            .lineHeight(1.45, fontSize: 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
    }

    /// TI-E-16: save URLs → clear the cache only if an effective URL changed (TI-E-17) → close.
    /// A failed save keeps the screen, the old URLs and the cache (TI-E-18).
    private func save() {
        let clearsCache = state.changesEffectiveURL
        guard state.save() else {
            dialog = DialogContent(message: "Failed to save. Try again.")
            return
        }
        if clearsCache { model.trustedIssuers.clearCache() }
        model.pop()
    }
}

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

struct SettingRow: View {
    let title: String
    let isOn: Bool
    var isLast: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(AppFont.medium(15))
                .foregroundStyle(Color.Palette.textPrimary)
                .lineHeight(1.3, fontSize: 15)
            Spacer(minLength: 0)
            ToggleSwitch(isOn: isOn, action: onToggle)
                .accessibilityLabel(title)
                .accessibilityIdentifier("settingToggle")
        }
        .padding(16)
        .rowDivider(isLast: isLast)
    }
}

struct ValueRow: View {
    let title: String
    let value: String
    var isLast: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.medium(15))
                        .foregroundStyle(Color.Palette.textPrimary)
                        .lineHeight(1.3, fontSize: 15)
                    Text(value)
                        .font(AppFont.regular(13))
                        .foregroundStyle(Color.Palette.textSecondary)
                        .lineHeight(1.4, fontSize: 13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Icons.chevronRight(size: 20).foregroundStyle(Color.Palette.primary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowDivider(isLast: isLast)
    }
}

struct ChoiceRow<Content: View>: View {
    let title: String
    var caption: String? = nil
    var footer: String? = nil
    var isLast: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.medium(15))
                .foregroundStyle(Color.Palette.textPrimary)
                .lineHeight(1.3, fontSize: 15)
            if let caption {
                Text(caption)
                    .font(AppFont.regular(12.5))
                    .foregroundStyle(Color.Palette.textSecondary)
                    .lineHeight(1.5, fontSize: 12.5)
                    .padding(.top, 4)
            }
            content.padding(.top, 12)
            if let footer {
                Text(footer)
                    .font(AppFont.semibold(12.5))
                    .kerning(-0.1)
                    .foregroundStyle(Color.Palette.primaryDark)
                    .lineHeight(1.5, fontSize: 12.5)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .rowDivider(isLast: isLast)
    }
}

struct AttributeRow: View {
    let label: String
    let isChecked: Bool
    var isLast: Bool = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(label)
                    .font(AppFont.regular(14))
                    .foregroundStyle(Color.Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                CheckBoxView(isOn: isChecked)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowDivider(isLast: isLast)
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String
    var note: String? = nil
    var isLast: Bool = false
    var rawLabel: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rawLabel ? label : label.uppercased())
                .font(AppFont.medium(11))
                .kerning(0.3)
                .foregroundStyle(Color.Palette.textSecondary)
            Text(value)
                .font(AppFont.regular(14))
                .foregroundStyle(Color.Palette.textPrimary)
                .lineHeight(1.5, fontSize: 14)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            if let note {
                Text(note)
                    .font(AppFont.regular(12.5))
                    .foregroundStyle(Color.Palette.textSecondary)
                    .lineHeight(1.5, fontSize: 12.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .rowDivider(isLast: isLast)
    }
}

struct KeyValueGroupRow: View {
    let label: String
    let items: [(String, String)]
    var isLast: Bool = false
    @State private var isOpen = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isOpen.toggle() } label: {
                HStack(spacing: 8) {
                    (isOpen ? Icons.chevronUp(size: 18) : Icons.chevronDown(size: 18))
                        .foregroundStyle(Color.Palette.primary)
                    Text(label.uppercased())
                        .font(AppFont.medium(11))
                        .kerning(0.3)
                        .foregroundStyle(Color.Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        KeyValueRow(label: item.0, value: item.1, isLast: index == items.count - 1)
                    }
                }
                .padding(.leading, 26)
                .padding(.bottom, 2)
            }
        }
        .rowDivider(isLast: isLast)
    }
}

struct RequestScopeRow: View {
    let label: String
    let scope: String
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.semibold(14))
                .foregroundStyle(Color.Palette.textPrimary)
            Spacer(minLength: 0)
            Text(scope)
                .font(AppFont.medium(13))
                .foregroundStyle(Color.Palette.textSecondary)
        }
        .padding(.vertical, 12)
        .rowDivider(isLast: isLast)
    }
}

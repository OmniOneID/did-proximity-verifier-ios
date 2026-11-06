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

struct CheckBoxView: View {
    let isOn: Bool
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size > 20 ? 6 : 5, style: .continuous)
            .fill(isOn ? Color.Palette.primary : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: size > 20 ? 6 : 5, style: .continuous)
                    .strokeBorder(isOn ? Color.Palette.primary : Color.Palette.gray300, lineWidth: 1.5)
            )
            .overlay {
                if isOn {
                    Icons.check(size: size > 20 ? 14 : 12).foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

struct SelectAllControl: View {
    let allOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Select all")
                    .font(AppFont.bold(11))
                    .foregroundStyle(Color.Palette.primary)
                CheckBoxView(isOn: allOn, size: 18)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SelectionChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Icons.check(size: 15).foregroundStyle(.white) }
                Text(label)
                    .font(isSelected ? AppFont.semibold(14) : AppFont.medium(14))
            }
            .foregroundStyle(isSelected ? .white : Color.Palette.textPrimary)
            .padding(.leading, (isSelected ? 11 : 14) + 1.5)
            .padding(.trailing, 14 + 1.5)
            .padding(.vertical, 9 + 1.5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.Palette.primary : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.Palette.primary : Color.Palette.gray300, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ToggleSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? Color.Palette.primary : Color.Palette.gray300)
                .frame(width: 46, height: 26)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "1" : "0")
        .animation(.easeInOut(duration: 0.14), value: isOn)
    }
}

/// Single-line text input with an inline error below it (Server URL · TI-E-14).
struct InputField: View {
    @Binding var text: String
    var placeholder: String = ""
    var error: String?
    var accessibilityID: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $text)
                .font(AppFont.regular(14))
                .foregroundStyle(Color.Palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .accessibilityIdentifier(accessibilityID ?? "")
            if let error {
                Text(error)
                    .font(AppFont.regular(12))
                    .foregroundStyle(Color.Palette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    private var borderColor: Color {
        if error != nil { return Color.Palette.error }
        return isFocused ? Color.Palette.primary : Color.Palette.divider
    }
}

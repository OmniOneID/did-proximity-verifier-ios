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

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.semibold(16))
                .kerning(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.ctaHeight)
        }
        .buttonStyle(FilledCTAStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct FilledCTAStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? (pressed ? Color.Palette.primaryDark : Color.Palette.primary)
                                    : Color.Palette.primaryDisabled)
            )
            .shadow(color: isEnabled && !pressed ? Color.Palette.primary.opacity(0.30) : .clear,
                    radius: 3, y: 2)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

struct OutlineButton: View {
    let title: String
    var color: Color = Color.Palette.primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.semibold(16))
                .kerning(0.3)
                .foregroundStyle(isEnabled ? color : Color.Palette.gray500)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.ctaHeight)
        }
        .buttonStyle(OutlineCTAStyle(color: color, isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct OutlineCTAStyle: ButtonStyle {
    let color: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(pressed ? color.opacity(0.10) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isEnabled ? color : Color.Palette.gray300, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

/// Compact outline button used inside rows and section headers (Server URL · TI-E-13).
struct SmallOutlineButton: View {
    let title: String
    var muted: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        let color = !isEnabled ? Color.Palette.gray500 : muted ? Color.Palette.textSecondary : Color.Palette.primary
        Button(action: action) {
            Text(title)
                .font(AppFont.semibold(13))
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(!isEnabled || muted ? Color.Palette.gray300 : Color.Palette.primary, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .fixedSize()
    }
}

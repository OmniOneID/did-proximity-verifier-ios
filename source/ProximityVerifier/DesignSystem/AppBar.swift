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

struct AppBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(AppFont.semibold(17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                leading.frame(width: 40, height: 40)
                Spacer(minLength: 0)
                trailing.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: Metrics.appBarHeight)
        .frame(maxWidth: .infinity)
        .background(Color.Palette.primary.ignoresSafeArea(edges: .top))
    }
}

extension AppBar where Trailing == EmptyView {
    init(title: String, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, leading: leading, trailing: { EmptyView() })
    }
}

struct AppBarBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Icons.back(size: 24)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("appBarLeft")
    }
}

struct AppBarMenuButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Icons.menu(size: 24)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
        .accessibilityIdentifier("appBarLeft")
    }
}

struct AppBarSettingsButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Icons.gear(size: 24)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Server URL")
        .accessibilityIdentifier("appBarRight")
    }
}

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

struct SectionTitle<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.Palette.sectionRule)
                .frame(width: 4, height: 16)
            Text(text)
                .font(AppFont.bold(13))
                .kerning(-0.1)
                .foregroundStyle(Color.Palette.textPrimary)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ text: String) {
        self.init(text: text, trailing: { EmptyView() })
    }
}

struct CardView<Content: View>: View {
    var bordered: Bool = false
    var padding: EdgeInsets = EdgeInsets()
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .padding(bordered ? 1 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(bordered ? Color.Palette.divider : .clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

extension EdgeInsets {
    static func all(_ v: CGFloat) -> EdgeInsets { EdgeInsets(top: v, leading: v, bottom: v, trailing: v) }
    static func symmetric(v: CGFloat, h: CGFloat) -> EdgeInsets {
        EdgeInsets(top: v, leading: h, bottom: v, trailing: h)
    }
}

struct NavigationRow: View {
    let title: String
    var isLast: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(AppFont.medium(15))
                    .foregroundStyle(Color.Palette.textPrimary)
                Spacer(minLength: 0)
                Icons.chevronRight(size: 20).foregroundStyle(Color.Palette.primary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowDivider(isLast: isLast)
    }
}

struct GroupHead<Trailing: View>: View {
    let label: String
    var isFirst: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(AppFont.heavy(11))
                .kerning(0.6)
                .foregroundStyle(Color.Palette.textSecondary)
            trailing
            Spacer(minLength: 0)
        }
        .padding(.top, isFirst ? 8 : 14)
        .padding(.bottom, 4)
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Color.Palette.divider).frame(height: 1) }
        }
    }
}

extension GroupHead where Trailing == EmptyView {
    init(_ label: String, isFirst: Bool = true) {
        self.init(label: label, isFirst: isFirst, trailing: { EmptyView() })
    }
}

struct CountBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(AppFont.bold(11))
            .kerning(0.2)
            .foregroundStyle(Color.Palette.primaryDark)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.Palette.primaryPale))
    }
}

private struct RowDivider: ViewModifier {
    let isLast: Bool
    let addsHeight: Bool

    func body(content: Content) -> some View {
        content
            .padding(.bottom, isLast || !addsHeight ? 0 : 1)
            .overlay(alignment: .bottom) {
                if !isLast { Rectangle().fill(Color.Palette.divider).frame(height: 1) }
            }
    }
}

extension View {
    func rowDivider(isLast: Bool, addsHeight: Bool = true) -> some View {
        modifier(RowDivider(isLast: isLast, addsHeight: addsHeight))
    }
}

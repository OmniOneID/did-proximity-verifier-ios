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

struct TransportList: View {
    static var rowHeight: CGFloat { DragReorder.rowHeight }

    let order: [TransportKind]
    let onToggle: (TransportKind) -> Void
    let onReorder: ([TransportKind]) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var dragging: DragReorder?
    @State private var dragStart: CGPoint?

    private var rows: [TransportKind] {
        order + TransportKind.allCases.filter { !order.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, kind in
                row(kind, isLast: rowIndex == rows.count - 1)
            }
        }
        .padding(1)
        .background(Color.Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Palette.divider, lineWidth: 1)
        )
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            dragging = nil
            dragStart = nil
        }
    }

    private func row(_ kind: TransportKind, isLast: Bool) -> some View {
        let index = order.firstIndex(of: kind)
        let enabled = index != nil
        let lifted = enabled && dragging?.index == index
        let lockedOn = enabled && order.count == 1

        return HStack(spacing: 12) {
            Button { onToggle(kind) } label: {
                CheckBoxView(isOn: enabled)
                    .compositingGroup()
                    .opacity(lockedOn ? 0.45 : 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!lockedOn)
            .accessibilityLabel("Use \(kind.label)")
            .accessibilityIdentifier("transportCheckBoxTouch")

            if let index {
                Text("\(index + 1)")
                    .font(AppFont.bold(11.5))
                    .foregroundStyle(Color.Palette.primaryDark)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.Palette.primaryPale))
                    .accessibilityIdentifier("transportBadge")
            } else {
                Color.clear.frame(width: 22, height: 22)
            }

            Text(kind.label)
                .font(AppFont.medium(14.5))
                .foregroundStyle(enabled ? Color.Palette.textPrimary : Color.Palette.gray500)
                .lineLimit(1)
                .accessibilityIdentifier("transportLabel")

            Spacer(minLength: 0)

            if let index {
                Icons.drag(size: 20)
                    .foregroundStyle(Color.Palette.gray500)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .highPriorityGesture(handleGesture(startingAt: index))
                    .accessibilityElement()
                    .accessibilityLabel("Reorder \(kind.label)")
                    .accessibilityIdentifier("transportHandle")
            } else {
                Color.clear.frame(width: 36, height: 44)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("transportRow")
        .background(Color.Palette.card)
        .rowDivider(isLast: isLast, addsHeight: false)
        .offset(y: lifted ? (dragging?.offset ?? 0) : 0)
        .shadow(color: lifted ? .black.opacity(0.16) : .clear, radius: 7, y: 4)
        .zIndex(lifted ? 2 : 1)
        .animation(.easeInOut(duration: 0.15), value: enabled)
    }

    private func handleGesture(startingAt index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let state = (dragStart == value.startLocation ? dragging : nil) ?? DragReorder(index: index)
                dragStart = value.startLocation
                let (next, move) = state.stepped(translation: value.translation.height,
                                                 count: order.count)
                if let move { onReorder(order.moving(from: move.from, to: move.to)) }
                dragging = next
            }
            .onEnded { _ in
                dragging = nil
                dragStart = nil
            }
    }
}

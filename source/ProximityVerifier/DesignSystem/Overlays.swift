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

struct DotSpinner: View {
    var size: CGFloat = 32
    var color: Color = Color.Palette.primary
    var trackColor: Color = Color.Palette.gray300

    @State private var step = 0
    private let timer = Timer.publish(every: 0.125, on: .main, in: .common).autoconnect()

    var body: some View {
        let dot = max(4, (size * 0.18).rounded())
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(i == step ? color : trackColor)
                    .frame(width: dot, height: dot)
                    .offset(y: -(size - dot) / 2)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: size, height: size)
        .onReceive(timer) { _ in step = (step + 1) % 8 }
    }
}

struct DialogContent: Identifiable, Equatable {
    let id = UUID()
    var title: String = "Error"
    let message: String
    var dismissesScreen: Bool = false

    static func == (a: DialogContent, b: DialogContent) -> Bool { a.id == b.id }
}

struct CenterDialog: View {
    let content: DialogContent
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 10) {
                Text(content.title)
                    .font(AppFont.bold(18))
                    .foregroundStyle(Color.Palette.textPrimary)
                Text(content.message)
                    .font(AppFont.regular(14))
                    .foregroundStyle(Color.Palette.textSecondary)
                    .lineHeight(1.5, fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: "OK", action: onDismiss)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
            )
            .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
            .padding(28)
        }
        .transition(.opacity)
    }
}

extension View {
    func errorDialog(_ dialog: Binding<DialogContent?>, onDismiss: @escaping (DialogContent) -> Void) -> some View {
        overlay {
            if let content = dialog.wrappedValue {
                CenterDialog(content: content) {
                    dialog.wrappedValue = nil
                    onDismiss(content)
                }
            }
        }
        .animation(.easeOut(duration: 0.16), value: dialog.wrappedValue)
    }
}

struct SheetAction: Identifiable {
    var id: String { label }
    let label: String
    let icon: AnyView
    let action: () -> Void

    init(label: String, @ViewBuilder icon: () -> some View, action: @escaping () -> Void) {
        self.label = label
        self.icon = AnyView(icon())
        self.action = action
    }
}

enum SheetMotion {
    static var slide: Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }
    static let settle = Animation.spring(response: 0.30, dampingFraction: 0.85)
    static let dismissDelay: TimeInterval = 0.32

    static func transition(bottomInset: CGFloat) -> AnyTransition {
        .move(edge: .bottom).combined(with: .offset(y: bottomInset))
    }
}

struct ActionBottomSheet: View {
    let title: String
    let description: String
    let actions: [SheetAction]
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber(dragOffset: $dragOffset, onClose: onClose)
            Text(title)
                .font(AppFont.semibold(18))
                .foregroundStyle(Color.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            Text(description)
                .font(AppFont.regular(13))
                .foregroundStyle(Color.Palette.textSecondary)
                .lineHeight(1.5, fontSize: 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                Button(action: item.action) {
                    HStack(spacing: 16) {
                        item.icon
                            .foregroundStyle(Color.Palette.primary)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.Palette.primaryPale)
                            )
                        Text(item.label)
                            .font(AppFont.medium(16))
                            .foregroundStyle(Color.Palette.textPrimary)
                        Spacer(minLength: 0)
                        Icons.chevronRight(size: 20).foregroundStyle(Color.Palette.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Color.Palette.divider).frame(height: 1) }
                }
            }

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: dragOffset)
    }

}

struct SheetGrabber: View {
    @Binding var dragOffset: CGFloat
    let onClose: () -> Void

    var body: some View {
        Capsule()
            .fill(Color.Palette.gray300)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in dragOffset = max(0, value.translation.height) }
                    .onEnded { value in
                        if value.translation.height > 80 || value.predictedEndTranslation.height > 160 {
                            withAnimation(SheetMotion.slide) { dragOffset = 0 }
                            onClose()
                        } else {
                            withAnimation(SheetMotion.settle) { dragOffset = 0 }
                        }
                    }
            )
    }
}

extension View {
    func actionSheet(isPresented: Binding<Bool>,
                     title: String,
                     description: String,
                     actions: [SheetAction]) -> some View {
        let dismiss: (@escaping () -> Void) -> Void = { work in
            withAnimation(SheetMotion.slide) { isPresented.wrappedValue = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + SheetMotion.dismissDelay, execute: work)
        }
        return overlay {
            GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismiss({}) }

                    ActionBottomSheet(
                        title: title,
                        description: description,
                        actions: actions.map { item in
                            SheetAction(label: item.label, icon: { item.icon }) { dismiss(item.action) }
                        },
                        onClose: { dismiss({}) })
                        .transition(SheetMotion.transition(bottomInset: proxy.safeAreaInsets.bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(SheetMotion.slide, value: isPresented.wrappedValue)
            }
        }
    }
}

struct SelectionOption: Identifiable {
    var id: String { label }
    let label: String
    let isSelected: Bool
    let action: () -> Void
}

struct SelectionBottomSheet: View {
    let title: String
    let description: String
    let options: [SelectionOption]
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber(dragOffset: $dragOffset, onClose: onClose)
            Text(title)
                .font(AppFont.semibold(18))
                .foregroundStyle(Color.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            Text(description)
                .font(AppFont.regular(13))
                .foregroundStyle(Color.Palette.textSecondary)
                .lineHeight(1.5, fontSize: 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            ForEach(options) { item in
                Button(action: item.action) {
                    HStack(spacing: 16) {
                        Text(item.label)
                            .font(AppFont.medium(16))
                            .foregroundStyle(Color.Palette.textPrimary)
                        Spacer(minLength: 0)
                        if item.isSelected {
                            Icons.check(size: 20, stroke: 2.5).foregroundStyle(Color.Palette.primary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(item.isSelected ? Color.Palette.primaryPale : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if item.id != options.first?.id { Rectangle().fill(Color.Palette.divider).frame(height: 1) }
                }
            }

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: dragOffset)
    }
}

extension View {
    func selectionSheet(isPresented: Binding<Bool>,
                        title: String,
                        description: String,
                        options: [SelectionOption]) -> some View {
        let close = { withAnimation(SheetMotion.slide) { isPresented.wrappedValue = false } }
        return overlay {
            GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { close() }

                    SelectionBottomSheet(
                        title: title,
                        description: description,
                        options: options.map { item in
                            SelectionOption(label: item.label, isSelected: item.isSelected) {
                                item.action()
                                close()
                            }
                        },
                        onClose: close)
                        .transition(SheetMotion.transition(bottomInset: proxy.safeAreaInsets.bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(SheetMotion.slide, value: isPresented.wrappedValue)
            }
        }
    }
}

struct LoadingScrim: View {
    var message: String = "Please wait a moment"

    var body: some View {
        ZStack {
            Color.Palette.scrim.ignoresSafeArea()
            VStack(spacing: 24) {
                DotSpinner(size: 48)
                Text(message)
                    .font(AppFont.regular(13))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { }
    }
}

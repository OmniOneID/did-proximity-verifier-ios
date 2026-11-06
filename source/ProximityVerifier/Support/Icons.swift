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

struct SymbolIcon: View {
    let name: String
    let size: CGFloat
    let weight: Font.Weight

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.82, weight: weight))
            .frame(width: size, height: size)
    }
}

struct CloseIcon: View {
    var size: CGFloat = 26

    var body: some View {
        let unit = size / 24
        Path { path in
            path.move(to: CGPoint(x: 18 * unit, y: 6 * unit))
            path.addLine(to: CGPoint(x: 6 * unit, y: 18 * unit))
            path.move(to: CGPoint(x: 6 * unit, y: 6 * unit))
            path.addLine(to: CGPoint(x: 18 * unit, y: 18 * unit))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

struct VectorIcon: View {
    let size: CGFloat
    var stroke: CGFloat = 1.8
    var filled = false
    let path: (inout Path) -> Void

    var body: some View {
        let unit = size / 24
        let shape = Path { path(&$0) }.applying(CGAffineTransform(scaleX: unit, y: unit))
        Group {
            if filled {
                shape.fill(style: FillStyle(eoFill: true))
            } else {
                shape.stroke(style: StrokeStyle(lineWidth: stroke * unit, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

private extension Path {
    mutating func curve(_ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
    }
    mutating func line(_ x: CGFloat, _ y: CGFloat) { addLine(to: CGPoint(x: x, y: y)) }
    mutating func start(_ x: CGFloat, _ y: CGFloat) { move(to: CGPoint(x: x, y: y)) }
}

enum Icons {
    static func menu(size: CGFloat = 24) -> VectorIcon {
        VectorIcon(size: size) { p in
            p.start(3, 6); p.line(21, 6)
            p.start(3, 12); p.line(21, 12)
            p.start(3, 18); p.line(21, 18)
        }
    }
    static func back(size: CGFloat = 24) -> SymbolIcon { SymbolIcon(name: "arrow.left", size: size, weight: .medium) }
    static func close(size: CGFloat = 26) -> CloseIcon { CloseIcon(size: size) }
    static func gear(size: CGFloat = 24) -> SymbolIcon { SymbolIcon(name: "gearshape", size: size, weight: .medium) }
    static func chevronRight(size: CGFloat = 20) -> SymbolIcon { SymbolIcon(name: "chevron.right", size: size, weight: .semibold) }
    static func chevronDown(size: CGFloat = 20) -> SymbolIcon { SymbolIcon(name: "chevron.down", size: size, weight: .semibold) }
    static func chevronUp(size: CGFloat = 20) -> SymbolIcon { SymbolIcon(name: "chevron.up", size: size, weight: .semibold) }
    static func check(size: CGFloat = 14, stroke: CGFloat = 3) -> VectorIcon {
        VectorIcon(size: size, stroke: stroke) { p in
            p.start(20, 6); p.line(9, 17); p.line(4, 12)
        }
    }
    static func qr(size: CGFloat = 22) -> VectorIcon {
        VectorIcon(size: size) { p in
            for origin in [CGPoint(x: 3, y: 3), CGPoint(x: 14, y: 3), CGPoint(x: 3, y: 14)] {
                p.addRoundedRect(in: CGRect(origin: origin, size: CGSize(width: 7, height: 7)), cornerSize: CGSize(width: 1, height: 1))
            }
            p.start(14, 14); p.line(17, 14); p.line(17, 17); p.line(14, 17); p.closeSubpath()
            p.start(20, 14); p.line(20, 17)
            p.start(14, 20); p.line(17, 20)
            p.start(17, 17); p.line(21, 17); p.line(21, 21)
        }
    }
    static func nfc(size: CGFloat = 22) -> VectorIcon {
        VectorIcon(size: size, filled: true) { p in
            p.start(20, 2); p.line(4, 2); p.curve(2.9, 2, 2, 2.9, 2, 4); p.line(2, 20)
            p.curve(2, 21.1, 2.9, 22, 4, 22); p.line(20, 22); p.curve(21.1, 22, 22, 21.1, 22, 20)
            p.line(22, 4); p.curve(22, 2.9, 21.1, 2, 20, 2); p.closeSubpath()
            p.start(20, 20); p.line(4, 20); p.line(4, 4); p.line(20, 4); p.closeSubpath()
            p.start(18, 6); p.line(13, 6); p.curve(11.9, 6, 11, 6.9, 11, 8); p.line(11, 10.28)
            p.curve(10.4, 10.63, 10, 11.26, 10, 12); p.curve(10, 13.1, 10.9, 14, 12, 14)
            p.curve(13.1, 14, 14, 13.1, 14, 12); p.curve(14, 11.26, 13.6, 10.62, 13, 10.28)
            p.line(13, 8); p.line(16, 8); p.line(16, 16); p.line(8, 16); p.line(8, 8); p.line(10, 8)
            p.line(10, 6); p.line(6, 6); p.line(6, 18); p.line(18, 18); p.closeSubpath()
        }
    }
    static func drag(size: CGFloat = 20) -> VectorIcon {
        VectorIcon(size: size) { p in
            p.start(4, 9); p.line(20, 9)
            p.start(4, 15); p.line(20, 15)
        }
    }
}

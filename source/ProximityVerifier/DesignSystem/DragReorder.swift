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

import CoreGraphics

struct DragReorder: Equatable {
    var index: Int
    var baseTranslation: CGFloat
    var offset: CGFloat

    static let rowHeight: CGFloat = 52

    init(index: Int, baseTranslation: CGFloat = 0, offset: CGFloat = 0) {
        self.index = index
        self.baseTranslation = baseTranslation
        self.offset = offset
    }

    func stepped(translation: CGFloat, count: Int) -> (state: DragReorder, move: (from: Int, to: Int)?) {
        let moved = translation - baseTranslation
        let target = min(max(index + Int((moved / Self.rowHeight).rounded()), 0), count - 1)

        guard target != index else {
            let lower = -CGFloat(index) * Self.rowHeight
            let upper = CGFloat(count - 1 - index) * Self.rowHeight
            return (DragReorder(index: index, baseTranslation: baseTranslation,
                                offset: min(max(moved, lower), upper)), nil)
        }

        let base = baseTranslation + CGFloat(target - index) * Self.rowHeight
        let lower = -CGFloat(target) * Self.rowHeight
        let upper = CGFloat(count - 1 - target) * Self.rowHeight
        return (DragReorder(index: target, baseTranslation: base,
                            offset: min(max(translation - base, lower), upper)), (index, target))
    }
}

extension Array {
    func moving(from: Int, to: Int) -> [Element] {
        var next = self
        next.insert(next.remove(at: from), at: to)
        return next
    }
}

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

enum AppFont {
    static func regular(_ size: CGFloat) -> Font { .custom("PretendardVariable-Regular", size: size) }
    static func medium(_ size: CGFloat)  -> Font { .custom("PretendardVariable-Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font { .custom("PretendardVariable-SemiBold", size: size) }
    static func bold(_ size: CGFloat)    -> Font { .custom("PretendardVariable-Bold", size: size) }
    static func heavy(_ size: CGFloat)   -> Font { .custom("PretendardVariable-ExtraBold", size: size) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

enum Metrics {
    static let screenHorizontal: CGFloat = 16
    static let screenTop: CGFloat = 20
    static let screenBottom: CGFloat = 24
    static let sectionGap: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let appBarHeight: CGFloat = 56
    static let ctaHeight: CGFloat = 52
}

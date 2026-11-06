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
import MdocReader

@main
struct ProximityVerifierApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        Self.resetForUITestIfRequested()
        // SDK log — Debug builds only; Release builds keep the SDK default `.off`.
        // Printed to stdout so the Xcode console and the Maestro runner (`devicectl --console`,
        // which carries stdout but not os_log) both get it. os_log is off to avoid doubled lines.
        MdocLog.level = .debug
        MdocLog.systemLogEnabled = false
        MdocLog.handler = { print("[MdocSDK] \($0.formatted)") }
        #endif
        let trustedIssuers = TrustedIssuerStore()
        let model = AppModel(session: Self.makeSession(trustedIssuers: trustedIssuers),
                             trustedIssuers: trustedIssuers)
        _model = State(initialValue: model)
    }

    @MainActor
    private static func makeSession(trustedIssuers store: TrustedIssuerStore) -> VerificationSession {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-mock") { return MockVerificationSession() }
        #endif
        return SDKVerificationSession(trustedIssuers: { store.issuers })
    }

    #if DEBUG
    /// E2E (Maestro) only: launched with `-uiTestReset YES`, wipes everything the app stores before any store
    /// reads it — settings, the trusted issuer list and its stamp, and the cached DID documents — the way
    /// Android's `pm clear` does. Maestro's `clearState` does not reach the app on a physical iPhone.
    private static func resetForUITestIfRequested() {
        guard UserDefaults.standard.bool(forKey: "uiTestReset") else { return }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: support.appendingPathComponent("TrustedIssuerDocuments"))
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.handleBackground() }
        }
    }
}

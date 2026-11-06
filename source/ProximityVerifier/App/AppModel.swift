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

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    // MARK: Navigation

    var path: [Route] = [] {
        didSet {
            if oldValue.contains(.transferStatus), !path.contains(.transferStatus), sessionTask != nil {
                sessionTask?.cancel()
                sessionTask = nil
                session.cancel()
            }
            if oldValue.contains(.receivedCredentials), !path.contains(.receivedCredentials) {
                receivedCredentials = []
            }
        }
    }

    func push(_ route: Route) { path.append(route) }

    func pop() { if !path.isEmpty { path.removeLast() } }

    func goHome() { path.removeAll() }

    var isScannerPresented = false

    // MARK: Request

    var request = VerificationRequestDraft()

    // MARK: Settings

    var settings: VerifierSettings {
        didSet { SettingsStore.save(settings) }
    }

    // MARK: Trust

    let trustedIssuers: TrustedIssuerStore

    // MARK: Session

    private(set) var transferStatus: TransferStatus = .connecting
    private(set) var sessionRequest = VerificationRequestDraft()
    private(set) var receivedCredentials: [ReceivedCredential] = []
    var dialog: DialogContent?

    private let session: VerificationSession
    private var sessionTask: Task<Void, Never>?

    var isSessionRunning: Bool { sessionTask != nil }

    init(session: VerificationSession, trustedIssuers: TrustedIssuerStore) {
        self.session = session
        self.trustedIssuers = trustedIssuers
        self.settings = SettingsStore.load()
    }

    // MARK: - Session flow

    func presentScanner() {
        guard !isSessionRunning else { return }
        isScannerPresented = true
    }

    func dismissScanner() { isScannerPresented = false }

    func startSession(qrString: String) {
        isScannerPresented = false
        transferStatus = .connecting
        path.append(.transferStatus)
        launch { [self] in
            try await session.run(qrString: qrString, request: request, settings: settings,
                                  onStatus: { [weak self] in self?.transferStatus = $0 })
        }
    }

    func startSessionViaNFC() {
        guard !isSessionRunning else { return }
        launch { [self] in
            try await session.runViaNFC(request: request, settings: settings,
                                        onStatus: { [weak self] status in
                                            guard let self else { return }
                                            self.transferStatus = status
                                            if status != .connecting, status != .disconnected,
                                               self.path.last != .transferStatus {
                                                self.path = [.transferStatus]
                                            }
                                        })
        }
    }

    func cancelSession() {
        sessionTask?.cancel()
        sessionTask = nil
        session.cancel()
        goHome()
    }

    func finishResult() {
        receivedCredentials = []
        goHome()
    }

    func dismissDialog(_ content: DialogContent) {
        if content.dismissesScreen { goHome() }
    }

    func handleBackground() {
        if isScannerPresented { dismissScanner() }
        if isSessionRunning {
            cancelSession()
        } else if path.last == .receivedCredentials || path.last == .transferStatus {
            receivedCredentials = []
            goHome()
        }
    }

    // MARK: - Private

    private func launch(_ body: @escaping () async throws -> [ReceivedCredential]) {
        sessionTask?.cancel()
        transferStatus = .connecting
        sessionRequest = request
        sessionTask = Task { [weak self] in
            do {
                let documents = try await body()
                guard let self, !Task.isCancelled else { return }
                self.sessionTask = nil
                self.receivedCredentials = documents
                self.path = [.receivedCredentials]
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.sessionTask = nil
                self.present(VerifierError(error))
            }
        }
    }

    private func present(_ error: VerifierError) {
        guard let message = error.message else {
            goHome()
            return
        }
        dialog = DialogContent(title: error.title, message: message, dismissesScreen: true)
    }
}

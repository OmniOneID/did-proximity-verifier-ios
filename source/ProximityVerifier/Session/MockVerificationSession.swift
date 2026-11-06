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
import UIKit

final class MockVerificationSession: VerificationSession {
    enum Scenario {
        case success
        case issuerNotTrusted
        case disconnected
        case sdkError(String)
    }

    var scenario: Scenario = .success
    var stepInterval: TimeInterval = 0.9

    private var task: Task<Void, Never>?
    private var isCancelled = false

    func run(qrString: String,
             request: VerificationRequestDraft,
             settings: VerifierSettings,
             onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential] {
        guard qrString.hasPrefix("mdoc:") else { throw VerifierError.invalidEngagement }
        return try await drive(request: request, settings: settings, onStatus: onStatus)
    }

    func runViaNFC(request: VerificationRequestDraft,
                   settings: VerifierSettings,
                   onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential] {
        try await drive(request: request, settings: settings, onStatus: onStatus)
    }

    func cancel() {
        isCancelled = true
        task?.cancel()
    }

    private func drive(request: VerificationRequestDraft,
                       settings: VerifierSettings,
                       onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential] {
        isCancelled = false
        let steps: [TransferStatus] = [.connecting, .connected, .deviceEngagementCompleted, .requestSent]
        for (index, step) in steps.enumerated() {
            try checkCancelled()
            await onStatus(step)
            try await sleep()

            if index == steps.count - 1 {
                switch scenario {
                case .disconnected:
                    await onStatus(.disconnected)
                    throw VerifierError.disconnected
                case .sdkError(let message):
                    await onStatus(.error(message))
                    throw VerifierError.sdk(message: message)
                default:
                    break
                }
            }
        }
        try checkCancelled()
        await onStatus(.responseReceived)
        return Self.sampleCredentials(for: request, trust: {
            if settings.skipIssuerAuth { return .skipped }
            if case .issuerNotTrusted = scenario { return .no(.notListed) }
            return .sampleYes
        }())
    }

    private func checkCancelled() throws {
        if isCancelled || Task.isCancelled { throw VerifierError.cancelled }
    }

    private func sleep() async throws {
        do {
            try await Task.sleep(for: .seconds(stepInterval))
        } catch {
            throw VerifierError.cancelled
        }
    }

    static func sampleCredentials(for request: VerificationRequestDraft,
                                  trust: IssuerTrustDisplay,
                                  deviceAuth: DeviceAuthDisplay = .yes) -> [ReceivedCredential] {
        var result: [ReceivedCredential] = []

        for group in DocumentCatalog.groups {
            guard let wanted = request.requestedElementIDs(for: group) else { continue }
            let all = sampleClaims(for: group.catalog.docType)
            let claims = all.filter { wanted.contains($0.id) }
            result.append(ReceivedCredential(docType: group.catalog.docType,
                                             issuerTrusted: trust,
                                             deviceAuth: deviceAuth,
                                             validFrom: "04 Aug 2026",
                                             validUntil: "02 Nov 2026",
                                             claims: claims))
        }
        return result
    }

    private static func sampleClaims(for docType: String) -> [ReceivedClaim] {
        func claim(_ id: String, _ value: ReceivedClaimValue) -> ReceivedClaim {
            ReceivedClaim(id: id, label: id, value: value)
        }
        switch docType {
        case ClaimCatalog.pid.docType:
            return [
                claim("family_name", .text("Kim")),
                claim("given_name", .text("Raon")),
                claim("birth_date", .text("1992-03-12")),
                claim("portrait", samplePortrait.map(ReceivedClaimValue.image) ?? .text("—")),
            ]
        default:
            return []
        }
    }

    // 100×120 px placeholder, the same size as the design's sample portrait.
    private static let samplePortrait: Data? = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 100, height: 120)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setStroke()
            let face = UIBezierPath(ovalIn: CGRect(x: 24, y: 10, width: 52, height: 70))
            face.lineWidth = 2
            face.stroke()
            let shoulders = UIBezierPath()
            shoulders.move(to: CGPoint(x: 20, y: 101))
            shoulders.addCurve(to: CGPoint(x: 80, y: 101),
                               controlPoint1: CGPoint(x: 36, y: 84), controlPoint2: CGPoint(x: 64, y: 84))
            shoulders.lineWidth = 2
            shoulders.stroke()
        }
        return image.pngData()
    }()
}

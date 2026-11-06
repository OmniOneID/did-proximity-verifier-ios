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
#if DEBUG
@_spi(MdocInternal) import MdocReader
@_spi(MdocInternal) import MdocNFC
#else
import MdocReader
#endif

@MainActor
final class SDKVerificationSession: VerificationSession {
    private let trustedIssuers: @MainActor () -> [TrustedIssuer]
    private let issuerKeys: IssuerKeyResolving

    private var reader: MdocReaderSession?
    private var relay: StatusRelay?

    init(trustedIssuers: @escaping @MainActor () -> [TrustedIssuer],
         issuerKeys: IssuerKeyResolving = IssuerKeyStoreFactory.make()) {
        self.trustedIssuers = trustedIssuers
        self.issuerKeys = issuerKeys
    }

    // MARK: - VerificationSession

    func run(qrString: String,
             request: VerificationRequestDraft,
             settings: VerifierSettings,
             onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential] {
        let engagement: EngagementPayload
        do {
            engagement = try EngagementPayload.parse(qrString: qrString)
        } catch {
            throw VerifierError.invalidEngagement
        }
        SessionTrace.log("engagement: \(engagement.technology) advertised=\(engagement.transmissions)")
        let configuration = try Self.qrConfiguration(settings.readerConfiguration, engagement: engagement)
        SessionTrace.log("priority: \(configuration.transmissionPriority)")
        return try await verify(request: request, settings: settings, configuration: configuration,
                                onStatus: onStatus) { reader in
            try await reader.connect(to: engagement)
        }
    }

    func runViaNFC(request: VerificationRequestDraft,
                   settings: VerifierSettings,
                   onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential] {
        try await verify(request: request, settings: settings, configuration: settings.readerConfiguration,
                         onStatus: onStatus) { reader in
            let engagement: EngagementPayload
            do {
                engagement = try await reader.connectViaNFC()
            } catch MdocProximityError.malformedEngagement, MdocProximityError.decodeFailed {
                throw VerifierError.connectionInterrupted
            } catch MdocProximityError.connectionFailed(let detail) where detail.hasPrefix("NFC session:") {
                // The Core NFC sheet closed before handover (timeout, system invalidation). The OS sheet already told
                // the user, so stay on Home without an app dialog, like a sheet cancel (NFC-E-04 · NFC-E-07).
                throw VerifierError.cancelled
            }
            SessionTrace.log("engagement: \(engagement.technology) advertised=\(engagement.transmissions)")
            SessionTrace.log("priority: \(settings.readerConfiguration.transmissionPriority)")
        }
    }

    nonisolated func cancel() {
        MainActor.assumeIsolated { closeReader() }
    }

    // MARK: - Private

    static func qrConfiguration(_ configuration: MdocReaderConfiguration,
                                engagement: EngagementPayload) throws -> MdocReaderConfiguration {
        let advertised = engagement.transmissions.compactMap(TransmissionKind.init)
        let policy = configuration.transmissionPriority
        let remaining = policy.filter { $0 != .nfc }
        if policy.contains(.nfc), !remaining.contains(where: advertised.contains),
           remaining.isEmpty || advertised.contains(.nfc) {
            throw VerifierError.nfcNotRecommended
        }
        var adjusted = configuration
        adjusted.transmissionPriority = remaining
        return adjusted
    }

    private func verify(request: VerificationRequestDraft,
                        settings: VerifierSettings,
                        configuration: MdocReaderConfiguration,
                        onStatus: @escaping TransferStatusHandler,
                        connect: (MdocReaderSession) async throws -> Void) async throws -> [ReceivedCredential] {
        closeReader()

        let issuers = trustedIssuers()
        let reader = Self.makeReader(configuration: configuration, trust: DeferredTrustEvaluator())
        let relay = StatusRelay(onStatus: onStatus)
        reader.delegate = relay
        self.reader = reader
        self.relay = relay
        defer { if self.reader === reader { closeReader() } }

        do {
            onStatus(.connecting)
            SessionTrace.log("settings: l2cap=\(settings.useL2CAP) bleMode=\(settings.bleTransferMode)")
            SessionTrace.log("connect: begin")
            try await connect(reader)
            try checkCancelled()
            SessionTrace.log("connect: done")
            onStatus(.deviceEngagementCompleted)

            let specs = request.itemsRequestSpecs()
            SessionTrace.log("request: \(specs.map(\.docType))")
            let response = try await reader.request(specs, at: Date())
            try checkCancelled()
            SessionTrace.log("response: \(response.documents.count) document(s), verdicts \(response.documents.map { "\($0.verdict)" })")
            #if DEBUG
            for document in response.documents { SessionTrace.log(SessionTrace.describe(document)) }
            #endif
            onStatus(.responseReceived)

            closeReader()
            return await credentials(from: response, issuers: issuers)
        } catch {
            SessionTrace.log("failed: \(error)")
            let failure = VerifierError(error)
            if !Task.isCancelled, case .disconnected = failure { onStatus(.disconnected) }
            throw failure
        }
    }

    private static func makeReader(configuration: MdocReaderConfiguration,
                                   trust: TrustEvaluatorProtocol) -> MdocReaderSession {
        #if DEBUG
        let source = CoreNfcTagSource()
        source.onTagSeen = { SessionTrace.log("nfc tag: \($0)") }
        let reader = MdocReaderSession(configuration: configuration, trust: trust,
                                       transportFactory: TracingTransportFactory(inner: ReaderTransportFactory()),
                                       nfcTagSource: TracingNfcTagSource(inner: source))
        reader.onTransportEvent = { event in
            if case .progress = event { return }
            SessionTrace.log("transport: \(event)")
        }
        return reader
        #else
        return MdocReaderSession(configuration: configuration, trust: trust)
        #endif
    }

    private func credentials(from response: VerifiedResponse,
                             issuers: [TrustedIssuer]) async -> [ReceivedCredential] {
        var credentials: [ReceivedCredential] = []
        for document in response.documents {
            if document.issuerDataAuth.verificationSkipped {
                credentials.append(ReceivedCredential(document, issuerTrusted: .skipped))
                continue
            }
            let evaluator = TrustedIssuerEvaluator(issuers: issuers, docType: document.docType, keys: issuerKeys)
            let resolved = await MdocReaderSession.resolveTrust(for: document, using: evaluator, at: Date())
            let display = evaluator.display(for: resolved)
            SessionTrace.log("trust \(document.docType): \(String(describing: evaluator.outcome)) → \(display.text)")
            credentials.append(ReceivedCredential(resolved, issuerTrusted: display))
        }
        return credentials
    }

    private func checkCancelled() throws {
        if Task.isCancelled { throw VerifierError.cancelled }
    }

    private func closeReader() {
        reader?.delegate = nil
        reader?.terminate()
        reader = nil
        relay = nil
    }
}

private extension TransmissionKind {
    init?(_ technology: TransmissionTechnology) {
        switch technology {
        case .ble: self = .ble
        case .nfc: self = .nfc
        case .wifiAware: self = .wifiAware
        @unknown default: return nil
        }
    }
}

private final class StatusRelay: MdocReaderSessionDelegate {
    private let onStatus: TransferStatusHandler

    init(onStatus: @escaping TransferStatusHandler) {
        self.onStatus = onStatus
    }

    func readerSession(_ session: MdocReaderSession, didChangeState state: MdocReaderState) {
        SessionTrace.log("state: \(state.rawValue)")
        guard let status = TransferStatus(state) else { return }
        deliver(status)
    }

    func readerSessionDidConnect(_ session: MdocReaderSession) {}

    func readerSession(_ session: MdocReaderSession, didProgress received: Int, of total: Int) {
        SessionTrace.log("progress: \(received)/\(total)")
    }

    func readerSession(_ session: MdocReaderSession, didFailWith error: MdocProximityError) {
        SessionTrace.log("didFail: \(error)")
        if case .disconnected = VerifierError(error) { deliver(.disconnected) }
    }

    private func deliver(_ status: TransferStatus) {
        MainActor.assumeIsolated { onStatus(status) }
    }
}

extension TransferStatus {
    init?(_ state: MdocReaderState) {
        switch state {
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .awaitingResponse: self = .requestSent
        case .verifying, .completed: self = .responseReceived
        case .terminated: self = .disconnected
        case .idle, .failed: return nil
        @unknown default: return nil
        }
    }
}

enum SessionTrace {
    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[session \(clock.string(from: Date()))] \(message())")
        #endif
    }
}

#if DEBUG
extension SessionTrace {
    static func describe(_ d: VerifiedDocument) -> String {
        let auth = d.mdocAuth
        let issuer = d.issuerDataAuth
        let mismatched = d.digests?.matches.flatMap { ns, m in m.filter { !$0.value }.map { "\(ns)/\($0.key)" } } ?? []
        var parts = [
            "doc \(d.docType)",
            "mdocAuth \(auth.method) valid=\(auth.valid) bound=\(auth.boundToIssuerDeviceKey)",
            "issuerAuth skipped=\(issuer.verificationSkipped) sig=\(issuer.signatureValid) docType=\(issuer.docTypeChecked)/\(issuer.docTypeMatches) trust=\(issuer.trust)",
            "digests \(d.digests.map { "\($0.allMatch)" } ?? "none") mismatched=\(mismatched)",
            "elements issuer=\(d.issuerSignedElements.mapValues(\.count)) device=\(d.deviceSignedElements.mapValues(\.count))",
            "notReturned=\(d.notReturned.mapValues(\.count)) errors=\(d.elementErrors)",
            "warnings=\(d.warnings.count)"
        ]
        if let v = issuer.validity {
            parts.append("validity \(v.validFrom)…\(v.validUntil) current=\(v.isCurrentlyValid)")
        }
        return "verdict detail: " + parts.joined(separator: " | ")
    }
}

/// Logs the transport the SDK actually builds — which BLE mode it picked when the holder advertised both, and
/// whether L2CAP was requested (a GATT fallback shows up as a `downgradedToGatt` transport event).
struct TracingTransportFactory: TransportFactoryProtocol {
    let inner: TransportFactoryProtocol
    var availableTechnologies: [TransmissionTechnology] { inner.availableTechnologies }
    func makeTransport(_ parameters: TransportParameters) throws -> DataRetrievalTransportProtocol {
        SessionTrace.log("transport: build \(parameters.technology) l2cap=\(parameters.l2cap)")
        return try inner.makeTransport(parameters)
    }
}

final class TracingNfcTagSource: NfcTagSource {
    private let inner: NfcTagSource
    init(inner: NfcTagSource) { self.inner = inner }
    func openChannel() async throws -> Iso7816Channel {
        TracingChannel(inner: try await inner.openChannel())
    }
    func cancel() { inner.cancel() }
}

final class TracingChannel: Iso7816Channel {
    private let inner: Iso7816Channel
    init(inner: Iso7816Channel) { self.inner = inner }

    func transceive(_ apdu: Data) async throws -> Data {
        let head = apdu.prefix(5).map { String(format: "%02X", $0) }.joined(separator: " ")
        SessionTrace.log("apdu > \(head) … (\(apdu.count)B)")
        let started = Date()
        do {
            let r = try await inner.transceive(apdu)
            let sw = r.suffix(2).map { String(format: "%02X", $0) }.joined()
            SessionTrace.log("apdu < SW \(sw) (\(r.count - 2)B) \(Int(Date().timeIntervalSince(started) * 1000))ms")
            return r
        } catch {
            SessionTrace.log("apdu < error after \(Int(Date().timeIntervalSince(started) * 1000))ms: \(error)")
            throw error
        }
    }
    var isAvailable: Bool { inner.isAvailable }
    func close() { inner.close() }
}
#endif

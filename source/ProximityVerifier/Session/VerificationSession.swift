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
import MdocReader

enum TransferStatus: Equatable {
    case connecting
    case connected
    case deviceEngagementCompleted
    case requestSent
    case responseReceived
    case disconnected
    case error(String)

    var displayText: String {
        switch self {
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .deviceEngagementCompleted: return "Device engagement completed"
        case .requestSent: return "Request sent"
        case .responseReceived: return "Response received"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error \(message)"
        }
    }
}

enum VerifierError: Error, Equatable {
    case connectionInterrupted
    case sdk(message: String?)
    case permission(message: String)
    case invalidEngagement
    case disconnected
    case noCompatibleTransport
    case nfcNotRecommended
    case cancelled

    static let connectionMessage = "The connection was interrupted. Please try again."
    static let genericMessage = "An unexpected error occurred."

    var message: String? {
        switch self {
        case .connectionInterrupted, .disconnected:
            return Self.connectionMessage
        case .sdk(let message):
            return message ?? Self.genericMessage
        case .permission(let message):
            return message
        case .invalidEngagement:
            return "This QR code is not a valid device engagement."
        case .noCompatibleTransport:
            return "No compatible transport is available with the current Transport settings."
        case .nfcNotRecommended:
            return "Devices connected by QR code can't transfer over NFC. Choose another transport in Settings."
        case .cancelled:
            return nil
        }
    }

    var title: String {
        if case .nfcNotRecommended = self { return "NFC not recommended" }
        return "Error"
    }
}

extension VerifierError {
    init(_ error: Error) {
        if let known = error as? VerifierError { self = known; return }
        if error is CancellationError { self = .cancelled; return }
        guard let sdk = error as? MdocProximityError else {
            self = .sdk(message: error.localizedDescription)
            return
        }
        switch sdk {
        case .connectionFailed, .transferTimeout, .engagementTimeout,
             .responseTimeout, .sessionEncryptionFailed, .counterMismatch:
            self = .connectionInterrupted
        case .peerDisconnected, .terminatedByPeer:
            self = .disconnected
        case .malformedEngagement:
            self = .invalidEngagement
        case .bleUnavailable(let reason):
            self = .permission(message: Self.unavailableMessage(transport: "Bluetooth", reason: reason))
        case .nfcUnavailable(let reason):
            self = .permission(message: Self.unavailableMessage(transport: "NFC", reason: reason))
        case .wifiAwareUnavailable:
            self = .noCompatibleTransport
        case .configurationRequired(let action):
            self = .permission(message: Self.message(for: action))
        case .unsupportedTransmissionTechnology:
            self = .noCompatibleTransport
        case .validationFailed(let detail), .decodeFailed(let detail):
            self = .sdk(message: detail)
        case .invalidState:
            self = .sdk(message: nil)
        @unknown default:
            self = .sdk(message: nil)
        }
    }

    private static func unavailableMessage(transport: String, reason: CapabilityReason) -> String {
        switch reason {
        case .noHardware:
            return "\(transport) is not supported on this device."
        case .osVersion:
            return "\(transport) on this device requires a newer iOS version."
        case .vendorPolicy:
            return "\(transport) is not available on this device."
        @unknown default:
            return "\(transport) is not available on this device."
        }
    }

    private static func message(for action: RequiredAction) -> String {
        switch action {
        case .enableBluetooth:
            return "Bluetooth is required to connect to the holder's device. Enable Bluetooth in system settings and try again."
        case .enableNfc:
            return "NFC is required to start this session. Enable NFC in system settings and try again."
        case .enableLocationServices:
            return "Location services are required for Bluetooth scanning. Enable them in system settings and try again."
        case .enableWifi:
            return "Wi-Fi is required to connect to the holder's device. Enable Wi-Fi in system settings and try again."
        case .grantPermission(let name) where name.lowercased() == "bluetooth":
            return "Bluetooth access is required to connect to the holder's device. Enable the Bluetooth permission in system settings and try again."
        case .grantPermission(let name):
            return "The \(name) permission is required to continue. Enable it in system settings and try again."
        case .addEntitlement(let name):
            return "This build is missing the \(name) entitlement."
        @unknown default:
            return VerifierError.genericMessage
        }
    }
}

typealias TransferStatusHandler = @MainActor (TransferStatus) -> Void

protocol VerificationSession: AnyObject {
    func run(qrString: String,
             request: VerificationRequestDraft,
             settings: VerifierSettings,
             onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential]

    func runViaNFC(request: VerificationRequestDraft,
                   settings: VerifierSettings,
                   onStatus: @escaping TransferStatusHandler) async throws -> [ReceivedCredential]

    func cancel()
}

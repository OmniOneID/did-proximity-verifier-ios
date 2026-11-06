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

enum ReceivedClaimValue: Equatable {
    case text(String)
    case group([(String, String)])
    case image(Data)

    static func == (a: ReceivedClaimValue, b: ReceivedClaimValue) -> Bool {
        switch (a, b) {
        case (.text(let l), .text(let r)): return l == r
        case (.image(let l), .image(let r)): return l == r
        case (.group(let l), .group(let r)):
            return l.count == r.count && zip(l, r).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: return false
        }
    }
}

struct ReceivedClaim: Identifiable, Equatable {
    let id: String
    let label: String
    let value: ReceivedClaimValue
}

enum IssuerTrustFailure: Equatable {
    case unidentified, notListed, docType, signature

    var message: String {
        switch self {
        case .unidentified: return "The issuer could not be identified from this credential."
        case .notListed: return "The issuer is not in the trusted issuer list."
        case .docType: return "The issuer is not trusted to issue this document type."
        case .signature: return "The issuer's signature could not be verified."
        }
    }
}

enum IssuerTrustDisplay: Equatable {
    case yes(issuerName: String?)
    case no(IssuerTrustFailure)
    case skipped

    var text: String {
        switch self {
        case .yes(let name?) where !name.isEmpty: return "Yes (\(name))"
        case .yes: return "Yes"
        case .no: return "No"
        case .skipped: return "Skipped"
        }
    }

    var note: String? {
        if case .no(let failure) = self { return failure.message }
        return nil
    }
}

extension IssuerTrustDisplay {
    static let sampleYes = IssuerTrustDisplay.yes(issuerName: "OpenDID Issuer")
}

enum DeviceAuthDisplay: Equatable {
    case yes, no

    var text: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
}

struct VerificationRow {
    let label: String
    let value: String
    var note: String? = nil
}

struct ReceivedCredential: Equatable {
    let docType: String
    let issuerTrusted: IssuerTrustDisplay
    let deviceAuth: DeviceAuthDisplay
    let validFrom: String
    let validUntil: String
    let claims: [ReceivedClaim]

    var validitySummary: [VerificationRow] {
        [VerificationRow(label: "Issuer Trusted", value: issuerTrusted.text, note: issuerTrusted.note),
         VerificationRow(label: "Device Auth", value: deviceAuth.text),
         VerificationRow(label: "Valid from", value: validFrom),
         VerificationRow(label: "Valid until", value: validUntil)]
    }
}

enum DateStyle {
    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yyyy HH:mm"
        return f
    }()

    static func date(_ date: Date) -> String { display.string(from: date) }

    static func stamp(_ date: Date) -> String { stamp.string(from: date) }
}

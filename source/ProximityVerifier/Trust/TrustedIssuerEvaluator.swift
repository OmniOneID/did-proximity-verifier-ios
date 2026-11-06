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

struct IssuerReference: Equatable {
    let did: String
    let method: String
    let fragment: String?

    init?(kid: String) {
        let base = String(kid.prefix { $0 != "?" && $0 != "#" })
        let parts = base.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "did", !parts[1].isEmpty, !parts[2].isEmpty else { return nil }
        did = base
        method = String(parts[1])
        fragment = kid.split(separator: "#", maxSplits: 1).dropFirst().first.map(String.init)
    }
}

final class DeferredTrustEvaluator: TrustEvaluatorProtocol {
    func evaluate(header: COSEHeaderSummary, purpose: TrustPurpose, at date: Date) async -> IssuerKeyResolution {
        .notResolved
    }
}

final class TrustedIssuerEvaluator: TrustEvaluatorProtocol {
    enum Outcome: Equatable {
        case matched(TrustedIssuer)
        case failed(IssuerTrustFailure)
    }

    private let issuers: [TrustedIssuer]
    private let docType: String
    private let keys: IssuerKeyResolving
    private(set) var outcome: Outcome?

    init(issuers: [TrustedIssuer], docType: String, keys: IssuerKeyResolving) {
        self.issuers = issuers
        self.docType = docType
        self.keys = keys
    }

    func evaluate(header: COSEHeaderSummary, purpose: TrustPurpose, at date: Date) async -> IssuerKeyResolution {
        guard purpose == .issuerDataAuthentication else { return .notResolved }
        guard let kid = header.kid, let reference = IssuerReference(kid: kid) else {
            return fail(.unidentified, reason: "kid is not a DID URL")
        }
        guard let issuer = issuers.first(where: { $0.did == reference.did }) else {
            return fail(.notListed, reason: "\(reference.did) is not in the trusted issuer list")
        }
        guard issuer.docTypes.contains(docType) else {
            return fail(.docType, reason: "\(reference.did) is not trusted for \(docType)")
        }
        guard let key = try? keys.publicKey(did: reference.did, keyId: reference.fragment) else {
            return fail(.signature, reason: "no key for \(kid)")
        }
        outcome = .matched(issuer)
        return IssuerKeyResolution(publicKey: key, trust: .trusted, source: .did(method: reference.method))
    }

    func display(for document: VerifiedDocument) -> IssuerTrustDisplay {
        let auth = document.issuerDataAuth
        if auth.verificationSkipped { return .skipped }
        switch outcome {
        case .matched(let issuer):
            guard case .trusted = auth.trust, auth.signatureValid, auth.docTypeMatches else {
                return .no(.signature)
            }
            return .yes(issuerName: issuer.name)
        case .failed(let failure):
            return .no(failure)
        case nil:
            return .no(.unidentified)
        }
    }

    private func fail(_ failure: IssuerTrustFailure, reason: String) -> IssuerKeyResolution {
        outcome = .failed(failure)
        return IssuerKeyResolution(publicKey: nil, trust: .untrusted(reason: reason), source: .none)
    }
}

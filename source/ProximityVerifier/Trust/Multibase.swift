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
import CryptoKit

enum Multibase {
    static func decode(_ text: String) throws -> Data {
        guard let prefix = text.first else { throw IssuerKeyError.unsupportedKeyFormat }
        let body = String(text.dropFirst())
        let decoded: Data?
        switch prefix {
        case "z": decoded = Base58.decode(body)
        case "u": decoded = Base64URL.decode(body)
        case "m": decoded = Data(base64Encoded: body.padding(
            toLength: (body.count + 3) / 4 * 4, withPad: "=", startingAt: 0))
        case "f", "F": decoded = hex(body)
        default: decoded = nil
        }
        guard let decoded else { throw IssuerKeyError.unsupportedKeyFormat }
        return decoded
    }

    private static func hex(_ text: String) -> Data? {
        guard text.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        var iterator = text.makeIterator()
        while let high = iterator.next(), let low = iterator.next() {
            guard let value = UInt8(String([high, low]), radix: 16) else { return nil }
            bytes.append(value)
        }
        return bytes.isEmpty ? nil : Data(bytes)
    }
}

enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let values: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (index, character) in alphabet.enumerated() { map[character] = index }
        return map
    }()

    static func decode(_ text: String) -> Data? {
        guard !text.isEmpty else { return nil }
        var bytes: [UInt8] = [0]
        for character in text {
            guard var carry = values[character] else { return nil }
            for index in bytes.indices.reversed() {
                carry += 58 * Int(bytes[index])
                bytes[index] = UInt8(carry & 0xff)
                carry >>= 8
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xff), at: 0)
                carry >>= 8
            }
        }
        let leadingZeros = text.prefix { $0 == "1" }.count
        let significant = bytes.drop { $0 == 0 }
        return Data(repeating: 0, count: leadingZeros) + Data(significant)
    }
}

enum Base64URL {
    static func decode(_ text: String) -> Data? {
        var padded = text.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.count % 4) % 4)
        return Data(base64Encoded: padded)
    }
}

enum IssuerPublicKey {
    private static let p256Multicodec: [UInt8] = [0x80, 0x24]

    static func sec1(fromMultibase text: String) throws -> Data {
        try sec1(from: Multibase.decode(text))
    }

    static func sec1(from bytes: Data) throws -> Data {
        var raw = bytes
        let prefixedLengths: Set<Int> = [33 + 2, 64 + 2, 65 + 2]
        if prefixedLengths.contains(raw.count),
           raw[raw.startIndex] == p256Multicodec[0], raw[raw.startIndex + 1] == p256Multicodec[1] {
            raw = raw.dropFirst(2)
        }
        switch (raw.count, raw.first) {
        case (65, 0x04):
            return Data(raw)
        case (33, 0x02), (33, 0x03):
            return try P256.Signing.PublicKey(compressedRepresentation: raw).x963Representation
        case (64, _):
            return Data([0x04]) + Data(raw)
        default:
            throw IssuerKeyError.unsupportedKeyFormat
        }
    }

    static func sec1(fromJwkX x: String, y: String) throws -> Data {
        guard let xBytes = Base64URL.decode(x), let yBytes = Base64URL.decode(y),
              xBytes.count == 32, yBytes.count == 32 else {
            throw IssuerKeyError.unsupportedKeyFormat
        }
        return Data([0x04]) + xBytes + yBytes
    }
}

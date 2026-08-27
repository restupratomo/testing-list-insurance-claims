import Foundation

/// Hides a literal from plain sight in the compiled binary's strings table.
///
/// Sensitive constants (hostnames, pinned key hashes) are stored XOR-masked with a
/// per-build key and only reassembled at the point of use, so they don't show up
/// as readable strings when the binary is inspected with `strings` or a disassembler.
struct ObfuscatedString {
    private let bytes: [UInt8]
    private let key: UInt8

    init(_ plainText: String, key: UInt8 = 0x5A) {
        self.key = key
        self.bytes = plainText.utf8.map { $0 ^ key }
    }

    var value: String {
        let decoded = bytes.map { $0 ^ key }
        // Not a Data->String conversion — decoding raw XOR-unmasked bytes.
        return String(decoding: decoded, as: UTF8.self) // swiftlint:disable:this optional_data_string_conversion
    }
}

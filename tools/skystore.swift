// SkyStore index tools for the maintainer. Run with the Swift that ships with Xcode / the CLT:
//
//   swift tools/skystore.swift keygen <private-key-file>   new Ed25519 key (file 0600), prints the public key
//   swift tools/skystore.swift build                        addons/*.json -> index.json
//   swift tools/skystore.swift sign <private-key-file>      index.json -> index.json.sig
//   swift tools/skystore.swift verify <public-key-base64>   checks index.json.sig
//
// The private key never goes into this repo (.gitignore has *.key). Keep it offline / in a password manager.
import CryptoKit
import Foundation

func fail(_ s: String) -> Never { FileHandle.standardError.write(Data(("skystore: " + s + "\n").utf8)); exit(1) }

let args = Array(CommandLine.arguments.dropFirst())
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let index = root.appendingPathComponent("index.json")
let sig = root.appendingPathComponent("index.json.sig")

func readKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8),
          let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { fail("cannot read the private key at \(path)") }
    return key
}

switch args.first {
case "keygen":
    guard args.count == 2 else { fail("usage: keygen <private-key-file>") }
    guard !FileManager.default.fileExists(atPath: args[1]) else { fail("\(args[1]) exists; not overwriting a key") }
    let key = Curve25519.Signing.PrivateKey()
    guard FileManager.default.createFile(atPath: args[1], contents: Data((key.rawRepresentation.base64EncodedString() + "\n").utf8),
                                         attributes: [.posixPermissions: 0o600]) else { fail("cannot write \(args[1])") }
    print("Private key written to \(args[1]) (keep it secret, never commit it).")
    print("Public key (put it in SkyRose: Sources/CaelestiaCore/Store/StoreIndex.swift, StoreSource.trustedKeys):")
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "build":
    let dir = root.appendingPathComponent("addons")
    let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    var entries: [Any] = []
    var ids = Set<String>()
    for f in files {
        guard let data = try? Data(contentsOf: f), let e = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { fail("\(f.lastPathComponent): not a JSON object") }
        guard let id = e["id"] as? String, f.lastPathComponent == id + ".json" else { fail("\(f.lastPathComponent): id must match the file name") }
        guard ids.insert(id).inserted else { fail("\(id) twice") }
        for key in ["name", "author", "summary", "kind", "licence"] where (e[key] as? String)?.isEmpty ?? true { fail("\(id): \(key) missing") }
        guard let versions = e["versions"] as? [[String: Any]], !versions.isEmpty else { fail("\(id): no versions") }
        for v in versions {
            guard let url = v["url"] as? String, url.hasPrefix("https://github.com/ganya002/skystore-index/releases/download/") else {
                fail("\(id): every version url must be a release asset of ganya002/skystore-index (mirror the creator's asset first)")
            }
            guard let sha = v["sha256"] as? String, sha.count == 64 else { fail("\(id): bad sha256") }
        }
        entries.append(e)
    }
    let out: [String: Any] = ["schema": 1, "generated": ISO8601DateFormatter().string(from: Date()), "addons": entries]
    let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try data.write(to: index)
    print("index.json: \(entries.count) addon(s). Now sign it.")
case "sign":
    guard args.count == 2 else { fail("usage: sign <private-key-file>") }
    guard let data = try? Data(contentsOf: index) else { fail("no index.json (run build)") }
    let s = try readKey(args[1]).signature(for: data)
    try (s.base64EncodedString() + "\n").write(to: sig, atomically: true, encoding: .utf8)
    print("index.json.sig written. Commit index.json and index.json.sig together.")
case "verify":
    guard args.count == 2, let raw = Data(base64Encoded: args[1]), let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else {
        fail("usage: verify <public-key-base64>")
    }
    guard let data = try? Data(contentsOf: index), let text = try? String(contentsOf: sig, encoding: .utf8),
          let s = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { fail("need index.json and index.json.sig") }
    guard pub.isValidSignature(s, for: data) else { fail("signature does NOT match") }
    print("OK: index.json is signed by that key.")
default:
    fail("usage: keygen <file> | build | sign <file> | verify <public-key>")
}

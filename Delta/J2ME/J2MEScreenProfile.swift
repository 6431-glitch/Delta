import Foundation

/// Evidence-based hints, not a claim that every game declares its native size.
struct J2MEScreenProfile: Equatable {
    enum Source: String { case manifest = "JAR metadata", descriptor = "JAD metadata", filename = "Filename", fallback = "Default", phone = "Phone profile", manual = "Manual" }
    let w: Int
    let h: Int
    let source: Source

    static func valid(_ w: Int, _ h: Int) -> Bool {
        (64...1024).contains(w) && (64...1024).contains(h)
    }

    static func attributes(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        var key: String?
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            if line.hasPrefix(" "), let key { result[key, default: ""] += line.dropFirst() }
            else if let colon = line.firstIndex(of: ":") {
                let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
                key = name
                result[name] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            } else { key = nil }
        }
        return result
    }

    static func descriptorAttributes(at url: URL) -> [String: String] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int, (1...65_536).contains(size),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return [:] }
        return Self.attributes(text)
    }

    static func detect(filename: String, manifest: [String: String], descriptor: [String: String] = [:]) -> Self {
        // A descriptor overrides the same manifest property. Never interpret Nokia's
        // Target-Display-Size as the native canvas; that property requests scaling.
        let jar = Dictionary(manifest.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        let jad = Dictionary(descriptor.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        let merged = jar.merging(jad, uniquingKeysWith: { _, last in last })
        let originalKey = "nokia-midlet-original-display-size"
        if let value = merged[originalKey], let size = dimensions(value, allowComma: true) {
            return Self(w: size.0, h: size.1, source: jad[originalKey] == nil ? .manifest : .descriptor)
        }
        // Optional explicit extensions. These are hints, not standard MIDP attributes.
        for prefix in ["midlet-screen-", "j2me.screen."] {
            let wk = prefix + "width", hk = prefix + "height"
            if let w = Int(merged[wk] ?? ""), let h = Int(merged[hk] ?? ""), valid(w, h) {
                return Self(w: w, h: h, source: jad[wk] != nil || jad[hk] != nil ? .descriptor : .manifest)
            }
        }
        if let size = dimensions(URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent, allowComma: false) {
            return Self(w: size.0, h: size.1, source: .filename)
        }
        return Self(w: 240, h: 320, source: .fallback)
    }

    private static func dimensions(_ text: String, allowComma: Bool) -> (Int, Int)? {
        let separator = allowComma ? "[xX×,]" : "[xX×]"
        let pattern = "(?<![A-Za-z0-9])([0-9]{2,4})\\s*" + separator + "\\s*([0-9]{2,4})(?![A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let string = text as NSString
        var sizes: Set<String> = []
        var candidate: (Int, Int)?
        for match in regex.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            guard let w = Int(string.substring(with: match.range(at: 1))),
                  let h = Int(string.substring(with: match.range(at: 2))), valid(w, h) else { continue }
            sizes.insert("\(w)x\(h)")
            candidate = (w, h)
        }
        // Multiple conflicting dimensions are ambiguous; ask the user via the override.
        return sizes.count == 1 ? candidate : nil
    }
}

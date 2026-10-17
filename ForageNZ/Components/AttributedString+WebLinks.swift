import Foundation

extension AttributedString {
    /// Only http and https are linked: the detector also matches bare domains and email
    /// addresses, and a citation should never open a mail draft.
    nonisolated init(linkingWebAddressesIn text: String) {
        self.init(text)
        // `.link` is a valid checking type, so this initialiser cannot throw in practice; were
        // it ever to, the citation still reads correctly as plain text.
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  let textRange = Range(match.range, in: text),
                  let linkRange = Range<AttributedString.Index>(textRange, in: self)
            else { continue }
            self[linkRange].link = url
        }
    }
}

import Foundation

extension String {
    public func extractHashtags() -> [String] {
        let hashtagPattern = "#[a-zA-Z0-9_]+"
        do {
            let regex = try NSRegularExpression(pattern: hashtagPattern, options: [])
            let results = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
            var hashtags: [String] = []
            for element in results {
                if let range = Range(element.range, in: self) {
                    hashtags.append(String(self[range]))
                }
            }
            return hashtags
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

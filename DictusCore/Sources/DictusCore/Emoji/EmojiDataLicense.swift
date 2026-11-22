import Foundation

/// The Unicode License v3 that ships beside the emoji indexes (#1027).
///
/// WHY READ FROM THE BUNDLE: the indexes are built from Unicode's emoji-test.txt and CLDR's
/// annotations, whose licence asks for its notice to travel with every copy. Réglages › Licences
/// shows the very file that is distributed, as it does for DM Sans's OFL.
public enum EmojiDataLicense {
    public static var text: String {
        guard let url = Bundle.module.url(forResource: "LICENSE-Unicode", withExtension: "txt", subdirectory: "EmojiIndex")
                ?? Bundle.module.url(forResource: "LICENSE-Unicode", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "UNICODE LICENSE V3. Copyright © 1991-2026 Unicode, Inc."
        }
        return text
    }
}

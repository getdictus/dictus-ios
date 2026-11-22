// Prints the words of stdin that the macOS spelling checker flags in the given language,
// one per line. prune_misspellings.py uses it to keep real words out of the removals
// (#995): a list of misspellings also holds words such as `thru` or `loosing`.
// A word is flagged only when both its lowercase and capitalized forms are.
//
// Usage: xcrun swift tools/misspellings/apple_spellcheck.swift en < words.txt
import AppKit

let language = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "en"
let checker = NSSpellChecker.shared
guard checker.availableLanguages.contains(language) else {
    FileHandle.standardError.write(Data("no spelling checker for \(language)\n".utf8))
    exit(1)
}
func isFlagged(_ word: String) -> Bool {
    checker.checkSpelling(
        of: word, startingAt: 0, language: language, wrap: false,
        inSpellDocumentWithTag: 0, wordCount: nil
    ).location != NSNotFound
}
// The word lists are lowercase, so a name (`kenya`, `holliday`) is also tried capitalized.
while let word = readLine() {
    if isFlagged(word) && isFlagged(word.capitalized) { print(word) }
}

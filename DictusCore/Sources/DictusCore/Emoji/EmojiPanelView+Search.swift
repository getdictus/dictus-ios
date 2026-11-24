// Emoji search inside the panel (#1027). The field, the results row and the ranking are Hex's
// (github.com/anomalyco/hex, branch dev @ 492d8c2, FullKeyboardView+Emoji.swift, "Search"),
// MIT, Copyright (c) 2026 Christopher Langton. The keys are Dictus's: Hex's own letter keys
// type into its search, while Dictus's key grid belongs to the view controller, which this
// change leaves alone, so the panel carries its own.
#if canImport(UIKit)
import UIKit

extension EmojiPanelView {
    var isSearching: Bool { query != nil }

    func setUpSearch() {
        searchField.placeholder = strings.searchPlaceholder
        searchField.closeLabel = strings.closeSearch
        searchField.onClose = { [weak self] in
            self?.onKeyClick?(.modifier)
            self?.endSearch()
        }
        searchField.isHidden = true
        addSubview(searchField)

        searchResults.renderer = glyphs
        searchResults.emptyText = strings.noResults
        searchResults.onPick = { [weak self] index in
            guard let self, index < self.searchEntries.count else { return }
            let entry = self.searchEntries[index]
            self.insert(self.display(for: entry), entry: entry)
        }
        searchResults.isHidden = true
        addSubview(searchResults)

        searchKeys.onCharacter = { [weak self] character in
            guard let self, let current = self.query else { return }
            self.onKeyClick?(.letter)
            self.query = current + character
            self.refreshSearch()
        }
        searchKeys.onSpace = { [weak self] in
            guard let self, let current = self.query else { return }
            self.onKeyClick?(.modifier)
            self.query = current + " "
            self.refreshSearch()
        }
        searchKeys.onDeleteDown = { [weak self] in
            guard let self else { return }
            self.deleteQueryCharacter()
            self.startDeleteRepeat { [weak self] in self?.deleteQueryCharacter() }
        }
        searchKeys.onDeleteUp = { [weak self] in self?.stopDeleteRepeat() }
        searchKeys.isHidden = true
        addSubview(searchKeys)
    }

    private func deleteQueryCharacter() {
        guard var current = query, !current.isEmpty else { return }
        onKeyClick?(.delete)
        current.removeLast()
        query = current
        refreshSearch()
    }

    func layoutSearch() {
        let row = rowFrame
        searchField.frame = row
        searchResults.frame = CGRect(x: metrics.side, y: row.maxY, width: bounds.width - 2 * metrics.side, height: 40)
        searchResults.fontSize = rowFontSize
        let keysTop = searchResults.frame.maxY + 2
        searchKeys.frame = CGRect(x: 0, y: keysTop, width: bounds.width, height: max(0, bounds.height - metrics.bottomInset - keysTop))
    }

    func applySearchPalette() {
        searchField.palette = palette
        searchResults.palette = palette
        searchKeys.palette = palette
    }

    /// The search takes the panel: the field where the suggestions were, a row of results,
    /// and letter keys in place of the grid.
    public func beginSearch() {
        guard query == nil else { return }
        query = ""
        hideCallout()
        closeTones()
        setSearchVisible(true)
        refreshSearch()
        setNeedsLayout()
    }

    /// The results follow the query; your suggestions while it's empty.
    func refreshSearch() {
        guard let query else { return }
        searchField.query = query
        var boost: [Int: Float] = [:]
        for (emoji, score) in usage.ranked(limit: 32) {
            if let entry = library.entryByEmoji[emoji] { boost[entry] = score }
        }
        searchEntries = query.trimmingCharacters(in: .whitespaces).isEmpty
            ? suggestions
            : EmojiSuggester.search(query, library: library, usage: boost)
        searchResults.setItems(searchEntries.map { (display(for: $0), library.name(of: $0)) })
    }

    /// Back to the grid, refilled: what you just picked is in Recents now, and the grid was
    /// hidden while it moved.
    public func endSearch() {
        guard query != nil else { return }
        query = nil
        stopDeleteRepeat()
        searchEntries = []
        setSearchVisible(false)
        fill()
        setNeedsLayout()
    }

    private func setSearchVisible(_ searching: Bool) {
        for view in [searchButton, suggestionRow, grid, categoryBar, lettersKey, deleteKey] as [UIView] {
            view.isHidden = searching
        }
        for view in [searchField, searchResults, searchKeys] as [UIView] {
            view.isHidden = !searching
        }
    }

    /// Fixtures and tests: type `text` into the search.
    func debugType(_ text: String) {
        beginSearch()
        query = (query ?? "") + text
        refreshSearch()
    }
}

/// The search's keys: the keyboard layout's letters, delete beside the last row, and space.
@MainActor
final class EmojiSearchKeysView: UIView {
    var palette = EmojiPanelPalette(isDark: false) {
        didSet {
            guard palette != oldValue else { return }
            for key in allKeys { key.palette = palette }
        }
    }
    var onCharacter: ((String) -> Void)?
    var onSpace: (() -> Void)?
    var onDeleteDown: (() -> Void)?
    var onDeleteUp: (() -> Void)?

    private let rows: [[PanelKeyButton]]
    private let deleteKey = PanelKeyButton()
    private let spaceKey = PanelKeyButton()
    private var allKeys: [PanelKeyButton] { rows.flatMap { $0 } + [deleteKey, spaceKey] }

    static let gap: CGFloat = 5
    static let side: CGFloat = 3

    init(rows letters: [[String]], space: String, delete: String) {
        rows = letters.map { row in
            row.map { letter in
                let key = PanelKeyButton()
                key.title = letter
                key.titleSize = 21
                key.isPrimary = true
                key.accessibilityLabel = letter
                return key
            }
        }
        super.init(frame: .zero)
        for key in rows.flatMap({ $0 }) {
            key.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
            addSubview(key)
        }
        deleteKey.symbol = "delete.left"
        deleteKey.accessibilityLabel = delete
        deleteKey.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        deleteKey.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(deleteKey)
        spaceKey.title = space
        spaceKey.titleSize = 16
        spaceKey.isPrimary = true
        spaceKey.accessibilityLabel = space
        spaceKey.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        addSubview(spaceKey)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The letter rows of a keyboard layout, as Dictus's old search keyboard had them.
    static func letterRows(for layout: LayoutType) -> [[String]] {
        switch layout {
        case .azerty:
            return [Array("azertyuiop"), Array("qsdfghjklm"), Array("wxcvbn")].map { $0.map(String.init) }
        case .qwerty:
            return [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")].map { $0.map(String.init) }
        case .qwertz:
            // The shared layout data, so the search keys cannot drift from the real ones (#151).
            return QWERTZLayout.lowercasedLettersRows
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rowCount = CGFloat(rows.count + 1)
        let height = max(20, (bounds.height - Self.gap * (rowCount - 1)) / rowCount)
        let columns = CGFloat(max(1, rows.map(\.count).max() ?? 1))
        let keyWidth = (bounds.width - 2 * Self.side - Self.gap * (columns - 1)) / columns
        for (index, row) in rows.enumerated() {
            let y = CGFloat(index) * (height + Self.gap)
            let isLast = index == rows.count - 1
            let deleteWidth = keyWidth * 1.5
            let room = isLast ? bounds.width - 2 * Self.side - deleteWidth - Self.gap : bounds.width - 2 * Self.side
            let rowWidth = CGFloat(row.count) * keyWidth + CGFloat(max(0, row.count - 1)) * Self.gap
            var x = Self.side + max(0, (room - rowWidth) / 2)
            for key in row {
                key.frame = CGRect(x: x, y: y, width: keyWidth, height: height)
                x += keyWidth + Self.gap
            }
            if isLast {
                deleteKey.frame = CGRect(x: bounds.width - Self.side - deleteWidth, y: y, width: deleteWidth, height: height)
            }
        }
        let spaceY = CGFloat(rows.count) * (height + Self.gap)
        spaceKey.frame = CGRect(x: Self.side, y: spaceY, width: bounds.width - 2 * Self.side, height: height)
    }

    @objc private func letterTapped(_ sender: PanelKeyButton) {
        guard let title = sender.title else { return }
        onCharacter?(title)
    }

    @objc private func spaceTapped() { onSpace?() }
    @objc private func deleteDown() { onDeleteDown?() }
    @objc private func deleteUp() { onDeleteUp?() }
}
#endif

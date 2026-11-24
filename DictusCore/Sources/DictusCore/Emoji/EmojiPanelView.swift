// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2,
// ios/HEXShared/FullKeyboard/Emoji/EmojiPanelView.swift), MIT, Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#1027):
// - It sits under Dictus's toolbar, so it lays itself out in the keyboard area's height
//   (`EmojiPanelMetrics`) and fits as many grid rows as that height takes.
// - Search lives in the panel, with keys of its own (`EmojiPanelView+Search.swift`): Hex's
//   letter keys type into the search, but Dictus's key grid belongs to the view controller,
//   which this change leaves alone.
// - It records your use itself, and the host only inserts text.
// - A skin-tone picker released where it opened stays open for a tap, as iOS's does.
// - Hex's experiments (ABC under the emoji key, the dictation bar's back key) are left out.
// - Its background is Hex's invisible touch fill (pull 2547, #503), so the bands its `hitTest`
//   hands to ABC and to the search button get their touches from iOS.
#if canImport(UIKit)
import UIKit

/// The emoji panel, in place of the keys: a row of emoji for what you just typed beside the
/// search button, then a grid that scrolls sideways through your recents and every category,
/// and a bar with ABC, the categories and delete. Holding an emoji that has skin tones offers
/// them; the one you pick is remembered for it.
@MainActor
public final class EmojiPanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    struct Section {
        let title: String
        let symbol: String
        let entries: [Int]
    }

    var palette = EmojiPanelPalette(isDark: false) {
        didSet {
            guard palette != oldValue else { return }
            applyPalette()
        }
    }
    var showsKeyPopups = true
    var metrics = EmojiPanelMetrics() { didSet { if metrics != oldValue { setNeedsLayout() } } }

    /// An emoji went in: the text to insert in the field.
    public var onInsert: ((String) -> Void)?
    public var onDelete: (() -> Void)?
    public var onLetters: (() -> Void)?
    /// A key went down: the click it makes. The host plays it (and the haptic) its own way.
    public var onKeyClick: ((KeySoundCategory) -> Void)?
    /// The field's text before the cursor, read when the panel fills: its words pick the
    /// suggestion row's emoji.
    public var textBefore: (() -> String?)?
    /// Words near a context word in meaning (`EmojiSemanticIndex`); nil keeps to the words'
    /// own emoji. See that file for why the keyboard leaves it nil.
    public var neighbors: EmojiSuggester.Neighbors?

    let library: EmojiLibrary
    let usage: EmojiUsageStore
    let strings: EmojiPanelStrings
    /// The search's letter rows, the keyboard's layout's.
    let letterRows: [[String]]
    /// The panel's emoji bitmaps, shared with its suggestion row and the search's results,
    /// and gone with the panel.
    let glyphs = EmojiGlyphRenderer()
    private(set) var sections: [Section] = []
    private(set) var suggestions: [Int] = []

    let suggestionRow = EmojiRowView()
    let searchButton = UIButton(type: .custom)
    let grid: UICollectionView
    let categoryBar: EmojiCategoryBar
    let lettersKey = PanelKeyButton()
    let deleteKey = PanelKeyButton()
    private let callout = KeyCalloutView()
    let tonePicker = AccentCalloutView()
    /// A hairline between the suggestion row and the grid.
    private let rowSeparator = UIView()
    var toneEntry: Int?
    /// The picker opened and the finger has not moved off the emoji: on release it stays open
    /// and a tap picks (iOS's own behaviour; Hex picks on release).
    var toneAwaitsTap = false
    var toneStart: CGPoint = .zero
    /// An emoji without skin tones held down: typed when the finger lifts over it.
    var heldEntry: (entry: Int, frame: CGRect)?
    private var layoutKey: GridGeometry?
    /// How many emoji the last `fill` gave Recents; the first layout corrects it (see there).
    private var filledCapacity: Int?
    private var sectionStarts: [CGFloat] = []
    private var deleteTimer: Timer?
    private var deleteStartedAt: TimeInterval = 0

    // Search (EmojiPanelView+Search.swift).
    let searchField = EmojiSearchField()
    let searchResults = EmojiRowView()
    let searchKeys: EmojiSearchKeysView
    var query: String?
    var searchEntries: [Int] = []

    static let holdDelay: TimeInterval = 0.4
    static let repeatDelay: TimeInterval = 0.45
    static let repeatInterval: TimeInterval = 0.09

    struct GridGeometry: Equatable {
        let rows: Int
        let rowHeight: CGFloat
        let columnWidth: CGFloat
        let headerHeight: CGFloat
        let fontSize: CGFloat
        let counts: [Int]
    }

    public init(library: EmojiLibrary, usage: EmojiUsageStore, strings: EmojiPanelStrings, letterRows: [[String]]) {
        self.library = library
        self.usage = usage
        self.strings = strings
        self.letterRows = letterRows
        grid = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        categoryBar = EmojiCategoryBar(
            items: [("clock", strings.recents)] + EmojiCategory.allCases.map { ($0.symbol, strings.title(of: $0)) }
        )
        searchKeys = EmojiSearchKeysView(rows: letterRows, space: strings.space, delete: strings.delete)
        super.init(frame: .zero)
        // Clear to the eye, but every point of the panel takes touches (`keyboardTouchFill`, #503).
        backgroundColor = .keyboardTouchFill
        isOpaque = false
        accessibilityIdentifier = "emoji.panel"

        searchButton.setImage(
            UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)),
            for: .normal
        )
        searchButton.accessibilityLabel = strings.searchPlaceholder
        searchButton.accessibilityIdentifier = "emoji.search"
        searchButton.layer.cornerCurve = .continuous
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        addSubview(searchButton)

        suggestionRow.renderer = glyphs
        suggestionRow.onPick = { [weak self] index in self?.pickSuggestion(index) }
        addSubview(suggestionRow)
        rowSeparator.isUserInteractionEnabled = false
        addSubview(rowSeparator)

        grid.backgroundColor = .clear
        grid.showsHorizontalScrollIndicator = false
        grid.delaysContentTouches = false
        // Cells draw their emoji when they're configured; only the visible ones should.
        grid.isPrefetchingEnabled = false
        grid.hideEdgeEffects()
        grid.dataSource = self
        grid.delegate = self
        grid.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        grid.register(
            EmojiSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: EmojiSectionHeader.reuseID
        )
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = Self.holdDelay
        grid.addGestureRecognizer(hold)
        addSubview(grid)

        categoryBar.onSelect = { [weak self] index in self?.jump(toSection: index) }
        categoryBar.onScrub = { [weak self] index, fraction in self?.scrub(toSection: index, fraction: fraction) }
        addSubview(categoryBar)

        lettersKey.title = strings.lettersTitle
        lettersKey.isPrimary = true
        lettersKey.isPlain = true
        lettersKey.accessibilityLabel = strings.lettersLabel
        lettersKey.accessibilityIdentifier = "emoji.letters"
        lettersKey.addTarget(self, action: #selector(lettersTapped), for: .touchUpInside)
        addSubview(lettersKey)

        deleteKey.symbol = "delete.left"
        deleteKey.isPrimary = true
        deleteKey.isPlain = true
        deleteKey.accessibilityLabel = strings.delete
        deleteKey.accessibilityIdentifier = "emoji.delete"
        deleteKey.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        deleteKey.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(deleteKey)

        setUpSearch()

        callout.isUserInteractionEnabled = false
        addSubview(callout)
        tonePicker.isHidden = true
        addSubview(tonePicker)
        applyPalette()
        #if DEBUG
        EmojiPanelDebug.register(self)
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    #if DEBUG
    deinit {
        NSLog("EMOJI_DEBUG panel freed")
    }
    #endif

    /// The search keys' letter rows for a keyboard layout.
    public static func letterRows(for layout: LayoutType) -> [[String]] {
        EmojiSearchKeysView.letterRows(for: layout)
    }

    // MARK: - Content

    /// Fills the panel for the text before the cursor and your use: the row's suggestions, and
    /// a full block of Recents, as the system keyboard's (your emoji, then common ones, then
    /// the first smileys). Recents are read here and nowhere else, so an emoji you pick does
    /// not move under your finger while the panel is open.
    public func fill() {
        var scores: [Int: Float] = [:]
        var frequent: [Int] = []
        let capacity = frequentCapacity
        filledCapacity = capacity
        for (emoji, score) in usage.ranked(limit: capacity) {
            guard let entry = library.entryByEmoji[emoji], scores[entry] == nil else { continue }
            scores[entry] = score
            frequent.append(entry)
        }
        let common = EmojiSuggester.defaults.compactMap { library.entryByEmoji[$0] }
            + library.entries.indices.lazy.filter { self.library.entries[$0].category == .smileys }.prefix(capacity)
        for entry in common where frequent.count < capacity && !frequent.contains(entry) {
            frequent.append(entry)
        }
        let context = EmojiContext(before: textBefore?(), stopwords: library.stopwords)
        let suggested = EmojiSuggester.suggestions(context: context, library: library, neighbors: neighbors, usage: scores, limit: 10)
        show(suggestions: suggested, frequent: frequent)
    }

    /// Fills the panel: `suggestions` for the row, `frequent` for the grid's first section.
    func show(suggestions: [Int], frequent: [Int]) {
        self.suggestions = suggestions
        suggestionRow.setItems(suggestions.map { (display(for: $0), library.name(of: $0)) })
        var sections = [Section(title: strings.recents, symbol: "clock", entries: frequent)]
        var byCategory = Array(repeating: [Int](), count: EmojiCategory.allCases.count)
        for (index, entry) in library.entries.enumerated() {
            byCategory[entry.category.rawValue].append(index)
        }
        for category in EmojiCategory.allCases {
            sections.append(Section(title: strings.title(of: category), symbol: category.symbol, entries: byCategory[category.rawValue]))
        }
        self.sections = sections
        layoutKey = nil
        sectionStarts = []
        grid.reloadData()
        setNeedsLayout()
    }

    /// The emoji with the skin tone you last picked for it.
    func display(for entry: Int) -> String {
        let item = library.entries[entry]
        let tone = item.hasTones ? usage.tone(for: item.emoji) : 0
        return tone > 0 && tone <= item.tones.count ? item.tones[tone - 1] : item.emoji
    }

    /// An emoji goes into the field and counts as used.
    func insert(_ text: String, entry: Int) {
        if entry < library.entries.count {
            usage.record(library.entries[entry].emoji)
        }
        onInsert?(text)
    }

    private func pickSuggestion(_ index: Int) {
        guard index < suggestions.count else { return }
        let entry = suggestions[index]
        insert(display(for: entry), entry: entry)
    }

    // MARK: - Layout

    /// The suggestion row's band at the top, where the search field goes while searching.
    var rowFrame: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width, height: metrics.rowHeight)
    }

    var barY: CGFloat { bounds.height - metrics.bottomInset - metrics.barHeight }

    /// The grid's rows: as many 38 pt rows as its height takes, three to five.
    var gridRows: Int {
        let height = barY - 2 - rowFrame.maxY - headerHeight
        return min(5, max(3, Int(height / 38)))
    }

    private var headerHeight: CGFloat { 18 }

    /// How many emoji Recents holds: eight columns of the grid's rows.
    var frequentCapacity: Int {
        gridRows * 8
    }

    /// The suggestion row's and the search results' emoji size.
    var rowFontSize: CGFloat { 26 }

    override public func layoutSubviews() {
        super.layoutSubviews()
        palette = EmojiPanelPalette(isDark: traitCollection.userInterfaceStyle == .dark)
        let row = rowFrame
        let side = metrics.side
        let buttonSide = min(36, row.height - 4)
        searchButton.frame = CGRect(x: row.minX + side, y: row.midY - buttonSide / 2, width: buttonSide + 8, height: buttonSide)
        searchButton.layer.cornerRadius = 10
        let rowStart = searchButton.frame.maxX + 4
        suggestionRow.frame = CGRect(x: rowStart, y: row.minY, width: row.maxX - side - rowStart, height: row.height)
        let hairline = 1 / max(1, traitCollection.displayScale)
        rowSeparator.frame = CGRect(x: row.minX + side, y: row.maxY - hairline, width: row.width - 2 * side, height: hairline)
        suggestionRow.fontSize = rowFontSize

        let barY = barY
        let barHeight = metrics.barHeight
        let keyWidth = metrics.barKeyWidth
        lettersKey.frame = CGRect(x: side, y: barY, width: keyWidth, height: barHeight)
        deleteKey.frame = CGRect(x: bounds.width - side - keyWidth, y: barY, width: keyWidth, height: barHeight)
        lettersKey.cornerRadius = metrics.cornerRadius
        deleteKey.cornerRadius = metrics.cornerRadius
        categoryBar.frame = CGRect(x: lettersKey.frame.maxX + 4, y: barY, width: max(0, deleteKey.frame.minX - lettersKey.frame.maxX - 8), height: barHeight)

        let gridTop = row.maxY
        let gridFrame = CGRect(x: 0, y: gridTop, width: bounds.width, height: max(0, barY - 2 - gridTop))
        grid.frame = gridFrame
        let band = UIEdgeInsets(top: barY - gridFrame.maxY, left: 0, bottom: max(0, bounds.height - barY - barHeight), right: 0)
        lettersKey.hitOutsets = UIEdgeInsets(top: band.top, left: lettersKey.frame.minX, bottom: band.bottom, right: categoryBar.frame.minX - lettersKey.frame.maxX)
        deleteKey.hitOutsets = UIEdgeInsets(top: band.top, left: deleteKey.frame.minX - categoryBar.frame.maxX, bottom: band.bottom, right: bounds.width - deleteKey.frame.maxX)
        callout.frame = bounds
        tonePicker.frame = bounds
        layoutSearch()
        // The host fills the panel before its first layout, when the grid's rows are not
        // known yet: Recents came out three rows' worth, and in a four-row grid it left a
        // gap. Refilled here once the height is known, before anything is on screen.
        if let filledCapacity, filledCapacity != frequentCapacity, query == nil {
            fill()
        }
        applyGridLayout(height: gridFrame.height)
    }

    /// The bar's keys take the whole band under the grid: the gap above them and the margin
    /// down to the keyboard's edge, where a thumb aiming at a small icon often lands. Between
    /// ABC and delete the bar takes it, each category the full width of its slot. This is what
    /// fixes Dictus's old ABC and search keys, which answered only on their glyphs.
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01, self.point(inside: point, with: event) else { return nil }
        // An open skin-tone picker waiting for its tap takes every touch.
        if toneAwaitsTap { return self }
        if query == nil, tonePicker.menu == nil, point.y >= grid.frame.maxY {
            if point.x < categoryBar.frame.minX { return lettersKey }
            if point.x >= categoryBar.frame.maxX { return deleteKey }
            return categoryBar
        }
        // The row's band left of the suggestions is the search button's, top to bottom.
        if query == nil, point.y < rowFrame.maxY, point.x < suggestionRow.frame.minX {
            return searchButton
        }
        return super.hitTest(point, with: event)
    }

    private func applyGridLayout(height: CGFloat) {
        let rows = gridRows
        let rowHeight = max(20, (height - headerHeight) / CGFloat(rows))
        let geometry = GridGeometry(
            rows: rows,
            rowHeight: rowHeight,
            // The system emoji keyboard's pitch, measured by Hex from screenshots.
            columnWidth: rowHeight >= 40 ? 46 : 42,
            headerHeight: headerHeight,
            fontSize: rowHeight >= 40 ? 32 : 28,
            counts: sections.map(\.entries.count)
        )
        guard geometry != layoutKey, height > 0 else { return }
        layoutKey = geometry
        sectionStarts = []
        grid.setCollectionViewLayout(Self.makeLayout(geometry), animated: false)
    }

    private static func makeLayout(_ g: GridGeometry) -> UICollectionViewCompositionalLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        config.interSectionSpacing = 10
        let counts = g.counts
        return UICollectionViewCompositionalLayout(sectionProvider: { index, _ in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(g.rowHeight)
            ))
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(g.columnWidth),
                    heightDimension: .absolute(g.rowHeight * CGFloat(g.rows))
                ),
                repeatingSubitem: item,
                count: g.rows
            )
            let section = NSCollectionLayoutSection(group: group)
            let count = counts.indices.contains(index) ? counts[index] : 0
            let columns = max(1, (count + g.rows - 1) / g.rows)
            // Above the section and as wide as it; scrolling keeps its name in view
            // (keepHeadersInView), as a pinned header would.
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(CGFloat(columns) * g.columnWidth),
                    heightDimension: .absolute(g.headerHeight)
                ),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            // A horizontal layout doesn't move the items below a top header; the inset does,
            // and the header ignores it.
            section.contentInsets = NSDirectionalEdgeInsets(top: g.headerHeight, leading: 2, bottom: 0, trailing: 2)
            section.supplementaryContentInsetsReference = .none
            return section
        }, configuration: config)
    }

    private func applyPalette() {
        searchButton.backgroundColor = palette.chipFill
        searchButton.tintColor = palette.textMuted
        rowSeparator.backgroundColor = palette.separator
        suggestionRow.palette = palette
        categoryBar.palette = palette
        lettersKey.palette = palette
        deleteKey.palette = palette
        callout.palette = palette
        tonePicker.palette = palette
        applySearchPalette()
        grid.reloadData()
    }

    // MARK: - Grid

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].entries.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseID, for: indexPath)
        if let cell = cell as? EmojiCell {
            let entry = sections[indexPath.section].entries[indexPath.item]
            cell.configure(
                emoji: display(for: entry),
                name: library.name(of: entry),
                fontSize: layoutKey?.fontSize ?? 32,
                palette: palette,
                renderer: glyphs,
                scale: collectionView.traitCollection.displayScale
            )
        }
        return cell
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: EmojiSectionHeader.reuseID,
            for: indexPath
        )
        if let header = view as? EmojiSectionHeader {
            header.label.text = sections[indexPath.section].title.uppercased()
            header.label.textColor = palette.textMuted
        }
        return view
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? EmojiCell)?.clear()
    }

    public func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        // No click here: a swipe through the grid starts on a cell too.
        guard showsKeyPopups, let frame = cellFrame(indexPath) else { return }
        let entry = sections[indexPath.section].entries[indexPath.item]
        callout.show(balloon(over: frame), label: display(for: entry))
    }

    public func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        callout.show(nil, label: "")
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        let entry = sections[indexPath.section].entries[indexPath.item]
        insert(display(for: entry), entry: entry)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        callout.show(nil, label: "")
        keepHeadersInView()
        // While a finger slides along the bar, the bar leads and the grid follows it.
        guard !categoryBar.isScrubbing else { return }
        if sectionStarts.isEmpty { measureSections() }
        let x = scrollView.contentOffset.x + 24
        let current = sectionStarts.lastIndex { $0 <= x } ?? 0
        categoryBar.selected = current
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String,
        at indexPath: IndexPath
    ) {
        keepHeadersInView()
    }

    /// A section's name stays at the grid's left edge while the section scrolls past, and
    /// the next section's name pushes it out.
    private func keepHeadersInView() {
        let left = grid.contentOffset.x
        for case let header as EmojiSectionHeader in grid.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            let room = max(0, header.frame.width - header.label.intrinsicContentSize.width - 16)
            header.shift = min(room, max(0, left - header.frame.minX))
        }
    }

    private func measureSections() {
        sectionStarts = sections.indices.map { section in
            guard !sections[section].entries.isEmpty,
                  let attributes = grid.layoutAttributesForItem(at: IndexPath(item: 0, section: section)) else {
                return .greatestFiniteMagnitude
            }
            return attributes.frame.minX
        }
    }

    func jump(toSection section: Int) {
        guard section < sections.count else { return }
        onKeyClick?(.modifier)
        grid.layoutIfNeeded()
        if sectionStarts.isEmpty { measureSections() }
        let start = sectionStart(section)
        let maxX = max(0, grid.contentSize.width - grid.bounds.width)
        grid.setContentOffset(CGPoint(x: min(maxX, max(0, start - 2)), y: 0), animated: false)
        categoryBar.selected = section
    }

    /// A finger sliding along the bar: the grid shows `section` `fraction` of the way
    /// through, live, so the bar scrubs through every emoji.
    private func scrub(toSection section: Int, fraction: CGFloat) {
        guard section < sections.count else { return }
        grid.layoutIfNeeded()
        if sectionStarts.isEmpty { measureSections() }
        let start = sectionStart(section)
        let end = section + 1 < sections.count ? sectionStart(section + 1) : grid.contentSize.width
        let maxX = max(0, grid.contentSize.width - grid.bounds.width)
        let x = start + min(1, max(0, fraction)) * max(0, end - start)
        grid.setContentOffset(CGPoint(x: min(maxX, max(0, x - 2)), y: 0), animated: false)
    }

    /// Where a section's first emoji sits in the grid; an empty one starts where the next does.
    private func sectionStart(_ section: Int) -> CGFloat {
        sectionStarts[section...].first { $0 != .greatestFiniteMagnitude } ?? grid.contentSize.width
    }

    func cellFrame(_ indexPath: IndexPath) -> CGRect? {
        guard let attributes = grid.layoutAttributesForItem(at: indexPath) else { return nil }
        return grid.convert(attributes.frame, to: self)
    }

    func balloon(over cell: CGRect) -> KeyBalloon {
        let width = cell.width + KeyBalloon.extraWidth
        let x = max(2, min(bounds.width - 2 - width, cell.midX - width / 2))
        let bubble = CGRect(x: x, y: max(0, cell.minY - KeyBalloon.neck - KeyBalloon.bubbleHeight), width: width, height: KeyBalloon.bubbleHeight)
        return KeyBalloon(keyFrame: cell, bubble: bubble)
    }

    func hideCallout() {
        callout.show(nil, label: "")
    }

    // MARK: - Keys

    @objc private func searchTapped() {
        onKeyClick?(.modifier)
        beginSearch()
    }

    @objc private func lettersTapped() {
        onKeyClick?(.modifier)
        onLetters?()
    }

    @objc private func deleteDown() {
        onKeyClick?(.delete)
        onDelete?()
        startDeleteRepeat { [weak self] in
            self?.onKeyClick?(.delete)
            self?.onDelete?()
        }
    }

    @objc private func deleteUp() {
        stopDeleteRepeat()
    }

    /// Delete held: `tick` again every `repeatInterval` once `repeatDelay` has passed.
    func startDeleteRepeat(_ tick: @escaping () -> Void) {
        deleteTimer?.invalidate()
        deleteStartedAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: Self.repeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, CACurrentMediaTime() - self.deleteStartedAt >= Self.repeatDelay else { return }
                tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        deleteTimer = timer
    }

    func stopDeleteRepeat() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    /// The panel is going: no timer, no open picker, no bitmaps.
    public func tearDown() {
        stopDeleteRepeat()
        tonePicker.show(nil)
        toneAwaitsTap = false
        callout.show(nil, label: "")
        glyphs.purge()
    }
}
#endif

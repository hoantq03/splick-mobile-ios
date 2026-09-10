import SwiftUI

public struct HighlightedText: View {
    private let text: String
    private let query: String
    private let font: Font
    private let color: Color

    public init(
        _ text: String,
        query: String,
        font: Font = SplickTheme.Typography.callout,
        color: Color = SplickTheme.Colors.textPrimary
    ) {
        self.text = text
        self.query = query
        self.font = font
        self.color = color
    }

    public var body: some View {
        highlightedText
            .font(font)
            .foregroundStyle(color)
    }

    private var highlightedText: Text {
        let ranges = Self.matchRanges(in: text, query: query)
        guard !ranges.isEmpty else {
            return Text(text)
        }

        var composed = Text("")
        var cursor = text.startIndex

        for range in ranges {
            if cursor < range.lowerBound {
                composed = composed + Text(String(text[cursor..<range.lowerBound]))
            }
            composed = composed + Text(String(text[range])).bold()
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            composed = composed + Text(String(text[cursor...]))
        }

        return composed
    }

    static func matchRanges(in text: String, query: String) -> [Range<String.Index>] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(
                  of: trimmedQuery,
                  options: [.caseInsensitive, .diacriticInsensitive],
                  range: searchStart..<text.endIndex,
                  locale: .current
              ) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        return ranges
    }
}

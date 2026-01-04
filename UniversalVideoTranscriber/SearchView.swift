//
//  SearchView.swift
//  UniversalVideoTranscriber
//
//  Search functionality with clickable timestamps
//

import SwiftUI

struct SearchView: View {
    @Binding var searchQuery: String
    let transcriptItems: [TranscriptItem]
    let onTimestampClick: (TimeInterval) -> Void
    
    private var searchResults: [TranscriptItem] {
        if searchQuery.isEmpty {
            return []
        }
        return transcriptItems.filter { item in
            item.text.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search transcription...", text: $searchQuery)
                    .textFieldStyle(.plain)
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            Divider()
            
            // Search results
            if !searchQuery.isEmpty {
                if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No results found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s") found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(searchResults) { item in
                                SearchResultRow(item: item, searchQuery: searchQuery) {
                                    onTimestampClick(item.timestamp)
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Enter search query")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct SearchResultRow: View {
    let item: TranscriptItem
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Timestamp badge
                Text(item.formattedTimestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(4)
                
                // Text with highlighted search term
                Text(highlightedText(item.text, query: searchQuery))
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Find all occurrences of the query (case-insensitive)
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while searchStartIndex < lowercasedText.endIndex,
              let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            
            if let attributedRange = Range(range, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.4)
                attributedString[attributedRange].foregroundColor = .primary
            }
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

#Preview {
    SearchView(
        searchQuery: .constant("test"),
        transcriptItems: [
            TranscriptItem(text: "This is a test transcription", timestamp: 10.5),
            TranscriptItem(text: "Another test line here", timestamp: 25.3),
        ],
        onTimestampClick: { _ in }
    )
}

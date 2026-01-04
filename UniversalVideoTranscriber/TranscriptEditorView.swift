//
//  TranscriptEditorView.swift
//  UniversalVideoTranscriber
//
//  Full-featured transcript editor with merge, split, delete, and edit capabilities
//

import SwiftUI

struct TranscriptEditorView: View {
    @Binding var items: [TranscriptItem]
    @Binding var isEditing: Bool
    @State private var selectedItems: Set<UUID> = []
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @State private var editingTimestamp: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Edit toolbar
            editToolbar

            Divider()

            // Editable transcript list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        editableSegmentRow(item: item, index: index)
                    }
                }
                .padding()
            }
        }
    }

    private var editToolbar: some View {
        HStack(spacing: 12) {
            Button(action: {
                isEditing = false
                selectedItems.removeAll()
            }) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Divider()
                .frame(height: 28)

            // Merge button
            Button(action: mergeSelectedSegments) {
                Label("Merge", systemImage: "arrow.triangle.merge")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(selectedItems.count < 2)
            .help("Merge selected segments into one")

            // Delete button
            Button(action: deleteSelectedSegments) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(selectedItems.isEmpty)
            .foregroundColor(.red)
            .help("Delete selected segments")

            Spacer()

            Text("\(selectedItems.count) selected")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func editableSegmentRow(item: TranscriptItem, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox
            Toggle("", isOn: Binding(
                get: { selectedItems.contains(item.id) },
                set: { isSelected in
                    if isSelected {
                        selectedItems.insert(item.id)
                    } else {
                        selectedItems.remove(item.id)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                // Timestamp editor
                HStack(spacing: 8) {
                    if editingItemID == item.id {
                        TextField("Timestamp", text: $editingTimestamp)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 120)
                            .onSubmit {
                                saveTimestampEdit(for: item, at: index)
                            }

                        Button("Save") {
                            saveTimestampEdit(for: item, at: index)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Cancel") {
                            editingItemID = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            editingItemID = item.id
                            editingTimestamp = item.formattedTimestamp
                        }) {
                            HStack(spacing: 4) {
                                Text(item.formattedTimestamp)
                                    .font(.system(.caption, design: .monospaced))
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        .help("Click to edit timestamp")
                    }

                    Text("#\(index + 1)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Split button
                    Button(action: {
                        splitSegment(at: index)
                    }) {
                        Label("Split", systemImage: "scissors")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Split segment at midpoint")
                }

                // Text editor - Use direct binding to array element
                TextEditor(text: Binding(
                    get: { items[index].text },
                    set: { newText in
                        // Directly update the array element without recreating the item
                        items[index] = TranscriptItem(
                            id: items[index].id,
                            text: newText,
                            timestamp: items[index].timestamp,
                            confidence: items[index].confidence
                        )
                    }
                ))
                .font(.body)
                .frame(minHeight: 60)
                .border(Color.gray.opacity(0.3), width: 1)
                .cornerRadius(4)
                .id(item.id) // Stable identity to prevent recreation
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedItems.contains(item.id) ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedItems.contains(item.id) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Editing Actions

    private func mergeSelectedSegments() {
        guard selectedItems.count >= 2 else { return }

        // Find indices of selected items
        let selectedIndices = items.enumerated().compactMap { index, item in
            selectedItems.contains(item.id) ? index : nil
        }.sorted()

        guard let firstIndex = selectedIndices.first else { return }

        // Combine text from all selected segments
        let mergedText = selectedIndices.map { items[$0].text }.joined(separator: " ")

        // Keep timestamp from first segment
        let firstTimestamp = items[firstIndex].timestamp

        // Calculate average confidence
        let avgConfidence = selectedIndices.map { items[$0].confidence }.reduce(0, +) / Float(selectedIndices.count)

        // Create merged item
        let mergedItem = TranscriptItem(
            text: mergedText,
            timestamp: firstTimestamp,
            confidence: avgConfidence
        )

        // Remove all selected items and insert merged item
        items.remove(atOffsets: IndexSet(selectedIndices))
        items.insert(mergedItem, at: firstIndex)

        selectedItems.removeAll()
    }

    private func splitSegment(at index: Int) {
        guard index < items.count else { return }

        let originalItem = items[index]
        let words = originalItem.text.split(separator: " ")

        guard words.count >= 2 else { return }  // Can't split single word

        let midpoint = words.count / 2
        let firstHalf = words.prefix(midpoint).joined(separator: " ")
        let secondHalf = words.suffix(words.count - midpoint).joined(separator: " ")

        // Estimate timestamp for second half (2 seconds after first)
        let secondTimestamp = originalItem.timestamp + 2.0

        let firstItem = TranscriptItem(
            text: firstHalf,
            timestamp: originalItem.timestamp,
            confidence: originalItem.confidence
        )

        let secondItem = TranscriptItem(
            text: secondHalf,
            timestamp: secondTimestamp,
            confidence: originalItem.confidence
        )

        // Replace original with two new items
        items.remove(at: index)
        items.insert(contentsOf: [firstItem, secondItem], at: index)
    }

    private func deleteSelectedSegments() {
        items.removeAll { selectedItems.contains($0.id) }
        selectedItems.removeAll()
    }

    private func saveTimestampEdit(for item: TranscriptItem, at index: Int) {
        // Parse timestamp (format: HH:MM:SS.mmm or MM:SS.mmm)
        let newTimestamp = parseTimestamp(editingTimestamp)

        items[index] = TranscriptItem(
            id: items[index].id,
            text: items[index].text,
            timestamp: newTimestamp,
            confidence: items[index].confidence
        )

        editingItemID = nil
    }

    private func parseTimestamp(_ formatted: String) -> TimeInterval {
        let components = formatted.split(separator: ":")
        guard components.count >= 2 else { return 0 }

        if components.count == 3 {
            // HH:MM:SS.mmm
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2].replacingOccurrences(of: ",", with: ".")) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else {
            // MM:SS.mmm
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1].replacingOccurrences(of: ",", with: ".")) ?? 0
            return minutes * 60 + seconds
        }
    }
}

#Preview {
    TranscriptEditorView(
        items: .constant([
            TranscriptItem(text: "First segment", timestamp: 0.0),
            TranscriptItem(text: "Second segment", timestamp: 5.0),
            TranscriptItem(text: "Third segment", timestamp: 10.0)
        ]),
        isEditing: .constant(true)
    )
}

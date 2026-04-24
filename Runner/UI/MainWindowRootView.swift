import AppKit
import SwiftUI

struct MainWindowRootView: View {
  @ObservedObject var store: ClrPkrStore
  @State private var isDropTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      FormatPillControl(selection: $store.format, formats: ColorFormat.allCases)
        .frame(height: 34)

      if store.hasVisibleImportedPalettes, let palette = store.currentImportedPalette {
        ImportedPaletteSection(
          store: store,
          palette: palette,
          onCopyText: copyText
        )
      }

      HistorySection(store: store, onCopyText: copyText)

      FooterBar(
        historyCount: store.history.count,
        isHistoryEmpty: store.history.isEmpty,
        onCopyHistory: { format in
          copyText(exportColors(store.history, format: format))
        },
        onClearHistory: {
          store.clearAll()
        }
      )
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 9)
    .frame(minWidth: 380, minHeight: 440)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PlatformColor.color(from: .windowBackgroundColor))
    .overlay(DropOverlay(isTargeted: isDropTargeted))
    .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted, perform: importDroppedItems(providers:))
  }

  private func importDroppedItems(providers: [NSItemProvider]) -> Bool {
    let group = DispatchGroup()
    var urls: [URL] = []

    for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
      group.enter()
      provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
        defer { group.leave() }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil) {
          urls.append(url)
        } else if let url = item as? URL {
          urls.append(url)
        }
      }
    }

    group.notify(queue: .main) {
      store.importSelectedItems(at: urls, includesNestedFolders: true)
    }

    return true
  }

  private func copyText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}

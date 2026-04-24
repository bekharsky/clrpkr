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

private struct ImportedPaletteSection: View {
  @ObservedObject var store: ClrPkrStore
  let palette: ImportedPalette
  let onCopyText: (String) -> Void
  @State private var burst: SwatchBurst?

  var body: some View {
    CardContainer(contentPadding: 9) {
      ZStack {
        HStack(alignment: .top, spacing: 12) {
          PreviewImageView(image: palette.previewImage, width: 84, height: 84)

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              if store.importedPalettes.count > 1 {
                HStack(spacing: 4) {
                  PagerButton(
                    symbolName: "chevron.left",
                    fallbackText: "<",
                    toolTip: "Previous imported palette",
                    action: {
                      store.showImportedPalette(at: store.currentImportedPaletteIndex - 1)
                    }
                  )
                  .disabled(store.currentImportedPaletteIndex == 0)

                  Text("\(store.currentImportedPaletteIndex + 1) of \(store.importedPalettes.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 42)

                  PagerButton(
                    symbolName: "chevron.right",
                    fallbackText: ">",
                    toolTip: "Next imported palette",
                    action: {
                      store.showImportedPalette(at: store.currentImportedPaletteIndex + 1)
                    }
                  )
                  .disabled(store.currentImportedPaletteIndex >= store.importedPalettes.count - 1)
                }
              }

              Spacer(minLength: 0)

              MenuButton(
                title: "Copy palette as...",
                controlSize: .small,
                items: PaletteExportFormat.allCases.map { format in
                  MenuButtonItem(title: format.label) {
                    onCopyText(exportColors(palette.colors, format: format))
                  }
                }
              )
              .fixedSize()

              SmallIconButton(
                symbolName: "trash",
                fallbackText: "Del",
                toolTip: "Remove imported palette",
                action: { store.removeCurrentImportedPalette() }
              )
              .padding(.trailing, 2)
            }
            .padding(.trailing, 2)

            if let sourceName = palette.sourceName, !sourceName.isEmpty {
              Text(sourceName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 4)
            }

            Spacer(minLength: 0)

            ScrollView(.horizontal, showsIndicators: true) {
              HStack(spacing: 8) {
                ForEach(palette.colors) { item in
                  PaletteSwatchChip(
                    color: item.rgbColor,
                    toolTip: swatchToolTip(for: item),
                    onBurst: showBurst(frame:color:),
                    action: {
                      onCopyText(formatColor(item, format: store.format))
                    }
                  )
                  .contextMenu {
                    ForEach(ColorFormat.allCases, id: \.rawValue) { format in
                      Button("Copy as \(format.label)") {
                        onCopyText(formatColor(item, format: format))
                      }
                    }
                  }
                }
              }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
          }
          .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        }

        if let burst {
          RoundedRectangle(cornerRadius: 11)
            .fill(PlatformColor.color(from: burst.color))
            .frame(width: 32, height: 32)
            .overlay(
              RoundedRectangle(cornerRadius: 11)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .opacity(burst.isLifted ? 0 : 1)
            .position(
              x: burst.frame.midX,
              y: burst.frame.midY + (burst.isLifted ? -28 : 0)
            )
            .allowsHitTesting(false)
            .zIndex(2)
        }
      }
      .coordinateSpace(name: "ImportedPaletteSection")
      .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func showBurst(frame: CGRect, color: NSColor) {
    let id = UUID()
    burst = SwatchBurst(id: id, frame: frame, color: color, isLifted: false)

    DispatchQueue.main.async {
      guard burst?.id == id else { return }
      withAnimation(.easeOut(duration: 0.50)) {
        burst?.isLifted = true
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
      guard burst?.id == id else { return }
      burst = nil
    }
  }
}

private struct SwatchBurst: Identifiable {
  let id: UUID
  let frame: CGRect
  let color: NSColor
  var isLifted: Bool
}

private struct HistorySection: View {
  @ObservedObject var store: ClrPkrStore
  let onCopyText: (String) -> Void

  var body: some View {
    CardContainer {
      if store.history.isEmpty {
        Text("Use Pick or drop an image to capture colors.")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          VStack(spacing: 4) {
            ForEach(store.history) { item in
              HistoryRowButton(
                item: item,
                format: store.format,
                action: {
                  onCopyText(formatColor(item, format: store.format))
                }
              )
              .contextMenu {
                ForEach(ColorFormat.allCases, id: \.rawValue) { format in
                  Button("Copy as \(format.label)") {
                    onCopyText(formatColor(item, format: format))
                  }
                }

                Divider()

                Button("Delete") {
                  store.removeHistoryItem(id: item.id)
                }
              }
            }
          }
        }
      }
    }
    .frame(minHeight: 140, maxHeight: .infinity)
    .frame(maxWidth: .infinity)
    .layoutPriority(1)
  }
}

private func swatchToolTip(for item: PickedColor) -> String {
  let match = NamedColorLookup.nearestMatch(red: item.red, green: item.green, blue: item.blue)
  return "\(match.name)\n\(formatColor(item, format: .hex))"
}

private struct FooterBar: View {
  let historyCount: Int
  let isHistoryEmpty: Bool
  let onCopyHistory: (PaletteExportFormat) -> Void
  let onClearHistory: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text(historyCount == 1 ? "1 pick" : "\(historyCount) picks")
        .font(.system(size: 11))
        .foregroundColor(.secondary)

      Spacer()

      MenuButton(
        title: "Copy history as...",
        controlSize: .small,
        isEnabled: !isHistoryEmpty,
        items: PaletteExportFormat.allCases.map { format in
          MenuButtonItem(title: format.label) {
            onCopyHistory(format)
          }
        }
      )
      .fixedSize()

      NativeButton(
        title: "Clear History",
        controlSize: .small,
        isEnabled: !isHistoryEmpty,
        action: onClearHistory
      )
      .fixedSize()
    }
  }
}

private struct DropOverlay: View {
  let isTargeted: Bool

  var body: some View {
    Group {
      if isTargeted {
        ZStack {
          RoundedRectangle(cornerRadius: 14)
            .fill(PlatformColor.dropOverlayBackground)

          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
              PlatformColor.dropOverlayStroke,
              style: StrokeStyle(lineWidth: 2, dash: [7, 6])
            )
            .padding(6)

          VStack(spacing: 6) {
            SymbolView(symbolName: "photo.on.rectangle.angled", fallbackText: "IMG")
              .foregroundColor(PlatformColor.dropOverlayAccent)

            Text("Drop images here to extract palettes")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(PlatformColor.dropOverlayText)

            Text("We'll pull dominant colors into Imported Palettes")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(PlatformColor.dropOverlayHint)
          }
        }
        .padding(6)
      }
    }
  }
}

private struct PreviewImageView: View {
  let image: NSImage?
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: height)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.black.opacity(0.08), lineWidth: 1)
          )
      } else {
        RoundedRectangle(cornerRadius: 8)
          .fill(PlatformColor.previewPlaceholder)
          .frame(width: width, height: height)
      }
    }
  }
}

import AppKit
import SwiftUI

final class ClrPkrStore: ObservableObject {
  @Published var history: [PickedColor] = []
  @Published var importedPalettes: [ImportedPalette] = []
  @Published var currentImportedPaletteIndex = 0
  @Published var isImportedPaletteVisible = false
  @Published var format: ColorFormat = .hex {
    didSet { publishRecentPickItems() }
  }
  @Published var alwaysOnTop = false

  var onPickRequested: (() -> Void)?
  var onImportRequested: (() -> Void)?
  var onAlwaysOnTopToggleRequested: (() -> Void)?
  var onRecentPicksChanged: (([RecentPickMenuItem]) -> Void)?

  var hasVisibleImportedPalettes: Bool {
    !importedPalettes.isEmpty && isImportedPaletteVisible
  }

  var currentImportedPalette: ImportedPalette? {
    guard importedPalettes.indices.contains(currentImportedPaletteIndex) else {
      return nil
    }
    return importedPalettes[currentImportedPaletteIndex]
  }

  func requestPick() {
    onPickRequested?()
  }

  func requestImport() {
    onImportRequested?()
  }

  func requestAlwaysOnTopToggle() {
    onAlwaysOnTopToggleRequested?()
  }

  func setAlwaysOnTop(_ value: Bool) {
    alwaysOnTop = value
  }

  func addPick(red: Int, green: Int, blue: Int, previewPng: Data?) {
    let color = NSColor(
      srgbRed: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: 1
    )
    let item = PickedColor(
      color: color,
      previewImage: previewPng.flatMap(NSImage.init(data:)),
      pickedAt: Date()
    )
    history.insert(item, at: 0)
    publishRecentPickItems()
  }

  func addPalette(colors: [NSColor], previewImage: NSImage?) {
    let items = colors.map {
      PickedColor(
        color: $0,
        previewImage: nil,
        pickedAt: Date()
      )
    }

    importedPalettes.insert(
      ImportedPalette(
        colors: items,
        previewImage: previewImage,
        importedAt: Date()
      ),
      at: 0
    )
    currentImportedPaletteIndex = 0
    isImportedPaletteVisible = true
    history.insert(contentsOf: items, at: 0)
    publishRecentPickItems()
  }

  func importSelectedItems(at urls: [URL], includesNestedFolders: Bool) {
    importImages(loadImportableImages(from: urls, includesNestedFolders: includesNestedFolders))
  }

  func removeCurrentImportedPalette() {
    guard importedPalettes.indices.contains(currentImportedPaletteIndex) else {
      clearImportedPalettes()
      return
    }

    importedPalettes.remove(at: currentImportedPaletteIndex)
    if importedPalettes.isEmpty {
      clearImportedPalettes()
    } else {
      currentImportedPaletteIndex = min(currentImportedPaletteIndex, importedPalettes.count - 1)
      isImportedPaletteVisible = true
    }
  }

  func showImportedPalette(at index: Int) {
    guard importedPalettes.indices.contains(index) else {
      return
    }

    currentImportedPaletteIndex = index
    isImportedPaletteVisible = true
  }

  func clearAll() {
    history.removeAll()
    clearImportedPalettes()
    publishRecentPickItems()
  }

  func currentRecentPickItems() -> [RecentPickMenuItem] {
    Array(history.prefix(10)).map {
      RecentPickMenuItem(
        text: recentPickMenuText(for: $0, format: format),
        color: $0.rgbColor
      )
    }
  }

  private func clearImportedPalettes() {
    importedPalettes.removeAll()
    currentImportedPaletteIndex = 0
    isImportedPaletteVisible = false
  }

  private func importImages(_ images: [NSImage]) {
    guard !images.isEmpty else {
      return
    }

    for image in images.reversed() {
      let colors = ImagePaletteExtractor.extractPalette(from: image).map(\.color)
      guard !colors.isEmpty else {
        continue
      }
      addPalette(colors: colors, previewImage: image)
    }
  }

  private func loadImportableImages(from urls: [URL], includesNestedFolders: Bool) -> [NSImage] {
    expandedImportURLs(from: urls, includesNestedFolders: includesNestedFolders).compactMap(NSImage.init(contentsOf:))
  }

  private func expandedImportURLs(from urls: [URL], includesNestedFolders: Bool) -> [URL] {
    var collectedFiles: [URL] = []
    let fileManager = FileManager.default

    for url in urls {
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        continue
      }

      if isDirectory.boolValue {
        if includesNestedFolders {
          let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
          )

          while let fileURL = enumerator?.nextObject() as? URL {
            if isImportableImageURL(fileURL) {
              collectedFiles.append(fileURL)
            }
          }
        } else if let children = try? fileManager.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: [.isRegularFileKey],
          options: [.skipsHiddenFiles]
        ) {
          collectedFiles.append(contentsOf: children.filter(isImportableImageURL(_:)))
        }
      } else if isImportableImageURL(url) {
        collectedFiles.append(url)
      }
    }

    return collectedFiles
  }

  private func isImportableImageURL(_ url: URL) -> Bool {
    let pathExtension = url.pathExtension.lowercased()
    return ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic", "heif"].contains(pathExtension)
  }

  private func publishRecentPickItems() {
    onRecentPicksChanged?(currentRecentPickItems())
  }
}

final class MainWindow: NSWindow, NSToolbarDelegate {
  private enum ToolbarIdentifier {
    static let main = NSToolbar.Identifier("com.kharion.clrpkr.main-toolbar")
    static let onTop = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.on-top")
    static let importItem = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.import")
    static let pick = NSToolbarItem.Identifier("com.kharion.clrpkr.toolbar.pick")
  }

  let store = ClrPkrStore()
  private weak var pinToolbarItem: NSToolbarItem?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func awakeFromNib() {
    let rootView = MainWindowRootView(store: store)
    let hostingController = NSHostingController(rootView: rootView)
    let windowFrame = frame
    contentViewController = hostingController
    setFrame(windowFrame, display: true)

    configureWindow()

    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureMainWindow(window: self)
    }

    super.awakeFromNib()
  }

  private func configureWindow() {
    styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    title = "ClrPkr"
    updateTitlebarCount(store.history.count)
    titleVisibility = .visible
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    backgroundColor = .windowBackgroundColor
    isOpaque = false
    hasShadow = true
    setContentSize(NSSize(width: 420, height: 500))
    minSize = NSSize(width: 380, height: 380)
    standardWindowButton(.miniaturizeButton)?.isEnabled = false
    standardWindowButton(.zoomButton)?.isEnabled = false
    setupToolbar()
    center()

    if #available(macOS 11.0, *) {
      toolbarStyle = .unified
      titlebarSeparatorStyle = .none
    }
  }

  func syncToolbarState() {
    pinToolbarItem?.image = toolbarImage(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
    pinToolbarItem?.toolTip = store.alwaysOnTop ? "Disable On Top" : "Enable On Top"
  }

  func updateTitlebarCount(_ count: Int) {
    if #available(macOS 11.0, *) {
      subtitle = count == 1 ? "1 pick" : "\(count) picks"
    }
  }

  @objc
  private func handleToolbarToggleOnTop(_ sender: Any?) {
    store.requestAlwaysOnTopToggle()
  }

  @objc
  private func handleToolbarImport(_ sender: Any?) {
    store.requestImport()
  }

  @objc
  private func handleToolbarPick(_ sender: Any?) {
    store.requestPick()
  }

  private func toolbarImage(systemName: String, tintColor: NSColor? = nil) -> NSImage? {
    guard let image = PlatformSymbol.image(systemName: systemName) else {
      return nil
    }

    guard let tintColor else {
      return image
    }

    let tintedImage = image.copy() as? NSImage ?? image
    tintedImage.lockFocus()
    defer { tintedImage.unlockFocus() }

    tintColor.set()
    NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
    tintedImage.isTemplate = false
    return tintedImage
  }

  private func setupToolbar() {
    let toolbar = NSToolbar(identifier: ToolbarIdentifier.main)
    toolbar.delegate = self
    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .regular
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    if #available(macOS 13.0, *) {
      toolbar.centeredItemIdentifiers = [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
    }
    self.toolbar = toolbar
    syncToolbarState()
  }

  private func makeToolbarItem(
    identifier: NSToolbarItem.Identifier,
    label: String,
    symbolName: String,
    action: Selector,
    tintColor: NSColor? = nil
  ) -> NSToolbarItem {
    let item = NSToolbarItem(itemIdentifier: identifier)
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.image = toolbarImage(systemName: symbolName, tintColor: tintColor)
    item.target = self
    item.action = action
    item.isBordered = true
    item.visibilityPriority = .high

    if identifier == ToolbarIdentifier.onTop {
      pinToolbarItem = item
    }

    return item
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [ToolbarIdentifier.onTop, ToolbarIdentifier.importItem, ToolbarIdentifier.pick]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case ToolbarIdentifier.onTop:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "On Top",
        symbolName: store.alwaysOnTop ? "pin.fill" : "pin",
        action: #selector(handleToolbarToggleOnTop(_:))
      )
    case ToolbarIdentifier.importItem:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "Import",
        symbolName: "folder.badge.plus",
        action: #selector(handleToolbarImport(_:))
      )
    case ToolbarIdentifier.pick:
      return makeToolbarItem(
        identifier: itemIdentifier,
        label: "Pick",
        symbolName: "eyedropper.full",
        action: #selector(handleToolbarPick(_:)),
        tintColor: .controlAccentColor
      )
    default:
      return nil
    }
  }
}

struct MainWindowRootView: View {
  @ObservedObject var store: ClrPkrStore
  @State private var isDropTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      formatPicker

      if store.hasVisibleImportedPalettes, let palette = store.currentImportedPalette {
        importedPaletteSection(palette)
      }

      historySection
      footer
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 9)
    .frame(minWidth: 380, minHeight: 440)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PlatformColor.color(from: .windowBackgroundColor))
    .overlay(dropOverlay)
    .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted, perform: importDroppedItems(providers:))
  }

  private var formatPicker: some View {
    FormatPillControl(selection: $store.format, formats: ColorFormat.allCases)
      .frame(height: 34)
  }

  private func importedPaletteSection(_ palette: ImportedPalette) -> some View {
    cardContainer {
      HStack(alignment: .top, spacing: 12) {
        previewImage(palette.previewImage, width: 96, height: 96)

        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 8) {
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
                  copyText(exportColors(palette.colors, format: format))
                }
              }
            )
            .fixedSize()

            SmallIconButton(
              symbolName: "xmark",
              fallbackText: "x",
              toolTip: "Remove imported palette",
              action: { store.removeCurrentImportedPalette() }
            )
          }

          ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
              ForEach(palette.colors) { item in
                PaletteSwatchChip(
                  color: item.rgbColor,
                  toolTip: "Copy \(formatColor(item, format: store.format))",
                  action: {
                    copyText(formatColor(item, format: store.format))
                  }
                )
                .contextMenu {
                  ForEach(ColorFormat.allCases, id: \.rawValue) { format in
                    Button("Copy as \(format.label)") {
                      copyText(formatColor(item, format: format))
                    }
                  }
                }
              }
            }
            .padding(.vertical, 6)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 64)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
      }
      .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var historySection: some View {
    cardContainer {
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
                  copyText(formatColor(item, format: store.format))
                }
              )
              .contextMenu {
                ForEach(ColorFormat.allCases, id: \.rawValue) { format in
                  Button("Copy as \(format.label)") {
                    copyText(formatColor(item, format: format))
                  }
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

  private var footer: some View {
    HStack(spacing: 10) {
      Text(store.history.count == 1 ? "1 pick" : "\(store.history.count) picks")
        .font(.system(size: 11))
        .foregroundColor(.secondary)

      Spacer()

      MenuButton(
        title: "Copy history as...",
        controlSize: .small,
        isEnabled: !store.history.isEmpty,
        items: PaletteExportFormat.allCases.map { format in
          MenuButtonItem(title: format.label) {
            copyText(exportColors(store.history, format: format))
          }
        }
      )
      .fixedSize()

      NativeButton(
        title: "Clear History",
        controlSize: .small,
        isEnabled: !store.history.isEmpty
      ) {
        store.clearAll()
      }
      .fixedSize()
    }
  }

  @ViewBuilder
  private var dropOverlay: some View {
    if isDropTargeted {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(PlatformColor.dropOverlayBackground)

        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(PlatformColor.dropOverlayStroke, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
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

  @ViewBuilder
  private func previewImage(_ image: NSImage?, width: CGFloat = 72, height: CGFloat = 72) -> some View {
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

  private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      content()
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(PlatformColor.cardBackground)
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.black.opacity(0.07), lineWidth: 1)
    )
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

private struct HistoryRowButton: View {
  let item: PickedColor
  let format: ColorFormat
  let action: () -> Void

  @State private var isHovering = false
  @State private var showBurst = false
  @State private var burstLifted = false
  @State private var burstID = 0

  var body: some View {
    Button {
      triggerBurst()
      action()
    } label: {
      ZStack(alignment: .trailing) {
        rowContent

        if showBurst {
          SymbolView(symbolName: "doc.on.doc", fallbackText: "Copy")
            .foregroundColor(.secondary)
            .opacity(burstLifted ? 0 : 1)
            .offset(x: -6, y: burstLifted ? -22 : -6)
            .zIndex(1)
        }
      }
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
  }

  private var rowContent: some View {
    HStack(spacing: 10) {
      preview

      VStack(alignment: .leading, spacing: 4) {
        Text(formatColor(item, format: format))
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .lineLimit(1)

        HStack(spacing: 6) {
          RoundedRectangle(cornerRadius: 8)
            .fill(PlatformColor.color(from: item.rgbColor))
            .frame(width: 16, height: 16)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

          Text(historySubtitle(for: item))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      SymbolView(symbolName: "doc.on.doc", fallbackText: "Copy")
        .foregroundColor(.secondary)
        .opacity(isHovering ? 1 : 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(isHovering ? PlatformColor.rowHover : Color.white)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.black.opacity(0.05), lineWidth: 1)
    )
  }

  @ViewBuilder
  private var preview: some View {
    if let previewImage = item.previewImage {
      Image(nsImage: previewImage)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    } else {
      RoundedRectangle(cornerRadius: 10)
        .fill(PlatformColor.color(from: item.rgbColor))
        .frame(width: 46, height: 46)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
  }

  private func triggerBurst() {
    burstID += 1
    let currentBurstID = burstID
    showBurst = true
    burstLifted = false

    DispatchQueue.main.async {
      guard burstID == currentBurstID else { return }
      withAnimation(.easeOut(duration: 0.32)) {
        burstLifted = true
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
      guard burstID == currentBurstID else { return }
      burstLifted = false
      showBurst = false
    }
  }
}

private struct PaletteSwatchChip: View {
  let color: NSColor
  let toolTip: String
  let action: () -> Void

  private let burstFrameHeight: CGFloat = 64
  private let restingOffset: CGFloat = 12
  private let liftDistance: CGFloat = 28

  @State private var showBurst = false
  @State private var burstLifted = false
  @State private var burstID = 0

  var body: some View {
    Button {
      triggerBurst()
      action()
    } label: {
      ZStack {
        swatch
          .offset(y: restingOffset)

        if showBurst {
          swatch
            .opacity(burstLifted ? 0 : 1)
            .offset(y: restingOffset + (burstLifted ? -liftDistance : 0))
            .zIndex(1)
        }
      }
      .frame(width: 32, height: burstFrameHeight)
    }
    .buttonStyle(.plain)
  }

  private var swatch: some View {
    RoundedRectangle(cornerRadius: 11)
      .fill(PlatformColor.color(from: color))
      .frame(width: 32, height: 32)
      .overlay(
        RoundedRectangle(cornerRadius: 11)
          .stroke(Color.black.opacity(0.10), lineWidth: 1)
      )
  }

  private func triggerBurst() {
    burstID += 1
    let currentBurstID = burstID
    showBurst = true
    burstLifted = false

    DispatchQueue.main.async {
      guard burstID == currentBurstID else { return }
      withAnimation(.easeOut(duration: 0.50)) {
        burstLifted = true
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
      guard burstID == currentBurstID else { return }
      burstLifted = false
      showBurst = false
    }
  }
}

private struct PagerButton: View {
  let symbolName: String
  let fallbackText: String
  let toolTip: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      SymbolView(symbolName: symbolName, fallbackText: fallbackText)
        .frame(width: 20, height: 20)
    }
    .buttonStyle(.plain)
  }
}

private struct SmallIconButton: View {
  let symbolName: String
  let fallbackText: String
  let toolTip: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      SymbolView(symbolName: symbolName, fallbackText: fallbackText)
        .foregroundColor(.secondary)
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
  }
}

private struct SymbolView: View {
  let symbolName: String
  let fallbackText: String

  var body: some View {
    if let image = PlatformSymbol.image(systemName: symbolName) {
      Image(nsImage: image)
        .renderingMode(.template)
    } else {
      Text(fallbackText)
        .font(.system(size: 11, weight: .semibold))
    }
  }
}

private struct MenuButtonItem {
  let title: String
  let action: () -> Void
}

private struct NativeButton: NSViewRepresentable {
  let title: String
  let controlSize: NSControl.ControlSize
  var isEnabled: Bool = true
  let action: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(action: action)
  }

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.handlePress(_:)))
    button.bezelStyle = .rounded
    button.controlSize = controlSize
    button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
    button.isEnabled = isEnabled
    return button
  }

  func updateNSView(_ nsView: NSButton, context: Context) {
    nsView.title = title
    nsView.controlSize = controlSize
    nsView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
    nsView.isEnabled = isEnabled
    context.coordinator.action = action
  }

  final class Coordinator: NSObject {
    var action: () -> Void

    init(action: @escaping () -> Void) {
      self.action = action
    }

    @objc
    func handlePress(_ sender: NSButton) {
      action()
    }
  }
}

private struct FormatPillControl: View {
  @Binding var selection: ColorFormat
  let formats: [ColorFormat]

  private let controlHeight: CGFloat = 34
  private let inset: CGFloat = 4
  private let spacing: CGFloat = 4
  private let activeHeight: CGFloat = 26
  private let activeCornerRadius: CGFloat = 9
  private let trackCornerRadius: CGFloat = 11

  var body: some View {
    GeometryReader { proxy in
      let activeWidth = segmentWidth(totalWidth: proxy.size.width)

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: trackCornerRadius)
          .fill(Color.black.opacity(0.075))

        if let selectedIndex = formats.firstIndex(of: selection) {
          RoundedRectangle(cornerRadius: activeCornerRadius)
            .fill(Color.white)
            .frame(width: activeWidth, height: activeHeight)
            .overlay(
              RoundedRectangle(cornerRadius: activeCornerRadius)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .offset(x: activeOffset(for: selectedIndex, width: activeWidth), y: inset)
        }

        HStack(spacing: spacing) {
          ForEach(formats, id: \.rawValue) { format in
            Text(format.label)
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(selection == format ? .primary : .secondary)
              .frame(maxWidth: .infinity)
              .frame(height: activeHeight)
              .contentShape(RoundedRectangle(cornerRadius: activeCornerRadius))
              .onTapGesture {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                  selection = format
                }
              }
          }
        }
        .padding(inset)
      }
      .overlay(
        RoundedRectangle(cornerRadius: trackCornerRadius)
          .stroke(Color.black.opacity(0.06), lineWidth: 1)
      )
    }
    .frame(height: controlHeight)
  }

  private func segmentWidth(totalWidth: CGFloat) -> CGFloat {
    let availableWidth = totalWidth - (inset * 2) - (spacing * CGFloat(max(formats.count - 1, 0)))
    return max(0, availableWidth / CGFloat(max(formats.count, 1)))
  }

  private func activeOffset(for index: Int, width: CGFloat) -> CGFloat {
    inset + CGFloat(index) * (width + spacing)
  }
}

private struct MenuButton: NSViewRepresentable {
  let title: String
  let controlSize: NSControl.ControlSize
  var isEnabled: Bool = true
  let items: [MenuButtonItem]

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.showMenu(_:)))
    button.bezelStyle = .rounded
    button.controlSize = controlSize
    button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
    button.isEnabled = isEnabled
    return button
  }

  func updateNSView(_ nsView: NSButton, context: Context) {
    nsView.title = title
    nsView.controlSize = controlSize
    nsView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
    nsView.isEnabled = isEnabled
    context.coordinator.items = items
  }

  final class Coordinator: NSObject {
    var items: [MenuButtonItem] = []

    @objc
    func showMenu(_ sender: NSButton) {
      let menu = NSMenu()
      for item in items {
        let menuItem = NSMenuItem(title: item.title, action: #selector(handleItem(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = Box(item)
        menu.addItem(menuItem)
      }
      let point = NSPoint(x: 0, y: sender.bounds.maxY + 6)
      menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc
    private func handleItem(_ sender: NSMenuItem) {
      guard let box = sender.representedObject as? Box else {
        return
      }
      box.item.action()
    }

    final class Box: NSObject {
      let item: MenuButtonItem

      init(_ item: MenuButtonItem) {
        self.item = item
      }
    }
  }
}

private enum PlatformSymbol {
  static func image(systemName: String) -> NSImage? {
    if #available(macOS 11.0, *) {
      let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      return image?.withSymbolConfiguration(config)
    }
    return nil
  }
}

private enum PlatformColor {
  static let chromeBackground = color(
    from: NSColor(
      srgbRed: 0.945,
      green: 0.953,
      blue: 0.965,
      alpha: 1
    )
  )
  static let cardBackground = color(from: NSColor.white)
  static let previewPlaceholder = color(
    from: NSColor(
      srgbRed: 0.94,
      green: 0.95,
      blue: 0.97,
      alpha: 1
    )
  )
  static let rowHover = color(
    from: NSColor(
      srgbRed: 0.92,
      green: 0.96,
      blue: 1.0,
      alpha: 1
    )
  )
  static let headerButtonForeground = color(
    from: NSColor(
      srgbRed: 0.31,
      green: 0.40,
      blue: 0.53,
      alpha: 1
    )
  )
  static let headerButtonHoverForeground = color(
    from: NSColor(
      srgbRed: 0.10,
      green: 0.35,
      blue: 0.74,
      alpha: 1
    )
  )
  static let headerButtonActiveForeground = color(
    from: NSColor(
      srgbRed: 0.05,
      green: 0.27,
      blue: 0.60,
      alpha: 1
    )
  )
  static let headerButtonHoverBackground = color(
    from: NSColor(
      srgbRed: 0.23,
      green: 0.58,
      blue: 0.98,
      alpha: 0.14
    )
  )
  static let headerButtonActiveBackground = color(
    from: NSColor(
      srgbRed: 0.23,
      green: 0.58,
      blue: 0.98,
      alpha: 0.26
    )
  )
  static let headerButtonHoverBorder = color(
    from: NSColor(
      srgbRed: 0.13,
      green: 0.46,
      blue: 0.92,
      alpha: 0.16
    )
  )
  static let headerButtonActiveBorder = color(
    from: NSColor(
      srgbRed: 0.13,
      green: 0.46,
      blue: 0.92,
      alpha: 0.24
    )
  )
  static let dropOverlayBackground = color(
    from: NSColor(
      srgbRed: 0.93,
      green: 0.97,
      blue: 1.0,
      alpha: 1
    )
  )
  static let dropOverlayStroke = color(
    from: NSColor(
      srgbRed: 0.13,
      green: 0.46,
      blue: 0.92,
      alpha: 0.55
    )
  )
  static let dropOverlayAccent = color(
    from: NSColor(
      srgbRed: 0.18,
      green: 0.43,
      blue: 0.79,
      alpha: 1
    )
  )
  static let dropOverlayText = color(
    from: NSColor(
      srgbRed: 0.22,
      green: 0.39,
      blue: 0.62,
      alpha: 1
    )
  )
  static let dropOverlayHint = color(
    from: NSColor(
      srgbRed: 0.32,
      green: 0.46,
      blue: 0.61,
      alpha: 1
    )
  )

  static func color(from nsColor: NSColor) -> Color {
    let rgb = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
    return Color(
      red: Double(rgb.redComponent),
      green: Double(rgb.greenComponent),
      blue: Double(rgb.blueComponent),
      opacity: Double(rgb.alphaComponent)
    )
  }
}

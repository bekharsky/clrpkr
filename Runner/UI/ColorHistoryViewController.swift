import Cocoa

final class ColorHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  var onRecentPicksChanged: (([RecentPickMenuItem]) -> Void)?

  private var history: [PickedColor] = []
  private var importedPalettes: [ImportedPalette] = []
  private var currentImportedPaletteIndex = 0
  private var isImportedPaletteVisible = false
  private var format: ColorFormat = .hex

  private let headerView = HeaderBarView()
  private let titleLabel = NSTextField(labelWithString: "ClrPkr")
  private let pickButton = HeaderPickButton(title: "", target: nil, action: nil)
  private let importButton = HeaderPickButton(title: "", target: nil, action: nil)
  private let pinButton = HeaderPickButton(title: "", target: nil, action: nil)
  private let closeButton = TrafficLightButton(title: "", target: nil, action: nil)
  private let formatPicker = FormatPickerView()
  private let dropCaptureView = WholeWindowDropView()
  private let panelView = NativePanelView()
  private let importedPaletteCard = PalettePagerCardView()
  private let importedPaletteThumbnailView = AspectFillImageView()
  private let importedPaletteTitle = NSTextField(labelWithString: "Imported Palette")
  private let importedPaletteSubtitle = NSTextField(labelWithString: "Click a swatch to copy in the selected format")
  private let importedPaletteRemoveButton = NSButton(title: "", target: nil, action: nil)
  private let importedPalettePreviousButton = NSButton(title: "", target: nil, action: nil)
  private let importedPaletteNextButton = NSButton(title: "", target: nil, action: nil)
  private let importedPalettePageLabel = NSTextField(labelWithString: "1 of 1")
  private let importedPaletteStrip = NSStackView()
  private let scrollView = NSScrollView()
  private let tableView = NSTableView()
  private let emptyLabel = NSTextField(labelWithString: "Use Pick or drop an image to capture colors.")
  private let countLabel = NSTextField(labelWithString: "0 picks")
  private let clearButton = NSButton(title: "Clear History", target: nil, action: nil)
  private let chromeBackgroundColor = NSColor(
    srgbRed: 0.945,
    green: 0.953,
    blue: 0.965,
    alpha: 1
  )
  private var isShowingDropOverlay = false

  private var hasVisibleImportedPalettes: Bool {
    !importedPalettes.isEmpty && isImportedPaletteVisible
  }

  override func loadView() {
    view = NSView()
    dropCaptureView.onDropImages = { [weak self] images in
      self?.importImages(images)
    }
    dropCaptureView.onDropStateChanged = { [weak self] isActive in
      self?.updateDropOverlayState(isActive)
    }
    view.wantsLayer = true
    view.layer?.backgroundColor = chromeBackgroundColor.cgColor
    buildInterface()
    refreshInterface()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
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
    refreshInterface()
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
    prependToHistory(items)
    refreshInterface()
  }

  func currentRecentPickItems() -> [RecentPickMenuItem] {
    Array(history.prefix(10)).map {
      RecentPickMenuItem(
        text: formatColor($0, format: format),
        color: $0.rgbColor
      )
    }
  }

  func setAlwaysOnTop(_ alwaysOnTop: Bool) {
    pinButton.isToggled = alwaysOnTop
    pinButton.toolTip = alwaysOnTop
      ? "Disable always on top"
      : "Keep window always on top"
  }

  private func buildInterface() {
    let root = NSStackView()
    root.orientation = .vertical
    root.spacing = 7
    root.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(root)
    dropCaptureView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(dropCaptureView)

    headerView.translatesAutoresizingMaskIntoConstraints = false
    headerView.wantsLayer = true
    headerView.layer?.backgroundColor = chromeBackgroundColor.cgColor

    titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    titleLabel.alignment = .left
    titleLabel.lineBreakMode = .byTruncatingTail

    closeButton.toolTip = "Close"
    closeButton.target = self
    closeButton.action = #selector(handleCloseWindow(_:))
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      closeButton.image = nil
    } else {
      closeButton.title = ""
    }

    pickButton.toolTip = "Pick color from screen"
    pickButton.target = NSApp.delegate
    pickButton.action = #selector(AppDelegate.startPickerFromToolbar(_:))
    pickButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "eyedropper.full",
        accessibilityDescription: "Pick"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      pickButton.image = image?.withSymbolConfiguration(config)
      pickButton.image?.isTemplate = true
      pickButton.imagePosition = .imageOnly
    } else {
      pickButton.title = "Pick"
    }

    pinButton.toolTip = "Keep window always on top"
    pinButton.target = NSApp.delegate
    pinButton.action = #selector(AppDelegate.toggleAlwaysOnTopFromToolbar(_:))
    pinButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "pin",
        accessibilityDescription: "Always on top"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      pinButton.image = image?.withSymbolConfiguration(config)
      pinButton.image?.isTemplate = true
      pinButton.imagePosition = .imageOnly
    } else {
      pinButton.title = "Top"
    }

    importButton.toolTip = "Import image file or folder"
    importButton.target = NSApp.delegate
    importButton.action = #selector(AppDelegate.importImagesFromToolbar(_:))
    importButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "folder.badge.plus",
        accessibilityDescription: "Import image source"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      importButton.image = image?.withSymbolConfiguration(config)
      importButton.image?.isTemplate = true
      importButton.imagePosition = .imageOnly
    } else {
      importButton.title = "Import"
    }

    let headerSpacer = HeaderDragHandleView()
    headerSpacer.translatesAutoresizingMaskIntoConstraints = false
    headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let headerStack = NSStackView(views: [
      closeButton,
      titleLabel,
      headerSpacer,
      pinButton,
      importButton,
      pickButton
    ])
    headerStack.orientation = .horizontal
    headerStack.alignment = .centerY
    headerStack.spacing = 8
    headerStack.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(headerStack)

    NSLayoutConstraint.activate([
      closeButton.widthAnchor.constraint(equalToConstant: 13.5),
      closeButton.heightAnchor.constraint(equalToConstant: 13.5),
      pinButton.widthAnchor.constraint(equalToConstant: 44),
      pinButton.heightAnchor.constraint(equalToConstant: 28),
      importButton.widthAnchor.constraint(equalToConstant: 44),
      importButton.heightAnchor.constraint(equalToConstant: 28),
      pickButton.widthAnchor.constraint(equalToConstant: 44),
      pickButton.heightAnchor.constraint(equalToConstant: 28),
      headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
      headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -2),
      headerStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 2),
      headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -2),
      titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160),
      titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 10)
    ])

    formatPicker.translatesAutoresizingMaskIntoConstraints = false
    formatPicker.setSelectedFormat(format, animated: false)
    formatPicker.onChange = { [weak self] selected in
      self?.handleFormatChanged(selected)
    }
    NSLayoutConstraint.activate([
      formatPicker.heightAnchor.constraint(equalToConstant: 34)
    ])

    panelView.translatesAutoresizingMaskIntoConstraints = false

    let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("history"))
    tableColumn.resizingMask = .autoresizingMask
    tableView.addTableColumn(tableColumn)
    tableView.headerView = nil
    tableView.backgroundColor = .clear
    tableView.focusRingType = .none
    tableView.selectionHighlightStyle = .none
    tableView.intercellSpacing = NSSize(width: 0, height: 4)
    tableView.rowHeight = 56
    tableView.delegate = self
    tableView.dataSource = self
    tableView.target = self
    tableView.doubleAction = #selector(handleRowActivated(_:))

    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.contentView.postsBoundsChangedNotifications = true
    scrollView.documentView = tableView
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScrollBoundsChanged(_:)),
      name: NSView.boundsDidChangeNotification,
      object: scrollView.contentView
    )

    emptyLabel.alignment = .center
    emptyLabel.textColor = NSColor.secondaryLabelColor
    emptyLabel.font = NSFont.systemFont(ofSize: 13)
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false

    panelView.addSubview(scrollView)
    panelView.addSubview(emptyLabel)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 1),
      scrollView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -1),
      scrollView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 1),
      scrollView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -1),
      emptyLabel.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: panelView.centerYAnchor),
      panelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
    ])

    importedPaletteCard.wantsLayer = true
    importedPaletteCard.layer?.cornerRadius = 12
    importedPaletteCard.layer?.backgroundColor = NSColor.white.cgColor
    importedPaletteCard.layer?.borderWidth = 1
    importedPaletteCard.layer?.borderColor = NSColor(
      srgbRed: 0.84,
      green: 0.89,
      blue: 0.95,
      alpha: 1
    ).cgColor
    importedPaletteCard.translatesAutoresizingMaskIntoConstraints = false
    importedPaletteCard.onSwipeLeft = { [weak self] in
      self?.showImportedPalette(at: (self?.currentImportedPaletteIndex ?? 0) + 1)
    }
    importedPaletteCard.onSwipeRight = { [weak self] in
      self?.showImportedPalette(at: (self?.currentImportedPaletteIndex ?? 0) - 1)
    }

    importedPaletteThumbnailView.translatesAutoresizingMaskIntoConstraints = false

    importedPaletteTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    importedPaletteSubtitle.font = NSFont.systemFont(ofSize: 11)
    importedPaletteSubtitle.textColor = NSColor.secondaryLabelColor
    importedPalettePageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    importedPalettePageLabel.textColor = NSColor.secondaryLabelColor
    importedPalettePageLabel.alignment = .center
    importedPaletteRemoveButton.bezelStyle = .texturedRounded
    importedPaletteRemoveButton.controlSize = .small
    importedPaletteRemoveButton.target = self
    importedPaletteRemoveButton.action = #selector(handleRemoveImportedPalette(_:))
    importedPaletteRemoveButton.toolTip = "Remove imported palette"
    importedPaletteRemoveButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(macOS 11.0, *) {
      let image = NSImage(
        systemSymbolName: "xmark",
        accessibilityDescription: "Remove imported palette"
      )
      let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
      importedPaletteRemoveButton.image = image?.withSymbolConfiguration(config)
      importedPaletteRemoveButton.imagePosition = .imageOnly
    } else {
      importedPaletteRemoveButton.title = "x"
    }

    configureImportedPalettePagerButton(
      importedPalettePreviousButton,
      symbolName: "chevron.left",
      fallbackTitle: "<",
      tooltip: "Previous imported palette",
      action: #selector(handleShowPreviousImportedPalette(_:))
    )
    configureImportedPalettePagerButton(
      importedPaletteNextButton,
      symbolName: "chevron.right",
      fallbackTitle: ">",
      tooltip: "Next imported palette",
      action: #selector(handleShowNextImportedPalette(_:))
    )

    importedPaletteStrip.orientation = .horizontal
    importedPaletteStrip.spacing = 8
    importedPaletteStrip.alignment = .centerY
    importedPaletteStrip.translatesAutoresizingMaskIntoConstraints = false

    let importedPalettePager = NSStackView(views: [
      importedPalettePreviousButton,
      importedPalettePageLabel,
      importedPaletteNextButton
    ])
    importedPalettePager.orientation = .horizontal
    importedPalettePager.spacing = 4
    importedPalettePager.alignment = .centerY
    importedPalettePager.translatesAutoresizingMaskIntoConstraints = false

    let importedPaletteText = NSStackView(views: [
      importedPaletteTitle,
      importedPaletteSubtitle,
      importedPalettePager
    ])
    importedPaletteText.orientation = .vertical
    importedPaletteText.spacing = 2
    importedPaletteText.alignment = .leading
    importedPaletteText.translatesAutoresizingMaskIntoConstraints = false

    importedPaletteCard.addSubview(importedPaletteThumbnailView)
    importedPaletteCard.addSubview(importedPaletteText)
    importedPaletteCard.addSubview(importedPaletteRemoveButton)
    importedPaletteCard.addSubview(importedPaletteStrip)
    NSLayoutConstraint.activate([
      importedPaletteThumbnailView.leadingAnchor.constraint(equalTo: importedPaletteCard.leadingAnchor, constant: 12),
      importedPaletteThumbnailView.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 12),
      importedPaletteThumbnailView.bottomAnchor.constraint(equalTo: importedPaletteCard.bottomAnchor, constant: -12),
      importedPaletteThumbnailView.widthAnchor.constraint(equalTo: importedPaletteThumbnailView.heightAnchor),
      importedPaletteText.leadingAnchor.constraint(equalTo: importedPaletteThumbnailView.trailingAnchor, constant: 10),
      importedPaletteText.trailingAnchor.constraint(lessThanOrEqualTo: importedPaletteRemoveButton.leadingAnchor, constant: -8),
      importedPaletteText.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 12),
      importedPalettePageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 42),
      importedPaletteRemoveButton.topAnchor.constraint(equalTo: importedPaletteCard.topAnchor, constant: 10),
      importedPaletteRemoveButton.trailingAnchor.constraint(equalTo: importedPaletteCard.trailingAnchor, constant: -10),
      importedPaletteStrip.leadingAnchor.constraint(equalTo: importedPaletteThumbnailView.trailingAnchor, constant: 10),
      importedPaletteStrip.trailingAnchor.constraint(equalTo: importedPaletteCard.trailingAnchor, constant: -12),
      importedPaletteStrip.topAnchor.constraint(equalTo: importedPaletteText.bottomAnchor, constant: 10),
      importedPaletteStrip.bottomAnchor.constraint(equalTo: importedPaletteCard.bottomAnchor, constant: -12)
    ])

    countLabel.font = NSFont.systemFont(ofSize: 11)
    countLabel.textColor = NSColor.secondaryLabelColor

    let countLabelContainer = NSView()
    countLabelContainer.translatesAutoresizingMaskIntoConstraints = false
    countLabel.translatesAutoresizingMaskIntoConstraints = false
    countLabelContainer.addSubview(countLabel)
    NSLayoutConstraint.activate([
      countLabel.leadingAnchor.constraint(equalTo: countLabelContainer.leadingAnchor, constant: 7),
      countLabel.trailingAnchor.constraint(equalTo: countLabelContainer.trailingAnchor),
      countLabel.topAnchor.constraint(equalTo: countLabelContainer.topAnchor),
      countLabel.bottomAnchor.constraint(equalTo: countLabelContainer.bottomAnchor)
    ])

    clearButton.bezelStyle = .rounded
    clearButton.controlSize = .regular
    clearButton.target = self
    clearButton.action = #selector(handleClearHistory(_:))

    let footer = NSStackView(views: [countLabelContainer, NSView(), clearButton])
    footer.orientation = .horizontal
    footer.alignment = .centerY

    root.addArrangedSubview(headerView)
    root.addArrangedSubview(formatPicker)
    root.addArrangedSubview(importedPaletteCard)
    root.addArrangedSubview(panelView)
    root.addArrangedSubview(footer)

    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 9),
      root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -9),
      importedPaletteCard.widthAnchor.constraint(equalTo: root.widthAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 30),
      root.topAnchor.constraint(equalTo: view.topAnchor, constant: 9),
      root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -9),
      dropCaptureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dropCaptureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dropCaptureView.topAnchor.constraint(equalTo: view.topAnchor),
      dropCaptureView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func refreshInterface() {
    refreshImportedPaletteSection()
    tableView.reloadData()
    let hasHistory = !history.isEmpty
    emptyLabel.isHidden = isShowingDropOverlay || hasHistory
    scrollView.isHidden = !hasHistory
    clearButton.isEnabled = hasHistory
    countLabel.stringValue = hasHistory ? "\(history.count) picks" : "0 picks"
    onRecentPicksChanged?(currentRecentPickItems())
  }

  private func updateDropOverlayState(_ isActive: Bool) {
    isShowingDropOverlay = isActive
    panelView.setDropTargetActive(isActive)
    refreshInterface()
  }

  private func handleFormatChanged(_ selected: ColorFormat) {
    format = selected
    refreshInterface()
  }

  @objc
  private func handleClearHistory(_ sender: Any?) {
    history.removeAll()
    clearImportedPalettes()
    refreshInterface()
  }

  @objc
  private func handleRemoveImportedPalette(_ sender: Any?) {
    guard importedPalettes.indices.contains(currentImportedPaletteIndex) else {
      clearImportedPalettes()
      refreshInterface()
      return
    }

    importedPalettes.remove(at: currentImportedPaletteIndex)
    if importedPalettes.isEmpty {
      clearImportedPalettes()
    } else {
      currentImportedPaletteIndex = min(currentImportedPaletteIndex, importedPalettes.count - 1)
      isImportedPaletteVisible = true
    }
    refreshInterface()
  }

  func importSelectedItems(at urls: [URL], includesNestedFolders: Bool) {
    importItems(at: urls, includesNestedFolders: includesNestedFolders)
  }

  private func refreshImportedPaletteSection() {
    importedPaletteCard.isHidden = !hasVisibleImportedPalettes

    guard hasVisibleImportedPalettes, let importedPalette = currentImportedPalette else {
      importedPaletteThumbnailView.image = nil
      importedPalettePageLabel.stringValue = "0 of 0"
      importedPaletteSubtitle.stringValue = "Drop an image to build a grouped palette"
      updateImportedPaletteNavigation()
      clearImportedPaletteStrip()
      return
    }

    importedPaletteThumbnailView.image = importedPalette.previewImage
    importedPaletteSubtitle.stringValue = "Click a swatch to copy as \(format.label)"
    importedPalettePageLabel.stringValue = "\(currentImportedPaletteIndex + 1) of \(importedPalettes.count)"
    updateImportedPaletteNavigation()

    clearImportedPaletteStrip()

    for item in importedPalette.colors {
      let button = PaletteSwatchButton(frame: .zero)
      button.color = item.rgbColor
      button.target = self
      button.action = #selector(handleImportedPaletteSwatch(_:))
      button.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
      button.toolTip = "Copy \(formatColor(item, format: format))"
      importedPaletteStrip.addArrangedSubview(button)
    }
  }

  @objc
  private func handleImportedPaletteSwatch(_ sender: NSButton) {
    guard
      let identifier = sender.identifier?.rawValue,
      let item = currentImportedPalette?.colors.first(where: { $0.id.uuidString == identifier })
    else {
      return
    }

    (sender as? PaletteSwatchButton)?.animateCopyBurst()
    copy(item: item)
  }

  @objc
  private func handleShowPreviousImportedPalette(_ sender: Any?) {
    navigateImportedPalette(by: -1)
  }

  @objc
  private func handleShowNextImportedPalette(_ sender: Any?) {
    navigateImportedPalette(by: 1)
  }

  @objc
  private func handleRowActivated(_ sender: Any?) {
    copySelectedRow()
  }

  @objc
  private func handleCloseWindow(_ sender: Any?) {
    view.window?.orderOut(sender)
  }

  @objc
  private func handleScrollBoundsChanged(_ notification: Notification) {
    refreshVisibleRowHoverStates()
  }

  private func copySelectedRow() {
    let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
    guard history.indices.contains(row) else {
      return
    }

    if let view = tableView.view(
      atColumn: 0,
      row: row,
      makeIfNecessary: false
    ) as? HistoryRowView {
      view.animateCopyBurst()
    }
    copy(item: history[row])
  }

  private func copy(item: PickedColor) {
    let value = formatColor(item, format: format)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
  }

  private func refreshVisibleRowHoverStates() {
    for row in tableView.rows(in: tableView.visibleRect).location..<(tableView.rows(in: tableView.visibleRect).location + tableView.rows(in: tableView.visibleRect).length) {
      guard row >= 0, row < tableView.numberOfRows else {
        continue
      }
      (tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? HistoryRowView)?
        .syncHoverStateWithMouse(animated: false)
    }
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    history.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("HistoryRowView")
    let item = history[row]
    let view = (tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryRowView)
      ?? {
        let rowView = HistoryRowView()
        rowView.identifier = identifier
        return rowView
      }()
    view.configure(item: item, format: format)
    return view
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    if tableView.selectedRow >= 0 {
      copySelectedRow()
      tableView.deselectAll(nil)
    }
  }

  private var currentImportedPalette: ImportedPalette? {
    guard importedPalettes.indices.contains(currentImportedPaletteIndex) else {
      return nil
    }
    return importedPalettes[currentImportedPaletteIndex]
  }

  private func clearImportedPaletteStrip() {
    importedPaletteStrip.arrangedSubviews.forEach { view in
      importedPaletteStrip.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
  }

  private func showImportedPalette(at index: Int) {
    guard importedPalettes.indices.contains(index) else {
      return
    }

    currentImportedPaletteIndex = index
    refreshImportedPaletteSection()
  }

  private func navigateImportedPalette(by offset: Int) {
    showImportedPalette(at: currentImportedPaletteIndex + offset)
  }

  private func updateImportedPaletteNavigation() {
    importedPalettePreviousButton.isEnabled = currentImportedPaletteIndex > 0
    importedPaletteNextButton.isEnabled = currentImportedPaletteIndex < (importedPalettes.count - 1)
  }

  private func prependToHistory(_ items: [PickedColor]) {
    history.insert(contentsOf: items, at: 0)
  }

  private func importItems(at urls: [URL], includesNestedFolders: Bool) {
    importImages(loadImportableImages(from: urls, includesNestedFolders: includesNestedFolders))
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
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
          )
          while let nestedURL = enumerator?.nextObject() as? URL {
            guard isImportableImageFile(at: nestedURL) else {
              continue
            }
            collectedFiles.append(nestedURL)
          }
        } else if let directoryContents = try? fileManager.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: [.isRegularFileKey],
          options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
          for childURL in directoryContents where isImportableImageFile(at: childURL) {
            collectedFiles.append(childURL)
          }
        }
      } else if isImportableImageFile(at: url) {
        collectedFiles.append(url)
      }
    }

    return collectedFiles.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
  }

  private func isImportableImageFile(at url: URL) -> Bool {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true else {
      return false
    }

    return NSImage(contentsOf: url) != nil
  }

  private func clearImportedPalettes() {
    importedPalettes.removeAll()
    currentImportedPaletteIndex = 0
    isImportedPaletteVisible = false
  }

  private func configureImportedPalettePagerButton(
    _ button: NSButton,
    symbolName: String,
    fallbackTitle: String,
    tooltip: String,
    action: Selector
  ) {
    button.bezelStyle = .texturedRounded
    button.controlSize = .small
    button.target = self
    button.action = action
    button.toolTip = tooltip
    button.setContentHuggingPriority(.required, for: .horizontal)
    if #available(macOS 11.0, *) {
      let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
      let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
      button.image = image?.withSymbolConfiguration(config)
      button.imagePosition = .imageOnly
      button.title = ""
    } else {
      button.title = fallbackTitle
    }
  }
}

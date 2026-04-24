import AppKit
import SwiftUI

struct CardContainer<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
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
}

struct HistoryRowButton: View {
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

struct PaletteSwatchChip: View {
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

struct PagerButton: View {
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

struct SmallIconButton: View {
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

struct SymbolView: View {
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

struct MenuButtonItem {
  let title: String
  let action: () -> Void
}

struct NativeButton: NSViewRepresentable {
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

struct FormatPillControl: View {
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

struct MenuButton: NSViewRepresentable {
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

enum PlatformSymbol {
  static func image(systemName: String) -> NSImage? {
    if #available(macOS 11.0, *) {
      let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
      return image?.withSymbolConfiguration(config)
    }
    return nil
  }
}

enum PlatformColor {
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

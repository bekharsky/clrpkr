import AppKit
import SwiftUI

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
  let onBurst: (CGRect, NSColor) -> Void
  let action: () -> Void

  var body: some View {
    GeometryReader { proxy in
      Button {
        onBurst(proxy.frame(in: .named("ImportedPaletteSection")), color)
        action()
      } label: {
        swatch
      }
    }
    .frame(width: 32, height: 32)
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

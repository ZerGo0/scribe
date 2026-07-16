#!/usr/bin/env swift
import AppKit
import Foundation

private let canvasSize = 1024
private let projectRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
private let foregroundURL =
  projectRoot
  .appendingPathComponent("Resources/AppIcon.icon/Assets/Foreground.png")

private func renderForeground() throws -> Data {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: canvasSize,
      pixelsHigh: canvasSize,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bitmapFormat: [],
      bytesPerRow: 0,
      bitsPerPixel: 0
    )
  else {
    throw CocoaError(.fileWriteUnknown)
  }

  let bounds = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
  let context = NSGraphicsContext(bitmapImageRep: bitmap)

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context?.imageInterpolation = .high
  context?.cgContext.clear(bounds)

  let symbolConfiguration = NSImage.SymbolConfiguration(
    pointSize: 300,
    weight: .semibold,
    scale: .large
  ).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

  guard
    let waveform = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
      .withSymbolConfiguration(symbolConfiguration)
  else {
    throw CocoaError(.featureUnsupported)
  }

  waveform.draw(
    in: NSRect(x: 128, y: 294, width: 500, height: 436),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
  )

  NSColor.white.setFill()
  let transcriptLines = [
    NSRect(x: 650, y: 608, width: 224, height: 44),
    NSRect(x: 650, y: 490, width: 168, height: 44),
    NSRect(x: 650, y: 372, width: 224, height: 44),
  ]

  for line in transcriptLines {
    NSBezierPath(roundedRect: line, xRadius: 22, yRadius: 22).fill()
  }

  context?.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }
  return data
}

do {
  let data = try renderForeground()
  try data.write(to: foregroundURL, options: .atomic)
  print("Generated \(foregroundURL.path)")
} catch {
  fputs("Could not generate app icon artwork: \(error.localizedDescription)\n", stderr)
  exit(1)
}

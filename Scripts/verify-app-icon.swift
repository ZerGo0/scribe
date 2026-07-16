#!/usr/bin/env swift
import AppKit
import Foundation

private enum VerificationError: LocalizedError {
  case failed(String)

  var errorDescription: String? {
    switch self {
    case .failed(let message): message
    }
  }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw VerificationError.failed(message) }
}

private func render(_ image: NSImage, pixels: Int) throws -> NSBitmapImageRep {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixels,
      pixelsHigh: pixels,
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
    throw VerificationError.failed("Could not create the icon preview bitmap.")
  }

  let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
  let context = NSGraphicsContext(bitmapImageRep: bitmap)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context?.cgContext.clear(bounds)
  context?.imageInterpolation = .high
  image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
  context?.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()
  return bitmap
}

private func verifyPixels(_ bitmap: NSBitmapImageRep) throws -> (colored: Int, bright: Int) {
  let width = bitmap.pixelsWide
  let height = bitmap.pixelsHigh
  let corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]

  for (x, y) in corners {
    let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
    try require(alpha < 0.08, "The rendered icon has an opaque outer corner.")
  }

  let centerAlpha = bitmap.colorAt(x: width / 2, y: height / 2)?.alphaComponent ?? 0
  try require(centerAlpha > 0.9, "The rendered icon has no opaque center.")

  var coloredPixels = 0
  var brightPixels = 0
  for y in 0..<height {
    for x in 0..<width {
      guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.25 else {
        continue
      }

      let red = color.redComponent
      let green = color.greenComponent
      let blue = color.blueComponent
      if blue > 0.45 && blue > green && blue > red * 0.9 { coloredPixels += 1 }
      if red > 0.65 && green > 0.65 && blue > 0.65 { brightPixels += 1 }
    }
  }

  try require(
    coloredPixels > width * height / 5, "The rendered icon is missing its blue background.")
  try require(
    brightPixels > max(width * height / 100, 4),
    "The rendered icon is missing its foreground mark."
  )
  return (coloredPixels, brightPixels)
}

private func writePreview(_ bitmap: NSBitmapImageRep, to url: URL) throws {
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw VerificationError.failed("The rendered icon preview could not be encoded.")
  }
  try data.write(to: url, options: .atomic)
}

guard CommandLine.arguments.count >= 2 else {
  fputs("Usage: verify-app-icon.swift <app-path> [preview-path]\n", stderr)
  exit(2)
}

let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
let fileManager = FileManager.default

do {
  guard let bundle = Bundle(url: appURL) else {
    throw VerificationError.failed("The app bundle could not be opened.")
  }

  try require(
    bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String == "AppIcon",
    "CFBundleIconName is not AppIcon."
  )
  try require(
    fileManager.fileExists(atPath: resourcesURL.appendingPathComponent("Assets.car").path),
    "The compiled asset catalog is missing."
  )
  try require(
    fileManager.fileExists(atPath: resourcesURL.appendingPathComponent("AppIcon.icns").path),
    "The backward-compatible app icon is missing."
  )

  let workspaceImage = NSWorkspace.shared.icon(forFile: appURL.path)
  let bitmap = try render(workspaceImage, pixels: 256)
  let smallBitmap = try render(workspaceImage, pixels: 32)

  if CommandLine.arguments.count >= 3 {
    let previewURL = URL(fileURLWithPath: CommandLine.arguments[2])
    try writePreview(bitmap, to: previewURL)
    try writePreview(
      smallBitmap,
      to: previewURL.deletingPathExtension().appendingPathExtension("32.png")
    )
  }

  let counts = try verifyPixels(bitmap)
  let smallCounts = try verifyPixels(smallBitmap)
  print(
    "Verified rendered app icon at 256 px "
      + "(\(counts.colored) colored, \(counts.bright) bright) and 32 px "
      + "(\(smallCounts.colored) colored, \(smallCounts.bright) bright)."
  )
} catch {
  fputs("App icon verification failed: \(error.localizedDescription)\n", stderr)
  exit(1)
}

import AppKit
import CoreGraphics

@MainActor
enum ActiveScreenResolver {
  static func activeScreen() -> NSScreen? {
    guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
      let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else {
      return screenContainingMouse()
    }

    for window in windows {
      guard
        (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == frontmostPID,
        (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
        let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
        bounds.width > 1,
        bounds.height > 1,
        let screen = screen(containingQuartzPoint: CGPoint(x: bounds.midX, y: bounds.midY))
      else {
        continue
      }
      return screen
    }

    return screenContainingMouse()
  }

  private static func screen(containingQuartzPoint point: CGPoint) -> NSScreen? {
    NSScreen.screens.first { screen in
      guard
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? NSNumber
      else {
        return false
      }
      return CGDisplayBounds(CGDirectDisplayID(number.uint32Value)).contains(point)
    }
  }

  private static func screenContainingMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
  }
}

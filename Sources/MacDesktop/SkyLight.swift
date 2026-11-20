import ApplicationServices

// Private window-server calls. Read-only: macOS blocks the write calls for other apps' windows.
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?
@_silgen_name("CGSCopySpacesForWindows") func CGSCopySpacesForWindows(_ connection: Int32, _ mask: Int32, _ windowIDs: CFArray) -> CFArray?
@_silgen_name("_AXUIElementGetWindow") func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<UInt32>) -> AXError

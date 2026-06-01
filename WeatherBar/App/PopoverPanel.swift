import AppKit
import SwiftUI

class PopoverPanel: NSPanel {
    init(contentRect: NSRect, contentViewController: NSViewController) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.isFloatingPanel = true
        self.level = .statusBar
        self.hasShadow = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.contentViewController = contentViewController
    }

    override var canBecomeKey: Bool {
        return true
    }
}

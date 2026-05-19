import AppKit
import Combine
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate {
    private let model = PromptMeterModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var hostingController: NSHostingController<ContentView>?
    private var sizeUpdateScheduled = false
    private var statusUpdateScheduled = false
    private var statusImageCache: [String: NSImage] = [:]
    private var lastStatusDisplay: StatusDisplay?
    private var cancellables = Set<AnyCancellable>()
    private static let maxStatusImageCacheSize = 64

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureNotifications()
        configureStatusItem()
        configurePopover()

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.schedulePopoverSizeUpdate()
                self?.scheduleStatusItemUpdate()
            }
            .store(in: &cancellables)

        updateStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.title = ""
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func configureNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            configurePopoverContentIfNeeded()
            updatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
        hostingController = nil
        sizeUpdateScheduled = false
    }

    private func configurePopoverContentIfNeeded() {
        guard hostingController == nil else { return }

        let controller = NSHostingController(rootView: ContentView(model: model))
        hostingController = controller
        popover.contentViewController = controller
    }

    private func schedulePopoverSizeUpdate() {
        guard popover.isShown, !sizeUpdateScheduled else { return }

        sizeUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            sizeUpdateScheduled = false
            updatePopoverSize()
        }
    }

    private func scheduleStatusItemUpdate() {
        guard !statusUpdateScheduled else { return }

        statusUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            statusUpdateScheduled = false
            updateStatusItem()
        }
    }

    private func updatePopoverSize() {
        guard let view = hostingController?.view else { return }
        view.layoutSubtreeIfNeeded()

        let fittingSize = view.fittingSize
        popover.contentSize = NSSize(
            width: max(306, fittingSize.width),
            height: fittingSize.height
        )
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        let display: StatusDisplay
        let sessionStatuses = model.menuBarSessionStatuses
        if !sessionStatuses.isEmpty {
            display = StatusDisplay(
                imageKey: Self.statusImageKey(for: sessionStatuses),
                entries: sessionStatuses.map(StatusEntry.init),
                tooltip: statusTooltip(for: sessionStatuses)
            )
        } else {
            display = StatusDisplay(
                imageKey: "system.text.bubble",
                entries: [],
                tooltip: "PromptMeter - \(model.metrics.estimatedTokens) estimated tokens"
            )
        }

        guard display != lastStatusDisplay else { return }
        lastStatusDisplay = display

        button.image = statusImage(for: display)
        button.title = ""
        button.toolTip = display.tooltip
    }

    private static func statusImageKey(for statuses: [MenuBarSessionStatus]) -> String {
        statuses
            .map { "\($0.icon.providerID):\($0.percentText)" }
            .joined(separator: "|")
    }

    private func statusTooltip(for statuses: [MenuBarSessionStatus]) -> String {
        let usageText = statuses
            .map { "\($0.providerName) session \($0.percentText) left" }
            .joined(separator: " · ")
        return "PromptMeter - \(model.metrics.estimatedTokens) estimated tokens · \(usageText)"
    }

    private func statusImage(for display: StatusDisplay) -> NSImage? {
        if let cached = statusImageCache[display.imageKey] {
            return cached
        }

        let image = display.entries.isEmpty
            ? systemStatusImage()
            : renderedStatusImage(for: display.entries)

        if let image {
            cacheStatusImage(image, key: display.imageKey)
        }

        return image
    }

    private func systemStatusImage() -> NSImage? {
        guard let copy = NSImage(
            systemSymbolName: "text.bubble",
            accessibilityDescription: "PromptMeter"
        )?.copy() as? NSImage else {
            return nil
        }

        copy.size = NSSize(width: 16, height: 16)
        copy.isTemplate = true
        return copy
    }

    private func renderedStatusImage(for entries: [StatusEntry]) -> NSImage? {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let iconSize = NSSize(width: 14, height: 14)
        let iconTextGap: CGFloat = 3
        let entryGap: CGFloat = 7
        let height: CGFloat = 18
        let textSizes = entries.map { $0.percentText.size(withAttributes: attributes) }

        let contentWidth = zip(entries, textSizes).reduce(CGFloat.zero) { total, item in
            let textWidth = ceil(item.1.width)
            let separator = total == 0 ? CGFloat.zero : entryGap
            return total + separator + iconSize.width + iconTextGap + textWidth
        }
        let image = NSImage(size: NSSize(width: max(1, ceil(contentWidth)), height: height))

        image.lockFocus()
        var x: CGFloat = 0
        for (index, entry) in entries.enumerated() {
            if index > 0 {
                x += entryGap
            }

            if let icon = NSImage(named: entry.icon.assetName) {
                icon.draw(
                    in: NSRect(x: x, y: (height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            x += iconSize.width + iconTextGap

            let textSize = textSizes[index]
            entry.percentText.draw(
                at: NSPoint(x: x, y: (height - textSize.height) / 2),
                withAttributes: attributes
            )
            x += ceil(textSize.width)
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func cacheStatusImage(_ image: NSImage, key: String) {
        if statusImageCache.count >= Self.maxStatusImageCacheSize {
            statusImageCache.removeAll(keepingCapacity: true)
        }
        statusImageCache[key] = image
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

private struct StatusDisplay: Equatable {
    let imageKey: String
    let entries: [StatusEntry]
    let tooltip: String
}

private struct StatusEntry: Equatable {
    let icon: ProviderIconKind
    let percentText: String

    init(status: MenuBarSessionStatus) {
        icon = status.icon
        percentText = status.percentText
    }
}

import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
@Suite(.serialized)
struct AttachmentImageViewerTests {
    @Test func zoomStepsClampsAndResetsTransform() {
        let session = AttachmentImageViewerSession()
        let ref = AttachmentRef(id: UUID(), filename: "chart.png")
        session.configure(items: [ref], initialID: ref.id, imageLoader: { _ in nil })

        #expect(session.zoomScale == 1.0)
        #expect(session.zoomPercentage == 100)
        #expect(session.zoomPercentageText == "100%")
        #expect(session.isDefaultZoom)

        session.zoomIn()
        #expect(abs(session.zoomScale - 1.2) < 0.001)
        #expect(session.zoomPercentageText == "120%")
        #expect(session.isShowingZoomHUD)

        session.zoomOut()
        #expect(abs(session.zoomScale - 1.0) < 0.001)
        #expect(session.zoomPercentageText == "100%")

        session.setZoom(10.0)
        #expect(session.zoomScale == AttachmentImageViewerSession.maxZoomScale)
        #expect(session.zoomPercentageText == "500%")

        session.panOffset = CGSize(width: 48, height: -32)
        session.setZoom(0.01)
        #expect(session.zoomScale == AttachmentImageViewerSession.minZoomScale)
        #expect(session.zoomPercentageText == "10%")
        #expect(session.panOffset == .zero)

        session.setZoom(1.8)
        session.panOffset = CGSize(width: 24, height: 18)
        session.resetZoom()
        #expect(session.zoomScale == 1.0)
        #expect(session.panOffset == .zero)
        #expect(session.isDefaultZoom)
    }

    @Test func doubleTapAndScrollMagnificationAndRotationBehaveConsistently() {
        let session = AttachmentImageViewerSession()
        let ref = AttachmentRef(id: UUID(), filename: "photo.png")
        session.configure(items: [ref], initialID: ref.id, imageLoader: { _ in nil })

        session.toggleDoubleTapZoom()
        #expect(abs(session.zoomScale - 2.0) < 0.001)
        #expect(session.zoomPercentageText == "200%")

        session.panOffset = CGSize(width: 30, height: 20)
        session.toggleDoubleTapZoom()
        #expect(abs(session.zoomScale - 1.0) < 0.001)
        #expect(session.panOffset == .zero)

        session.applyScrollDelta(5.0)
        #expect(session.zoomScale > 1.0)

        session.resetZoom(showHUD: false)
        session.applyMagnification(0.5)
        #expect(abs(session.zoomScale - 1.5) < 0.001)

        #expect(session.rotationDegrees == 0)
        session.rotateClockwise()
        #expect(session.rotationDegrees == 90)
        session.rotateClockwise()
        #expect(session.rotationDegrees == 180)
        session.rotateClockwise()
        #expect(session.rotationDegrees == 270)
        session.rotateClockwise()
        #expect(session.rotationDegrees == 0)
    }

    @Test func multiItemNavigationAndRemovalAdvanceOrCloseCleanly() {
        let first = AttachmentRef(id: UUID(), filename: "one.png")
        let second = AttachmentRef(id: UUID(), filename: "two.png")
        let third = AttachmentRef(id: UUID(), filename: "three.png")
        var removedIDs: [UUID] = []
        var didRequestClose = false

        let session = AttachmentImageViewerSession()
        session.onRequestClose = { didRequestClose = true }
        session.configure(
            items: [first, second, third],
            initialID: second.id,
            imageLoader: { _ in nil },
            onRemove: { removedIDs.append($0.id) }
        )

        #expect(session.currentIndex == 1)
        #expect(session.currentItem?.id == second.id)
        #expect(session.canGoPrevious)
        #expect(session.canGoNext)

        session.setZoom(1.6)
        session.rotateClockwise()
        session.step(by: 1)
        #expect(session.currentItem?.id == third.id)
        #expect(session.zoomScale == 1.0)
        #expect(session.rotationDegrees == 0)
        #expect(!session.canGoNext)

        session.removeCurrentItem()
        #expect(removedIDs == [third.id])
        #expect(session.items.map(\.id) == [first.id, second.id])
        #expect(session.currentItem?.id == second.id)
        #expect(!didRequestClose)

        session.removeCurrentItem()
        session.removeCurrentItem()
        #expect(session.items.isEmpty)
        #expect(didRequestClose)
    }

    @Test func windowControllerShowsAndClosesOnPrivacyLock() {
        let controller = AttachmentImageViewerWindowController.shared
        defer { controller.close() }

        let first = AttachmentRef(id: UUID(), filename: "paste.png")
        let second = AttachmentRef(id: UUID(), filename: "paste-2.png")
        controller.show(
            items: [first, second],
            initialID: second.id,
            imageLoader: { _ in NSImage(size: NSSize(width: 64, height: 48)) },
            activate: false
        )

        #expect(controller.hostedWindow != nil)
        #expect(controller.hostedWindow?.title.contains("2 / 2") == true)
        #expect(controller.hostedWindow?.title.contains("paste-2.png") == true)

        NotificationCenter.default.post(name: .privacyMask, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(controller.hostedWindow == nil)
    }
}

import DesignLibrary
import SwiftUI
import UIKit

/// Identification photos for one species, with the caption and credit each one carries.
///
/// Captions are shown rather than hidden behind a tap: "the stem base" is the whole reason
/// the photo is useful, and credits are a licence obligation. Tapping a photo opens it full
/// screen, where it can be zoomed to see the detail the strip is too small to show.
struct SpeciesPhotoStrip: View {
    let species: ForageSpecies

    var body: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            if !species.photos.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: .small) {
                        ForEach(species.photos) { photo in
                            photoCard(photo)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if let url = species.moreImagesURL {
                VStack(alignment: .leading, spacing: .xxxSmall) {
                    Link(destination: url) {
                        HStack(spacing: .xxSmall) {
                            Image(systemName: "safari")
                                .icon(size: .small, color: .accent)
                            VStack(alignment: .leading, spacing: .empty) {
                                Text("More photos on the web")
                                    .font(.caption)
                                
                                Text("Requires internet connection.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func photoCard(_ photo: SpeciesPhoto) -> some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            Button {
                FullScreenPhotoViewer.present(photos: species.photos, selection: photo.id)
            } label: {
                BundledPhoto(fileName: photo.fileName)
                    .frame(width: Layout.photoWidth, height: Layout.photoHeight)
                    .clipShape(Layout.cardShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photo.caption)
            .accessibilityHint("Opens the photo full screen")
            .accessibilityIdentifier("speciesPhoto.\(photo.fileName)")

            Text(photo.caption)
                .font(.caption)
                .lineLimit(3)

            Text(photo.credit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .lineLimit(3)
        }
        .frame(width: Layout.photoWidth)
    }
}

/// Every photo of one species, one at a time and full screen, swiped between like Photos.
/// The caption and credit stay on screen: the credit is a licence obligation wherever the
/// photo is shown, and the caption says which feature to look at once zoomed in.
///
/// Swiping the photo up or down off the screen closes it, as in Photos, with the species page
/// showing through as it goes.
private struct FullScreenPhotoViewer: View {
    let photos: [SpeciesPhoto]
    @State var selection: SpeciesPhoto.ID
    let close: (_ animated: Bool) -> Void
    /// Hides the close button and caption while a photo is dragged. Flipped only at the start
    /// and end of a drag: the drag itself lives in UIKit, so the pager isn't re-rendered per frame.
    @State private var isDragging = false

    /// Presented by UIKit rather than with `fullScreenCover`: a cover takes the page beneath
    /// it out of the window, so a photo dragged away revealed an empty screen instead of the
    /// species page. `.overFullScreen` leaves that page in place behind the viewer.
    @MainActor
    static func present(photos: [SpeciesPhoto], selection: SpeciesPhoto.ID) {
        guard let presenter = topViewController() else { return }
        let viewer = FullScreenPhotoViewer(photos: photos, selection: selection) { [weak presenter] animated in
            presenter?.dismiss(animated: animated)
        }
        let host = UIHostingController(rootView: viewer)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.modalPresentationCapturesStatusBarAppearance = true
        presenter.present(host, animated: true)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(photos) { photo in
                ZoomablePhoto(
                    fileName: photo.fileName,
                    caption: photo.caption,
                    onDragChanged: { isDragging = $0 },
                    // The photo has already left the screen; a second fade would only delay.
                    onDismiss: { close(false) }
                )
                .ignoresSafeArea()
                .tag(photo.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .overlay(alignment: .bottom) {
            if let photo = photos.first(where: { $0.id == selection }) {
                captionPanel(photo)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .statusBarHidden()
        // A drag that reaches the bottom edge would otherwise be taken by the home indicator,
        // cancelling it mid-flight.
        .defersSystemGestures(on: .bottom)
    }

    private var closeButton: some View {
        Button {
            close(true)
        } label: {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.all, .small)
                .background(.black.opacity(0.5), in: Circle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("photoViewer.close")
        .padding(.all, .medium)
        .opacity(isDragging ? 0 : 1)
    }

    private func captionPanel(_ photo: SpeciesPhoto) -> some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            Text(photo.caption)
                .font(.callout)
            Text(photo.credit)
                .font(.caption)
                .italic()
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, .medium)
        // Clear of the page dots, which sit at the very bottom.
        .padding(.bottom, .large)
        .background(.black.opacity(0.5))
        .allowsHitTesting(false)
        .opacity(isDragging ? 0 : 1)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// One photo that pinches, double-taps and pans like Photos. A `UIScrollView`, because its
/// zooming already does what people expect — focal-point pinch, bounce at the limits, pan
/// only while zoomed — and at fit-to-screen it has nothing to scroll, so a horizontal swipe
/// still reaches the pager.
private struct ZoomablePhoto: UIViewRepresentable {
    let fileName: String
    let caption: String
    let onDragChanged: (Bool) -> Void
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> ZoomingImageView {
        let view = ZoomingImageView(
            image: BundledPhoto.image(named: fileName, maxPixelSize: Layout.fullScreenPhotoDecodePixelSize)
        )
        view.imageView.accessibilityLabel = caption
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: ZoomingImageView, context: Context) {
        view.onDragChanged = onDragChanged
        view.onDismiss = onDismiss
    }
}

private final class ZoomingImageView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()
    var onDragChanged: ((Bool) -> Void)?
    var onDismiss: (() -> Void)?
    private lazy var dismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragToDismiss(_:)))

    /// How far, in points, the photo must be dragged before letting go closes it.
    private static let dismissDistance: CGFloat = 120
    /// A flick this fast, in points per second, closes it from any distance.
    private static let dismissVelocity: CGFloat = 1000

    init(image: UIImage?) {
        super.init(frame: .zero)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        addSubview(imageView)
        // The viewer's backdrop is this view's own colour, so dragging can fade it frame by
        // frame without touching SwiftUI state.
        backgroundColor = .black

        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = Layout.fullScreenPhotoMaximumZoom
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        addGestureRecognizer(dismissPan)
        // When the dismiss pan declines — zoomed in, or a sideways swipe for the pager — it
        // fails at once and the scroll view's own pan takes over.
        panGestureRecognizer.require(toFail: dismissPan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: Zooming

    /// At fit-to-screen the image view is sized to the photo's aspect, not the screen's, so a
    /// zoomed photo pans to its own edges rather than into letterboxing.
    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == minimumZoomScale, let size = imageView.image?.size, size.width > 0, size.height > 0 {
            let fit = min(bounds.width / size.width, bounds.height / size.height)
            let fitted = CGSize(width: size.width * fit, height: size.height * fit)
            if imageView.bounds.size != fitted {
                imageView.frame = CGRect(origin: .zero, size: fitted)
                contentSize = fitted
            }
        }
        centre()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centre()
    }

    /// Keeps a photo smaller than the screen in the middle of it, at any zoom.
    private func centre() {
        let horizontal = max(0, (bounds.width - imageView.frame.width) / 2)
        let vertical = max(0, (bounds.height - imageView.frame.height) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// Double-tap zooms into the point tapped, and back out again from anywhere.
    @objc private func toggleZoom(_ gesture: UITapGestureRecognizer) {
        guard zoomScale == minimumZoomScale else {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let scale = maximumZoomScale / 2
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        let target = CGRect(
            origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
            size: size
        )
        zoom(to: target, animated: true)
    }

    // MARK: Drag to dismiss

    /// Only a mostly-vertical drag at fit-to-screen closes the photo. Zoomed in, the same drag
    /// is panning around the photo.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = dismissPan.velocity(in: self)
        return zoomScale == minimumZoomScale && abs(velocity.y) > abs(velocity.x)
    }

    @objc private func dragToDismiss(_ gesture: UIPanGestureRecognizer) {
        let offset = gesture.translation(in: self).y
        let velocity = gesture.velocity(in: self).y
        switch gesture.state {
        case .began:
            onDragChanged?(true)
        case .changed:
            follow(offset)
        // A cancel is judged like a release: the system cancels a drag that runs off the
        // screen, which is exactly the drag that should close the photo.
        case .ended, .cancelled:
            if abs(velocity) > Self.dismissVelocity {
                flyOff(from: offset, down: velocity > 0)
            } else if abs(offset) > Self.dismissDistance {
                flyOff(from: offset, down: offset > 0)
            } else {
                springBack()
            }
        default:
            break
        }
    }

    /// Moves the photo by transform, so `layoutSubviews` keeps its fitted size, and fades the
    /// backdrop as it goes so the species page shows through.
    private func follow(_ offset: CGFloat) {
        imageView.transform = CGAffineTransform(translationX: 0, y: offset)
        backgroundColor = .black.withAlphaComponent(1 - min(1, abs(offset) / (2 * Self.dismissDistance)))
    }

    /// Carries on from where the finger let go, a full screen further the way it was heading,
    /// so the photo never doubles back on its way out.
    private func flyOff(from offset: CGFloat, down: Bool) {
        let exit = offset + (down ? bounds.height : -bounds.height)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.follow(exit)
        } completion: { _ in
            self.onDismiss?()
        }
    }

    private func springBack() {
        onDragChanged?(false)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.follow(0)
        }
    }
}

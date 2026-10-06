import SwiftUI

extension View {
    /// The look of the app's own boxes, such as the question box and the site list, to sit with the stats cards: the
    /// cards' background in `shape`, with a hairline border.
    func boxStyle(_ shape: some InsettableShape) -> some View {
        background(Constants.Colors.secondaryBackground, in: shape)
            .overlay(shape.stroke(Color(.opaqueSeparator), lineWidth: 0.5))
    }
}

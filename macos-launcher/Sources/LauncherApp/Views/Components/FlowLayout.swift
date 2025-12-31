import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = DesignTokens.Spacing.small
    var rowSpacing: CGFloat = DesignTokens.Spacing.small

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: proposal.height))
            let proposedWidth = currentRowWidth == 0 ? size.width : currentRowWidth + spacing + size.width

            if proposedWidth > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + rowSpacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = proposedWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        maxRowWidth = max(maxRowWidth, currentRowWidth)
        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var xPos = bounds.minX
        var yPos = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: proposal.height))
            if xPos + size.width > bounds.maxX, xPos > bounds.minX {
                xPos = bounds.minX
                yPos += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: xPos, y: yPos),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )

            xPos += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

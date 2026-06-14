//
//  RangeSliderView.swift
//  TK8
//

import SwiftUI

struct RangeSliderView: View {
    @Binding private var lowerValue: Int
    @Binding private var upperValue: Int

    private let bounds: ClosedRange<Int>
    private let accent: Color
    private let valueFormatter: (Int) -> String

    init(
        lowerValue: Binding<Int>,
        upperValue: Binding<Int>,
        bounds: ClosedRange<Int>,
        accent: Color,
        valueFormatter: @escaping (Int) -> String = { "\($0)" }
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
        self.accent = accent
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        GeometryReader { proxy in
            let thumbDiameter: CGFloat = 26
            let trackHeight: CGFloat = 5
            let availableWidth = max(1, proxy.size.width - thumbDiameter)
            let lowerX = xPosition(for: lowerValue, width: availableWidth, thumbDiameter: thumbDiameter)
            let upperX = xPosition(for: upperValue, width: availableWidth, thumbDiameter: thumbDiameter)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.10))
                    .frame(width: availableWidth, height: trackHeight)
                    .offset(x: thumbDiameter / 2)

                Capsule()
                    .fill(accent)
                    .frame(width: max(0, upperX - lowerX), height: trackHeight)
                    .offset(x: lowerX)

                thumb
                    .offset(x: lowerX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let value = value(
                                    at: gesture.location.x,
                                    width: availableWidth,
                                    thumbDiameter: thumbDiameter
                                )
                                lowerValue = min(value, upperValue)
                            }
                    )
                    .accessibilityLabel("Minimum Frame".localized())
                    .accessibilityValue(valueFormatter(lowerValue))

                thumb
                    .offset(x: upperX - thumbDiameter / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let value = value(
                                    at: gesture.location.x,
                                    width: availableWidth,
                                    thumbDiameter: thumbDiameter
                                )
                                upperValue = max(value, lowerValue)
                            }
                    )
                    .accessibilityLabel("Maximum Frame".localized())
                    .accessibilityValue(valueFormatter(upperValue))
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .frame(height: 36)
    }

    private var thumb: some View {
        Circle()
            .fill(Color(red: 0.10, green: 0.14, blue: 0.20))
            .frame(width: 26, height: 26)
            .overlay(
                Circle()
                    .stroke(accent, lineWidth: 3)
            )
            .shadow(color: accent.opacity(0.28), radius: 8, y: 4)
    }

    private func xPosition(for value: Int, width: CGFloat, thumbDiameter: CGFloat) -> CGFloat {
        let span = max(1, bounds.upperBound - bounds.lowerBound)
        let clampedValue = min(max(value, bounds.lowerBound), bounds.upperBound)
        let ratio = CGFloat(clampedValue - bounds.lowerBound) / CGFloat(span)
        return thumbDiameter / 2 + ratio * width
    }

    private func value(at xPosition: CGFloat, width: CGFloat, thumbDiameter: CGFloat) -> Int {
        let ratio = min(max((xPosition - thumbDiameter / 2) / width, 0), 1)
        let span = bounds.upperBound - bounds.lowerBound
        return bounds.lowerBound + Int((ratio * CGFloat(span)).rounded())
    }
}

#Preview {
    RangeSliderPreview()
}

private struct RangeSliderPreview: View {
    @State private var lowerValue = -14
    @State private var upperValue = -10

    var body: some View {
        RangeSliderView(
            lowerValue: $lowerValue,
            upperValue: $upperValue,
            bounds: -40...30,
            accent: .red
        )
        .padding()
        .background(.black)
    }
}

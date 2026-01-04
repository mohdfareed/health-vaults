import Foundation
import SwiftUI

/// A concise circular progress ring with an optional threshold marker.
struct ProgressRing: View {
    let value: Double  // Total value representing 100%
    let progress: Double  // Current progress
    let threshold: Double?  // Optional threshold value
    let color: Color  // Progress color
    let thresholdColor: Color  // Threshold marker color
    let icon: Image?  // Optional center icon

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = size * 0.15
            let maxScale = max(value, threshold ?? value)
            let progressTrim = CGFloat(min(max(progress / maxScale, 0), 1))
            let thresholdTrim = CGFloat(min(max((threshold ?? 0) / maxScale, 0), 1))

            ZStack {
                // Background circle
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .foregroundColor(color.opacity(0.1))

                // Progress arc
                Circle()
                    .trim(from: 0, to: progressTrim)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .foregroundColor(progressTrim >= 1 ? .red : color)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: progress)

                // Threshold marker dot with background erase
                if threshold != nil {
                    // Determine marker position: if threshold exceeds value, mark the 'value' point
                    let markerTrim: CGFloat =
                        (threshold! > value)
                        ? CGFloat(min(max(value / maxScale, 0), 1))
                        : thresholdTrim
                    // Compute position along the ring
                    let angle = markerTrim * 360 - 90
                    let radius = size / 2
                    let x = cos(angle * .pi / 180) * radius + size / 2
                    let y = sin(angle * .pi / 180) * radius + size / 2

                    // Erase underlying ring behind the dot using adaptive color
                    Circle()
                        .fill(eraserColor)
                        .frame(width: lineWidth * 1.4, height: lineWidth * 1.4)
                        .position(x: x, y: y)

                    Circle()  // Draw the threshold dot
                        .fill(thresholdColor)
                        .frame(width: lineWidth, height: lineWidth)
                        .position(x: x, y: y)
                }

                // Center icon
                if let icon = icon {
                    icon
                        .symbolVariant(.fill)
                        .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Adaptive eraser color that works in both app and widget contexts.
    private var eraserColor: Color {
        // Use explicit colors instead of semantic `.background` which
        // doesn't work correctly in widget container backgrounds
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
}

// MARK: - Previews
#Preview {
    VStack(spacing: 20) {
        ProgressRing(
            value: 1000,
            progress: 999,
            threshold: 1500,
            color: .blue,
            thresholdColor: .green,
            icon: Image(systemName: "flame.fill")
        )
        ProgressRing(
            value: 1000,
            progress: 500,
            threshold: 750,
            color: .pink,
            thresholdColor: .red,
            icon: Image(systemName: "flame.fill")
        )
        ProgressRing(
            value: 1000,
            progress: 800,
            threshold: 750,
            color: .purple,
            thresholdColor: .red,
            icon: Image(systemName: "flame.fill")
        )
        ProgressRing(
            value: 1000,
            progress: 250,
            threshold: 50,
            color: .indigo,
            thresholdColor: .red,
            icon: Image(systemName: "flame.fill")
        )
    }
    .padding()
}

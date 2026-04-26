import CoreGraphics
import Foundation

// MARK: - Gesture Result

enum GestureResult {
    case tap(GridPosition)
    case swipe(fromKey: GridPosition, direction: SwipeDirection)
    case swipeBack(fromKey: GridPosition, direction: SwipeDirection) // uppercase variant
    case circle(GridPosition) // uppercase of tap char
    case specialSwipe(SpecialSwipe)
    case none

    enum SpecialSwipe {
        case spaceSwipeUp          // toggle symbols
        case spaceSwipeUpAndBack   // toggle center labels
        case globeSwipeLeft        // toggle full width
        case globeSwipeRight       // toggle full width
        case globeSwipeUp          // increase size
        case globeSwipeDown        // decrease size
        case globeCircle           // move command bar
    }
}

// MARK: - Gesture Engine

class GestureEngine {
    private(set) var points: [CGPoint] = []
    private var keyRegions: [GridPosition: CGRect] = [:]
    private var spaceBarRegion: CGRect = .zero
    private var globeRegion: CGRect = .zero

    var hasActiveGesture: Bool { !points.isEmpty }

    // Thresholds
    private let tapDistanceThreshold: CGFloat = 15.0
    private let minSwipeDistance: CGFloat = 20.0
    private let subcellActivationDistance: CGFloat = 12.0

    // MARK: - Setup

    func updateKeyRegions(_ regions: [GridPosition: CGRect]) {
        self.keyRegions = regions
    }

    func updateSpaceBarRegion(_ region: CGRect) {
        self.spaceBarRegion = region
    }

    func updateGlobeRegion(_ region: CGRect) {
        self.globeRegion = region
    }

    // MARK: - Touch Tracking

    func touchBegan(at point: CGPoint) {
        points = [point]
    }

    func touchMoved(to point: CGPoint) {
        points.append(point)
    }

    func touchEnded(at point: CGPoint) -> GestureResult {
        points.append(point)
        let result = analyzeGesture()
        points.removeAll()
        return result
    }

    func touchCancelled() {
        points.removeAll()
    }

    // MARK: - Analysis

    private func analyzeGesture() -> GestureResult {
        guard let start = points.first, let end = points.last else {
            return .none
        }

        // Check special regions first
        if spaceBarRegion.contains(start) {
            return analyzeSpaceBarGesture()
        }
        if globeRegion.contains(start) {
            return analyzeGlobeGesture()
        }

        guard let startKey = keyAt(start) else { return .none }

        let totalDistance = distance(start, end)
        let maxDistance = maxDistance(from: start)

        // Simple tap: minimal movement
        if totalDistance < tapDistanceThreshold && maxDistance < tapDistanceThreshold {
            return .tap(startKey)
        }

        let endKey = keyAt(end)
        let subcellDirection = firstSubcellDirection(from: startKey)

        // Finger returned to the same key: resolve against the 3x3 subcells.
        if endKey == startKey {
            if isCircularMotion() {
                return .circle(startKey)
            }
            if let direction = subcellDirection {
                if didReturnTowardStart(from: start, to: end, key: startKey) {
                    return .swipeBack(fromKey: startKey, direction: direction)
                }
                return .swipe(fromKey: startKey, direction: direction)
            }
            return .tap(startKey)
        }

        if let direction = subcellDirection {
            return .swipe(fromKey: startKey, direction: direction)
        }

        // Finger ended on a different key: prefer the destination key's grid
        // direction so slightly off-center starts still resolve cleanly.
        let direction = endKey.flatMap { gridDirection(from: startKey, to: $0) }
            ?? peakSwipeDirection(from: startKey)
        return .swipe(fromKey: startKey, direction: direction)
    }

    // MARK: - Special Gesture Analysis

    private func analyzeSpaceBarGesture() -> GestureResult {
        guard let start = points.first, let end = points.last else { return .none }

        let dy = end.y - start.y
        let totalDist = distance(start, end)

        if totalDist < tapDistanceThreshold {
            // Tap on spacebar
            return .tap(GridPosition(row: 3, col: 0)) // spacebar position
        }

        // Check for swipe up and back. Use the spacebar bounds instead of
        // exact start/end distance so a natural return still counts.
        let cameBack = spaceBarRegion.insetBy(dx: -12, dy: -12).contains(end) && hasUpwardExcursion()
        if cameBack {
            return .specialSwipe(.spaceSwipeUpAndBack)
        }

        if dy < -minSwipeDistance {
            return .specialSwipe(.spaceSwipeUp)
        }

        return .tap(GridPosition(row: 3, col: 0))
    }

    private func analyzeGlobeGesture() -> GestureResult {
        guard let start = points.first, let end = points.last else { return .none }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let totalDist = distance(start, end)

        if totalDist < tapDistanceThreshold {
            return .tap(GridPosition(row: 0, col: 3)) // globe position
        }

        // Check for circle
        if isCircularMotion() {
            return .specialSwipe(.globeCircle)
        }

        // Directional swipes
        if abs(dx) > abs(dy) {
            if dx > minSwipeDistance {
                return .specialSwipe(.globeSwipeRight)
            } else if dx < -minSwipeDistance {
                return .specialSwipe(.globeSwipeLeft)
            }
        } else {
            if dy < -minSwipeDistance {
                return .specialSwipe(.globeSwipeUp)
            } else if dy > minSwipeDistance {
                return .specialSwipe(.globeSwipeDown)
            }
        }

        return .none
    }

    // MARK: - Helper: Find key at point

    private func keyAt(_ point: CGPoint) -> GridPosition? {
        for (pos, rect) in keyRegions {
            if rect.contains(point) {
                return pos
            }
        }
        return nil
    }

    // MARK: - Helper: Peak swipe direction

    private func peakSwipeDirection(from key: GridPosition) -> SwipeDirection {
        guard let region = keyRegions[key] else { return .top }
        let center = CGPoint(x: region.midX, y: region.midY)

        // Find the point furthest from the key center
        var maxDist: CGFloat = 0
        var peakPoint = center

        for point in points {
            let d = distance(point, center)
            if d > maxDist {
                maxDist = d
                peakPoint = point
            }
        }

        let angle = atan2(-(peakPoint.y - center.y), peakPoint.x - center.x)
        return SwipeDirection.fromAngle(Double(angle))
    }

    private func gridDirection(from start: GridPosition, to end: GridPosition) -> SwipeDirection? {
        let row = max(-1, min(1, end.row - start.row))
        let col = max(-1, min(1, end.col - start.col))

        switch (row, col) {
        case (-1, -1): return .topLeft
        case (-1, 0):  return .top
        case (-1, 1):  return .topRight
        case (0, -1):  return .left
        case (0, 1):   return .right
        case (1, -1):  return .bottomLeft
        case (1, 0):   return .bottom
        case (1, 1):   return .bottomRight
        default:       return nil
        }
    }

    private func firstSubcellDirection(from key: GridPosition) -> SwipeDirection? {
        guard let region = keyRegions[key], let start = points.first else { return nil }
        let center = CGPoint(x: region.midX, y: region.midY)

        for point in points.dropFirst() {
            guard distance(start, point) >= subcellActivationDistance ||
                    distance(center, point) >= min(region.width, region.height) * 0.22 else {
                continue
            }

            if let direction = subcellDirection(for: point, in: region) {
                return direction
            }
            if !region.contains(point) {
                return subcellDirection(
                    for: CGPoint(
                        x: min(max(point.x, region.minX), region.maxX),
                        y: min(max(point.y, region.minY), region.maxY)
                    ),
                    in: region
                )
            }
        }
        return nil
    }

    private func subcellDirection(for point: CGPoint, in region: CGRect) -> SwipeDirection? {
        guard region.width > 0, region.height > 0 else { return nil }

        let normalizedX = min(max((point.x - region.minX) / region.width, 0), 0.999)
        let normalizedY = min(max((point.y - region.minY) / region.height, 0), 0.999)
        let col = Int(normalizedX * 3)
        let row = Int(normalizedY * 3)

        switch (row, col) {
        case (0, 0): return .topLeft
        case (0, 1): return .top
        case (0, 2): return .topRight
        case (1, 0): return .left
        case (1, 2): return .right
        case (2, 0): return .bottomLeft
        case (2, 1): return .bottom
        case (2, 2): return .bottomRight
        default:     return nil
        }
    }

    private func didReturnTowardStart(from start: CGPoint, to end: CGPoint, key: GridPosition) -> Bool {
        guard let region = keyRegions[key] else { return false }
        let centerBox = CGRect(
            x: region.minX + region.width / 3,
            y: region.minY + region.height / 3,
            width: region.width / 3,
            height: region.height / 3
        ).insetBy(dx: -10, dy: -10)

        return distance(start, end) <= max(tapDistanceThreshold * 2, min(region.width, region.height) * 0.28) ||
            centerBox.contains(end)
    }

    // MARK: - Helper: Circle detection

    private func isCircularMotion() -> Bool {
        guard points.count >= 10 else { return false }

        // Compute total turning angle using cross products
        var totalAngle: Double = 0

        let step = max(1, points.count / 20) // Sample ~20 points
        var sampledPoints: [CGPoint] = []
        for i in stride(from: 0, to: points.count, by: step) {
            sampledPoints.append(points[i])
        }
        if let last = points.last, sampledPoints.last != last {
            sampledPoints.append(last)
        }

        guard sampledPoints.count >= 4 else { return false }

        for i in 1..<(sampledPoints.count - 1) {
            let prev = sampledPoints[i - 1]
            let curr = sampledPoints[i]
            let next = sampledPoints[i + 1]

            let v1x = Double(curr.x - prev.x)
            let v1y = Double(curr.y - prev.y)
            let v2x = Double(next.x - curr.x)
            let v2y = Double(next.y - curr.y)

            let cross = v1x * v2y - v1y * v2x
            let dot = v1x * v2x + v1y * v2y
            let angle = atan2(cross, dot)
            totalAngle += angle
        }

        // A full circle has total turning angle of ~2π (or ~-2π)
        return abs(totalAngle) > 1.5 * .pi
    }

    // MARK: - Helper: Vertical excursion detection

    private func hasUpwardExcursion() -> Bool {
        guard let start = points.first else { return false }
        let threshold: CGFloat = 30
        for point in points {
            if start.y - point.y > threshold {
                return true
            }
        }
        return false
    }

    // MARK: - Helper: Distance

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    private func maxDistance(from start: CGPoint) -> CGFloat {
        points.map { distance(start, $0) }.max() ?? 0
    }
}

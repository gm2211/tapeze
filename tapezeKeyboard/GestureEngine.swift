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
        case keyboardSpace         // long horizontal stroke across three keys
        case keyboardBackspace     // long vertical stroke across three keys
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
    private var resizeRegion: CGRect = .zero
    private var forgivingCommandRegions: [GridPosition: CGRect] = [:]

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

    func updateResizeRegion(_ region: CGRect) {
        self.resizeRegion = region
    }

    func updateForgivingCommandRegions(_ regions: [GridPosition: CGRect]) {
        forgivingCommandRegions = regions
    }

    func keyPosition(at point: CGPoint) -> GridPosition? {
        keyAt(point)
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
        if !spaceBarRegion.isEmpty && spaceBarRegion.contains(start) {
            return analyzeSpaceBarGesture()
        }
        if !globeRegion.isEmpty && globeRegion.contains(start) {
            return analyzeGlobeGesture()
        }
        if !resizeRegion.isEmpty && resizeRegion.contains(start) {
            return analyzeResizeGesture()
        }

        // These diamonds sit between four character keys. Give stationary
        // thumb taps a larger target, while leaving all swipe ownership alone.
        if let commandPosition = forgivingCommandTap(from: start, to: end) {
            return .tap(commandPosition)
        }

        if let chordGesture = analyzeKeyboardChordGesture() {
            return .specialSwipe(chordGesture)
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
            if let region = keyRegions[startKey], isCircularMotion(in: region) {
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

        // Check for swipe up and back. Use the spacebar bounds instead of
        // exact start/end distance so a straight there-and-back path still
        // counts even when it lands close enough to look like a tap.
        let cameBack = spaceBarRegion.insetBy(dx: -12, dy: -12).contains(end) && hasUpwardExcursion()
        if cameBack {
            return .specialSwipe(.spaceSwipeUpAndBack)
        }

        if totalDist < tapDistanceThreshold {
            // Tap on spacebar
            return .tap(GridPosition(row: 3, col: 0)) // spacebar position
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

        // Check for circle before tap: a good loop often ends near its start.
        if isCircularMotion(in: globeRegion) || isClosedLoopGesture(in: globeRegion) {
            return .specialSwipe(.globeCircle)
        }

        if let horizontalToggle = globeBackAndForthSwipe(from: start, to: end) {
            return .specialSwipe(horizontalToggle)
        }

        if totalDist < tapDistanceThreshold {
            return .tap(GridPosition(row: 0, col: 3)) // globe position
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

    private func analyzeResizeGesture() -> GestureResult {
        guard let start = points.first, let end = points.last else { return .none }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let totalDist = distance(start, end)

        if let horizontalToggle = resizeBackAndForthSwipe(from: start, to: end) {
            return .specialSwipe(horizontalToggle)
        }

        if totalDist < tapDistanceThreshold {
            return .tap(GridPosition(row: 3, col: 3))
        }

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

        return .tap(GridPosition(row: 3, col: 3))
    }

    private func analyzeKeyboardChordGesture() -> GestureResult.SpecialSwipe? {
        guard points.count >= 2,
              let start = points.first,
              let end = points.last else { return nil }

        let bounds = pathBounds()
        let dx = end.x - start.x
        let dy = end.y - start.y
        let crossed = crossedMainGridKeys()
        let horizontalThreshold = averageMainKeyWidth() * 2.15
        let verticalThreshold = averageMainKeyHeight() * 2.15

        if abs(dx) >= horizontalThreshold,
           bounds.width >= horizontalThreshold,
           bounds.width > bounds.height * 1.35 {
            for row in 0..<3 {
                let cols = Set(crossed.filter { $0.row == row }.map(\.col))
                if cols == Set(0..<3) {
                    return .keyboardSpace
                }
            }
        }

        if abs(dy) >= verticalThreshold,
           bounds.height >= verticalThreshold,
           bounds.height > bounds.width * 1.35 {
            for col in 0..<3 {
                let rows = Set(crossed.filter { $0.col == col }.map(\.row))
                if rows == Set(0..<3) {
                    return .keyboardBackspace
                }
            }
        }

        return nil
    }

    private func resizeBackAndForthSwipe(from start: CGPoint, to end: CGPoint) -> GestureResult.SpecialSwipe? {
        guard points.count >= 4 else { return nil }

        var maxLeft: CGFloat = 0
        var maxRight: CGFloat = 0
        var maxVertical: CGFloat = 0

        for point in points {
            let dx = point.x - start.x
            maxLeft = max(maxLeft, -dx)
            maxRight = max(maxRight, dx)
            maxVertical = max(maxVertical, abs(point.y - start.y))
        }

        let horizontalExcursion = max(maxLeft, maxRight)
        let returnedNearStart = distance(start, end) <= max(tapDistanceThreshold * 2, min(resizeRegion.width, resizeRegion.height) * 0.35)

        guard returnedNearStart,
              horizontalExcursion > minSwipeDistance,
              horizontalExcursion > maxVertical * 1.35 else {
            return nil
        }

        return maxRight >= maxLeft ? .globeSwipeRight : .globeSwipeLeft
    }

    private func globeBackAndForthSwipe(from start: CGPoint, to end: CGPoint) -> GestureResult.SpecialSwipe? {
        guard points.count >= 4 else { return nil }

        var maxLeft: CGFloat = 0
        var maxRight: CGFloat = 0
        var maxVertical: CGFloat = 0

        for point in points {
            let dx = point.x - start.x
            maxLeft = max(maxLeft, -dx)
            maxRight = max(maxRight, dx)
            maxVertical = max(maxVertical, abs(point.y - start.y))
        }

        let horizontalExcursion = max(maxLeft, maxRight)
        let returnedNearStart = distance(start, end) <= max(tapDistanceThreshold * 2, min(globeRegion.width, globeRegion.height) * 0.35)

        guard returnedNearStart,
              horizontalExcursion > minSwipeDistance,
              horizontalExcursion > maxVertical * 1.35 else {
            return nil
        }

        return maxRight >= maxLeft ? .globeSwipeRight : .globeSwipeLeft
    }

    // MARK: - Helper: Find key at point

    private func keyAt(_ point: CGPoint) -> GridPosition? {
        let candidates = keyRegions.filter { pos, rect in
            guard rect.contains(point) else { return false }
            guard isCommandDiamond(pos) else { return true }
            return diamondContains(point, in: rect)
        }

        // If the point sits well inside a command diamond's center, the
        // user is aiming at the diamond (globe / abc / shift / enter), not
        // the surrounding letter cells — diamond wins.
        let diamondHit = candidates
            .filter { isCommandDiamond($0.key) }
            .min { lhs, rhs in
                distanceToCenter(point, lhs.value) < distanceToCenter(point, rhs.value)
            }
        if let diamond = diamondHit,
           isPointDeepInsideDiamond(point, rect: diamond.value) {
            return diamond.key
        }

        return candidates.sorted { lhs, rhs in
            let leftPriority = hitPriority(for: lhs.key)
            let rightPriority = hitPriority(for: rhs.key)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return area(lhs.value) < area(rhs.value)
        }.first?.key
    }

    private func distanceToCenter(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return sqrt(dx * dx + dy * dy)
    }

    private func isPointDeepInsideDiamond(_ point: CGPoint, rect: CGRect) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let normalizedX = abs(point.x - rect.midX) / (rect.width / 2)
        let normalizedY = abs(point.y - rect.midY) / (rect.height / 2)
        // Inner 75% of the diamond — clearly aimed at the command.
        return normalizedX + normalizedY <= 0.75
    }

    private func hitPriority(for pos: GridPosition) -> Int {
        // Lower number = higher priority (wins the hit test).
        // Letter/main-grid cells: 0 (highest) — they win over diamonds when overlapping.
        // Backspace column (row 2): 1 — above-keyboard column commands.
        // Diamond command keys (globe, 123, enter, shift): 2 (lowest) — only fire if no letter cell hit.
        guard isCommandPosition(pos) else { return 0 }
        return pos.row == 2 ? 1 : 2
    }

    private func isCommandPosition(_ pos: GridPosition) -> Bool {
        pos.col == 3 || pos.col == -1
    }

    private func isMainGridPosition(_ pos: GridPosition) -> Bool {
        (0..<3).contains(pos.row) && (0..<3).contains(pos.col)
    }

    private func isCommandDiamond(_ pos: GridPosition) -> Bool {
        isCommandPosition(pos) && pos.row != 2
    }

    private func diamondContains(_ point: CGPoint, in rect: CGRect) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let normalizedX = abs(point.x - rect.midX) / (rect.width / 2)
        let normalizedY = abs(point.y - rect.midY) / (rect.height / 2)
        return normalizedX + normalizedY <= 1.08
    }

    private func forgivingCommandTap(from start: CGPoint, to end: CGPoint) -> GridPosition? {
        let movementLimit = tapDistanceThreshold * 1.35
        guard distance(start, end) <= movementLimit,
              maxDistance(from: start) <= movementLimit else {
            return nil
        }

        return forgivingCommandRegions
            .filter { _, region in
                diamondContains(start, in: region) && diamondContains(end, in: region)
            }
            .min { lhs, rhs in
                distanceToCenter(start, lhs.value) < distanceToCenter(start, rhs.value)
            }?
            .key
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }

    private func crossedMainGridKeys() -> Set<GridPosition> {
        let mainRegions = keyRegions.filter { isMainGridPosition($0.key) }
        guard !mainRegions.isEmpty else { return [] }

        var crossed = Set<GridPosition>()
        let expandedRegions = mainRegions.mapValues { $0.insetBy(dx: -8, dy: -8) }

        for point in points {
            for (pos, rect) in expandedRegions where rect.contains(point) {
                crossed.insert(pos)
            }
        }

        guard points.count >= 2 else { return crossed }

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            for (pos, rect) in expandedRegions where segmentIntersectsRect(from: start, to: end, rect: rect) {
                crossed.insert(pos)
            }
        }

        return crossed
    }

    private func averageMainKeyWidth() -> CGFloat {
        let widths = keyRegions.filter { isMainGridPosition($0.key) }.map(\.value.width)
        guard !widths.isEmpty else { return minSwipeDistance * 3 }
        return widths.reduce(0, +) / CGFloat(widths.count)
    }

    private func averageMainKeyHeight() -> CGFloat {
        let heights = keyRegions.filter { isMainGridPosition($0.key) }.map(\.value.height)
        guard !heights.isEmpty else { return minSwipeDistance * 3 }
        return heights.reduce(0, +) / CGFloat(heights.count)
    }

    private func segmentIntersectsRect(from start: CGPoint, to end: CGPoint, rect: CGRect) -> Bool {
        if rect.contains(start) || rect.contains(end) {
            return true
        }

        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]

        for index in corners.indices {
            let next = corners[(index + 1) % corners.count]
            if segmentsIntersect(start, end, corners[index], next) {
                return true
            }
        }

        return false
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        let d1 = orientation(p1, p2, q1)
        let d2 = orientation(p1, p2, q2)
        let d3 = orientation(q1, q2, p1)
        let d4 = orientation(q1, q2, p2)

        return d1 * d2 <= 0 && d3 * d4 <= 0
    }

    private func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
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
        let activation = max(subcellActivationDistance, min(region.width, region.height) * 0.18)

        var farthestPoint: CGPoint?
        var farthestDistance: CGFloat = 0

        for point in points.dropFirst() {
            let outwardDistance = distance(center, point)
            guard outwardDistance >= activation || distance(start, point) >= activation else {
                continue
            }

            if outwardDistance > farthestDistance {
                farthestDistance = outwardDistance
                farthestPoint = point
            }
        }

        guard let point = farthestPoint else { return nil }

        // Use angle from key center to the peak excursion point.
        // This is more robust than subcell-clamping when the finger curves
        // back toward the center or overshoots past the key edge.
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        // Convert to math-style angle (y up positive).
        let angle = atan2(-dy, dx)
        return SwipeDirection.fromAngle(angle)
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

    private func isCircularMotion(in region: CGRect) -> Bool {
        guard points.count >= 8,
              region.width > 0,
              region.height > 0,
              let start = points.first,
              let end = points.last else { return false }

        let bounds = pathBounds()
        let pathWidth = bounds.width
        let pathHeight = bounds.height
        let minRegionSide = min(region.width, region.height)
        // Loosen loop size requirement so partial / squished loops still register.
        let minLoopSize = max(minRegionSide * 0.20, minSwipeDistance * 0.9)
        // Allow finger to land further from the start — partial circles often
        // don't close all the way back.
        let returnedNearStart = distance(start, end) <= max(tapDistanceThreshold * 2.2, minRegionSide * 0.45)

        guard returnedNearStart,
              pathWidth >= minLoopSize,
              pathHeight >= minLoopSize,
              pathLength() >= minRegionSide * 1.2 else {
            return false
        }

        var totalAngle: Double = 0
        let step = max(1, points.count / 20)
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

        // Accept open / partial loops (~260° and up).
        return abs(totalAngle) > 1.45 * .pi
    }

    private func isClosedLoopGesture(in region: CGRect) -> Bool {
        guard points.count >= 6, let start = points.first, let end = points.last else {
            return false
        }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return false
        }

        let pathWidth = maxX - minX
        let pathHeight = maxY - minY
        let minLoopSize = max(min(region.width, region.height) * 0.22, minSwipeDistance)
        let returnedNearStart = distance(start, end) <= max(tapDistanceThreshold * 2, min(region.width, region.height) * 0.32)

        return returnedNearStart && pathWidth >= minLoopSize && pathHeight >= minLoopSize
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

    private func pathBounds() -> CGRect {
        guard let first = points.first else { return .zero }

        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func pathLength() -> CGFloat {
        guard points.count >= 2 else { return 0 }

        var total: CGFloat = 0
        for index in 1..<points.count {
            total += distance(points[index - 1], points[index])
        }
        return total
    }

    private func maxDistance(from start: CGPoint) -> CGFloat {
        points.map { distance(start, $0) }.max() ?? 0
    }
}

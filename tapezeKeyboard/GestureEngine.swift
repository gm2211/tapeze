import CoreGraphics
import Foundation

// MARK: - Gesture Result

enum GestureResult {
    case tap(GridPosition)
    /// `reach` is how far the finger travelled from touchdown, normalized by the
    /// key's half-side: ~0.3 is a wobble off a tap, ~1.0 reaches the key edge.
    /// Callers use it to require extra commitment for unlabeled targets.
    case swipe(fromKey: GridPosition, direction: SwipeDirection, reach: CGFloat)
    case swipeBack(fromKey: GridPosition, direction: SwipeDirection, reach: CGFloat) // uppercase variant
    case circle(GridPosition) // uppercase of tap char
    case specialSwipe(SpecialSwipe)
    case none

    enum SpecialSwipe {
        case spaceSwipeUp          // toggle symbols
        case spaceSwipeUpAndBack   // toggle center labels
        case spaceCursorLeft       // move insertion point left
        case spaceCursorRight      // move insertion point right
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

        let startRegion = keyRegions[startKey]

        // Loops resolve before key ownership. A circle drawn on an edge or
        // corner key — the top-right "i" most of all — routinely bulges into a
        // neighbour or off the grid entirely, so the gesture belongs to the key
        // the finger touched down on, not wherever it happened to lift.
        if let region = startRegion, isCircularMotion(in: region) {
            return .circle(startKey)
        }

        let endKey = keyAt(end)
        let subcell = firstSubcellDirection(from: startKey)

        // A loop that fell short of a full turn is still a capital attempt, not
        // a reach for an unlabeled symbol. Reporting it as a swipe-back keeps it
        // on the uppercase path, which falls back to the key's own capital when
        // the direction carries no secondary letter.
        if let region = startRegion, isLoopLikeMotion(in: region) {
            let direction = subcell?.direction ?? peakSwipeDirection(from: startKey)
            let reach = subcell?.reach ?? normalizedReach(maxDistance, in: region)
            return .swipeBack(fromKey: startKey, direction: direction, reach: reach)
        }

        // Finger returned to the same key: resolve against the 3x3 subcells.
        if endKey == startKey {
            if let subcell {
                if didReturnTowardStart(from: start, to: end, key: startKey) {
                    return .swipeBack(fromKey: startKey, direction: subcell.direction, reach: subcell.reach)
                }
                return .swipe(fromKey: startKey, direction: subcell.direction, reach: subcell.reach)
            }
            return .tap(startKey)
        }

        if let subcell {
            return .swipe(fromKey: startKey, direction: subcell.direction, reach: subcell.reach)
        }

        // Finger ended on a different key: prefer the destination key's grid
        // direction so slightly off-center starts still resolve cleanly.
        let direction = endKey.flatMap { gridDirection(from: startKey, to: $0) }
            ?? peakSwipeDirection(from: startKey)
        // Crossing into a neighbouring key is itself a committed gesture.
        let crossKeyReach = keyRegions[startKey].map { normalizedReach(maxDistance, in: $0) } ?? 1
        return .swipe(fromKey: startKey, direction: direction, reach: crossKeyReach)
    }

    // MARK: - Special Gesture Analysis

    private func analyzeSpaceBarGesture() -> GestureResult {
        guard let start = points.first, let end = points.last else { return .none }

        let dx = end.x - start.x
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

        if abs(dx) >= minSwipeDistance, abs(dx) > abs(dy) * 1.2 {
            return .specialSwipe(dx < 0 ? .spaceCursorLeft : .spaceCursorRight)
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

    private func firstSubcellDirection(from key: GridPosition) -> (direction: SwipeDirection, reach: CGFloat)? {
        guard let region = keyRegions[key], let start = points.first else { return nil }
        let center = CGPoint(x: region.midX, y: region.midY)
        let activation = max(subcellActivationDistance, min(region.width, region.height) * 0.18)

        var farthestPoint: CGPoint?
        var farthestDistance: CGFloat = 0

        for point in points.dropFirst() {
            let travelDistance = distance(start, point)
            guard travelDistance >= activation else { continue }

            if travelDistance > farthestDistance {
                farthestDistance = travelDistance
                farthestPoint = point
            }
        }

        guard let point = farthestPoint else { return nil }

        // Require deliberate travel from touchdown, then resolve the target
        // from the key center so off-center starts do not skew corner swipes.
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        // Convert to math-style angle (y up positive).
        let angle = atan2(-dy, dx)
        return (SwipeDirection.fromAngle(angle), normalizedReach(farthestDistance, in: region))
    }

    /// Peak travel from touchdown expressed in key half-sides.
    private func normalizedReach(_ travel: CGFloat, in region: CGRect) -> CGFloat {
        let halfSide = min(region.width, region.height) / 2
        guard halfSide > 0 else { return 0 }
        return travel / halfSide
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
        let minSide = min(region.width, region.height)
        guard let peakIndex = points.indices.max(by: {
            distance(start, points[$0]) < distance(start, points[$1])
        }) else { return false }

        let peak = points[peakIndex]
        let outboundDistance = distance(start, peak)
        let endDistance = distance(start, end)
        let returnDistance = distance(peak, end)

        // Capital swipe-back must be a deliberate excursion followed by a real
        // retrace. This keeps quick taps with a small directional wobble from
        // becoming uppercase secondary letters.
        guard peakIndex < points.index(before: points.endIndex),
              outboundDistance >= max(minSwipeDistance * 1.4, minSide * 0.30),
              returnDistance >= outboundDistance * 0.55,
              endDistance <= max(tapDistanceThreshold * 1.35, outboundDistance * 0.42) else {
            return false
        }

        let outwardX = peak.x - start.x
        let outwardY = peak.y - start.y
        let returnX = end.x - peak.x
        let returnY = end.y - peak.y
        let denominator = max(outboundDistance * returnDistance, 0.001)
        let directionAgreement = (outwardX * returnX + outwardY * returnY) / denominator
        return directionAgreement <= -0.45
    }

    // MARK: - Helper: Circle detection

    /// Shape summary of the current path, measured against the key it started on.
    private struct LoopMetrics {
        /// Gap between touchdown and lift. A closed loop ends on top of its
        /// start; an arc the finger let go of early ends up to a diameter away.
        let endDistance: CGFloat
        let minRegionSide: CGFloat
        let hasLoopExtent: Bool
        let hasLoopLength: Bool
        /// Signed turning, in radians, accumulated along the sampled path.
        let totalTurn: Double
        /// How much of the turning went the same way; ~1 for a clean loop.
        let turnConsistency: Double
        /// Enclosed area over bounding-box area: ~0.79 for a circle, ~0 for a
        /// there-and-back retrace, which is what separates the two gestures
        /// when both cover the same ground and return to the same spot.
        let fillRatio: Double
    }

    private func loopMetrics(in region: CGRect) -> LoopMetrics? {
        guard points.count >= 6,
              region.width > 0,
              region.height > 0,
              let start = points.first,
              let end = points.last else { return nil }

        let bounds = pathBounds()
        let minRegionSide = min(region.width, region.height)
        let minLoopSize = max(minRegionSide * 0.24, minSwipeDistance)

        var totalAngle: Double = 0
        var totalAbsoluteAngle: Double = 0

        // Resample by distance travelled rather than by index. Touch samples
        // arrive faster than the finger moves, so evenly-indexed points on a
        // small loop sit a pixel or two apart and their headings are mostly
        // sensor noise — which is what used to make a perfectly good circle
        // read as inconsistent turning.
        let spacing = max(6, minRegionSide * 0.12)
        var sampledPoints: [CGPoint] = [start]
        for point in points.dropFirst() where distance(sampledPoints[sampledPoints.count - 1], point) >= spacing {
            sampledPoints.append(point)
        }
        if let last = sampledPoints.last,
           last != end,
           distance(last, end) >= spacing * 0.5 {
            sampledPoints.append(end)
        }

        guard sampledPoints.count >= 4 else { return nil }

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
            totalAbsoluteAngle += abs(angle)
        }

        let boundsArea = Double(bounds.width * bounds.height)
        let fillRatio = boundsArea > 0 ? enclosedArea() / boundsArea : 0

        return LoopMetrics(
            endDistance: distance(start, end),
            minRegionSide: minRegionSide,
            hasLoopExtent: bounds.width >= minLoopSize && bounds.height >= minLoopSize,
            hasLoopLength: pathLength() >= minRegionSide * 0.95,
            totalTurn: totalAngle,
            turnConsistency: abs(totalAngle) / max(totalAbsoluteAngle, 0.001),
            fillRatio: fillRatio
        )
    }

    private func isCircularMotion(in region: CGRect) -> Bool {
        guard let metrics = loopMetrics(in: region),
              metrics.hasLoopExtent,
              metrics.hasLoopLength else {
            return false
        }

        let turn = abs(metrics.totalTurn)
        let closedLoopGap = max(tapDistanceThreshold * 1.5, metrics.minRegionSide * 0.32)

        // A compact loop can arrive with only a handful of sampled points.
        // Require sustained turning in one direction so taps, hooks, and
        // there-and-back strokes cannot masquerade as center-key capitals.
        if metrics.endDistance <= closedLoopGap,
           turn > 1.25 * .pi,
           metrics.turnConsistency >= 0.72 {
            return true
        }

        // Circles on edge and corner keys get cut short — there is less room to
        // swing the finger, so the finger lifts before closing the ring and the
        // gap alone can be most of a diameter. Accept those on the strength of
        // the area they sweep: a retrace or a straight stroke encloses nothing,
        // so neither reaches this bar however far it travels.
        return metrics.endDistance <= max(tapDistanceThreshold * 2, metrics.minRegionSide * 0.75)
            && turn > 1.05 * .pi
            && metrics.turnConsistency >= 0.70
            && metrics.fillRatio >= 0.30
    }

    /// A rounded stroke that swept real area but stayed under the circle bar.
    /// Not enough to type a capital on its own, but enough to keep the gesture
    /// off the unlabeled-symbol path.
    private func isLoopLikeMotion(in region: CGRect) -> Bool {
        guard let metrics = loopMetrics(in: region),
              metrics.hasLoopExtent,
              metrics.endDistance <= max(tapDistanceThreshold * 2, metrics.minRegionSide * 0.75) else {
            return false
        }

        return abs(metrics.totalTurn) > 0.75 * .pi
            && metrics.turnConsistency >= 0.62
            && metrics.fillRatio >= 0.18
    }

    /// Shoelace area of the path, closed back to its first point. Coordinates
    /// are taken relative to touchdown: the terms then stay the size of the
    /// gesture rather than the size of the screen.
    private func enclosedArea() -> Double {
        guard points.count >= 3, let origin = points.first else { return 0 }

        var doubledArea: Double = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let x1 = Double(current.x - origin.x)
            let y1 = Double(current.y - origin.y)
            let x2 = Double(next.x - origin.x)
            let y2 = Double(next.y - origin.y)
            doubledArea += x1 * y2 - x2 * y1
        }
        return abs(doubledArea) / 2
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

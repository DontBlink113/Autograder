import Foundation
import PencilKit
import CoreGraphics

struct StrokeSampler {
    let pointsPerStroke: Int
    
    init(pointsPerStroke: Int = 50) {
        self.pointsPerStroke = pointsPerStroke
    }
    
    func samplePoints(from strokePath: PKStrokePath, startIndex: Int, endIndex: Int) -> [SampledPoint] {
        guard endIndex > startIndex else { return [] }
        
        let totalLength = calculateTotalLength(from: strokePath, startIndex: startIndex, endIndex: endIndex)
        guard totalLength > 0 else {
            let point = strokePath[startIndex]
            return [SampledPoint(x: point.location.x, y: point.location.y)]
        }
        
        let segmentLength = totalLength / CGFloat(pointsPerStroke - 1)
        var sampledPoints: [SampledPoint] = []
        
        let firstPoint = strokePath[startIndex]
        sampledPoints.append(SampledPoint(x: firstPoint.location.x, y: firstPoint.location.y))
        
        var accumulatedDistance: CGFloat = 0
        var targetDistance = segmentLength
        var lastPoint = firstPoint.location
        
        for i in (startIndex + 1)...endIndex {
            let currentPoint = strokePath[i].location
            let segmentDist = distance(from: lastPoint, to: currentPoint)
            
            if segmentDist == 0 { continue }
            
            var remainingSegment = segmentDist
            var segmentStart = lastPoint
            
            while accumulatedDistance + remainingSegment >= targetDistance && sampledPoints.count < pointsPerStroke {
                let distanceToNextSample = targetDistance - accumulatedDistance
                let ratio = distanceToNextSample / remainingSegment
                
                let interpolatedX = segmentStart.x + ratio * (currentPoint.x - segmentStart.x)
                let interpolatedY = segmentStart.y + ratio * (currentPoint.y - segmentStart.y)
                
                sampledPoints.append(SampledPoint(x: interpolatedX, y: interpolatedY))
                
                segmentStart = CGPoint(x: interpolatedX, y: interpolatedY)
                remainingSegment -= distanceToNextSample
                accumulatedDistance = 0
                targetDistance = segmentLength
            }
            
            accumulatedDistance += remainingSegment
            lastPoint = currentPoint
        }
        
        if sampledPoints.count < pointsPerStroke {
            let lastPathPoint = strokePath[endIndex]
            sampledPoints.append(SampledPoint(x: lastPathPoint.location.x, y: lastPathPoint.location.y))
        }
        
        return sampledPoints
    }
    
    private func calculateTotalLength(from strokePath: PKStrokePath, startIndex: Int, endIndex: Int) -> CGFloat {
        var totalLength: CGFloat = 0
        var lastPoint = strokePath[startIndex].location
        
        for i in (startIndex + 1)...endIndex {
            let currentPoint = strokePath[i].location
            totalLength += distance(from: lastPoint, to: currentPoint)
            lastPoint = currentPoint
        }
        
        return totalLength
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

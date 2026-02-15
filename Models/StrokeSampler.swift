import Foundation
import PencilKit
import CoreGraphics

struct StrokeSampler {
    let sampleDistance: CGFloat
    
    init(sampleDistance: CGFloat = 5.0) {
        self.sampleDistance = sampleDistance
    }
    
    func samplePointsAlongDistance(from strokePath: PKStrokePath, startIndex: Int, endIndex: Int) -> [SampledPoint] {
        guard endIndex > startIndex else { return [] }
        
        var sampledPoints: [SampledPoint] = []
        var accumulatedDistance: CGFloat = 0
        
        let firstPoint = strokePath[startIndex]
        sampledPoints.append(SampledPoint(x: firstPoint.location.x, y: firstPoint.location.y))
        
        var lastPoint = firstPoint.location
        
        for i in (startIndex + 1)...endIndex {
            let currentPoint = strokePath[i].location
            let segmentDistance = distance(from: lastPoint, to: currentPoint)
            
            if segmentDistance == 0 { continue }
            
            var remainingSegment = segmentDistance
            var segmentStart = lastPoint
            
            while accumulatedDistance + remainingSegment >= sampleDistance {
                let distanceToNextSample = sampleDistance - accumulatedDistance
                let ratio = distanceToNextSample / remainingSegment
                
                let interpolatedX = segmentStart.x + ratio * (currentPoint.x - segmentStart.x)
                let interpolatedY = segmentStart.y + ratio * (currentPoint.y - segmentStart.y)
                
                sampledPoints.append(SampledPoint(x: interpolatedX, y: interpolatedY))
                
                segmentStart = CGPoint(x: interpolatedX, y: interpolatedY)
                remainingSegment -= distanceToNextSample
                accumulatedDistance = 0
            }
            
            accumulatedDistance += remainingSegment
            lastPoint = currentPoint
        }
        
        let lastPathPoint = strokePath[endIndex]
        let lastSampled = sampledPoints.last
        if lastSampled == nil || distance(from: CGPoint(x: lastSampled!.x, y: lastSampled!.y), to: lastPathPoint.location) > 0.1 {
            sampledPoints.append(SampledPoint(x: lastPathPoint.location.x, y: lastPathPoint.location.y))
        }
        
        return sampledPoints
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

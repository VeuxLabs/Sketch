//
//  DoodleKitView.swift
//  DoodleKit
//
//  Created by daihase on 04/06/2018.
//  Copyright (c) 2018 daihase. All rights reserved.
//

import UIKit

public enum SketchToolType {
    case pen
    case eraser
    case line
    case arrow
    case rectangleStroke
    case rectangleFill
    case ellipseStroke
    case ellipseFill
    case stamp
}

public enum ImageRenderingMode {
    case scale
    case original
}

@objc public protocol SketchViewDelegate: NSObjectProtocol  {
    @objc optional func drawView(_ view: SketchView, willBeginDrawUsingTool tool: AnyObject)
    @objc optional func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject)
}

public class SketchView: UIView {
    public var lineColor = UIColor.black
    public var lineWidth = CGFloat(10)
    public var lineAlpha = CGFloat(1)
    public var stampImage: UIImage?
    public var drawTool: SketchToolType = .pen
    
    public let previousPoint1XKey = "previousPoint1XKey"
    public let previousPoint1YKey = "previousPoint1YKey"
    public let previousPoint2XKey = "previousPoint2XKey"
    public let previousPoint2YKey = "previousPoint2YKey"
    public let currenPointXKey = "currenPointXKey"
    public let currenPointYKey = "currenPointYKey"

 
    
    private var currentTool: SketchTool?
    public var drawingPenType: PenType = .normal
    public var sketchViewDelegate: SketchViewDelegate?
    private var pathArray = [SketchTool]()
    private var pathArrayBackup = [SketchTool]()
    private var bufferArray = [SketchTool]()
    private var bufferArrayBackup = [SketchTool]()
    private var currentPoint: CGPoint?
    private var previousPoint1: CGPoint?
    private var previousPoint2: CGPoint?
    private var image: UIImage?
    private var backgroundImage: UIImage?
    private var drawMode: ImageRenderingMode = .original
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        prepareForInitial()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        prepareForInitial()
    }
    
    private func prepareForInitial() {
        backgroundColor = UIColor.clear
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        switch drawMode {
        case .original:
            image?.draw(at: CGPoint.zero)
            break
        case .scale:
            image?.draw(in: self.bounds)
            break
        }
        
        currentTool?.draw()
    }
    
    private func updateCacheImage(_ isUpdate: Bool) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        
        if isUpdate {
            image = nil
            switch drawMode {
            case .original:
                if let backgroundImage = backgroundImage  {
                    (backgroundImage.copy() as! UIImage).draw(at: CGPoint.zero)
                }
                break
            case .scale:
                (backgroundImage?.copy() as! UIImage).draw(in: self.bounds)
                break
            }
            
            for obj in pathArray {
                obj.draw()
                }
        } else {
            image?.draw(at: .zero)
            currentTool?.draw()
        }
        
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    private func toolWithCurrentSettings() -> SketchTool? {
        switch drawTool {
        case .pen:
            return PenTool()
        case .eraser:
            return EraserTool()
        case .stamp:
            return StampTool()
        case .line:
            return LineTool()
        case .arrow:
            return ArrowTool()
        case .rectangleStroke:
            let rectTool = RectTool()
            rectTool.isFill = false
            return rectTool
        case .rectangleFill:
            let rectTool = RectTool()
            rectTool.isFill = true
            return rectTool
        case .ellipseStroke:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = false
            return ellipseTool
        case .ellipseFill:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = true
            return ellipseTool
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        currentTool = toolWithCurrentSettings()
        currentTool?.lineWidth = lineWidth
        currentTool?.lineColor = lineColor
        currentTool?.lineAlpha = lineAlpha
        switch currentTool! {
        case is PenTool:
            guard let penTool = currentTool as? PenTool else { return }
            pathArray.append(penTool)
            penTool.drawingPenType = drawingPenType
            penTool.setInitialPoint(currentPoint!)
        case is StampTool:
            guard let stampTool = currentTool as? StampTool else { return }
            pathArray.append(stampTool)
            stampTool.setStampImage(image: stampImage)
            stampTool.setInitialPoint(currentPoint!)
        default:
            guard let currentTool = currentTool else { return }
            pathArray.append(currentTool)
            currentTool.setInitialPoint(currentPoint!)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        previousPoint2 = previousPoint1
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        if let penTool = currentTool as? PenTool {
            let renderingBox = penTool.createBezierRenderingBox(previousPoint2!, widhPreviousPoint: previousPoint1!, withCurrentPoint: currentPoint!, view: self)
            setNeedsDisplay(renderingBox)
        } else {
            currentTool?.moveFromPoint(previousPoint1!, toPoint: currentPoint!)
            setNeedsDisplay()
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event)
        finishDrawing()
    }
    
    fileprivate func finishDrawing() {
        updateCacheImage(false)
        bufferArray.removeAll()
        sketchViewDelegate?.drawView?(self, didEndDrawUsingTool: currentTool! as AnyObject)
        currentTool = nil
    }
    
    private func resetTool() {
        currentTool = nil
    }
    
    public func clear() {
        resetTool()
        bufferArray.removeAll()
        pathArray.removeAll()
        updateCacheImage(true)
        setNeedsDisplay()
    }
    
    
    public func redrawView(lineColor: UIColor) {
        copyAuxArrays()
        clear()
        self.lineColor = lineColor
        restorePointsBackup(lineColor: lineColor)
        updateCacheImage(true)
        setNeedsDisplay()
    }
    
    
    func copyAuxArrays(){
        pathArrayBackup = pathArray
        bufferArrayBackup = bufferArray
    }
    
    func restorePointsBackup(lineColor: UIColor){
        pathArray = copyPointsArray(lineColor: lineColor, pointsArray: pathArrayBackup)
        bufferArray = copyPointsArray(lineColor: lineColor, pointsArray: bufferArrayBackup)
        pathArrayBackup.removeAll()
        bufferArrayBackup.removeAll()
    }
    
    
    func copyPointsArray(lineColor: UIColor, pointsArray:[SketchTool]) -> [SketchTool]{
        var pointsArrayModified = [SketchTool]()
        for sketchTool in pointsArray{
            let mutableSketchTool = sketchTool as! PenTool
            mutableSketchTool.lineColor = lineColor
            let coordinates = mutableSketchTool.coordinates
            mutableSketchTool.path = CGMutablePath.init()
            mutableSketchTool.coordinates = [Coordinates]()
            for coordinateObject in coordinates{
                let _ = mutableSketchTool.createBezierRenderingBox(CGPoint(x: coordinateObject.previousPoint2.x * self.bounds.width, y: coordinateObject.previousPoint2.y * self.bounds.height), widhPreviousPoint: CGPoint(x: coordinateObject.previousPoint1.x * self.bounds.width, y: coordinateObject.previousPoint1.y * self.bounds.height), withCurrentPoint: CGPoint(x: coordinateObject.currenPoint.x * self.bounds.width, y: coordinateObject.currenPoint.y * self.bounds.height), view: self)
            }
            pointsArrayModified.append(mutableSketchTool)
        }
        return pointsArrayModified
    }
    
    func pinch() {
        resetTool()
        guard let tool = pathArray.last else { return }
        bufferArray.append(tool)
        pathArray.removeLast()
        updateCacheImage(true)
        
        setNeedsDisplay()
    }
    
    public func loadImage(image: UIImage) {
        self.image = image
        backgroundImage =  image.copy() as? UIImage
        bufferArray.removeAll()
        pathArray.removeAll()
        updateCacheImage(true)
        
        setNeedsDisplay()
    }
    
    public func undo() {
        if canUndo() {
            guard let tool = pathArray.last else { return }
            resetTool()
            bufferArray.append(tool)
            pathArray.removeLast()
            updateCacheImage(true)
            
            setNeedsDisplay()
        }
    }
    
    public func redo() {
        if canRedo() {
            guard let tool = bufferArray.last else { return }
            resetTool()
            pathArray.append(tool)
            bufferArray.removeLast()
            updateCacheImage(true)
            setNeedsDisplay()
        }
    }
    
    public func canUndo() -> Bool {
        return pathArray.count > 0
    }
    
    public func canRedo() -> Bool {
        return bufferArray.count > 0
    }
    
    
    public func mapCurrentSketchToPlainObject() -> [[[String: Double]]]{
        var pathArrayDictionary = [[[String:Double]]]()
        for object in pathArray{
            if let penTool = object as? PenTool{
                var coordinatesArray = [[String:Double]]()
                for coordinates in penTool.coordinates{
                    let coordinatesDictionary = [previousPoint1XKey: Double(coordinates.previousPoint1.x),
                                                 previousPoint1YKey: Double(coordinates.previousPoint1.y),
                                                 previousPoint2XKey: Double(coordinates.previousPoint2.x),
                                                 previousPoint2YKey: Double(coordinates.previousPoint2.y),
                                                 currenPointXKey: Double(coordinates.currenPoint.x),
                                                 currenPointYKey: Double(coordinates.currenPoint.y)]
                    coordinatesArray.append(coordinatesDictionary)
                }
                pathArrayDictionary.append(coordinatesArray)
            }
        }
        return pathArrayDictionary
    }
    
    
    public func loadDraw(path: [[[String: Double]]]){
        for penTool in path{
            currentTool = toolWithCurrentSettings()
            currentTool?.lineWidth = lineWidth
            currentTool?.lineColor = lineColor
            currentTool?.lineAlpha = lineAlpha
            guard let object = currentTool as? PenTool else { return }
            pathArray.append(object)
            for coordinates in penTool{
                let previousPoint1 = CGPoint(x: coordinates[previousPoint1XKey]!, y: coordinates[previousPoint1YKey]!)
                let previousPoint2 = CGPoint(x: coordinates[previousPoint2XKey]!, y: coordinates[previousPoint2YKey]!)
                let currenPoint = CGPoint(x: coordinates[currenPointXKey]!, y: coordinates[currenPointYKey]!)
                let _ = object.createBezierRenderingBox(previousPoint2, widhPreviousPoint: previousPoint1, withCurrentPoint: currenPoint, view: self)
            }
        }
        if path.count > 0{
            updateCacheImage(true)
            setNeedsDisplay()
        }
    }
}

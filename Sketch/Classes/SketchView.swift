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
    @objc optional func saveBackupRequired(sketchView: SketchView)
}

public struct SketchConstants{
    public static let previousPoint1Key = "previousPointKey"
    public static let previousPoint2Key = "previousPoint2Key"
    public static let currentPointKey = "currentPointKey"
}

public class SketchView: UIView {
    public var lineColor = UIColor.black
    public var lineWidth = CGFloat(10)
    public var lineAlpha = CGFloat(1)
    public var stampImage: UIImage?
    public var drawTool: SketchToolType = .pen
    private let maximumPointsAllowedForASingleStroke = 1000
   
    
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
    private var hasChanges = false
    private var currentStrokesCount: Int = 0
    
    
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
    
    public func numberOfStrokes()->Int{
        return pathArray.count
    }
    
    public func updateCacheImage(_ isUpdate: Bool) {
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
        currentStrokesCount = 0
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        currentTool = toolWithCurrentSettings()
        currentTool?.lineWidth = lineWidth
        currentTool?.lineColor = lineColor
        currentTool?.lineAlpha = lineAlpha
        switch currentTool! {
        case is PenTool:
            guard let penTool = currentTool as? PenTool else { return }
            if drawTool != .eraser{
                hasChanges = true
                pathArray.append(penTool)
            }
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
        currentStrokesCount += 1
        if currentStrokesCount == maximumPointsAllowedForASingleStroke {
            sketchViewDelegate?.saveBackupRequired?(sketchView: self)
            touchesCancelled(touches, with: event)
            return
        }
        if currentStrokesCount > maximumPointsAllowedForASingleStroke {
            return
        }
        guard let touch = touches.first else { return }
        previousPoint2 = previousPoint1
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        if let penTool = currentTool as? PenTool {
            if pathArray.count > 0 && drawTool == .eraser{
                penTool.path.addPath(penTool.createSubPath(previousPoint2: previousPoint2!, previousPoint1: previousPoint1!, currentPoint: currentPoint!))
                currentTool = penTool
                for (index,object) in pathArray.enumerated(){
                    if let objectParsed = object as? PenTool{
                        let intersectionFound = objectParsed.path.boundingBox.intersects(penTool.path.boundingBox)
                        if intersectionFound{
                             hasChanges = true
                            let backupObject = getToolObjectCopy(toolObject: pathArray[index] as! PenTool)
                            backupObject.index = index
                            backupObject.backupPath = backupObject.path
                            backupObject.path = CGMutablePath()
                            pathArray[index] = backupObject
                            pathArray.append(backupObject)
                            updateCacheImage(true)
                            setNeedsDisplay()
                            let filtered = pathArray.filter{($0 as! PenTool).index == nil}
                            if filtered.count == 0{
                                hasChanges = false
                            }
                        }
                    }
                }
            }
            else{
                let renderingBox = penTool.createBezierRenderingBox(previousPoint2!, widhPreviousPoint: previousPoint1!, withCurrentPoint: currentPoint!, view: self)
                setNeedsDisplay(renderingBox)
            }
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
    
    public func clearSaveFlag(){
        hasChanges = false
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
            if mutableSketchTool.index != nil {
                mutableSketchTool.backupPath = mutableSketchTool.path
                mutableSketchTool.path = CGMutablePath.init()
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
            hasChanges = true
            guard let tool = pathArray.last as? PenTool else { return }
            if tool.index != nil {
                let backupTool = getToolObjectCopy(toolObject: pathArray[tool.index!] as! PenTool)
                backupTool.path = tool.backupPath!
                backupTool.index = nil
                backupTool.backupPath = nil
                pathArray[tool.index!] = backupTool
            }
            resetTool()
            bufferArray.append(tool)
            pathArray.removeLast()
            updateCacheImage(true)
            setNeedsDisplay()
        }
    }
    
    public func redo() {
        if canRedo() {
            hasChanges = true
            guard let tool = bufferArray.last as? PenTool else { return }
            if tool.index != nil{
                pathArray[tool.index!] = tool
            }
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
    
    public func canSave() ->Bool{
        return hasChanges
    }
    
    public func canDelete() -> Bool{
        if pathArray.count == 0{
            return false
        }
        let emptyElements = pathArray.filter{($0 as! PenTool).path.isEmpty}.count
        return pathArray.count != emptyElements
    }
    
    public func noteWasSavedInTheDB(){
        hasChanges = false
    }
    
    
    public func mapCurrentSketchToPlainObject() -> [[[String: CGPoint]]]{
        var pathArrayDictionary = [[[String:CGPoint]]]()
        for object in pathArray{
            if let penTool = object as? PenTool, !penTool.path.isEmpty{
                var coordinatesArray = [[String:CGPoint]]()
                for coordinates in penTool.coordinates{
                    let coordinatesDictionary = [SketchConstants.previousPoint1Key: coordinates.previousPoint1,
                                                 SketchConstants.previousPoint2Key: coordinates.previousPoint2,
                                                 SketchConstants.currentPointKey: coordinates.currenPoint]
                    coordinatesArray.append(coordinatesDictionary)
                }
                pathArrayDictionary.append(coordinatesArray)
            }
        }
        return pathArrayDictionary
    }
    
    
    public func loadDraw(path: [[[String: CGPoint]]]){
        for penTool in path{
            currentTool = toolWithCurrentSettings()
            currentTool?.lineWidth = lineWidth
            currentTool?.lineColor = lineColor
            currentTool?.lineAlpha = lineAlpha
            guard let object = currentTool as? PenTool else { return }
            pathArray.append(object)
            for coordinates in penTool{
                let _ = object.createBezierRenderingBox(CGPoint(x: coordinates[SketchConstants.previousPoint2Key]!.x * self.bounds.width, y: coordinates[SketchConstants.previousPoint2Key]!.y * self.bounds.height), widhPreviousPoint: CGPoint(x: coordinates[SketchConstants.previousPoint1Key]!.x * self.bounds.width, y: coordinates[SketchConstants.previousPoint1Key]!.y * self.bounds.height), withCurrentPoint: CGPoint(x: coordinates[SketchConstants.currentPointKey]!.x * self.bounds.width, y: coordinates[SketchConstants.currentPointKey]!.y * self.bounds.height), view: self)
            }
        }
        if path.count > 0{
            hasChanges = true
            updateCacheImage(true)
            setNeedsDisplay()
        }
    }
    
    
    
    private func getToolObjectCopy(toolObject: PenTool) -> PenTool{
        let backupTool = PenTool.init(path: toolObject.path, lineColor: toolObject.lineColor, lineAlpha: toolObject.lineAlpha, drawingPenType: toolObject.drawingPenType, coordinates: toolObject.coordinates, backupPath: toolObject.backupPath, index: toolObject.index)
        backupTool.lineWidth = toolObject.lineWidth
        backupTool.lineColor = toolObject.lineColor
        backupTool.lineAlpha = toolObject.lineAlpha
        return backupTool
    }
}


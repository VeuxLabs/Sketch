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
            let renderingBox = penTool.createBezierRenderingBox(previousPoint2!, widhPreviousPoint: previousPoint1!, withCurrentPoint: currentPoint!)
            print("previousPoint2: \(previousPoint2!), widhPreviousPoint: \(previousPoint1!), withCurrentPoint: \(currentPoint!)")
            setNeedsDisplay(renderingBox)
            print("--------------------")
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
        
        let dsds = pathArray.first as! PenTool
        

        
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
            var mutableSketchTool = sketchTool
            mutableSketchTool.lineColor = lineColor
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
    
    func canUndo() -> Bool {
        return pathArray.count > 0
    }
    
    func canRedo() -> Bool {
        return bufferArray.count > 0
    }
    
    
    
    public func testLoadDraw(){
        
        
        currentTool = toolWithCurrentSettings()
        currentTool?.lineWidth = lineWidth
        currentTool?.lineColor = lineColor
        currentTool?.lineAlpha = lineAlpha
        
        guard let penTool = currentTool as? PenTool else { return }
        pathArray.append(penTool)
        penTool.drawingPenType = drawingPenType
        
        if let oneElement = currentTool as? PenTool {
            let a = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 126.5), widhPreviousPoint: CGPoint(x: 176.5, y: 126.5), withCurrentPoint: CGPoint(x: 176.5, y: 127.0))
            //setNeedsDisplay(a)
            let b = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 126.5), widhPreviousPoint: CGPoint(x: 176.5, y: 127.0), withCurrentPoint: CGPoint(x: 176.5, y: 128.5))
            //setNeedsDisplay(b)
            let c = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 127.0), widhPreviousPoint: CGPoint(x: 176.5, y: 128.5), withCurrentPoint: CGPoint(x: 176.5, y: 130.0))
            //setNeedsDisplay(c)
            let d = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 128.5), widhPreviousPoint: CGPoint(x: 176.5, y: 130.0), withCurrentPoint: CGPoint(x: 176.5, y: 134.0))
            //setNeedsDisplay(d)
            let e = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 130.0), widhPreviousPoint: CGPoint(x: 176.5, y: 134.0), withCurrentPoint: CGPoint(x: 176.5, y: 139.0))
            //setNeedsDisplay(e)
            let f = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 134.0), widhPreviousPoint: CGPoint(x: 176.5, y: 139.0), withCurrentPoint: CGPoint(x: 176.5, y: 144.0))
            //setNeedsDisplay(f)
            let g = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 139.0), widhPreviousPoint: CGPoint(x: 176.5, y: 144.0), withCurrentPoint: CGPoint(x: 176.5, y: 146.5))
            //setNeedsDisplay(g)
            let h = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 144.0), widhPreviousPoint: CGPoint(x: 176.5, y: 146.5), withCurrentPoint: CGPoint(x: 176.5, y: 150.0))
            //setNeedsDisplay(h)
            let i = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 146.5), widhPreviousPoint: CGPoint(x: 176.5, y: 150.0), withCurrentPoint: CGPoint(x: 176.5, y: 151.0))
            //setNeedsDisplay(i)
            let j = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 150.0), widhPreviousPoint: CGPoint(x: 176.5, y: 151.0), withCurrentPoint: CGPoint(x: 176.5, y: 152.0))
            //setNeedsDisplay(j)
            
            let k = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 151.0), widhPreviousPoint: CGPoint(x: 176.5, y: 152.0), withCurrentPoint: CGPoint(x: 176.5, y: 153.0))
            //setNeedsDisplay(k)
            
            let ij = oneElement.createBezierRenderingBox(CGPoint(x: 176.5, y: 152.0), widhPreviousPoint: CGPoint(x: 176.5, y: 153.0), withCurrentPoint: CGPoint(x: 176.5, y: 153.5))
            //setNeedsDisplay(ij)
            
        }
        updateCacheImage(true)
        setNeedsDisplay()

    }
}

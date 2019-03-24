//
//  StreamingProgressBar.swift
//
//  Created by Kyle Zaragoza on 9/16/15.
//  Portions Copyright © 2015 Kyle Zaragoza. All rights reserved.
//  Portions from the `ScrubberBar` library, Copyright © 2015 Squareheads. MIT licensed.
//  Portions from the `JGDetailScrubber` library, Copyright © 2013 Jonas Gessner. All rights reserved.
//  Portions Copyright © 2019 Perceval Faramaz.
//

import UIKit

@objc public protocol StreamingProgressBarDelegate {
    @objc optional func streamingBar(bar: StreamingProgressBar, didScrubToProgress: CGFloat)
}

@IBDesignable open class StreamingProgressBar: UIControl {
    
    @IBOutlet public weak var delegate: StreamingProgressBarDelegate?
    
    @IBInspectable open var progressBarColor: UIColor = UIColor.white {
        didSet {
            progressBarLayer.backgroundColor = progressBarColor.cgColor
            draggerLayer.fillColor = progressBarColor.cgColor
        }
    }
    
    @IBInspectable open var secondaryProgressBarColor: UIColor = UIColor.clear {
        didSet {
            secondaryProgressBarLayer.backgroundColor = secondaryProgressBarColor.cgColor
        }
    }
    
    @IBInspectable open var secondaryProgress: CGFloat = 0 {
        didSet {
            if secondaryProgress > 1 {
                secondaryProgress = 1
            } else if secondaryProgress < 0 {
                secondaryProgress = 0
            }
            layout(secondaryProgressBarLayer, forProgress: secondaryProgress)
        }
    }

    @IBInspectable open var progress: CGFloat = 0.5 {
        willSet {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.4)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        }
        didSet {
            progress = progress.clamped(to: 0...1)
            layout(progressBarLayer, forProgress: progress)
            CATransaction.commit()
        }
    }
    
    @IBInspectable open var draggerRadius: CGFloat = 10 {
        didSet {
            let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: draggerRadius, height: draggerRadius))
            draggerLayer.path = path.cgPath
            layoutDragger()
        }
    }
    
    @IBInspectable open var scrubbingEnabled: Bool = true
    @IBInspectable open var detailScrubbingEnabled: Bool = false
    open var scrubbingSpeed: CGFloat = 1
    
    open var scrubbingSpeeds: [CGFloat: CGFloat] = [0  :   1,
                                                    50 : 0.5,
                                                    100:0.25,
                                                    150: 0.1] {
        didSet {
            scrubbingPositions = scrubbingSpeeds.keys.sorted(by: { $0 > $1 })
        }
    }
    fileprivate var scrubbingPositions = [CGFloat]()
    fileprivate var thumbRect = CGRect.zero
    
    fileprivate var isDragging: Bool = false
    fileprivate var firstTouchX: CGFloat = 0
    fileprivate var firstTouchProgress: CGFloat = 0
    
    fileprivate let progressBarLayer: CALayer = {
        let layer = CALayer()
        return layer
    }()
    
    fileprivate let draggerLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.backgroundColor = UIColor.clear.cgColor
        return layer
    }()
    
    fileprivate let secondaryProgressBarLayer: CALayer = {
        let layer = CALayer()
        return layer
    }()
    
    
    // MARK: - Layout
    
    private func animateLayer(_ layer: CALayer, toFrame frame: CGRect) {
        let animation = CABasicAnimation(keyPath: "frame")
        animation.fromValue = layer.frame
        animation.toValue = frame
        layer.frame = frame
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "frame")
    }
    
    fileprivate func layout(_ layer: CALayer, forProgress progress: CGFloat) {
        let layerFrame = CGRect(
            origin: CGPoint.zero,
            size: CGSize(width: self.bounds.width * progress, height: self.bounds.height))
        
        animateLayer(layer, toFrame: layerFrame)
        
        if (layer == progressBarLayer) {
            layoutDragger()
        }
    }
    
    fileprivate func layoutDragger() {
        let layerFrame = CGRect(
            origin: CGPoint(x: (self.bounds.width * progress - draggerRadius/2),
                            y: (self.bounds.height - draggerRadius)/2),
            size: CGSize(width: draggerRadius, height: draggerRadius))
        
        animateLayer(draggerLayer, toFrame: layerFrame)
    }
    
    // MARK: - Init
    
    private func commonInit() {
        self.layer.addSublayer(secondaryProgressBarLayer)
        self.layer.addSublayer(progressBarLayer)
        self.layer.addSublayer(draggerLayer)
        self.clipsToBounds = false
        self.layer.masksToBounds = false
        layoutProgressBars()
        
        let speeds = self.scrubbingSpeeds
        self.scrubbingSpeeds = speeds //to trigger didSet and rebuild positions array
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    // MARK: - Layout
    
    fileprivate func layoutProgressBars() {
        layout(secondaryProgressBarLayer, forProgress: secondaryProgress)
        layout(progressBarLayer,          forProgress: progress)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutProgressBars()
    }
    
    // MARK: - Interaction
    
    func positionFromProgress(progress: CGFloat) -> CGFloat {
        return (CGFloat(bounds.width) * progress) - self.bounds.width
    }
    
    func progressFromPosition(position: CGFloat) -> CGFloat {
        return (position / CGFloat(bounds.width)).clamped(to: 0...1)
    }
    
    func touchIsInDragger(object: AnyObject, touch: UITouch, xPosition: inout CGFloat) -> Bool {
        if scrubbingEnabled == true {
            let pointInView = touch.location(in: self)
            
            let draggerRect = draggerLayer.frame
            let allowedRectSize = CGSize(width: draggerRect.width + 25,
                                         height: max(self.frame.height, draggerRect.height) + 20)
            let allowedRectOrigin = CGPoint(x: draggerRect.minX - (allowedRectSize.width - draggerRect.width)/2,
                                            y: draggerRect.minY - (allowedRectSize.height - draggerRect.height)/2)
            let allowedRect = CGRect(origin: allowedRectOrigin,
                                     size: allowedRectSize)
            thumbRect = allowedRect
            
            /*let path = UIBezierPath(ovalIn: allowedRect)
             let isInDragger = path.contains(pointInView)*/
            
            let isInDragger = allowedRect.contains(pointInView)
            
            if isInDragger {
                xPosition = pointInView.x
                return true
            }
        }
        return false
    }
    
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        var xPos : CGFloat = 0
        if touchIsInDragger(object: self, touch: touch, xPosition: &xPos) {
            isDragging = true
            firstTouchX = xPos
            firstTouchProgress = progress
            return true
        }
        return super.beginTracking(touch, with: event)
    }
    
    fileprivate func scrubbingSpeedAtDelta(_ verticalDelta: CGFloat) -> CGFloat {
        if (verticalDelta >= 0) {
            for position in scrubbingPositions {
                if verticalDelta >= position {
                    return scrubbingSpeeds[position]!
                }
            }
        }
        return 1
    }
    
    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if scrubbingEnabled == true, isDragging == true {
            let pointInView = touch.location(in: self)
            
            let oldSpeed = scrubbingSpeed
            let verticalDelta = abs(abs(pointInView.y) - bounds.midY)
            scrubbingSpeed = scrubbingSpeedAtDelta(verticalDelta)
            if abs(oldSpeed - scrubbingSpeed) > 0.001 {
                firstTouchProgress = self.progress
                firstTouchX = pointInView.x
            }
            
            let relativeProgress = (pointInView.x - firstTouchX) / (bounds.width - thumbRect.width)
            
            self.progress = firstTouchProgress + relativeProgress * scrubbingSpeed
            delegate?.streamingBar?(bar: self, didScrubToProgress: self.progress)
            
            return true
        }
        return super.continueTracking(touch, with: event)
    }
    
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isDragging = false
        super.endTracking(touch, with: event)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

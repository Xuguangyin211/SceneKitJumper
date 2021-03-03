//
//  SecondVC.swift
//  SceneKitJumper
//
//  Created by xuguangyin on 2021/3/2.
//

import UIKit
import SceneKit

class SecondVC: UIViewController, SCNPhysicsContactDelegate {
    
    var score: NSInteger = 0
    var pressDate: NSDate? = nil

    var scnView: SCNView = SCNView()
    var scene: SCNScene = SCNScene()
    var jumper: SCNNode = SCNNode()
    var floor: SCNNode = SCNNode()
    var camera: SCNNode = SCNNode()
    var light: SCNNode = SCNNode()

    var platform: SCNNode = SCNNode()
    var nextPlatform: SCNNode = SCNNode()
    var lastPlatform: SCNNode = SCNNode()

    enum NS_OPTIONS: Int {
        case CollisionDetectionMaskNone
        case CollisionDetectionMaskFloor
        case CollisionDetectionMaskPlatform
        case CollisionDetectionMaskJumper
        case CollisionDetectionMaskOldPlatform

        public func value() -> Int {
            switch self {
            case .CollisionDetectionMaskNone:
                return 0
            case .CollisionDetectionMaskFloor:
                return 1 << 0
            case .CollisionDetectionMaskPlatform:
                return 1 << 1
            case .CollisionDetectionMaskJumper:
                return 1 << 2
            case .CollisionDetectionMaskOldPlatform:
                return 1 << 3
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        creatView()
        createFirstPlatform()
    }

    func creatView() {
        scene = {
            let scene = SCNScene()
            scene.physicsWorld.contactDelegate = self
            scene.physicsWorld.gravity = SCNVector3Make(0, -Float(kGravityValue), 0)
            return scene
        }()

        //创建view
        scnView = {
            let view = SCNView()
            view.scene = self.scene
            view.allowsCameraControl = false
            view.autoenablesDefaultLighting = false
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(view)
            let constraintH = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[view]-0-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: ["view": view])
            let constraintV = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[view]-0-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: ["view": view])
            self.view.addConstraints(constraintH)
            self.view.addConstraints(constraintV)
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(accumulateStrength))
            view.addGestureRecognizer(longPress)
            return view
        }()

        //创建地板：（用于光影效果，与落地判断）
        floor = {
            let node = SCNNode()
            let floor = SCNFloor()
            floor.firstMaterial?.diffuse.contents = UIColor.white
            node.geometry = floor
            let body = SCNPhysicsBody.static()
            body.restitution = 0
            body.friction = 1
            body.damping = 0.3
            body.categoryBitMask = NS_OPTIONS.CollisionDetectionMaskFloor.value()
            body.collisionBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value()|NS_OPTIONS.CollisionDetectionMaskPlatform.value()|NS_OPTIONS.CollisionDetectionMaskOldPlatform.value();
            body.contactTestBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value()
            node.physicsBody = body
            self.scene.rootNode.addChildNode(node)
            return node
        }()

        //初始化小人，小人是动态物体，自由落体到第一个台子中心，会受重力影响，会与台子和地板碰撞
        jumper = {
            let node = SCNNode()
            let box = SCNBox.init(width: 1, height: 1, length: 1, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = UIColor.white
            node.geometry = box
            let body = SCNPhysicsBody.dynamic()
            body.restitution = 0
            body.friction = 1
            body.rollingFriction = 1
            body.damping = 0.3
            body.allowsResting = true
            body.categoryBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value();
            body.collisionBitMask = NS_OPTIONS.CollisionDetectionMaskPlatform.value()|NS_OPTIONS.CollisionDetectionMaskFloor.value()|NS_OPTIONS.CollisionDetectionMaskOldPlatform.value();
            node.physicsBody = body
            node.position = SCNVector3Make(0, 12.5, 0)
            self.scene.rootNode.addChildNode(node)
            return node
        }()

        //初始化相机：光源随相机移动，所以将光源设置为相机的字节点
        camera = {
            let node = SCNNode()
            node.camera = SCNCamera()
            node.camera?.zFar = 200
            node.camera?.zNear = 0.1
            self.scene.rootNode.addChildNode(node)
            node.eulerAngles = SCNVector3Make(-0.7, 0.6, 0)
            node.addChildNode(self.light)
            return node
        }()

        //灯光
        light = {
            let node = SCNNode()

            let light = SCNLight()
            light.color = UIColor.white
            light.type = SCNLight.LightType.omni
            node.light = light
            return node
        }();
    }

    //懒加载
    lazy var inforView: UIControl = {
        let view = UIControl()
        view.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height)
        view.backgroundColor = UIColor.orange

        var press = UITapGestureRecognizer(target: self, action: #selector(reStart))
        view.addGestureRecognizer(press)
        self.view.addSubview(view)
        return view
    }()

    lazy var scoreLab: UILabel = {
        let lab = UILabel()
        let x = inforView.bounds.width - 200
        let y = inforView.bounds.height - 100
        lab.frame = CGRect(x: x/2, y: y/2, width: 200, height: 100)
        lab.textAlignment = .center
        self.inforView.addSubview(lab)
        return lab
    }()

    //重新开始
    @objc func reStart() {
        self.view.sendSubviewToBack(self.inforView)
        scnView.removeFromSuperview()
        self.score = 0;
        if (self.scnView != nil && self.floor != nil && self.jumper != nil) {
            creatView()
            createFirstPlatform()
        }
    }

    func createFirstPlatform() {
        platform = {
            let node = SCNNode()

            let cylinder = SCNCylinder.init(radius: 5, height: 2)
            cylinder.firstMaterial?.diffuse.contents = UIColor.red
            node.geometry = cylinder

            let body = SCNPhysicsBody.static()
            body.restitution = 0
            body.friction = 1
            body.damping = 0
            body.categoryBitMask = NS_OPTIONS.CollisionDetectionMaskPlatform.value();
            body.collisionBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value()|NS_OPTIONS.CollisionDetectionMaskPlatform.value()|NS_OPTIONS.CollisionDetectionMaskOldPlatform.value();
            node.physicsBody = body
            node.position = SCNVector3Make(0, 1, 0)
            self.scene.rootNode.addChildNode(node)
            return node
        }()
        moveCameraToCurrentPlatform()
    }

    //调整镜头以观察小人目前所在的台子的位置
    func moveCameraToCurrentPlatform() {
        var position = SCNVector3()
        position = self.platform.presentation.position
        position.x += 20
        position.y += 30
        position.z += 20
        let move = SCNAction.move(to: position, duration: 0.5)
        self.camera.runAction(move)
        createNextPlatform()
    }

    func createNextPlatform() {
        nextPlatform = {
            let node = SCNNode()
            //随机大小
            let radius = (Int(arc4random()) % kMinPlatformRadius) + (kMaxPlatformRadius - kMinPlatformRadius)
            let cylinder = SCNCylinder.init(radius: CGFloat(radius), height: 2)
            let r = (CGFloat(arc4random() % 255)) / 255.0
            let g = (CGFloat(arc4random() % 255)) / 255.0
            let b = (CGFloat(arc4random() % 255)) / 255.0
            let color = UIColor(red: r, green: g, blue: b, alpha: 1)
            cylinder.firstMaterial?.diffuse.contents = color
            node.geometry = cylinder

            let body = SCNPhysicsBody.dynamic()
            body.restitution = 1
            body.friction = 1
            body.damping = 0
            body.allowsResting = true
            body.categoryBitMask = NS_OPTIONS.CollisionDetectionMaskPlatform.value();
            body.collisionBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value()|NS_OPTIONS.CollisionDetectionMaskFloor.value()|NS_OPTIONS.CollisionDetectionMaskOldPlatform.value()|NS_OPTIONS.CollisionDetectionMaskPlatform.value();
            body.contactTestBitMask = NS_OPTIONS.CollisionDetectionMaskJumper.value();
            node.physicsBody = body
            //随机位置
            var position = SCNVector3()
            position = self.platform.presentation.position
            let xDistance: Int = (Int(arc4random()) % (kMaxPlatformRadius * 3 - 1)) + 1

            let lastRadius = 5
            let maxDistance = sqrt(pow(Double(kMaxPlatformRadius * 3), 2) - pow(Double(xDistance), 2))
            let minDistance = Double((xDistance > lastRadius + radius) ? Double(xDistance) : sqrt(pow(Double(lastRadius + radius), 2) - pow(Double(xDistance), 2)))
            let zDistance: Double = (Double((arc4random() / UInt32(RAND_MAX))) * (maxDistance - minDistance)) + minDistance
            position.z -= Float(zDistance)
            position.x -= Float(xDistance)
            position.y += 5;
            node.position = position
            self.scene.rootNode.addChildNode(node)
            return node
        }()
    }

    //蓄力
    //长按手势事件，通过长按时间差模拟力量，如果有最大值
    @objc func accumulateStrength(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == UIGestureRecognizer.State.began {
            pressDate = NSDate()
            updateStrengthStatus()
        } else if recognizer.state == UIGestureRecognizer.State.ended {
            if (pressDate != nil) {
                self.jumper.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                self.jumper.removeAllActions()
                guard let pressDates = pressDate?.timeIntervalSince1970 else {
                    return
                }
                let nowDate = NSDate().timeIntervalSince1970
                var power = nowDate - pressDates
                power = power > kMaxPressDuration ? kMaxPressDuration : power
                jumpWithPower(power: power)
                pressDate = nil
            }
        }
        print("ok")
    }

    //力量显示
    //这里简单地用眼神表示，力量越大，小人颜色越红
    func updateStrengthStatus() {
        let action = SCNAction.customAction(duration: kMaxPressDuration) { [weak self] (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(kMaxPressDuration)
            self?.jumper.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 1 - percentage, blue: 1 - percentage, alpha: 1)
        }
        self.jumper.runAction(action)
    }

    //发力
    //根据力量给小人一个力，根据按的时间长短，对小人施加一个力，力由一个向上的力，和平面向上的力组成，平面方向的力由小人的位置和目标台子的位置计算得出。
    func jumpWithPower(power: Double) {
        let powers = power * 30
        let platformPosition = self.nextPlatform.presentation.position
        let jumperPosition = self.jumper.presentation.position
        let subtractionX = platformPosition.x - jumperPosition.x
        let subtractionZ = platformPosition.z - jumperPosition.z
        let proportion = abs(subtractionX / subtractionZ)
        var x = sqrt(1 / (pow(proportion, 2) + 1)) * proportion
        var z = sqrt(1 / (pow(proportion, 2) + 1))
        x *= subtractionX < 0 ? -1 : 1
        z *= subtractionZ < 0 ? -1 : 1
        let force = SCNVector3Make(x * Float(powers), 20, z * Float(powers))
        self.jumper.physicsBody?.applyForce(force, asImpulse: true)
    }

    //跳跃会触发的事件
    func jumpCompleted() {
        self.score += 1
        self.lastPlatform = self.platform
        self.platform = self.nextPlatform
        moveCameraToCurrentPlatform()
    }

    @objc func gameOver() {
        self.view.bringSubviewToFront(self.inforView)
        self.scoreLab.text = NSString.init(format: "分数是： %d", self.score) as String
        print("over")
    }

    //碰撞事件监听，如果小人与地板接触，游戏结束。取消对地板小人的监听，如果小人与台子碰撞，跳跃完成，进行状态刷新
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let bodyA = contact.nodeA.physicsBody
        let bodyB = contact.nodeB.physicsBody
        if bodyA?.categoryBitMask == NS_OPTIONS.CollisionDetectionMaskJumper.value() {
            if bodyB?.categoryBitMask == NS_OPTIONS.CollisionDetectionMaskFloor.value() {
                bodyB?.contactTestBitMask = NS_OPTIONS.CollisionDetectionMaskNone.value()
                self.performSelector(onMainThread: #selector(gameOver), with: nil, waitUntilDone: false)
            } else if (bodyB?.categoryBitMask == NS_OPTIONS.CollisionDetectionMaskPlatform.value()) {
                bodyB?.categoryBitMask = NS_OPTIONS.CollisionDetectionMaskOldPlatform.value()
                jumpCompleted()
            }
        }
    }

    deinit {
        print("ssss")
    }

}

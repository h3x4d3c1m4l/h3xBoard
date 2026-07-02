import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?
    
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    public static var externalWindow:UIWindow?

    // 初始化
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 建立 Flutter EventChannel
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger())
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        // 建立 Flutter MethodChannel
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }
    
    // 接收主頁面的命令和參數
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "getScreen":
                let screens = UIScreen.screens
                var screenInfos = [String]()
                for i in 0..<screens.count {
                    let screen = screens[i]
                    screenInfos.append("\(i). [\(Int(screen.nativeBounds.width))x\(Int(screen.nativeBounds.height))]")
                }
                result(screenInfos)

            // 傳回外接顯示器支援的解像度列表
            case "getModes":
                let args = call.arguments as? [String: Any]
                let target = (args?["targetScreen"] as? Int) ?? 1
                if (UIScreen.screens.count > target) {
                    let screen = UIScreen.screens[target]
                    var modes = screen.availableModes
                        .map { "\(Int($0.size.width))x\(Int($0.size.height))" }
                    // Some panels (e.g. the Simulator's external screen) don't list
                    // their native resolution among availableModes — offer it too.
                    let native = "\(Int(screen.nativeBounds.width))x\(Int(screen.nativeBounds.height))"
                    if !modes.contains(native) { modes.append(native) }
                    result(modes)
                } else {
                    result([String]())
                }

            // 連結外部顯示器
            case "connect":
                if (UIScreen.screens.count > 1) {
                    let args = call.arguments as? [String: Any]
                    let routeName = (args?["routeName"] as? String) ?? "externalView"
                    let externalScreen = UIScreen.screens[1]
                    let scale = externalScreen.scale
                    let reqWidth = args?["width"] as? Int
                    let reqHeight = args?["height"] as? Int

                    // Window size in PIXELS. Default to the panel's true native
                    // resolution (`nativeBounds`) — NOT `availableModes.last`,
                    // which is a legacy low-res mode on many displays, and not the
                    // largest `availableMode` either, since some panels (e.g. the
                    // iOS Simulator's external display) don't list their native
                    // resolution as a mode at all. That produced a tiny window.
                    var pxWidth = externalScreen.nativeBounds.width
                    var pxHeight = externalScreen.nativeBounds.height
                    // When a specific resolution is requested, switch the screen to
                    // that mode (if it exists) and size the window to it.
                    if let w = reqWidth, let h = reqHeight {
                        if let match = externalScreen.availableModes.first(where: {
                            Int($0.size.width) == w && Int($0.size.height) == h
                        }) {
                            externalScreen.currentMode = match
                        }
                        pxWidth = CGFloat(w)
                        pxHeight = CGFloat(h)
                    }
                    // UIWindow frames are in points; convert from pixels via scale.
                    var frame = CGRect.zero
                    frame.size = CGSize(width: pxWidth / scale, height: pxHeight / scale)

                    let flutterEngine = FlutterEngine()
                    flutterEngine.run(withEntrypoint: "externalDisplayMain", initialRoute: routeName)
                    let externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                    ExternalDisplayPlugin.registerGeneratedPlugin?(externalViewController)

                    ExternalDisplayPlugin.receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: flutterEngine.binaryMessenger)
                    ExternalDisplayPlugin.receiveParameters?.setStreamHandler(ExternalViewHandler())
                    ExternalDisplayPlugin.sendParameters = FlutterMethodChannel(name: "sendParameters", binaryMessenger: flutterEngine.binaryMessenger)
                    flutterEngine.registrar(forPlugin: "")?.addMethodCallDelegate(ExternalDisplaySendParameters(), channel: ExternalDisplayPlugin.sendParameters!)

                    externalViewController.view.frame = frame
                    ExternalDisplayPlugin.externalWindow = UIWindow(frame: frame)
                    ExternalDisplayPlugin.externalWindow?.rootViewController = externalViewController

                    ExternalDisplayPlugin.externalWindow?.screen = externalScreen
                    ExternalDisplayPlugin.externalWindow?.isHidden = false

                    result(["height": frame.size.height, "width": frame.size.width])
                } else {
                    result(false)
                }

            case "disconnect":
                if (UIScreen.screens.count > 1) {
                    ExternalDisplayPlugin.externalWindow?.removeFromSuperview()
                    ExternalDisplayPlugin.externalWindow = nil
                    result(true)
                } else {
                    result(false)
                }

            // 等候外部顯示器可以接收參數
            case "waitingTransferParametersReady":
                let sendFail = DispatchWorkItem(block: {
                    result(false)
                    ExternalDisplayPlugin.connectReturn = nil
                })

                func returnResolution() -> Void {
                    sendFail.cancel()
                    result(true)
                    ExternalDisplayPlugin.connectReturn = nil
                }
                ExternalDisplayPlugin.connectReturn = returnResolution

                if (ExternalDisplayPlugin.externalViewEvents != nil) {
                    ExternalDisplayPlugin.connectReturn?()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: sendFail)
                }

            // 發送參數到外部顯示頁面
            case "sendParameters":
                if (ExternalDisplayPlugin.externalViewEvents != nil) {
                    ExternalDisplayPlugin.externalViewEvents?(call.arguments)
                    result(true)
                } else {
                    result(false)
                }

            default:
                result(false)
        }
    }
}

// 接收外部顯示頁面的命令和參數
public class ExternalDisplaySendParameters: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        ExternalDisplayPlugin.mainViewEvents?(call.arguments)
    }
}

// 主頁面 Flutter 開始和停止對 swift 傳送資料的監控
public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver:NSObjectProtocol?
    var didDisconnectObserver:NSObjectProtocol?
    
    // 主頁面 Flutter 的開始監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events
        if #available(iOS 14.0, *) {
            // 檢查是否Mac機
            if (ProcessInfo.processInfo.isiOSAppOnMac) {
                return nil
            }
        }

        // 檢查是否已連接外部顯示器
        if (UIScreen.screens.count > 1) {
            events(true)
        }

        // 開始監控插入外部顯示器
        didConnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didConnectNotification, object:nil, queue:nil) {_ in
            events(true)
        }
        
        // 開始監控拔出外部顯示器
        didDisconnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didDisconnectNotification, object:nil, queue: nil) {_ in
            ExternalDisplayPlugin.externalWindow?.removeFromSuperview()
            ExternalDisplayPlugin.externalWindow = nil
            events(false)
        }
        return nil
    }
    
    // 主頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // 停止監控插入和拔出外部顯示器
        NotificationCenter.default.removeObserver(didConnectObserver!)
        NotificationCenter.default.removeObserver(didDisconnectObserver!)

        // 取消 swift 傳回的資料功能
        ExternalDisplayPlugin.mainViewEvents = nil

        return nil
    }
}

// 外部顯示頁面 Flutter 開始和停止對 swift 傳送資料的監控
public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.externalViewEvents = events
        ExternalDisplayPlugin.connectReturn?()
        return nil
    }

    // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        ExternalDisplayPlugin.receiveParameters?.setStreamHandler(nil)
        ExternalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}

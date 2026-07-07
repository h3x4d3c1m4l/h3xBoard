import Flutter
import UIKit

/// Whether a screen mode physically fits the panel — its pixel size doesn't
/// exceed the panel's native pixels (`nativeBounds`). Orientation-tolerant:
/// compares the larger and smaller dimensions independently, since `nativeBounds`
/// is reported in a canonical orientation. iPadOS lists oversized signal modes
/// (e.g. 3840×2160, 4096×2160) that a smaller panel can't switch to — excluded.
fileprivate func fitsPanel(_ mode: UIScreenMode, _ native: CGSize) -> Bool {
    let mMax = max(mode.size.width, mode.size.height)
    let mMin = min(mode.size.width, mode.size.height)
    let pMax = max(native.width, native.height)
    let pMin = min(native.width, native.height)
    return mMax <= pMax && mMin <= pMin
}

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?
    
    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    public static var externalWindow:UIWindow?

    // The external panel's true native pixel size. `nativeBounds` on an external
    // UIScreen tracks the CURRENT mode (it shrinks after we switch to a lower
    // resolution), so we remember the largest size observed for this display —
    // captured at first connect while it is still at its native mode — and use
    // that as the stable ceiling. Reset when the display is physically unplugged.
    public static var cachedNativeSize:CGSize?

    // Largest-area size among the live nativeBounds, the current mode, and what we
    // cached earlier — i.e. the panel's real native, undrifted by mode switches.
    static func nativeSize(for screen: UIScreen) -> CGSize {
        let candidates: [CGSize] = [screen.nativeBounds.size, screen.currentMode?.size, cachedNativeSize].compactMap { $0 }
        let best = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? screen.nativeBounds.size
        cachedNativeSize = best
        return best
    }

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
                    let native = ExternalDisplayPlugin.nativeSize(for: screen)
                    NSLog("[ExtDisplay] getModes: nativeBounds=\(screen.nativeBounds.size) current=\(String(describing: screen.currentMode?.size)) resolvedNative=\(native) available=\(screen.availableModes.map { $0.size })")
                    // Only offer modes the physical panel can display; drop the
                    // oversized signal modes iPadOS reports (e.g. 3840x2160 on a
                    // 3440x1440 panel), which only flicker and never switch.
                    var seen = Set<String>()
                    var modes = [String]()
                    for mode in screen.availableModes where fitsPanel(mode, native) {
                        let key = "\(Int(mode.size.width))x\(Int(mode.size.height))"
                        if seen.insert(key).inserted { modes.append(key) }
                    }
                    // Some panels (e.g. the Simulator's external screen) don't list
                    // their native resolution among availableModes — offer it too.
                    let nativeKey = "\(Int(native.width))x\(Int(native.height))"
                    if seen.insert(nativeKey).inserted { modes.append(nativeKey) }
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
                    let reqWidth = args?["width"] as? Int
                    let reqHeight = args?["height"] as? Int
                    let native = ExternalDisplayPlugin.nativeSize(for: externalScreen)

                    // Choose the screen mode to apply:
                    //  - a specific request → the matching available mode, but only
                    //    if the panel can physically display it (guards against a
                    //    stale/oversized saved value that would just flicker);
                    //  - Auto (nil) or an unmatched request → the largest mode that
                    //    fits the panel. Applying a mode for Auto is what actually
                    //    switches the display to its native resolution instead of
                    //    leaving it in whatever mode it was already in.
                    var chosen: UIScreenMode?
                    if let w = reqWidth, let h = reqHeight {
                        chosen = externalScreen.availableModes.first(where: {
                            Int($0.size.width) == w && Int($0.size.height) == h && fitsPanel($0, native)
                        })
                    }
                    if chosen == nil {
                        chosen = externalScreen.availableModes
                            .filter { fitsPanel($0, native) }
                            .max(by: { $0.size.width * $0.size.height < $1.size.width * $1.size.height })
                    }
                    NSLog("[ExtDisplay] connect: req=(\(String(describing: reqWidth)),\(String(describing: reqHeight))) nativeBounds=\(externalScreen.nativeBounds.size) current=\(String(describing: externalScreen.currentMode?.size)) resolvedNative=\(native) chosen=\(String(describing: chosen?.size)) available=\(externalScreen.availableModes.map { $0.size })")

                    // Window size in PIXELS. Fall back to the panel's native
                    // resolution when no mode is available (e.g. the iOS Simulator's
                    // external display lists none).
                    var pxWidth = native.width
                    var pxHeight = native.height
                    if let mode = chosen {
                        externalScreen.currentMode = mode
                        pxWidth = mode.size.width
                        pxHeight = mode.size.height
                    }
                    // Read scale AFTER any mode change. UIWindow frames are in
                    // points; convert from pixels via scale.
                    let scale = externalScreen.scale
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
            // Physical unplug — forget the cached native so a different monitor
            // gets its own detection on the next connect.
            ExternalDisplayPlugin.cachedNativeSize = nil
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

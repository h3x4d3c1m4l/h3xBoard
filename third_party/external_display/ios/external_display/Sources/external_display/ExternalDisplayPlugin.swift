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

/// The `UISceneDelegate` UIKit instantiates for the external-display scene role,
/// named in the host app's `UIApplicationSceneManifest`. Under the UIScene life
/// cycle an external display is not a `UIScreen` we may open a window onto — the
/// system decides when it exists and hands it to us as a scene, and a `UIWindow`
/// only renders there if it was created against that scene. So this delegate
/// exists purely to observe: it reports plug/unplug to Dart and holds the scene
/// the `connect` method later attaches a Flutter view to. Leaving the scene
/// empty is deliberate and safe — the system mirrors the main screen until we
/// put something in it.
@objc(ExternalDisplaySceneDelegate)
public class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {

    public var window: UIWindow?

    public let sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        sceneLifeCycleDelegate.scene(scene, willConnectTo: session, options: connectionOptions)
        NSLog("[ExtDisplay] external scene connected: role=\(session.role.rawValue)")
        ExternalDisplayPlugin.mainViewEvents?(true)
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        sceneLifeCycleDelegate.sceneDidDisconnect(scene)
        ExternalDisplayPlugin.teardownExternalWindow()
        // Physical unplug — forget the cached native so a different monitor
        // gets its own detection on the next connect.
        ExternalDisplayPlugin.cachedNativeSize = nil
        ExternalDisplayPlugin.mainViewEvents?(false)
    }

    public func sceneWillEnterForeground(_ scene: UIScene) {
        sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
    }

    public func sceneDidBecomeActive(_ scene: UIScene) {
        sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
    }

    public func sceneWillResignActive(_ scene: UIScene) {
        sceneLifeCycleDelegate.sceneWillResignActive(scene)
    }

    public func sceneDidEnterBackground(_ scene: UIScene) {
        sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
    }

}

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    public static var connectReturn:(() -> Void)?
    public static var mainViewEvents:FlutterEventSink?
    public static var externalViewEvents:FlutterEventSink?

    public static var registerGeneratedPlugin:((FlutterViewController)->Void)?
    public static var receiveParameters:FlutterEventChannel?
    public static var sendParameters:FlutterMethodChannel?
    public static var externalWindow:UIWindow?
    public static var externalEngine:FlutterEngine?

    // The external panel's true native pixel size. `nativeBounds` on an external
    // UIScreen tracks the CURRENT mode (it shrinks after we switch to a lower
    // resolution), so we remember the largest size observed for this display —
    // captured at first connect while it is still at its native mode — and use
    // that as the stable ceiling. Reset when the display is physically unplugged.
    public static var cachedNativeSize:CGSize?

    /// Every scene that is not the app's own window — i.e. the external
    /// display(s). Matching on "not `.windowApplication`" rather than on
    /// `.windowExternalDisplayNonInteractive` covers the iOS 15 role name too,
    /// without an availability check.
    static func externalScenes() -> [UIWindowScene] {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role != .windowApplication }
    }

    static func externalScene() -> UIWindowScene? {
        return externalScenes().first
    }

    // Largest-area size among the live nativeBounds, the current mode, and what we
    // cached earlier — i.e. the panel's real native, undrifted by mode switches.
    static func nativeSize(for screen: UIScreen) -> CGSize {
        let candidates: [CGSize] = [screen.nativeBounds.size, screen.currentMode?.size, cachedNativeSize].compactMap { $0 }
        let best = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? screen.nativeBounds.size
        cachedNativeSize = best
        return best
    }

    static func teardownExternalWindow() {
        externalWindow?.isHidden = true
        externalWindow?.rootViewController = nil
        externalWindow = nil
        externalEngine?.destroyContext()
        externalEngine = nil
        externalViewEvents = nil
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
            // The app's own scene counts as screen 0, so an attached display makes
            // this list longer than one — which is how Dart detects it at startup.
            case "getScreen":
                var screenInfos = ["0. [main]"]
                for (i, scene) in ExternalDisplayPlugin.externalScenes().enumerated() {
                    let bounds = scene.screen.nativeBounds
                    screenInfos.append("\(i + 1). [\(Int(bounds.width))x\(Int(bounds.height))]")
                }
                result(screenInfos)

            // 傳回外接顯示器支援的解像度列表
            case "getModes":
                guard let scene = ExternalDisplayPlugin.externalScene() else {
                    result([String]())
                    return
                }
                let screen = scene.screen
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

            // 連結外部顯示器
            case "connect":
                guard let externalScene = ExternalDisplayPlugin.externalScene() else {
                    result(false)
                    return
                }
                let args = call.arguments as? [String: Any]
                let routeName = (args?["routeName"] as? String) ?? "externalView"
                let externalScreen = externalScene.screen
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

                // Replace whatever was there — Dart reconnects to change resolution.
                ExternalDisplayPlugin.teardownExternalWindow()

                let flutterEngine = FlutterEngine()
                flutterEngine.run(withEntrypoint: "externalDisplayMain", initialRoute: routeName)
                let externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                ExternalDisplayPlugin.registerGeneratedPlugin?(externalViewController)
                ExternalDisplayPlugin.externalEngine = flutterEngine

                ExternalDisplayPlugin.receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: flutterEngine.binaryMessenger)
                ExternalDisplayPlugin.receiveParameters?.setStreamHandler(ExternalViewHandler())
                ExternalDisplayPlugin.sendParameters = FlutterMethodChannel(name: "sendParameters", binaryMessenger: flutterEngine.binaryMessenger)
                flutterEngine.registrar(forPlugin: "")?.addMethodCallDelegate(ExternalDisplaySendParameters(), channel: ExternalDisplayPlugin.sendParameters!)

                externalViewController.view.frame = frame
                // Binding the window to the scene is what puts it on the external
                // panel; a scene-less UIWindow would simply never appear.
                let window = UIWindow(windowScene: externalScene)
                window.frame = frame
                window.rootViewController = externalViewController
                window.isHidden = false
                ExternalDisplayPlugin.externalWindow = window
                // The scene delegate owns the window for the scene's lifetime, so
                // it survives an app backgrounding without us holding it alone.
                (externalScene.delegate as? ExternalDisplaySceneDelegate)?.window = window

                result(["height": frame.size.height, "width": frame.size.width])

            case "disconnect":
                if ExternalDisplayPlugin.externalWindow != nil {
                    (ExternalDisplayPlugin.externalScene()?.delegate as? ExternalDisplaySceneDelegate)?.window = nil
                    ExternalDisplayPlugin.teardownExternalWindow()
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

    // 主頁面 Flutter 的開始監控 swift 傳回的資料
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        ExternalDisplayPlugin.mainViewEvents = events
        // 檢查是否Mac機
        if (ProcessInfo.processInfo.isiOSAppOnMac) {
            return nil
        }

        // 檢查是否已連接外部顯示器. Plug and unplug afterwards arrive as scene
        // connect/disconnect on ExternalDisplaySceneDelegate, so there is no
        // UIScreen notification to observe here.
        if (!ExternalDisplayPlugin.externalScenes().isEmpty) {
            events(true)
        }
        return nil
    }

    // 主頁面 Flutter 的停止監控 swift 傳回的資料
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
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

import UIKit
import Flutter
import Photos

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate else { return }
        
        // Create Flutter engine
        let flutterEngine = FlutterEngine(name: "io.flutter", project: nil)
        flutterEngine.run(withEntrypoint: nil)
        
        // Register plugins with the engine
        GeneratedPluginRegistrant.register(with: flutterEngine)
        
        // Create Flutter view controller with the engine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        
        // Set up method channel for setting video creation dates
        let videoDateChannel = FlutterMethodChannel(
            name: "co.uk.vidbeamish.EzyPics/video_date",
            binaryMessenger: flutterViewController.binaryMessenger
        )
        
        videoDateChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "setCreationDate" {
                guard let args = call.arguments as? [String: Any],
                      let assetId = args["assetId"] as? String,
                      let timestamp = args["timestamp"] as? Int64 else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                
                PHPhotoLibrary.shared().performChanges({
                    if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                        PHAssetChangeRequest(for: asset).creationDate = date
                    }
                }, completionHandler: { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "SET_DATE_FAILED", message: error?.localizedDescription ?? "Unknown error", details: nil))
                    }
                })
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = flutterViewController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}


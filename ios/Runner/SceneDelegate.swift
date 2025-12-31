import UIKit
import Flutter

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


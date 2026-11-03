import SwiftUI

final class ArcadeAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .allButUpsideDown
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}

@main
struct HTMLArcadeApp: App {
    @UIApplicationDelegateAdaptor(ArcadeAppDelegate.self) private var appDelegate
    @StateObject private var library = GameLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .preferredColorScheme(.dark)
                .tint(ArcadeTheme.lime)
                .task {
                    await library.start()
                    #if DEBUG
                    if let fixture = ProcessInfo.processInfo.environment["ARCADE_IMPORT_FILE"] {
                        await library.importFiles([URL(fileURLWithPath: fixture)])
                    }
                    #endif
                }
                .onOpenURL { url in
                    Task {
                        while !library.isReady { try? await Task.sleep(for: .milliseconds(100)) }
                        await library.importFiles([url])
                    }
                }
        }
    }
}

import SwiftUI
import SwiftData

@main
struct TickrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JiraAccount.self,
            TimeEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        appDelegate.modelContainer = sharedModelContainer
    }
    
    var body: some Scene {
        Settings {
            PreferencesView()
                .modelContainer(sharedModelContainer)
        }
    }
}

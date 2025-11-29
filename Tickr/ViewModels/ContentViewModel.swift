import Foundation
import SwiftData
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var selectedAccount: JiraAccount?
    @Published var issues: [JiraIssue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private(set) var timerManager: TimerManager
    private var modelContext: ModelContext?
    private let apiService = JiraAPIService()
    
    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
        let tempContext = modelContext ?? ModelContext(
            try! ModelContainer(for: JiraAccount.self, TimeEntry.self)
        )
        self.timerManager = TimerManager(modelContext: tempContext, apiService: apiService)
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        self.timerManager = TimerManager(modelContext: context, apiService: apiService)
    }
    
    func loadInitialData() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<JiraAccount>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        if let activeAccount = try? context.fetch(descriptor).first {
            selectedAccount = activeAccount
            Task {
                await refreshIssues()
            }
        } else {
            let allDescriptor = FetchDescriptor<JiraAccount>(
                sortBy: [SortDescriptor(\.name)]
            )
            if let firstAccount = try? context.fetch(allDescriptor).first {
                selectAccount(firstAccount)
            }
        }
    }
    
    func selectAccount(_ account: JiraAccount) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<JiraAccount>()
        if let allAccounts = try? context.fetch(descriptor) {
            for acc in allAccounts {
                acc.isActive = false
            }
        }
        
        account.isActive = true
        try? context.save()
        
        selectedAccount = account
        Task {
            await refreshIssues()
        }
    }
    
    func refreshIssues() async {
        guard let account = selectedAccount else {
            errorMessage = "No account selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            issues = try await apiService.fetchAssignedIssues(for: account)
            account.lastSyncedAt = Date()
            try? modelContext?.save()
        } catch {
            errorMessage = error.localizedDescription
            issues = []
        }
        
        isLoading = false
    }
}

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JiraAccount.name)]) private var accounts: [JiraAccount]
    @StateObject private var viewModel: ContentViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel(modelContext: nil))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                accounts: accounts,
                selectedAccount: viewModel.selectedAccount,
                onAccountSelected: { account in
                    viewModel.selectAccount(account)
                },
                onRefresh: {
                    Task {
                        await viewModel.refreshIssues()
                    }
                }
            )
            
            Divider()
            
            IssuesListView(
                issues: viewModel.issues,
                isLoading: viewModel.isLoading,
                error: viewModel.errorMessage,
                timerManager: viewModel.timerManager,
                onStartTimer: { issue in
                    guard let account = viewModel.selectedAccount else { return }
                    viewModel.timerManager.startTimer(for: issue, account: account)
                },
                onStopTimer: { issueKey in
                    Task {
                        do {
                            try await viewModel.timerManager.stopTimer(for: issueKey)
                            await viewModel.refreshIssues()
                        } catch {
                            viewModel.errorMessage = "Failed to stop timer: \(error.localizedDescription)"
                        }
                    }
                },
                onCancelTimer: { issueKey in
                    viewModel.timerManager.cancelTimer(for: issueKey)
                }
            )
        }
        .frame(width: 400, height: 500)
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.loadInitialData()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JiraAccount.self, TimeEntry.self], inMemory: true)
}

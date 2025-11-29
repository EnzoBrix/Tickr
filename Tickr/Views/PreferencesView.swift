import SwiftUI
import SwiftData

struct PreferencesView: View {
    var body: some View {
        AccountsPreferencesView()
            .frame(minWidth: 600, minHeight: 500)
            .fixedSize()
    }
}

struct AccountsPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JiraAccount.name)]) private var accounts: [JiraAccount]
    
    @State private var selectedAccount: JiraAccount?
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jira Accounts")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedAccount == nil)
            }
            .padding()
            
            Divider()
            
            if accounts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Accounts")
                        .font(.headline)
                    Text("Click + to add your first Jira account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedAccount) {
                    ForEach(accounts) { account in
                        AccountRowView(account: account)
                            .tag(account)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddAccountSheet(modelContext: modelContext)
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let account = selectedAccount {
                    deleteAccount(account)
                }
            }
        } message: {
            Text("Are you sure you want to delete this account? All time entries will be deleted.")
        }
    }
    
    private func deleteAccount(_ account: JiraAccount) {
        modelContext.delete(account)
        try? modelContext.save()
        selectedAccount = nil
    }
}

struct AccountRowView: View {
    let account: JiraAccount
    @State private var isTestingConnection = false
    @State private var testResult: String?
    
    private let apiService = JiraAPIService()
    
    var body: some View {
        HStack {
            if let avatarURL = account.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.system(size: 13, weight: .semibold))
                
                if let username = account.username {
                    Text(username)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(account.baseURL)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(account.accountType.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    if account.isActive {
                        Text("Active")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if let result = testResult {
                        Text(result)
                            .font(.system(size: 10))
                            .foregroundColor(result.contains("✓") ? .green : .red)
                    }
                }
            }
            
            Spacer()
            
            Button(isTestingConnection ? "Testing..." : "Test") {
                testConnection()
            }
            .buttonStyle(.bordered)
            .disabled(isTestingConnection)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                let success = try await apiService.testConnection(for: account)
                await MainActor.run {
                    testResult = success ? "✓ OK" : "✗ Failed"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ Error"
                    isTestingConnection = false
                }
            }
        }
    }
}

struct AddAccountSheet: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var baseURL = ""
    @State private var email = ""
    @State private var apiToken = ""
    @State private var accountType: JiraAccount.AccountType = .cloud
    @State private var isTestingConnection = false
    @State private var testResult: String?
    
    private let apiService = JiraAPIService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Jira Account")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Picker("Account Type", selection: $accountType) {
                    Text("Cloud").tag(JiraAccount.AccountType.cloud)
                    Text("Data Center").tag(JiraAccount.AccountType.dataCenter)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)
                
                TextField("Account Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Jira Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                
                if accountType == .cloud {
                    Text("e.g., https://yourcompany.atlassian.net")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("e.g., https://jira.yourcompany.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if accountType == .cloud {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("API Token", text: $apiToken)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Create an API token at https://id.atlassian.com/manage-profile/security/api-tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    SecureField("Personal Access Token", text: $apiToken)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Create a PAT in Jira Data Center: Profile → Personal Access Tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("✓") ? .green : .red)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Test Connection") {
                    testConnection()
                }
                .buttonStyle(.bordered)
                .disabled(isTestingConnection || !isFormValid)
                
                Button("Add Account") {
                    addAccount()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private var isFormValid: Bool {
        if accountType == .cloud {
            return !name.isEmpty && !baseURL.isEmpty && !email.isEmpty && !apiToken.isEmpty
        } else {
            return !name.isEmpty && !baseURL.isEmpty && !apiToken.isEmpty
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                // Test connection directly without creating account
                let success = try await testJiraConnection(
                    baseURL: baseURL,
                    email: email,
                    apiToken: apiToken
                )
                
                await MainActor.run {
                    testResult = success ? "✓ Connection successful!" : "✗ Connection failed"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ Error: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func testJiraConnection(baseURL: String, email: String, apiToken: String) async throws -> Bool {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        
        let apiVersion = accountType == .dataCenter ? "2" : "3"
        guard let requestURL = URL(string: "\(url)/rest/api/\(apiVersion)/myself") else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if accountType == .dataCenter {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        } else {
            let authString = "\(email):\(apiToken)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    private func addAccount() {
        let account = JiraAccount(
            name: name,
            baseURL: baseURL,
            email: accountType == .cloud ? email : "",
            apiToken: "",
            accountType: accountType
        )
        
        modelContext.insert(account)
        
        do {
            try modelContext.save()
        } catch {
            dismiss()
            return
        }
        
        account.apiToken = apiToken
        
        Task {
            do {
                let userInfo = try await apiService.fetchUserInfo(for: account)
                await MainActor.run {
                    account.username = userInfo.username
                    account.avatarURL = userInfo.avatarURL
                    try? modelContext.save()
                }
            } catch {
            }
        }
        
        dismiss()
    }
}

#Preview {
    PreferencesView()
        .modelContainer(for: [JiraAccount.self], inMemory: true)
}

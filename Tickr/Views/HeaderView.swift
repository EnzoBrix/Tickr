import SwiftUI

struct HeaderView: View {
    let accounts: [JiraAccount]
    let selectedAccount: JiraAccount?
    let onAccountSelected: (JiraAccount) -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if accounts.isEmpty {
                Text("No accounts")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            } else {
                Menu {
                    ForEach(accounts) { account in
                        Button(action: {
                            onAccountSelected(account)
                        }) {
                            HStack {
                                Text(account.name)
                                if account.isActive {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedAccount?.name ?? "Select Account")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
            }
            
            Spacer()
            
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            
            SettingsLink {
                Image(systemName: "gear")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

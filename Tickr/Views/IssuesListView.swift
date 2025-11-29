import SwiftUI

struct IssuesListView: View {
    let issues: [JiraIssue]
    let isLoading: Bool
    let error: String?
    @ObservedObject var timerManager: TimerManager
    let onStartTimer: (JiraIssue) -> Void
    let onStopTimer: (String) -> Void
    let onCancelTimer: (String) -> Void
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading issues...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if let error = error {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.system(size: 14, weight: .semibold))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
            } else if issues.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("No Issues")
                        .font(.system(size: 14, weight: .semibold))
                    Text("You have no assigned issues")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(issues) { issue in
                            VStack(spacing: 0) {
                                IssueRowView(
                                    issue: issue,
                                    isTimerActive: timerManager.isTimerActive(for: issue.key),
                                    elapsedTime: timerManager.getElapsedTime(for: issue.key),
                                    onStartTimer: {
                                        onStartTimer(issue)
                                    },
                                    onStopTimer: {
                                        onStopTimer(issue.key)
                                    },
                                    onCancelTimer: {
                                        onCancelTimer(issue.key)
                                    }
                                )
                                
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct IssueRowView: View {
    let issue: JiraIssue
    let isTimerActive: Bool
    let elapsedTime: String
    let onStartTimer: () -> Void
    let onStopTimer: () -> Void
    let onCancelTimer: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(issue.key)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(issue.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.bottom, 6)
                
                HStack(spacing: 8) {
                    StatusBadge(status: issue.status, statusCategory: issue.statusCategory)
                    
                    if let priority = issue.priority {
                        Text(priority)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    if let timeSpent = issue.formattedTimeSpent {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 8))
                            Text(timeSpent)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.green)
                    }
                    
                    if isTimerActive {
                        Text(elapsedTime)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .cornerRadius(5)
                    }
                }
                
                if let parentKey = issue.parentKey, let parentSummary = issue.parentSummary {
                    HStack(spacing: 4) {
                        Text(parentKey)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(parentSummary)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if isTimerActive {
                HStack(spacing: 8) {
                    Button(action: onStopTimer) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Stop timer")
                    
                    Button(action: onCancelTimer) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel timer")
                }
            } else {
                Button(action: onStartTimer) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Start timer")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

struct StatusBadge: View {
    let status: String
    let statusCategory: String?
    
    var statusColor: Color {
        switch status.lowercased() {
        case "done", "closed", "resolved":
            return .green
        case "in progress", "in review", "in development":
            return .blue
        case "to do", "open", "backlog":
            return .gray
        default:
            break
        }
        
        if let category = statusCategory?.lowercased() {
            switch category {
            case "blue-gray", "inprogress":
                return .blue
            case "green", "success":
                return .green
            default:
                return .orange
            }
        }
        
        return .orange
    }
    
    var body: some View {
        Text(status)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor)
            .cornerRadius(4)
    }
}

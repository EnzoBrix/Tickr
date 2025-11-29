import Foundation
import SwiftData

@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var issueKey: String
    var issueSummary: String
    var startTime: Date
    var endTime: Date?
    var comment: String?
    var isSynced: Bool
    var syncedAt: Date?
    var worklogId: String?
    
    var account: JiraAccount?
    
    init(
        id: UUID = UUID(),
        issueKey: String,
        issueSummary: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        comment: String? = nil,
        isSynced: Bool = false,
        account: JiraAccount? = nil
    ) {
        self.id = id
        self.issueKey = issueKey
        self.issueSummary = issueSummary
        self.startTime = startTime
        self.endTime = endTime
        self.comment = comment
        self.isSynced = isSynced
        self.account = account
    }
    
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var isRunning: Bool {
        endTime == nil
    }
}

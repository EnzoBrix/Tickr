import Foundation

nonisolated
struct JiraIssue: Identifiable, Codable {
    let id: String
    let key: String
    let summary: String
    let status: String
    let statusCategory: String?
    let assignee: String?
    let priority: String?
    let issueType: String
    let timeSpentSeconds: Int?
    let parentKey: String?
    let parentSummary: String?
    
    var displayName: String {
        "\(key): \(summary)"
    }
    
    var formattedTimeSpent: String? {
        guard let seconds = timeSpentSeconds, seconds > 0 else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

nonisolated
struct JiraIssuesResponse: Codable, Sendable {
    let issues: [JiraIssueAPI]
    let total: Int?
    let isLast: Bool?
}

nonisolated
struct JiraIssueAPI: Codable, Sendable {
    let id: String
    let key: String
    let fields: JiraFields
}

nonisolated
struct JiraFields: Codable, Sendable {
    let summary: String
    let status: JiraStatus
    let assignee: JiraUser?
    let priority: JiraPriority?
    let issuetype: JiraIssueType
    let timetracking: JiraTimeTracking?
    let parent: JiraParent?
}

nonisolated
struct JiraParent: Codable, Sendable {
    let key: String
    let fields: JiraParentFields
}

nonisolated
struct JiraParentFields: Codable, Sendable {
    let summary: String
}

nonisolated
struct JiraTimeTracking: Codable, Sendable {
    let timeSpentSeconds: Int?
}

nonisolated
struct JiraStatus: Codable, Sendable {
    let name: String
    let statusCategory: JiraStatusCategory?
}

nonisolated
struct JiraStatusCategory: Codable, Sendable {
    let colorName: String
}

nonisolated
struct JiraUser: Codable, Sendable {
    let displayName: String
    let emailAddress: String?
}

nonisolated
struct JiraPriority: Codable, Sendable {
    let name: String
}

nonisolated
struct JiraIssueType: Codable, Sendable {
    let name: String
}

nonisolated
struct JiraWorklogRequest: Codable, Sendable {
    let timeSpentSeconds: Int
    let started: String // ISO 8601 format
    let comment: JiraWorklogComment?
    
    nonisolated
    struct JiraWorklogComment: Codable, Sendable {
        let type: String
        let version: Int
        let content: [ContentNode]
        
        nonisolated
        struct ContentNode: Codable, Sendable {
            let type: String
            let content: [TextNode]
            
            nonisolated
            struct TextNode: Codable, Sendable {
                let type: String
                let text: String
            }
        }
    }
}

nonisolated
struct JiraWorklogResponse: Codable, Sendable {
    let id: String
    let issueId: String
    let timeSpentSeconds: Int
}

extension JiraIssue {
    nonisolated init(from apiIssue: JiraIssueAPI) {
        self.id = apiIssue.id
        self.key = apiIssue.key
        self.summary = apiIssue.fields.summary
        self.status = apiIssue.fields.status.name
        self.statusCategory = apiIssue.fields.status.statusCategory?.colorName
        self.assignee = apiIssue.fields.assignee?.displayName
        self.priority = apiIssue.fields.priority?.name
        self.issueType = apiIssue.fields.issuetype.name
        self.timeSpentSeconds = apiIssue.fields.timetracking?.timeSpentSeconds
        self.parentKey = apiIssue.fields.parent?.key
        self.parentSummary = apiIssue.fields.parent?.fields.summary
    }
}

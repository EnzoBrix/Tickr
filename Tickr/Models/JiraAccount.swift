import Foundation
import SwiftData

@Model
final class JiraAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var email: String
    var accountType: AccountType
    var isActive: Bool
    var createdAt: Date
    var lastSyncedAt: Date?
    var username: String?
    var avatarURL: String?
    
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.account)
    var timeEntries: [TimeEntry]?
    
    enum AccountType: String, Codable {
        case cloud = "Cloud"
        case dataCenter = "Data Center"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        email: String,
        apiToken: String,
        accountType: AccountType = .cloud,
        isActive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.email = email
        self.accountType = accountType
        self.isActive = isActive
        self.createdAt = createdAt
    }
    
    var keychainKey: String {
        if accountType == .dataCenter {
            return "pat@\(baseURL)"
        } else {
            return "\(email)@\(baseURL)"
        }
    }
    
    var apiToken: String {
        get {
            (try? KeychainManager.shared.retrieveToken(forKey: keychainKey)) ?? ""
        }
        set {
            try? KeychainManager.shared.saveToken(newValue, forKey: keychainKey)
        }
    }
    
    var apiVersion: String {
        accountType == .dataCenter ? "2" : "3"
    }
    
    var sanitizedBaseURL: String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }
    
}

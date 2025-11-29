import Foundation

enum JiraAPIError: LocalizedError {
    case invalidURL
    case invalidCredentials
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Jira URL"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .unauthorized:
            return "Unauthorized. Please check your API token."
        }
    }
}

actor JiraAPIService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    private func addAuthentication(to request: inout URLRequest, for account: JiraAccount) {
        if account.accountType == .dataCenter {
            request.setValue("Bearer \(account.apiToken)", forHTTPHeaderField: "Authorization")
        } else {
            let authString = "\(account.email):\(account.apiToken)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            }
        }
    }
    
    func fetchAssignedIssues(for account: JiraAccount) async throws -> [JiraIssue] {
        let endpoint: String
        if account.accountType == .cloud {
            endpoint = "/rest/api/3/search/jql"
        } else {
            endpoint = "/rest/api/2/search"
        }
        
        let jql = "assignee = currentUser()"
        
        var components = URLComponents(string: account.sanitizedBaseURL + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "maxResults", value: "30"),
            URLQueryItem(name: "fields", value: "summary,status,assignee,priority,issuetype,timetracking,parent")
        ]
        
        guard let url = components?.url else {
            throw JiraAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        addAuthentication(to: &request, for: account)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw JiraAPIError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let issuesResponse = try JSONDecoder().decode(JiraIssuesResponse.self, from: data)
                return issuesResponse.issues.map { JiraIssue(from: $0) }
            case 401:
                throw JiraAPIError.unauthorized
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw JiraAPIError.serverError(httpResponse.statusCode, errorMessage)
            }
        } catch let error as JiraAPIError {
            throw error
        } catch let error as DecodingError {
            throw JiraAPIError.decodingError(error)
        } catch {
            throw JiraAPIError.networkError(error)
        }
    }
    
    func submitWorklog(
        issueKey: String,
        timeSpentSeconds: Int,
        startedAt: Date,
        for account: JiraAccount
    ) async throws -> String {
        
        let endpoint = "/rest/api/\(account.apiVersion)/issue/\(issueKey)/worklog"
        
        guard let url = URL(string: account.sanitizedBaseURL + endpoint) else {
            throw JiraAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        addAuthentication(to: &request, for: account)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let startedString = formatter.string(from: startedAt)
        
        let adjustedSeconds = max(timeSpentSeconds, 60)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData: Data
        if account.accountType == .dataCenter {
            let worklogRequest = JiraWorklogRequestDataCenter(
                timeSpentSeconds: adjustedSeconds,
                started: startedString,
                comment: "Work logged via Tickr"
            )
            jsonData = try encoder.encode(worklogRequest)
        } else {
            let commentObj = JiraWorklogRequest.JiraWorklogComment(
                type: "doc",
                version: 1,
                content: [
                    JiraWorklogRequest.JiraWorklogComment.ContentNode(
                        type: "paragraph",
                        content: [
                            JiraWorklogRequest.JiraWorklogComment.ContentNode.TextNode(
                                type: "text",
                                text: "Work logged via Tickr"
                            )
                        ]
                    )
                ]
            )
            let worklogRequest = JiraWorklogRequest(
                timeSpentSeconds: adjustedSeconds,
                started: startedString,
                comment: commentObj
            )
            jsonData = try encoder.encode(worklogRequest)
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraAPIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let worklogResponse = try JSONDecoder().decode(JiraWorklogResponse.self, from: data)
            return worklogResponse.id
        case 401:
            throw JiraAPIError.unauthorized
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw JiraAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    func testConnection(for account: JiraAccount) async throws -> Bool {
        let endpoint = "/rest/api/\(account.apiVersion)/myself"
        
        guard let url = URL(string: account.sanitizedBaseURL + endpoint) else {
            throw JiraAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        addAuthentication(to: &request, for: account)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            throw JiraAPIError.networkError(error)
        }
    }
    
    func fetchUserInfo(for account: JiraAccount) async throws -> (username: String, avatarURL: String?) {
        let endpoint = "/rest/api/\(account.apiVersion)/myself"
        
        guard let url = URL(string: account.sanitizedBaseURL + endpoint) else {
            throw JiraAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        addAuthentication(to: &request, for: account)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraAPIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            throw JiraAPIError.serverError(httpResponse.statusCode, "Failed to fetch user info")
        }
        
        let userInfo = try JSONDecoder().decode(JiraUserInfo.self, from: data)
        return (userInfo.displayName, userInfo.avatarUrls.the48X48)
    }
}

nonisolated
struct JiraWorklogRequestDataCenter: Codable {
    let timeSpentSeconds: Int
    let started: String
    let comment: String
}

nonisolated
struct JiraUserInfo: Codable {
    let displayName: String
    let avatarUrls: JiraAvatarUrls
    
    nonisolated
    struct JiraAvatarUrls: Codable {
        let the48X48: String?
        
        enum CodingKeys: String, CodingKey {
            case the48X48 = "48x48"
        }
    }
}

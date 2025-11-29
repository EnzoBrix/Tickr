import Foundation
import SwiftData
import Combine

@MainActor
class TimerManager: ObservableObject {
    @Published var activeTimers: [TimeEntry] = []
    @Published var elapsedTimes: [UUID: TimeInterval] = [:]
    
    private var timerSubscription: AnyCancellable?
    private let modelContext: ModelContext
    private let apiService: JiraAPIService
    
    var onTimerUpdated: (() -> Void)?
    
    init(modelContext: ModelContext, apiService: JiraAPIService = JiraAPIService()) {
        self.modelContext = modelContext
        self.apiService = apiService
        loadActiveTimers()
    }
    
    func getElapsedTime(for issueKey: String) -> String {
        guard let timer = activeTimers.first(where: { $0.issueKey == issueKey }),
              let elapsed = elapsedTimes[timer.id] else {
            return "00:00:00"
        }
        
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) / 60 % 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func isTimerActive(for issueKey: String) -> Bool {
        activeTimers.contains(where: { $0.issueKey == issueKey })
    }
    
    func startTimer(for issue: JiraIssue, account: JiraAccount) {
        if activeTimers.contains(where: { $0.issueKey == issue.key }) {
            return
        }
        
        let accountId = account.id
        let descriptor = FetchDescriptor<JiraAccount>(
            predicate: #Predicate<JiraAccount> { acc in
                acc.id == accountId
            }
        )
        
        guard let persistedAccount = try? modelContext.fetch(descriptor).first else {
            return
        }
        
        let entry = TimeEntry(
            issueKey: issue.key,
            issueSummary: issue.summary,
            startTime: Date(),
            account: persistedAccount
        )
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
        } catch {
            return
        }
        
        activeTimers.append(entry)
        elapsedTimes[entry.id] = 0
        startTimerUpdates()
    }
    
    func stopTimer(for issueKey: String) async throws {
        guard let timer = activeTimers.first(where: { $0.issueKey == issueKey }) else {
            throw TimerError.noActiveTimer
        }
        
        guard let account = timer.account else {
            throw TimerError.noActiveTimer
        }
        
        timer.endTime = Date()
        try? modelContext.save()
        
        let duration = timer.endTime!.timeIntervalSince(timer.startTime)
        let seconds = Int(duration)
        
        do {
            let worklogId = try await apiService.submitWorklog(
                issueKey: timer.issueKey,
                timeSpentSeconds: seconds,
                startedAt: timer.startTime,
                for: account
            )
            
            timer.worklogId = worklogId
            timer.worklogId = worklogId
            timer.isSynced = true
            timer.syncedAt = Date()
            
            try? modelContext.save()
        } catch {
            throw error
        }
        
        activeTimers.removeAll(where: { $0.id == timer.id })
        elapsedTimes.removeValue(forKey: timer.id)
        
        if activeTimers.isEmpty {
            stopTimerUpdates()
        }
        
        onTimerUpdated?()
    }
    
    func cancelTimer(for issueKey: String) {
        guard let timer = activeTimers.first(where: { $0.issueKey == issueKey }) else { return }
        
        modelContext.delete(timer)
        try? modelContext.save()
        
        activeTimers.removeAll(where: { $0.id == timer.id })
        elapsedTimes.removeValue(forKey: timer.id)
        
        if activeTimers.isEmpty {
            stopTimerUpdates()
        }
    }
    
    private func loadActiveTimers() {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        if let timers = try? modelContext.fetch(descriptor) {
            activeTimers = timers
            for timer in timers {
                elapsedTimes[timer.id] = timer.duration
            }
            if !timers.isEmpty {
                startTimerUpdates()
            }
        }
    }
    
    private func startTimerUpdates() {
        guard timerSubscription == nil else { return }
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTimes()
            }
    }
    
    private func stopTimerUpdates() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    private func updateElapsedTimes() {
        for timer in activeTimers {
            elapsedTimes[timer.id] = timer.duration
        }
    }
}

enum TimerError: LocalizedError {
    case noActiveTimer
    case alreadyRunning
    
    var errorDescription: String? {
        switch self {
        case .noActiveTimer:
            return "No active timer to submit"
        case .alreadyRunning:
            return "A timer is already running"
        }
    }
}

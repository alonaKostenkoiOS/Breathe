import Foundation
import BreatheCore

actor LocalCoachSessionStore: CoachSessionStoring {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL; return }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = base.appendingPathComponent("Breathe", isDirectory: true).appendingPathComponent("coach_sessions_v1.json")
    }

    func all() throws -> [CoachSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([CoachSession].self, from: Data(contentsOf: fileURL))
            .sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ session: CoachSession) throws {
        var sessions = try all()
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }
}

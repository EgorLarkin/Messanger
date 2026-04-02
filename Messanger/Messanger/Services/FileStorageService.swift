import Foundation

final class FileStorageService {
    static let shared = FileStorageService()

    private init() { }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func saveDownloadedFile(data: Data, fileName: String) throws -> URL {
        let safeName = sanitizedFileName(fileName)
        let destinationURL = uniqueDestinationURL(for: safeName)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let baseURL = documentsDirectory.appendingPathComponent(fileName)

        if !FileManager.default.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        let ext = baseURL.pathExtension
        let name = baseURL.deletingPathExtension().lastPathComponent
        var counter = 1

        while true {
            let candidateName = ext.isEmpty
                ? "\(name) (\(counter))"
                : "\(name) (\(counter)).\(ext)"

            let candidateURL = documentsDirectory.appendingPathComponent(candidateName)

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            counter += 1
        }
    }

    private func sanitizedFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "file" : trimmed
    }
}

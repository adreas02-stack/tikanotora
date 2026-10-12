import Foundation

/// Στέλνει μια καταγραφή στο Google Form → γράφεται αυτόματα στο Google Sheet.
enum FormUploader {
    private static let allowed = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    static func send(_ entry: LogEntry) async -> Bool {
        guard Settings.isFormConfigured, let url = URL(string: Settings.formURL) else { return false }

        let fields = [
            (Settings.entryCategory, entry.category),
            (Settings.entrySub, entry.subcategory),
            (Settings.entryTime, timeFormatter.string(from: entry.date))
        ]
        let body = fields.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 20

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

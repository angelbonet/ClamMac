import Foundation

public enum Pushover {
    public static func send(title: String, message: String, user: String, token: String) async {
        guard !user.isEmpty, !token.isEmpty, let url = URL(string: "https://api.pushover.net/1/messages.json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var c = URLComponents()
        c.queryItems = [.init(name: "token", value: token), .init(name: "user", value: user),
                        .init(name: "title", value: title), .init(name: "message", value: message)]
        req.httpBody = c.percentEncodedQuery?.data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}

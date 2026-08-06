import Alamofire
import Foundation

/// Alamofire 接线的活范例:只构造请求,不发网络
enum PingRequestBuilder {
    static func makeSearchRequest(query: String) throws -> URLRequest {
        let request = try URLRequest(url: "https://example.com/search", method: .get)
        return try URLEncodedFormParameterEncoder.default.encode(["q": query], into: request)
    }
}

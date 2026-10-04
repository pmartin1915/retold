import Foundation

/// Real FileProtector: Data Protection via FileManager.setAttributes.
struct FileManagerProtector: FileProtector {
    func protect(_ url: URL, as type: FileProtectionType) throws {
        try FileManager.default.setAttributes([.protectionKey: type], ofItemAtPath: url.path)
    }
}

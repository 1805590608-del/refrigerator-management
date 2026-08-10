import Foundation
import ObjectiveC
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: rawValue)
        case .simplifiedChinese:
            Locale(identifier: rawValue)
        }
    }

    var resourceName: String? {
        switch self {
        case .system:
            nil
        case .english:
            rawValue
        case .simplifiedChinese:
            rawValue
        }
    }
}

enum AppLanguageStorage {
    static let key = "appLanguage"
}

enum AppLanguageController {
    static func apply(_ rawValue: String) {
        let language = AppLanguage(rawValue: rawValue) ?? .system
        Bundle.main.setLanguageResource(named: language.resourceName)
    }
}

private var languageBundleKey: UInt8 = 0

private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

private extension Bundle {
    func setLanguageResource(named resourceName: String?) {
        object_setClass(self, LocalizedBundle.self)

        guard
            let resourceName,
            let path = path(forResource: resourceName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            objc_setAssociatedObject(self, &languageBundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        objc_setAssociatedObject(self, &languageBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

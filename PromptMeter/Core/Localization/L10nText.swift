import SwiftUI

extension Text {
    init(_ key: L10nKey) {
        self.init(verbatim: L10n.tr(key))
    }
}

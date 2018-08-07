//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit
import PassKit

/**
 * An object representing the contents of a PassKit pass.
 */

@objc final class WalletPassViewModel: NSObject {

    /// The pass represented in the view..
    @objc let rawPass: PKPass

    /// Creates a new pass view model from the pass.
    init(pass: PKPass) {
        self.rawPass = pass
    }

    // MARK: - Properties

    /// The title of the pass (describes the pass type).
    @objc var title: String {
        return rawPass.localizedName
    }

    /// The entity that issued the pass.
    @objc var issuer: String {
        return rawPass.organizationName
    }

    /// The icon of the pass.
    @objc var icon: UIImage {
        return rawPass.icon
    }

    /// The URL to the pass in the Wallet app.
    @objc var url: URL? {
        return rawPass.passURL
    }

    /// Whether the pass was already added to the library.
    @objc var isAdded: Bool {
        return PKPassLibrary().containsPass(rawPass)
    }

}

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

import Foundation

extension ConversationContentViewController: PopoverPresenter { }

extension ConversationContentViewController {
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator?) {

        guard let coordinator = coordinator else { return }

        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.updatePopoverSourceRect()
        }
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass else { return }

        shareViewControllerWrapper?.resizeDisabled = isIPadRegular()

        ///TODO: need this?
//        guard !self.inRotation else { return }

        updatePopoverSourceRect()
    }

    @objc func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameDidChange(notification:)),
                                               name: NSNotification.Name.UIKeyboardDidChangeFrame,
                                               object: nil)

    }

    @objc func keyboardFrameDidChange(notification: Notification) {
        updatePopoverSourceRect()
    }
}

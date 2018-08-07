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

public protocol PopoverPresenter: class {

    /// The presenting popover. Its frame should be updated when the orientation or screen size changes.
    var presentedPopover: UIPopoverPresentationController? {get set}

    /// The popover's arrow points to this view
    var popoverPointToView: UIView? {get set}

    /// Call this method when screen size changes, e.g. when viewWillTransition, keyboard appear
    func updatePopoverSourceRect()
}

///TODO: keyboard mv to LHS when out of bound.
extension PopoverPresenter where Self: UIViewController {
    public func updatePopoverSourceRect() {
        guard let presentedPopover = presentedPopover,
              let popoverPointToView = popoverPointToView else { return }

        presentedPopover.sourceRect = popoverPointToView.popoverSourceRect(from: self)
    }
}


extension UIPopoverPresentationController {


    /// Config a UIPopoverPresentationController with support of device orientation changing and source rect calculation
    ///
    /// - Parameters:
    ///   - popoverPresenter: the PopoverPresenter which presents this popover, usually a UIViewController
    ///   - pointToView: the view that the popover's points to
    ///   - sourceView: the source View of the popover
    ///   - backgroundColor: background color of the popover
    ///   - permittedArrowDirections: permittedArrowDirections of the popover
    public func config(from popoverPresenter: PopoverPresenter,
                             pointToView: UIView,
                             sourceView: UIView,
                             backgroundColor: UIColor? = nil,
                             permittedArrowDirections: UIPopoverArrowDirection = .down) {

        if let viewController = popoverPresenter as? UIViewController {
            sourceRect = pointToView.popoverSourceRect(from: viewController)
        }

        popoverPresenter.presentedPopover = self
        popoverPresenter.popoverPointToView = pointToView

        self.sourceView = sourceView
        
        if let backgroundColor = backgroundColor {
            self.backgroundColor = backgroundColor
        }
        self.permittedArrowDirections = permittedArrowDirections
    }
}

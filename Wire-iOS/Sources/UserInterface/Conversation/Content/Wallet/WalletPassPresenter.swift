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

/// The callback providing the parsed pass for the message.
typealias WalletPassPresenterParsingCallback = (ZMMessage, WalletPassViewModel?) -> Void

/**
 * An object that parses and presents Wallet passes.
 */

@objc class WalletPassPresenter: NSObject, ZMMessageObserver {

    let urlOpener: URLOpener = UIApplication.shared

    private var pendingMessages: [ZMMessage: WalletPassPresenterParsingCallback] = [:]
    private var cache: [ZMMessage: WalletPassViewModel] = [:]
    private var messageObserverTokens: [ZMMessage: Any] = [:]
    private let parseQueue = DispatchQueue(label: "WalletPassPresenter.ParsePass")

    // MARK: - Parsing

    /**
     * Attempts to parse the Wallet pass in the message.
     */

    @objc func parsePass(for message: ZMMessage, completionHandler: @escaping WalletPassPresenterParsingCallback) {
        // If we cached the result, return the cached result
        if let viewModel = cache[message] {
            completionHandler(message, viewModel)
            return
        }

        // If we already downloaded the fiel, start parsing
        if let url = urlForPass(in: message) {
            parsePassFromURL(url, completionHandler: completionHandler)
            return
        }

        // Otherwise, schedule a download and parse the pass

        guard let userSession = ZMUserSession.shared() else {
            completionHandler(message, nil)
            return
        }

        guard let fileMetadata = message.fileMessageData else {
            completionHandler(message, nil)
            return
        }

        guard !pendingMessages.keys.contains(message) else {
            return
        }

        let messageToken = MessageChangeInfo.add(observer: self, for: message, userSession: userSession)
        messageObserverTokens[message] = messageToken
        pendingMessages[message] = completionHandler

        message.requestDownload()
    }

    private func parsePassFromURL(_ fileURL: URL, message: ZMMessage, completionHandler: @escaping WalletPassPresenterParsingCallback) {
        parseQueue.async {
            guard let data = try? Data(contentsOf: fileURL) else {
                DispatchQueue.main.async { completionHandler(message, nil) }
                return
            }

            var error: NSError? = nil
            let pass = PKPass(data: data, error: &error)

            guard error == nil else {
                DispatchQueue.main.async { completionHandler(message, nil) }
                return
            }

            let viewModel = WalletPassViewModel(rawPass: pass)
            DispatchQueue.main.async { completionHandler(message, viewModel) }
        }
    }

    @objc func openPass(for message: ZMMessage, completionHandler: @escaping (PKAddPassesViewController?) -> Void) {
        guard let viewModel = cache[message] else {
            completionHandler(nil)
            return
        }

        if let localPassURL = viewModel.url && urlOpener.canOpenURL(localPassURL) {
            guard urlOpener.openURL(localPassURL) == true else {
                completionHandler(nil)
                return
            }
        }

        guard let viewController = PKAddPassesViewController(pass: viewModel.rawPass) else {
            completionHandler(nil)
            return
        }

    }

    // MARK: - ZMMessageObserver

    func messageDidChange(_ changeInfo: MessageChangeInfo) {
        let message = changeInfo.message

        guard let fileMessageData = message.fileMessageData,
            let completionHandler = pendingMessages[message],
            fileMessageData.transferState == .downloaded,
            let fileURL = fileMessageData.fileURL,
            fileURL.isFileURL,
            message.isWalletPass else {
                return
        }

        self.parsePassFromURL(fileURL, completionHandler: completionHandler)
    }

    private func urlForPass(in message: ZMMessage) -> URL? {
        guard message.isWalletPass else {
            return nil
        }

        guard let url = message.fileMessageData?.fileURL, url.isFileURL == true else {
            return nil
        }

        return url
    }

}

// MARK: - Helpers

extension ZMConversationMessage {

    /// Whether the message contains a Wallet pass.
    var isWalletPass: Bool {
        return fileMessageData?.isWalletPass == true
    }

}

extension ZMFileMessageData {

    /// Whether the message contains a Wallet pass.
    var isWalletPass: Bool {
        return mimeType == "application/vnd.apple.pkpass"
    }

}

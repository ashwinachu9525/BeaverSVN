//
//  RepoRefreshController.swift
//  FreeSVN
//
//  Created by Aswin K on 03/04/26.
//

import Foundation
import AppKit

final class RepoRefreshController {

    private var timer: Timer?

    func start(interval: TimeInterval, action: @escaping () -> Void) {

        timer?.invalidate()

        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in

            guard NSApp.isActive else { return }

            action()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

//
//  RepoWatcher.swift
//  FreeSVN
//
//  Created by Aswin K on 02/04/26.
//
import Foundation
import Combine

class RepoWatcher: ObservableObject {

    private var watcher: DispatchSourceFileSystemObject?
    private var monitoredFileDescriptor: Int32 = -1
    private var callback: (() -> Void)?

    /// Start watching a folder for changes
    func startWatching(path: String, callback: @escaping () -> Void) {
        stopWatching() // Stop any existing watcher first

        self.callback = callback

        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open path: \(path)")
            return
        }
        monitoredFileDescriptor = fileDescriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global()
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.callback?()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.monitoredFileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.monitoredFileDescriptor = -1
        }

        watcher = source
        source.resume()
    }

    /// Stop watching
    func stopWatching() {
        watcher?.cancel()
        watcher = nil
    }

    deinit {
        stopWatching()
    }
}

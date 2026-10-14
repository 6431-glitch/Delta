//
//  LoadImageURLOperation.swift
//  Delta
//
//  Created by Riley Testut on 10/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import ImageIO

import Nuke

import Roxas

extension LoadImageURLOperation
{
    enum Error: Swift.Error
    {
        case doesNotExist
        case invalid
        case downloadFailed(Swift.Error)
    }
}

class LoadImageURLOperation: RSTLoadOperation<UIImage, NSURL>, @unchecked Sendable
{
    let url: URL
    
    override var isAsynchronous: Bool {
        return !self.url.isFileURL
    }
    
    private let taskLock = NSLock()
    private var downloadOperation: ImageTask?
    private var didFinish = false
    // Only accessed on the main queue, as required by UIApplication.
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    init(url: URL)
    {
        self.url = url
        
        super.init(cacheKey: url as NSURL)
    }
    
    override func cancel()
    {
        super.cancel()
        
        taskLock.lock()
        let task = downloadOperation
        downloadOperation = nil
        taskLock.unlock()
        task?.cancel()
        DispatchQueue.main.async { self.endBackgroundTask() }
        
        if self.isAsynchronous
        {
            self.finish()
        }
    }
    
    override func loadResult(completion: @escaping (UIImage?, Swift.Error?) -> Void)
    {
        let callback = { (image: UIImage?, error: Error?) in
            
            if self.url.isFileURL, let image = image, !self.isCancelled
            {
                // Force decompression of image
                UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1.0)
                image.draw(at: CGPoint.zero)
                UIGraphicsEndImageContext()
            }
            
            completion(image, error)
        }
        
        if self.url.isFileURL
        {
            self.loadLocalImage(completion: callback)
        }
        else
        {
            self.loadRemoteImage(completion: callback)
        }
    }
    
    private func loadLocalImage(completion: @escaping (UIImage?, Error?) -> Void)
    {
        guard let imageSource = CGImageSourceCreateWithURL(self.url as CFURL, nil) else {
            completion(nil, .doesNotExist)
            return
        }
        
        guard let quartzImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            completion(nil, .invalid)
            return
        }
        
        let image = UIImage(cgImage: quartzImage)
        completion(image, nil)
    }
    
    private func loadRemoteImage(completion: @escaping (UIImage?, Error?) -> Void)
    {
        DispatchQueue.main.async {
            guard !self.isCancelled else { return }
            self.backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in self?.cancel() }
            let task = ArtworkImagePipeline.shared.loadImage(with: ArtworkImagePipeline.request(for: self.url)) { result in
                self.taskLock.lock()
                self.downloadOperation = nil
                self.taskLock.unlock()
                self.endBackgroundTask()
                switch result {
                case .success(let response): completion(response.image, nil)
                case .failure(let error): completion(nil, .downloadFailed(error))
                }
            }
            self.taskLock.lock()
            if self.isCancelled {
                self.taskLock.unlock()
                task.cancel()
                self.endBackgroundTask()
            } else {
                self.downloadOperation = task
                self.taskLock.unlock()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    override func finish() {
        taskLock.lock()
        guard !didFinish else { taskLock.unlock(); return }
        didFinish = true
        taskLock.unlock()
        super.finish()
    }
}

//
//  ImageCacheManager.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/28/25.
//

import UIKit

final class ImageCacheManager: CacheManageable {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func fetch(for url: String) async -> UIImage? {
        let key = NSString(string: url)
        if let cacheImage = cache.object(forKey: key) { return cacheImage }
        
        if let diskImage = loadFromDisk(for: url) {
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        guard let imageURL = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: data) else { return nil }
            
            save(image, for: url)
            return image
        } catch {
            NSLog("이미지 다운로드 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    func save(_ image: UIImage, for key: String) {
        let url = NSString(string: key)
        cache.setObject(image, forKey: url)
        
        if let data = image.pngData() { saveToDisk(data, for: key) }
    }
    
    // MARK: Private methods
    
    private func loadFromDisk(for url: String) -> UIImage? {
        guard let diskCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first,
              let imageURL = URL(string: url)
        else { return nil }
        
        var filePath = URL(filePath: diskCachePath)
        filePath.append(path: imageURL.lastPathComponent)
        
        guard FileManager.default.fileExists(atPath: filePath.path()),
              let imageData = try? Data(contentsOf: filePath),
              let image = UIImage(data: imageData)
        else { return nil }
        
        return image
    }
    
    private func saveToDisk(_ data: Data, for url: String) {
        guard let diskCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first,
              let imageURL = URL(string: url)
        else { return }
        
        var filePath = URL(filePath: diskCachePath)
        filePath.append(path: imageURL.lastPathComponent)
        
        FileManager.default.createFile(atPath: filePath.path(), contents: data)
    }
}

//
//  ImageCacheManager.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/28/25.
//

import UIKit

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func fetchImage(for url: String) async ->  UIImage? {
        let key = NSString(string: url)
        
        if let cachedImage = cache.object(forKey: key) { return cachedImage }
        guard let imageURL = URL(string: url) else { return nil }
        
        if let diskCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            var filePath = URL(filePath: diskCachePath)
            filePath.append(path: imageURL.lastPathComponent)
            
            if !FileManager.default.fileExists(atPath: filePath.path()) {
                // TODO: 중복되는 로직이 많아서 수정해야함
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    FileManager.default.createFile(atPath: filePath.path(), contents: data)
                    
                    guard let image = UIImage(data: data) else { return nil }
                    
                    cache.setObject(image, forKey: key)
                    return image
                } catch {
                    NSLog("이미지 다운로드 실패: \(error.localizedDescription)")
                }
            } else {
                guard let imageData = try? Data(contentsOf: filePath) else {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: imageURL)
                        guard let image = UIImage(data: data) else { return nil }
                        
                        cache.setObject(image, forKey: key)
                        return image
                    } catch {
                        NSLog("이미지 다운로드 실패: \(error.localizedDescription)")
                    }
                    return nil
                }
                
                guard let image = UIImage(data: imageData) else { return nil }
                
                cache.setObject(image, forKey: key)
                return image
            }
        }
        
        return nil
    }
}

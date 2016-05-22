//
//  FlickrSearcher.swift
//  flickrSearch
//
//  Created by Richard Turton on 31/07/2014.
//  Copyright (c) 2014 Razeware. All rights reserved.
//

import Foundation
import UIKit

let apiKey = "a0a1f8f83bd9c2cad9c18651f9fe50e6"

struct FlickrSearchResults {
  let searchTerm : String
  let searchResults : [FlickrPhoto]
}

class FlickrPhoto : Equatable {
  let photoID : String
  let title: String
  private let farm : Int
  private let server : String
  private let secret : String
  
  typealias ImageLoadCompletion = (image: UIImage?, error: NSError?) -> Void
  
  init (photoID:String, title:String, farm:Int, server:String, secret:String) {
    self.photoID = photoID
    self.title = title
    self.farm = farm
    self.server = server
    self.secret = secret
  }
  
  func flickrImageURL(size:String = "m") -> NSURL {
    return NSURL(string: "http://farm\(farm).staticflickr.com/\(server)/\(photoID)_\(secret)_\(size).jpg")!
  }
  
  func loadThumbnail(completion: ImageLoadCompletion) {
    if let image = ImageCache.sharedCache.imageForKey(photoID) {
      completion(image: image, error: nil)
    } else {
        loadImageFromURL(URL: flickrImageURL("m")) { image, error in
            if let image = image {
                ImageCache.sharedCache.setImage(image, forKey: self.photoID)
            }
            completion(image: image, error: error)
        }
        
    }
    
  }
  
  func loadLargeImage(completion: ImageLoadCompletion) {
    loadImageFromURL(URL: flickrImageURL("b"), completion: completion)
  }
  
  func loadImageFromURL(URL URL: NSURL, completion: ImageLoadCompletion) {
    let loadRequest = NSURLRequest(URL: URL)
    NSURLConnection.sendAsynchronousRequest(loadRequest,
      queue: NSOperationQueue.mainQueue()) {
        response, data, error in
        
        if error != nil {
          completion(image: nil, error: error)
          return
        }
        
        if data != nil {
          completion(image: UIImage(data: data!), error: nil)
          return
        }
        
        completion(image: nil, error: nil)
    }
  }
}


extension FlickrPhoto {
  var isFavourite: Bool {
    get {
      return NSUserDefaults.standardUserDefaults().boolForKey(photoID)
    }
    set {
      NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: photoID)
    }
  }
}

func == (lhs: FlickrPhoto, rhs: FlickrPhoto) -> Bool {
  return lhs.photoID == rhs.photoID
}

class Flickr {
  
  let processingQueue = NSOperationQueue()
  
  func searchFlickrForTerm(searchTerm: String, completion : (results: FlickrSearchResults?, error : NSError?) -> Void){
    
    let searchURL = flickrSearchURLForSearchTerm(searchTerm)
    let searchRequest = NSURLRequest(URL: searchURL)
    
    NSURLConnection.sendAsynchronousRequest(searchRequest, queue: processingQueue) {response, data, error in
      if error != nil {
        completion(results: nil,error: error)
        return
      }
      
      var resultsDictionary = NSDictionary()
      print("\(resultsDictionary) resultsDic created")
      
      do {
        resultsDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options:NSJSONReadingOptions(rawValue: 0)) as! NSDictionary
        print(resultsDictionary.count)
      } catch let JSONError as NSError {
        completion(results: nil, error: JSONError)
        print(JSONError)
        return
        
      }
      
      switch (resultsDictionary["stat"] as! String) {
      case "ok":
        print("Results processed OK")
      case "fail":
        let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:resultsDictionary["message"]!])
        completion(results: nil, error: APIError)
        return
      default:
        let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
        completion(results: nil, error: APIError)
        return
      }
      
      let photosContainer = resultsDictionary["photos"] as! NSDictionary
      let photosReceived = photosContainer["photo"] as! [NSDictionary]
      
      let flickrPhotos : [FlickrPhoto] = photosReceived.map {
        photoDictionary in
        
        let photoID = photoDictionary["id"] as? String ?? ""
        let title = photoDictionary["title"] as? String ?? ""
        let farm = photoDictionary["farm"] as? Int ?? 0
        let server = photoDictionary["server"] as? String ?? ""
        let secret = photoDictionary["secret"] as? String ?? ""
        
        let flickrPhoto = FlickrPhoto(photoID: photoID, title: title, farm: farm, server: server, secret: secret)
        
        return flickrPhoto
      }
      
      dispatch_async(dispatch_get_main_queue(), {
        completion(results:FlickrSearchResults(searchTerm: searchTerm, searchResults: flickrPhotos), error: nil)
      })
    }
  }
  
  private func flickrSearchURLForSearchTerm(searchTerm:String) -> NSURL {
    
    let escapedTerm = searchTerm.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
    
    let URLString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(escapedTerm)&per_page=20&format=json&nojsoncallback=1"
    return NSURL(string: URLString)!
  }
}

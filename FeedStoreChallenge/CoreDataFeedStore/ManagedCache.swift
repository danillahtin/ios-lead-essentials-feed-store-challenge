//
//  ManagedCache+CoreDataClass.swift
//  FeedStoreChallenge
//
//  Created by Danil Lahtin on 25.04.2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//
//

import Foundation
import CoreData

final class ManagedCache: NSManagedObject {
    @NSManaged var timestamp: Date
    @NSManaged var images: NSOrderedSet

    func makeLocalFeedImages() -> [LocalFeedImage] {
        images.lazy
            .map({ $0 as! ManagedFeedImage })
            .map({ $0.makeLocalFeedImage() })
    }
}

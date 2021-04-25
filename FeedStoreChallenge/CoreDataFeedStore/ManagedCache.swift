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
    @NSManaged private(set) var timestamp: Date
    @NSManaged private(set) var images: NSOrderedSet

    convenience init(
        with feed: [LocalFeedImage],
        timestamp: Date,
        context: NSManagedObjectContext
    ) {
        self.init(context: context)

        self.images = NSOrderedSet(array: feed.map({ ManagedFeedImage(with: $0, in: context) }))
        self.timestamp = timestamp
    }

    func makeLocalFeedImages() -> [LocalFeedImage] {
        images.lazy
            .map({ $0 as! ManagedFeedImage })
            .map({ $0.makeLocalFeedImage() })
    }

    static func request(in context: NSManagedObjectContext) throws -> ManagedCache? {
        let name = ManagedCache.entity().name!
        let request = NSFetchRequest<ManagedCache>(entityName: name)
        return try context.fetch(request).first
    }

    static func removeIfExists(in context: NSManagedObjectContext) throws {
        try request(in: context).map(context.delete)
    }
}

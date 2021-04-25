//
//  ManagedFeedImage+CoreDataClass.swift
//  FeedStoreChallenge
//
//  Created by Danil Lahtin on 25.04.2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//
//

import Foundation
import CoreData

final class ManagedFeedImage: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var details: String?
    @NSManaged public var location: String?
    @NSManaged public var url: URL
    @NSManaged public var cache: ManagedCache

    convenience init(with image: LocalFeedImage, in context: NSManagedObjectContext) {
        self.init(context: context)

        id = image.id
        details = image.description
        location = image.location
        url = image.url
    }

    func makeLocalFeedImage() -> LocalFeedImage {
        LocalFeedImage(
            id: id,
            description: details,
            location: location,
            url: url
        )
    }
}

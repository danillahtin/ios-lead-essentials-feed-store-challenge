//
//  CoreDataFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Danil Lahtin on 25.04.2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
import CoreData

public final class CoreDataFeedStore: FeedStore {
    private let context: NSManagedObjectContext

    public init(storeUrl: URL, bundle: Bundle = .main) throws {
        let container = try NSPersistentContainer.load(modelName: "ManagedCacheModel", at: storeUrl, in: bundle)
        context = container.newBackgroundContext()
    }

    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        perform { context in
            do {
                try context.removeCacheIfExists()
                try context.save()

                completion(.none)
            } catch {
                context.rollback()
                completion(error)
            }
        }
    }

    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        perform { context in
            do {
                try context.removeCacheIfExists()
                context.insert(feed, timestamp: timestamp)
                try context.save()

                completion(.none)
            } catch {
                context.rollback()
                completion(error)
            }
        }
    }

    public func retrieve(completion: @escaping RetrievalCompletion) {
        perform { context in
            do {
                guard let cache = try context.requestCache() else {
                    return completion(.empty)
                }

                completion(.found(feed: cache.makeLocalFeedImages(), timestamp: cache.timestamp!))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func perform(_ action: @escaping (NSManagedObjectContext) -> ()) {
        context.perform { [context] in
            action(context)
        }
    }
}

// MARK: - Helpers

private extension ManagedFeedImage {
    convenience init(with image: LocalFeedImage, in context: NSManagedObjectContext) {
        self.init(context: context)

        id = image.id
        details = image.description
        location = image.location
        url = image.url
    }

    func makeLocalFeedImage() -> LocalFeedImage {
        LocalFeedImage(
            id: id!,
            description: details,
            location: location,
            url: url!
        )
    }
}

private extension ManagedCache {
    func makeLocalFeedImages() -> [LocalFeedImage] {
        images!
            .map({ $0 as! ManagedFeedImage })
            .map({ $0.makeLocalFeedImage() })
    }
}

private extension NSManagedObjectContext {
    func requestCache() throws -> ManagedCache? {
        let request = NSFetchRequest<ManagedCache>(entityName: ManagedCache.entity().name!)
        return try fetch(request).first
    }

    func removeCacheIfExists() throws {
        try requestCache().map(delete)
    }

    func insert(_ feed: [LocalFeedImage], timestamp: Date) {
        let cache = ManagedCache(context: self)

        cache.images = NSOrderedSet(array: feed.map({ ManagedFeedImage(with: $0, in: self) }))
        cache.timestamp = timestamp

        insert(cache)
    }
}

private extension NSPersistentContainer {
    enum Error: Swift.Error {
        case modelNotFound(name: String, inBundle: Bundle)
        case loadPersistentStores(error: Swift.Error)
    }

    static func load(
        modelName: String,
        at url: URL,
        in bundle: Bundle
    ) throws -> NSPersistentContainer {
        guard let model = bundle.model(with: modelName) else {
            throw Error.modelNotFound(name: modelName, inBundle: bundle)
        }

        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]

        try container.loadPersistentStoresSync()

        return container
    }

    private func loadPersistentStoresSync() throws {
        let group = DispatchGroup()
        group.enter()

        var error: Error?
        loadPersistentStores(completionHandler: {
            error = $1.map(Error.loadPersistentStores)
            group.leave()
        })

        group.wait()

        try error.map({ throw $0 })
    }
}

private extension Bundle {
    func model(with name: String) -> NSManagedObjectModel? {
        url(forResource: name, withExtension: "momd")
            .flatMap(NSManagedObjectModel.init(contentsOf:))
    }
}

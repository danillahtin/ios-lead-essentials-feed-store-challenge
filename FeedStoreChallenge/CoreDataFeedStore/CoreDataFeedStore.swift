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
        context.perform { [context] in
            do {
                try context.findCache()
                    .map({ context.delete($0) })
                    .map({ try context.save() })

                completion(.none)
            } catch {
                completion(error)
            }
        }
    }

    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        context.perform { [context] in
            do {
                try context.findCache()
                    .map({ context.delete($0) })
                    .map({ try context.save() })

                let cache = ManagedCache(with: feed, timestamp: timestamp, in: context)
                context.insert(cache)
                try context.save()

                completion(.none)
            } catch {
                completion(error)
            }
        }
    }

    public func retrieve(completion: @escaping RetrievalCompletion) {
        context.perform { [context] in
            do {
                guard let cache = try context.findCache() else {
                    return completion(.empty)
                }

                completion(.found(feed: cache.makeLocalFeedImages(), timestamp: cache.timestamp!))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Helpers

private extension ManagedFeedImage {
    static func makeFromLocalFeedImage(in context: NSManagedObjectContext) -> (LocalFeedImage) -> ManagedFeedImage {
        return {
            let managed = ManagedFeedImage(context: context)

            managed.id = $0.id
            managed.details = $0.description
            managed.location = $0.location
            managed.url = $0.url

            return managed
        }
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
    convenience init(with feed: [LocalFeedImage], timestamp: Date, in context: NSManagedObjectContext) {
        self.init(context: context)

        self.images = NSOrderedSet(array: feed.map(ManagedFeedImage.makeFromLocalFeedImage(in: context)))
        self.timestamp = timestamp
    }

    func makeLocalFeedImages() -> [LocalFeedImage] {
        images!
            .map({ $0 as! ManagedFeedImage })
            .map({ $0.makeLocalFeedImage() })
    }
}

private extension NSManagedObjectContext {
    func findCache() throws -> ManagedCache? {
        let request = NSFetchRequest<ManagedCache>(entityName: ManagedCache.entity().name!)
        return try fetch(request).first
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

        let group = DispatchGroup()
        group.enter()

        var error: Error?
        container.loadPersistentStores(completionHandler: {
            error = $1.map(Error.loadPersistentStores)
            group.leave()
        })

        group.wait()

        if let error = error {
            throw error
        }

        return container
    }
}

private extension Bundle {
    func model(with name: String) -> NSManagedObjectModel? {
        url(forResource: name, withExtension: "momd")
            .flatMap(NSManagedObjectModel.init(contentsOf:))
    }
}

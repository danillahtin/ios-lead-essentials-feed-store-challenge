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
        context.modify(ManagedCache.removeIfExists, completion: completion)
    }

    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        context.modify({ context in
            try ManagedCache.removeIfExists(in: context)
            let cache = ManagedCache(with: feed, timestamp: timestamp, context: context)
            context.insert(cache)
        }, completion: completion)
    }

    public func retrieve(completion: @escaping RetrievalCompletion) {
        context.perform { [context] in
            do {
                let cache = try ManagedCache.request(in: context)
                let result: RetrieveCachedFeedResult = cache.map({
                    .found(feed: $0.makeLocalFeedImages(), timestamp: $0.timestamp)
                }) ?? .empty

                completion(result)
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Helpers

private extension NSManagedObjectContext {
    func modify(_ block: @escaping (NSManagedObjectContext) throws -> (), completion: @escaping (Error?) -> ()) {
        perform { [self] in
            do {
                try block(self)
                try self.save()

                completion(.none)
            } catch {
                self.rollback()
                completion(error)
            }
        }
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

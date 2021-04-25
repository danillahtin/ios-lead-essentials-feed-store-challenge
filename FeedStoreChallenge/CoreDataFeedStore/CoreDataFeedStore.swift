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
    private final class FeedCache {
        let feed: [LocalFeedImage]
        let timestamp: Date

        init(feed: [LocalFeedImage], timestamp: Date) {
            self.feed = feed
            self.timestamp = timestamp
        }
    }

    private var cache: FeedCache?
    private let container: NSPersistentContainer?

    public init(storeUrl: URL, bundle: Bundle = .main) throws {
        container = try .load(modelName: "ManagedCacheModel", at: storeUrl, in: bundle)
    }

    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        cache = nil
        completion(.none)
    }

    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        cache = FeedCache(feed: feed, timestamp: timestamp)
        completion(.none)
    }

    public func retrieve(completion: @escaping RetrievalCompletion) {
        guard let cache = cache else {
            return completion(.empty)
        }
        completion(.found(feed: cache.feed, timestamp: cache.timestamp))
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

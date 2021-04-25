//
//  CoreDataFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Danil Lahtin on 25.04.2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation

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

    public init() {}

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

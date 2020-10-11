# QueuesDatabaseHooks

**Note:** This is experimental and based on https://github.com/vapor/queues/pull/87. This package is part 2 out of 3 of a series of product improvements to Queues.

This package adds database success and failure tracking for all dequeued jobs. Getting started is easy:

```swift
app.migrations.add(QueueDatabaseEntry())
app.queues.add(QueuesDatabaseNotificationHook(db: app.db))
```

And that's all! Your app will now start tracking job data in your specified database.

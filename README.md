# QueuesDatabaseHooks

This package adds database success and failure tracking for all dequeued jobs. Getting started is easy:

```swift
app.migrations.add(QueueDatabaseEntry())
app.queues.add(QueuesNotification(db: app.db))
```

And that's all! Your app will now start tracking job data in your specified database.

# QueuesDatabaseHooks

This package adds database success and failure tracking for all dequeued jobs.

## Installation
Use the SPM string to easily include the dependendency in your Package.swift file.

```swift
.package(url: "https://github.com/vapor-community/queues-database-hooks.git", from: ...)
```

After you have the package installed, getting started is easy:

```swift
app.migrations.add(QueueDatabaseEntryMigration())
app.queues.add(QueuesDatabaseNotificationHook.default(db: app.db))
```

And that's all! Your app will now start tracking job data in your specified database.

## Configuring the error handler
By default, the package will attempt to transform `Error`s into `String`s via the `localizedDescription` property. You can pass in a closure when initializing the `QueuesDatabaseNotificationHook` object to specify how to transform errors. You can also pass in a closure for transforming the notification data (if, for example, you only want to save the payload data for certain job names.)

```swift
let dbHook = QueuesDatabaseNotificationHook(db: db) { error -> (String) in
    // Do something here with `error` that returns a string
} payloadClosure: { data -> (NotificationJobData) in
    return data
}
app.queues.add(dbHook)
```

## What can I do with this data?
Out of the box, there's nothing built in to analyze the data that is captured. You can think of this as a "bring your own frontend" project - now that you have the data from your queue jobs you can do whatever you like with it. 

That being said, there are some community projects built on top of the data that surface insights and create dashboards:

1. https://github.com/gotranseo/queues-dash

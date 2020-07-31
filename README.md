# search_scan_sql 0.0.1

This is an application that can be used to look up data on a database on a local device, and display it on the screen.  It has an existing use in a different capacity, that probably isn't difficult to determine, but it's designed to be searched either via the `Author` or `Title` fields, unless the search term is 13 characters in length and are all numeric, in which case it searches the `isbnList` column for a match.

I've included a number of barcodes whose ISBN numbers already exist in the database (though the books don't match up, b/c I just made up fake ones for example purposes). Look for these as images in the `/assets/barcodes` directory.

## Under the Hood

A local SQLite3 database is kept in `assets` directory, along with it's suggested db schema. 

Scan works, but additional work would need to be done to local environments in both iOS && Android. If you're just building locally it should be fine. See: https://pub.dev/packages/barcode_scan



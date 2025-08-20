// Initializes collections, validation (flexible), and indexes for UpNext
// Note: Mongo runs these scripts in alphabetical order.

const dbName = 'upnext';
const database = db.getSiblingDB(dbName);

// Artists collection with flexible schema (allows additional fields)
database.createCollection('artists', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name'],
      additionalProperties: true,
      properties: {
        name: { bsonType: 'string' },
        normalized: { bsonType: 'string' },
        external: { bsonType: 'array' },
        ids: {
          bsonType: 'object',
          additionalProperties: true,
          properties: {
            mbid: { bsonType: ['string', 'null'] },
            wikidataId: { bsonType: ['string', 'null'] },
            wikipediaTitle: { bsonType: ['string', 'null'] }
          }
        },
        synopsis: {
          bsonType: 'object',
          additionalProperties: true,
          properties: {
            text: { bsonType: 'string' },
            source: {
              bsonType: 'object',
              additionalProperties: true,
              properties: {
                name: { bsonType: 'string' },
                url: { bsonType: 'string' },
                license: { bsonType: 'string' }
              }
            },
            lastCheckedAt: { bsonType: ['date', 'null'] }
          }
        },
        images: { bsonType: 'array' }
      }
    }
  }
});

// Events collection (concerts) with flexible schema
database.createCollection('events', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['title', 'artists', 'venueId', 'startsAt', 'source'],
      additionalProperties: true,
      properties: {
        title: { bsonType: 'string' },
        artists: { bsonType: 'array' },
        venueId: { bsonType: 'objectId' },
        startsAt: { bsonType: 'date' },
        doorsAt: { bsonType: ['date', 'null'] },
        tz: { bsonType: ['string', 'null'] },
        priceMin: { bsonType: ['double', 'int', 'null'] },
        priceMax: { bsonType: ['double', 'int', 'null'] },
        currency: { bsonType: ['string', 'null'] },
        priceAvg: { bsonType: ['double', 'int', 'null'] },
        priceFromProviders: { bsonType: 'array' },
        tourName: { bsonType: ['string', 'null'] },
        genres: { bsonType: 'array' },
        source: {
          bsonType: 'object',
          required: ['provider', 'id'],
          additionalProperties: true,
          properties: {
            provider: { bsonType: 'string' },
            id: { bsonType: 'string' },
            url: { bsonType: ['string', 'null'] }
          }
        },
        setlist: { bsonType: 'object' },
        status: { bsonType: ['string', 'null'] },
        isAllAges: { bsonType: ['bool', 'null'] },
        images: { bsonType: 'array' },
        popularity: { bsonType: ['double', 'int', 'null'] }
      }
    }
  }
});

// Venues (minimal for reference)
database.createCollection('venues', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name', 'location'],
      additionalProperties: true,
      properties: {
        name: { bsonType: 'string' },
        address: { bsonType: 'object' },
        location: {
          bsonType: 'object',
          properties: {
            type: { enum: ['Point'] },
            coordinates: { bsonType: 'array', items: { bsonType: 'double' } }
          }
        },
        external: { bsonType: 'array' }
      }
    }
  }
});

// Indexes
// Artists: text search, external ids, mbid unique if present
database.artists.createIndex({ normalized: 'text', name: 'text' });
database.artists.createIndex({ 'external.provider': 1, 'external.id': 1 });
database.artists.createIndex({ 'ids.mbid': 1 }, { unique: true, sparse: true });

// Venues: 2dsphere for geospatial
database.venues.createIndex({ location: '2dsphere' });

database.events.createIndex({ 'source.provider': 1, 'source.id': 1 }, { unique: true });
database.events.createIndex({ startsAt: 1, venueId: 1 });
database.events.createIndex({ 'artists': 1, startsAt: 1 });

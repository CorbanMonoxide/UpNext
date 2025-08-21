// Create Lists and List Items collections with basic indexes
const dbName = 'upnext';
const database = db.getSiblingDB(dbName);

// Lists
if (!database.getCollectionNames().includes('lists')) {
  database.createCollection('lists', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['name'],
        additionalProperties: true,
        properties: {
          name: { bsonType: 'string' },
          isSystem: { bsonType: ['bool', 'null'] },
          key: { bsonType: ['string', 'null'] },
          createdAt: { bsonType: ['date', 'null'] },
          updatedAt: { bsonType: ['date', 'null'] },
        }
      }
    }
  });
}

// List Items
if (!database.getCollectionNames().includes('list_items')) {
  database.createCollection('list_items', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['listId', 'eventId'],
        additionalProperties: true,
        properties: {
          listId: { bsonType: 'objectId' },
          eventId: { bsonType: 'objectId' },
          note: { bsonType: ['string', 'null'] },
          status: { enum: ['saved', 'attended', null] },
          attendedAt: { bsonType: ['date', 'null'] },
          addedAt: { bsonType: ['date', 'null'] },
          order: { bsonType: ['int', 'null'] },
        }
      }
    }
  });
}

// Indexes
// Avoid duplicates of same event in a list
database.list_items.createIndex({ listId: 1, eventId: 1 }, { unique: true });
// Fast lookup by list
database.list_items.createIndex({ listId: 1, addedAt: -1 });

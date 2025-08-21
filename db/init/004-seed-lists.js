// Seed a system "Attended" list if not present
const dbName = 'upnext';
const database = db.getSiblingDB(dbName);

function upsertSystemList(key, name) {
  const existing = database.lists.findOne({ key: key });
  if (existing) return existing._id;
  const now = new Date();
  const res = database.lists.insertOne({
    name: name,
    key: key,
    isSystem: true,
    createdAt: now,
    updatedAt: now,
  });
  return res.insertedId;
}

upsertSystemList('attended', 'Attended');

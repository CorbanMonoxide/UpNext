// Seeds 3 artists and 3 concerts with flexible fields (scalable schema)
const dbName = 'upnext';
const database = db.getSiblingDB(dbName);

function upsertArtist(a) {
  const norm = a.name.toLowerCase();
  const doc = {
    name: a.name,
    normalized: norm,
    external: a.external || [],
    ids: a.ids || {},
    synopsis: a.synopsis || null,
    images: a.images || []
  };
  database.artists.updateOne(
    { name: a.name },
    { $set: doc },
    { upsert: true }
  );
}

function insertVenue(v) {
  const existing = database.venues.findOne({ name: v.name });
  if (existing) return existing._id;
  const res = database.venues.insertOne(v);
  return res.insertedId;
}

function insertEvent(e) {
  const existing = database.events.findOne({ 'source.provider': e.source.provider, 'source.id': e.source.id });
  if (existing) return existing._id;
  const res = database.events.insertOne(e);
  return res.insertedId;
}

// Sample Artists
upsertArtist({
  name: 'The Midnight',
  ids: { mbid: null, wikidataId: 'Q21014274', wikipediaTitle: 'The_Midnight_(band)' },
  synopsis: {
    text: 'The Midnight is an American synthwave band known for nostalgic, cinematic soundscapes.',
    source: { name: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/The_Midnight_(band)', license: 'CC BY-SA' }
  },
  images: []
});

upsertArtist({
  name: 'Tame Impala',
  ids: { mbid: '063cf61b-28e5-4eab-94a1-71e9e9b52e7e', wikidataId: 'Q152709', wikipediaTitle: 'Tame_Impala' },
  synopsis: {
    text: 'Tame Impala is a psychedelic music project of Australian multi-instrumentalist Kevin Parker.',
    source: { name: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Tame_Impala', license: 'CC BY-SA' }
  }
});

upsertArtist({
  name: 'Phoebe Bridgers',
  ids: { mbid: 'f4e8a058-5c9e-4b9d-8b3f-0a9f3e6c62af', wikidataId: 'Q42058874', wikipediaTitle: 'Phoebe_Bridgers' },
  synopsis: {
    text: 'Phoebe Bridgers is an American singer-songwriter known for her emotive indie folk.',
    source: { name: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Phoebe_Bridgers', license: 'CC BY-SA' }
  }
});

// Sample Venues
const venue1Id = insertVenue({
  name: 'The Greek Theatre',
  address: { line1: '2700 N Vermont Ave', city: 'Los Angeles', state: 'CA', country: 'US', postal: '90027' },
  location: { type: 'Point', coordinates: [-118.2933, 34.1192] }
});

const venue2Id = insertVenue({
  name: 'Madison Square Garden',
  address: { line1: '4 Pennsylvania Plaza', city: 'New York', state: 'NY', country: 'US', postal: '10001' },
  location: { type: 'Point', coordinates: [-73.9934, 40.7505] }
});

const venue3Id = insertVenue({
  name: 'Red Rocks Amphitheatre',
  address: { line1: '18300 W Alameda Pkwy', city: 'Morrison', state: 'CO', country: 'US', postal: '80465' },
  location: { type: 'Point', coordinates: [-105.2057, 39.6654] }
});

// Helper to get artist ids array by names
function artistIds(names) {
  return names.map(n => database.artists.findOne({ name: n })).filter(Boolean).map(a => a._id);
}

// Sample Events (Concerts)
insertEvent({
  title: 'The Midnight at The Greek',
  artists: artistIds(['The Midnight']),
  venueId: venue1Id,
  startsAt: new Date('2025-09-15T19:30:00-07:00'),
  doorsAt: new Date('2025-09-15T18:30:00-07:00'),
  tz: 'America/Los_Angeles',
  priceMin: 35,
  priceMax: 95,
  currency: 'USD',
  priceAvg: 60,
  tourName: 'Endless Summer Tour',
  genres: ['Synthwave'],
  source: { provider: 'seed', id: 'evt-001', url: null },
  setlist: { provider: 'setlistfm', id: null, url: 'https://www.setlist.fm/' },
  status: 'scheduled',
  isAllAges: true,
  images: [],
  popularity: 0.7
});

insertEvent({
  title: 'Tame Impala Live at MSG',
  artists: artistIds(['Tame Impala']),
  venueId: venue2Id,
  startsAt: new Date('2025-10-05T20:00:00-04:00'),
  doorsAt: new Date('2025-10-05T19:00:00-04:00'),
  tz: 'America/New_York',
  priceMin: 60,
  priceMax: 180,
  currency: 'USD',
  priceAvg: 110,
  tourName: 'Currents Anniversary Tour',
  genres: ['Psychedelic Rock', 'Indie'],
  source: { provider: 'seed', id: 'evt-002', url: null },
  setlist: { provider: 'setlistfm', id: null, url: 'https://www.setlist.fm/' },
  status: 'scheduled',
  isAllAges: true,
  images: [],
  popularity: 0.9
});

insertEvent({
  title: 'Phoebe Bridgers at Red Rocks',
  artists: artistIds(['Phoebe Bridgers']),
  venueId: venue3Id,
  startsAt: new Date('2025-08-30T20:00:00-06:00'),
  doorsAt: new Date('2025-08-30T19:00:00-06:00'),
  tz: 'America/Denver',
  priceMin: 45,
  priceMax: 150,
  currency: 'USD',
  priceAvg: 85,
  tourName: 'Reunion Tour',
  genres: ['Indie Folk'],
  source: { provider: 'seed', id: 'evt-003', url: null },
  setlist: { provider: 'setlistfm', id: null, url: 'https://www.setlist.fm/' },
  status: 'scheduled',
  isAllAges: false,
  images: [],
  popularity: 0.8
});

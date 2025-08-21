import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const UpNextApp());
}

class UpNextApp extends StatelessWidget {
  const UpNextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UpNext POC',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UpNext — Local DB'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: 'Artists'),
          Tab(text: 'Up Next'),
        ]),
      ),
      body: TabBarView(controller: _tab, children: const [
        ArtistsList(),
        EventsList(),
      ]),
    );
  }
}

class ArtistsList extends StatefulWidget {
  const ArtistsList({super.key});

  @override
  State<ArtistsList> createState() => _ArtistsListState();
}

class _ArtistsListState extends State<ArtistsList> {
  late Future<List<Artist>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchArtists();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Artist>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No artists'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = items[i];
            return ListTile(
              title: Text(a.name),
              subtitle: a.synopsis != null ? Text(a.synopsis!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArtistPage(artist: a),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class EventsList extends StatefulWidget {
  const EventsList({super.key});

  @override
  State<EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<EventsList> {
  late Future<List<EventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No events'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = items[i];
            return ListTile(
              title: Text(e.title),
              subtitle: Text([
                if (e.startsAt != null) e.startsAt!.toLocal().toString(),
                if (e.tourName != null) e.tourName!,
              ].join(' • ')),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventPage(eventId: e.id, initial: e),
                ));
              },
            );
          },
        );
      },
    );
  }
}

class Artist {
  final String id;
  final String name;
  final String? synopsis;

  Artist({required this.id, required this.name, this.synopsis});

  factory Artist.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['_id'];
    return Artist(
      id: idVal is Map && idVal['\$oid'] != null ? idVal['\$oid'] as String : idVal.toString(),
      name: json['name'] as String,
      synopsis: (json['synopsis'] is Map) ? (json['synopsis']['text'] as String?) : null,
    );
  }
}

class EventItem {
  final String id;
  final String title;
  final DateTime? startsAt;
  final String? tourName;

  EventItem({required this.id, required this.title, this.startsAt, this.tourName});

  factory EventItem.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['_id'];
    DateTime? starts;
    final s = json['startsAt'];
    if (s is String) {
      starts = DateTime.tryParse(s);
    }
    return EventItem(
      id: idVal is Map && idVal['\$oid'] != null ? idVal['\$oid'] as String : idVal.toString(),
      title: json['title'] as String,
      startsAt: starts,
      tourName: json['tourName'] as String?,
    );
  }
}

class AppList {
  final String id;
  final String name;
  final String? key;

  AppList({required this.id, required this.name, this.key});

  factory AppList.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['_id'];
    return AppList(
  id: idVal is Map && idVal['\$oid'] != null ? idVal['\$oid'] as String : idVal.toString(),
      name: json['name'] as String,
      key: json['key'] as String?,
    );
  }
}

class Api {
  // For local dev via Docker: http://localhost:8080
  static const String base = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');

  static Future<List<Artist>> fetchArtists() async {
    final r = await http.get(Uri.parse('$base/api/artists'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final List list = jsonDecode(r.body) as List;
    return list.map((j) => Artist.fromJson(j)).toList();
  }

  static Future<List<EventItem>> fetchEvents() async {
    final r = await http.get(Uri.parse('$base/api/events'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final List list = jsonDecode(r.body) as List;
    return list.map((j) => EventItem.fromJson(j)).toList();
  }

  static Future<Artist> fetchArtist(String id) async {
    final r = await http.get(Uri.parse('$base/api/artists/$id'));
    if (r.statusCode == 404) throw Exception('Artist not found');
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final Map<String, dynamic> j = jsonDecode(r.body) as Map<String, dynamic>;
    return Artist.fromJson(j);
  }

  static Future<List<EventItem>> fetchArtistEvents(String id, {bool past = false}) async {
    final r = await http.get(Uri.parse('$base/api/artists/$id/events?past=${past ? 'true' : 'false'}'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final List list = jsonDecode(r.body) as List;
    return list.map((j) => EventItem.fromJson(j)).toList();
  }

  static Future<EventItem> fetchEvent(String id) async {
    final r = await http.get(Uri.parse('$base/api/events/$id'));
    if (r.statusCode == 404) throw Exception('Event not found');
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final Map<String, dynamic> j = jsonDecode(r.body) as Map<String, dynamic>;
    return EventItem.fromJson(j);
  }

  static Future<List<AppList>> fetchLists() async {
    final r = await http.get(Uri.parse('$base/api/lists'));
    if (r.statusCode != 200) throw Exception('Failed: ${r.statusCode} ${r.body}');
    final List list = jsonDecode(r.body) as List;
    return list.map((j) => AppList.fromJson(j)).toList();
  }

  static Future<void> addItemToList({required String listId, required String eventId, String? status, DateTime? attendedAt, String? note}) async {
    final uri = Uri.parse('$base/api/lists/$listId/items');
    final body = <String, dynamic>{
      'eventId': eventId,
      if (status != null) 'status': status,
      if (attendedAt != null) 'attendedAt': attendedAt.toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final r = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (r.statusCode != 201) throw Exception('Add failed: ${r.statusCode} ${r.body}');
  }
}

class ArtistPage extends StatelessWidget {
  final Artist artist;
  const ArtistPage({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(artist.name),
          bottom: const TabBar(tabs: [
            Tab(text: 'About'),
            Tab(text: 'Concerts'),
          ]),
        ),
        body: TabBarView(children: [
          _AboutTab(artist: artist),
          _ArtistConcertsTab(artistId: artist.id),
        ]),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final Artist artist;
  const _AboutTab({required this.artist});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  artist.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (artist.synopsis != null && artist.synopsis!.trim().isNotEmpty) ...[
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(artist.synopsis!),
          ] else ...[
            Text('No bio available yet.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ArtistConcertsTab extends StatefulWidget {
  final String artistId;
  const _ArtistConcertsTab({required this.artistId});

  @override
  State<_ArtistConcertsTab> createState() => _ArtistConcertsTabState();
}

class _ArtistConcertsTabState extends State<_ArtistConcertsTab> {
  bool showPast = false;
  late Future<List<EventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchArtistEvents(widget.artistId, past: showPast);
  }

  void _reload() {
    setState(() {
      _future = Api.fetchArtistEvents(widget.artistId, past: showPast);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(showPast ? 'Past shows' : 'Upcoming shows'),
              const Spacer(),
              Switch(
                value: showPast,
                onChanged: (v) {
                  showPast = v;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<EventItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('No concerts to show'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = items[i];
                  return ListTile(
                    title: Text(e.title),
                    subtitle: Text([
                      if (e.startsAt != null) e.startsAt!.toLocal().toString(),
                      if (e.tourName != null) e.tourName!,
                    ].join(' • ')),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EventPage(eventId: e.id, initial: e),
                      ));
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class EventPage extends StatefulWidget {
  final String eventId;
  final EventItem? initial;
  const EventPage({super.key, required this.eventId, this.initial});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  late Future<EventItem> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(title: Text(initial?.title ?? 'Event')),
      body: FutureBuilder<EventItem>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final e = snapshot.data ?? initial!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text([
                  if (e.startsAt != null) e.startsAt!.toLocal().toString(),
                  if (e.tourName != null) e.tourName!,
                ].join(' • ')),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I've been"),
                  onPressed: () async {
                    final e = (await _future);
                    if (!context.mounted) return;
                    try {
                      final lists = await Api.fetchLists();
                      final attended = lists.firstWhere((l) => l.key == 'attended', orElse: () => lists.first);
                      await Api.addItemToList(
                        listId: attended.id,
                        eventId: e.id,
                        status: 'attended',
                        attendedAt: e.startsAt,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as attended')));
                    } catch (err) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add to List…'),
                  onPressed: () async {
                    final e = (await _future);
                    if (!context.mounted) return;
                    try {
                      final lists = await Api.fetchLists();
                      if (!context.mounted) return;
                      final selected = await showModalBottomSheet<AppList>(
                        context: context,
                        showDragHandle: true,
                        builder: (ctx) => _ListPicker(lists: lists),
                      );
                      if (selected == null) return;
                      await Api.addItemToList(listId: selected.id, eventId: e.id, status: 'saved');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${selected.name}')));
                    } catch (err) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListPicker extends StatelessWidget {
  final List<AppList> lists;
  const _ListPicker({required this.lists});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text('Choose a list', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: lists.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final l = lists[i];
                return ListTile(
                  title: Text(l.name),
                  subtitle: l.key != null ? Text(l.key!) : null,
                  onTap: () => Navigator.of(context).pop(l),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

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
          Tab(text: 'Events'),
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
}

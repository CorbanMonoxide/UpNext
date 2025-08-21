package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Server struct {
	db         *mongo.Database
	artistsCol *mongo.Collection
	eventsCol  *mongo.Collection
	listsCol   *mongo.Collection
	itemsCol   *mongo.Collection
}

type Artist struct {
	ID       interface{} `json:"id" bson:"_id"`
	Name     string      `json:"name" bson:"name"`
	Synopsis *struct {
		Text string `json:"text" bson:"text"`
	} `json:"synopsis,omitempty" bson:"synopsis,omitempty"`
}

type Event struct {
	ID       interface{} `json:"id" bson:"_id"`
	Title    string      `json:"title" bson:"title"`
	StartsAt time.Time   `json:"startsAt" bson:"startsAt"`
	TourName *string     `json:"tourName,omitempty" bson:"tourName,omitempty"`
}

func main() {
	mongoURI := getenv("MONGO_URI", "mongodb://localhost:27017")
	dbName := getenv("DB_NAME", "upnext")
	port := getenv("PORT", "8080")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("mongo connect: %v", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		log.Fatalf("mongo ping: %v", err)
	}

	db := client.Database(dbName)
	s := &Server{
		db:         db,
		artistsCol: db.Collection("artists"),
		eventsCol:  db.Collection("events"),
	listsCol:   db.Collection("lists"),
	itemsCol:   db.Collection("list_items"),
	}

	if err := s.ensureSystemLists(context.Background()); err != nil {
		log.Printf("warn: ensure system lists: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealth)
	mux.HandleFunc("/api/artists", s.handleArtistsList)
	// Subroutes for artist detail and events
	mux.HandleFunc("/api/artists/", s.handleArtistSubroutes)
	mux.HandleFunc("/api/events", s.handleEventsList)
	mux.HandleFunc("/api/events/", s.handleEventSubroutes)
	// Lists MVP
	mux.HandleFunc("/api/lists", s.handleLists)
	mux.HandleFunc("/api/lists/", s.handleListSubroutes)

	handler := withCORS(mux)

	log.Printf("API listening on :%s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatal(err)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleArtistsList(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	opts := options.Find().
		SetProjection(bson.M{
			"name":     1,
			"synopsis": 1,
		}).
		SetSort(bson.D{{Key: "name", Value: 1}}).
		SetLimit(100)

	cur, err := s.artistsCol.Find(ctx, bson.M{}, opts)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	defer cur.Close(ctx)

	out := make([]Artist, 0)
	if err := cur.All(ctx, &out); err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// handleArtistSubroutes dispatches /api/artists/{id} and /api/artists/{id}/events
func (s *Server) handleArtistSubroutes(w http.ResponseWriter, r *http.Request) {
	// Expected paths: /api/artists/{id} or /api/artists/{id}/events
	base := "/api/artists/"
	if len(r.URL.Path) <= len(base) {
		http.NotFound(w, r)
		return
	}
	rest := r.URL.Path[len(base):]
	// split rest by '/'
	var segs []string
	for _, p := range splitNonEmpty(rest, '/') {
		segs = append(segs, p)
	}
	if len(segs) == 0 {
		http.NotFound(w, r)
		return
	}
	idHex := segs[0]
	oid, err := primitive.ObjectIDFromHex(idHex)
	if err != nil {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	if len(segs) == 1 {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		s.handleArtistDetail(w, r, oid)
		return
	}
	if len(segs) == 2 && segs[1] == "events" {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		s.handleArtistEvents(w, r, oid)
		return
	}
	http.NotFound(w, r)
}

func splitNonEmpty(s string, sep rune) []string {
	out := make([]string, 0, 4)
	cur := make([]rune, 0, len(s))
	for _, r := range s {
		if r == sep {
			if len(cur) > 0 {
				out = append(out, string(cur))
				cur = cur[:0]
			}
			continue
		}
		cur = append(cur, r)
	}
	if len(cur) > 0 {
		out = append(out, string(cur))
	}
	return out
}

func (s *Server) handleArtistDetail(w http.ResponseWriter, r *http.Request, id primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var a Artist
	err := s.artistsCol.FindOne(ctx, bson.M{"_id": id}, options.FindOne().SetProjection(bson.M{
		"name":     1,
		"synopsis": 1,
	})).Decode(&a)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.NotFound(w, r)
			return
		}
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, a)
}

func (s *Server) handleArtistEvents(w http.ResponseWriter, r *http.Request, id primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	// past=false by default
	past := r.URL.Query().Get("past") == "true"
	now := time.Now()
	filter := bson.M{"artists": id}
	if past {
		filter["startsAt"] = bson.M{"$lt": now}
	} else {
		filter["startsAt"] = bson.M{"$gte": now}
	}

	sort := 1
	if past {
		sort = -1
	}

	opts := options.Find().
		SetProjection(bson.M{
			"title":    1,
			"startsAt": 1,
			"tourName": 1,
		}).
		SetSort(bson.D{{Key: "startsAt", Value: sort}}).
		SetLimit(200)

	cur, err := s.eventsCol.Find(ctx, filter, opts)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	defer cur.Close(ctx)

	var out []Event
	if err := cur.All(ctx, &out); err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleEventsList(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	opts := options.Find().
		SetProjection(bson.M{
			"title":    1,
			"startsAt": 1,
			"tourName": 1,
		}).
		SetSort(bson.D{{Key: "startsAt", Value: 1}}).
		SetLimit(100)

	cur, err := s.eventsCol.Find(ctx, bson.M{}, opts)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	defer cur.Close(ctx)

	out := make([]Event, 0)
	if err := cur.All(ctx, &out); err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// handleEventSubroutes: /api/events/{id}
func (s *Server) handleEventSubroutes(w http.ResponseWriter, r *http.Request) {
	base := "/api/events/"
	if len(r.URL.Path) <= len(base) {
		http.NotFound(w, r)
		return
	}
	rest := r.URL.Path[len(base):]
	segs := splitNonEmpty(rest, '/')
	if len(segs) != 1 || r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	oid, err := primitive.ObjectIDFromHex(segs[0])
	if err != nil {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	s.handleEventDetail(w, r, oid)
}

func (s *Server) handleEventDetail(w http.ResponseWriter, r *http.Request, id primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var e Event
	err := s.eventsCol.FindOne(ctx, bson.M{"_id": id}, options.FindOne().SetProjection(bson.M{
		"title":    1,
		"startsAt": 1,
		"tourName": 1,
	})).Decode(&e)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.NotFound(w, r)
			return
		}
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, e)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, err error) {
	writeJSON(w, code, map[string]any{"error": err.Error()})
}

func getenv(key, def string) string {
	val := os.Getenv(key)
	if val == "" {
		return def
	}
	return val
}

func (s *Server) ensureSystemLists(ctx context.Context) error {
	// Create Attended system list if missing
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	key := "attended"
	name := "Attended"
	update := bson.M{
		"$setOnInsert": bson.M{
			"name":      name,
			"key":       key,
			"isSystem":  true,
			"createdAt": time.Now(),
			"updatedAt": time.Now(),
		},
	}
	_, err := s.listsCol.UpdateOne(ctx, bson.M{"key": key}, update, options.Update().SetUpsert(true))
	return err
}

// ===== Lists (MVP) =====
type List struct {
	ID        interface{} `json:"id" bson:"_id"`
	Name      string      `json:"name" bson:"name"`
	Key       *string     `json:"key,omitempty" bson:"key,omitempty"`
	IsSystem  *bool       `json:"isSystem,omitempty" bson:"isSystem,omitempty"`
	CreatedAt *time.Time  `json:"createdAt,omitempty" bson:"createdAt,omitempty"`
	UpdatedAt *time.Time  `json:"updatedAt,omitempty" bson:"updatedAt,omitempty"`
}

type ListItem struct {
	ID         interface{}        `json:"id" bson:"_id"`
	ListID     interface{}        `json:"listId" bson:"listId"`
	EventID    interface{}        `json:"eventId" bson:"eventId"`
	Note       *string            `json:"note,omitempty" bson:"note,omitempty"`
	Status     *string            `json:"status,omitempty" bson:"status,omitempty"`
	AttendedAt *time.Time         `json:"attendedAt,omitempty" bson:"attendedAt,omitempty"`
	AddedAt    *time.Time         `json:"addedAt,omitempty" bson:"addedAt,omitempty"`
	Order      *int               `json:"order,omitempty" bson:"order,omitempty"`
}

func (s *Server) handleLists(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		cur, err := s.listsCol.Find(ctx, bson.M{}, options.Find().SetSort(bson.D{{Key: "isSystem", Value: -1}, {Key: "name", Value: 1}}))
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err)
			return
		}
		defer cur.Close(ctx)
	out := make([]List, 0)
		if err := cur.All(ctx, &out); err != nil {
			writeErr(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, out)
	case http.MethodPost:
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		var body struct{ Name string `json:"name"` }
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Name == "" {
			writeErr(w, http.StatusBadRequest, err)
			return
		}
		now := time.Now()
		res, err := s.listsCol.InsertOne(ctx, bson.M{"name": body.Name, "createdAt": now, "updatedAt": now})
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, bson.M{"id": res.InsertedID, "name": body.Name})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleListSubroutes(w http.ResponseWriter, r *http.Request) {
	base := "/api/lists/"
	if len(r.URL.Path) <= len(base) {
		http.NotFound(w, r)
		return
	}
	rest := r.URL.Path[len(base):]
	segs := splitNonEmpty(rest, '/')
	if len(segs) == 0 {
		http.NotFound(w, r)
		return
	}
	oid, err := primitive.ObjectIDFromHex(segs[0])
	if err != nil {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	if len(segs) == 1 {
		switch r.Method {
		case http.MethodGet:
			s.handleListDetail(w, r, oid)
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
		}
		return
	}
	if len(segs) == 2 {
		switch segs[1] {
		case "items":
			switch r.Method {
			case http.MethodGet:
				s.handleListItems(w, r, oid)
			case http.MethodPost:
				s.handleListAddItem(w, r, oid)
			default:
				w.WriteHeader(http.StatusMethodNotAllowed)
			}
			return
		}
	}
	http.NotFound(w, r)
}

func (s *Server) handleListDetail(w http.ResponseWriter, r *http.Request, id primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	var lst List
	if err := s.listsCol.FindOne(ctx, bson.M{"_id": id}).Decode(&lst); err != nil {
		if err == mongo.ErrNoDocuments {
			http.NotFound(w, r)
			return
		}
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, lst)
}

func (s *Server) handleListItems(w http.ResponseWriter, r *http.Request, listID primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	cur, err := s.itemsCol.Find(ctx, bson.M{"listId": listID}, options.Find().SetSort(bson.D{{Key: "addedAt", Value: -1}}))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	defer cur.Close(ctx)
	out := make([]ListItem, 0)
	if err := cur.All(ctx, &out); err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleListAddItem(w http.ResponseWriter, r *http.Request, listID primitive.ObjectID) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	var body struct {
		EventID string     `json:"eventId"`
		Status  *string    `json:"status"`
		Note    *string    `json:"note"`
		When    *time.Time `json:"attendedAt"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.EventID == "" {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	evtID, err := primitive.ObjectIDFromHex(body.EventID)
	if err != nil {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	now := time.Now()
	doc := bson.M{
		"listId":     listID,
		"eventId":    evtID,
		"note":       body.Note,
		"status":     body.Status,
		"attendedAt": body.When,
		"addedAt":    now,
	}
	_, err = s.itemsCol.UpdateOne(ctx, bson.M{"listId": listID, "eventId": evtID}, bson.M{"$setOnInsert": doc}, options.Update().SetUpsert(true))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, bson.M{"ok": true})
}

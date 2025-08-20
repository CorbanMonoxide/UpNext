package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Server struct {
	db         *mongo.Database
	artistsCol *mongo.Collection
	eventsCol  *mongo.Collection
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
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealth)
	mux.HandleFunc("/api/artists", s.handleArtistsList)
	mux.HandleFunc("/api/events", s.handleEventsList)

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

	var out []Artist
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

	var out []Event
	if err := cur.All(ctx, &out); err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
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

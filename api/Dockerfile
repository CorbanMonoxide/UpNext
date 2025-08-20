# Build stage
FROM golang:1.22-alpine AS build
WORKDIR /app
# Copy only go.mod first; go.sum may not exist yet
COPY go.mod ./
RUN go mod download
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o server

# Runtime stage
FROM gcr.io/distroless/base-debian12
WORKDIR /app
ENV PORT=8080
COPY --from=build /app/server /app/server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/server"]

FROM golang:1.24.1-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY . .

ENV CGO_ENABLED=0
RUN go build -o main -ldflags "-s -w" .

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/main .

COPY index.html .


EXPOSE 8080

CMD ["./main"]

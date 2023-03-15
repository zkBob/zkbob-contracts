FROM golang:1.20.2 as build

WORKDIR /app

COPY go.* ./
RUN go mod download

COPY . .

RUN mkdir -p out && \
    go build -o ./out/export ./cms/export/main.go && \
    go build -o ./out/upload ./cms/upload/main.go

FROM ubuntu:20.04

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

COPY ./contracts ./contracts
COPY --from=build /app/out/ ./out

EXPOSE 3333

ENTRYPOINT ["./out/export"]

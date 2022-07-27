FROM golang:1.18.3 as build

WORKDIR /app

COPY go.* ./
RUN go mod download

COPY . .

RUN mkdir -p out && \
    go build -o ./out/vanityaddr ./main.go

FROM ubuntu:20.04

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

COPY ./contracts ./contracts
COPY --from=build /app/out/ ./out

EXPOSE 3333

ENTRYPOINT ["./out/vanityaddr"]

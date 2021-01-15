###
FROM golang:1.14.4-alpine3.12 as builder

RUN apk add --no-cache bash gcc libc-dev make openssl-dev

WORKDIR /app

ARG CGO_ENABLED=1
ENV GO111MODULE=on
ENV GOPATH=

COPY go.mod go.sum ./

RUN go mod download

COPY . .

# Preload an in-tree but disabled-by-default plugin by adding it to the IPFS_PLUGINS variable
# e.g. docker build --build-arg IPFS_PLUGINS="foo bar baz"
ARG IPFS_PLUGINS=

# Build the thing.
# Also: fix getting HEAD commit hash via git rev-parse.
RUN  mkdir -p .git/objects \
  && make build GOTAGS=openssl IPFS_PLUGINS=$IPFS_PLUGINS

###
FROM alpine:3.12

RUN apk add --no-cache fuse ca-certificates

# Get the ipfs binary, entrypoint script from the build container.
COPY --from=builder /app/cmd/ipfs/ipfs /usr/local/bin/ipfs
COPY --from=builder /app/bin/entrypoint.sh /entrypoint.sh

# Swarm TCP; should be exposed to the public
EXPOSE 4001
# Swarm UDP; should be exposed to the public
EXPOSE 4001/udp
# Daemon API; must not be exposed publicly but to client services under you control
EXPOSE 5001
# Web Gateway; can be exposed publicly with a proxy, e.g. as https://ipfs.example.org
EXPOSE 8080
# Swarm Websockets; must be exposed publicly when the node is listening using the websocket transport (/ipX/.../tcp/8081/ws).
EXPOSE 8081

# Create the fs-repo directory and switch to a non-privileged user.
ENV USER=ipfs
ENV IPFS_PATH=/data/ipfs

RUN adduser -D -h /home/$USER -u 1000 -G users $USER \
  # Create the fs-repo directory
  && mkdir -p $IPFS_PATH \
  && chown $USER:users $IPFS_PATH \
  # Create mount points for `ipfs mount` command
  && mkdir /ipfs /ipns \
  && chown $USER:users /ipfs /ipns

USER $USER

# Expose the fs-repo as a volume.
# start_ipfs initializes an fs-repo if none is mounted.
# Important this happens after the USER directive so permissions are correct.
VOLUME $IPFS_PATH

# The default logging level
ENV IPFS_LOGGING ""

ENTRYPOINT ["/entrypoint.sh"]

CMD ["daemon", "--migrate=true"]

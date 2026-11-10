# syntax=docker/dockerfile:1.28
# git-pkgs/proxy at the release UPSTREAM_COMMIT names, with every patch in patches/ applied in
# order. The test stage runs upstream's suite on the patched source; CI builds it, and the
# image stage runs as upstream's image does: uid 1000 in /data.

# v0.11.0 of 2026-10-31.
ARG UPSTREAM_COMMIT=15789d40bb47556b05c2e142c3923d5290c3544f

# 1.27.2 of 2026-10-08, the newest Go image at least 7 days old. v0.11.0 needs Go 1.26.7.
FROM --platform=$BUILDPLATFORM golang:1.27.2-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS source
ARG UPSTREAM_COMMIT
# The git cache tests run git, and go.mod's toolchain line must not fetch a newer Go.
# apk installs through the package proxy when the build has its packages-netrc secret (CI); without it, from Alpine's own mirrors.
RUN --mount=type=secret,id=packages-netrc,target=/root/.netrc,required=false \
    set -e; \
    repos=""; \
    if [ -s /root/.netrc ]; then \
      v=$(cut -d. -f1,2 /etc/alpine-release); \
      repos="--repositories-file /dev/null --repository https://packages.jorisjonkers.dev/apk/alpine/v$v/main --repository https://packages.jorisjonkers.dev/apk/alpine/v$v/community"; \
    fi; \
    apk add --no-cache $repos git
ENV GOTOOLCHAIN=local CGO_ENABLED=0
ADD https://github.com/git-pkgs/proxy.git#${UPSTREAM_COMMIT} /src
WORKDIR /src
COPY patches/ /patches/
RUN set -e; for p in /patches/*.patch; do echo "applying ${p##*/}"; git apply --verbose "$p"; done
ARG GOPROXY
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=secret,id=packages-netrc,target=/run/secrets/packages-netrc,required=false \
    NETRC=/run/secrets/packages-netrc go mod download

FROM source AS test
ARG GOPROXY
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=secret,id=packages-netrc,target=/run/secrets/packages-netrc,required=false \
    NETRC=/run/secrets/packages-netrc go vet ./... && NETRC=/run/secrets/packages-netrc go test ./...

FROM source AS build
ARG GOPROXY
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=secret,id=packages-netrc,target=/run/secrets/packages-netrc,required=false \
    NETRC=/run/secrets/packages-netrc GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/proxy ./cmd/proxy

# 3.24.2, the runtime upstream's v0.11.0 image uses.
FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
# apk installs through the package proxy when the build has its packages-netrc secret (CI); without it, from Alpine's own mirrors.
RUN --mount=type=secret,id=packages-netrc,target=/root/.netrc,required=false \
    set -e; \
    repos=""; \
    if [ -s /root/.netrc ]; then \
      v=$(cut -d. -f1,2 /etc/alpine-release); \
      repos="--repositories-file /dev/null --repository https://packages.jorisjonkers.dev/apk/alpine/v$v/main --repository https://packages.jorisjonkers.dev/apk/alpine/v$v/community"; \
    fi; \
    apk add --no-cache $repos ca-certificates git \
 && adduser -D -u 1000 proxy
COPY --from=build /out/proxy /usr/local/bin/proxy
# By number: the images lock refuses a named user.
USER 1000:1000
WORKDIR /data
EXPOSE 8080
ENTRYPOINT ["proxy"]
CMD ["serve"]

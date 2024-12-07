FROM golang:alpine AS webhook-build

WORKDIR /go/src/github.com/adnanh/webhook

# Install dependencies
RUN apk add --update -t build-deps curl libc-dev gcc libgcc jq

# Set default version to "latest" if not specified
ARG VERSION=latest

# If VERSION is set to "latest", fetch the latest release version from GitHub API
RUN if [ "$VERSION" = "latest" ]; then \
        VERSION=$(curl -s https://api.github.com/repos/adnanh/webhook/releases/latest | jq -r .tag_name); \
    fi && \
    echo "Using version ${VERSION}" && \
    curl -L --silent -o webhook.tar.gz "https://github.com/adnanh/webhook/archive/${VERSION}.tar.gz" && \
    tar -xzf webhook.tar.gz --strip 1

# Download dependencies
RUN go get -d -v

# Build the binary
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/webhook

# Stage 2: Clone and prepare transferwee
FROM alpine:latest AS transferwee-setup

RUN apk add --no-cache git

WORKDIR /app/transferwee

# Clone transferwee repository
RUN git clone https://github.com/iamleot/transferwee.git .

# Stage 3: Create final image
FROM python:3-alpine

LABEL org.opencontainers.image.source = "https://github.com/jee-r/docker-transferwee-hook" 

RUN pip install requests
WORKDIR /app/transferwee

# Install dependencies for transferwee
COPY --from=transferwee-setup /app/transferwee /app/transferwee
COPY --from=webhook-build /usr/local/bin/webhook /usr/local/bin/webhook
COPY ./hooks.yaml /hooks.yaml

WORKDIR /data

# Expose default ports used by both applications (if needed)
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/webhook"]
CMD [ "-verbose", "-hooks", "/hooks.yaml" ]
FROM alpine:latest

RUN apk add --no-cache \
    bats \
    bash \
    git \
    jq

RUN apk add --no-cache --virtual .build-deps go && \
    go install github.com/editorconfig-checker/editorconfig-checker/v3/cmd/editorconfig-checker@latest && \
    apk del --no-cache .build-deps

RUN git config --global user.email "you@example.com" && \
    git config --global user.name "Your Name" && \
    git config --global --add safe.directory /app

ENV PATH="/root/go/bin:${PATH}"
WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]

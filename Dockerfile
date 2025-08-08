# Build the manager binary
FROM registry.access.redhat.com/ubi9/go-toolset:1.24.4@sha256:a90b4605b47c396c74de55f574d0f9e03b24ca177dec54782f86cdf702c97dbc as builder

USER 1001

WORKDIR /opt/app-root/src

# Copy the Go Modules manifests
COPY --chown=1001:0 go.mod go.mod
COPY --chown=1001:0 go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY --chown=1001:0 . .

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -cover -covermode=atomic -a -o manager cmd/main.go \
 && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o snapshotgc cmd/snapshotgc/snapshotgc.go

ARG ENABLE_WEBHOOKS=true
ENV ENABLE_WEBHOOKS=${ENABLE_WEBHOOKS}
# Use ubi-minimal as minimal base image to package the manager binary
# Refer to https://catalog.redhat.com/software/containers/ubi9/ubi-minimal/615bd9b4075b022acc111bf5 for more details
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6-1752587672
COPY --from=builder /opt/app-root/src/manager /manager-go
COPY --from=builder /opt/app-root/src/snapshotgc /

# To allow the non-root user to write to a temporary directory, we
# create a new directory and set its ownership. This is more explicit
# and secure than relying on system-wide permissions for directories like /tmp.
RUN mkdir -p /tmp/appdata && \
    chown -R 65532:65532 /tmp/appdata

# It is mandatory to set these labels
LABEL name="integration-service"
LABEL com.redhat.component="konflux-integration-service"
LABEL description="Konflux Integration Service"
LABEL io.k8s.description="Konflux Integration Service"
LABEL io.k8s.display-name="Integration-service"
LABEL summary="Konflux Integration Service"
LABEL io.openshift.tags="konflux"

COPY entrypoint.sh manager
RUN chmod +x manager

USER 65532:65532

ENV GOCOVERDIR=/tmp/appdata

ENTRYPOINT ["/manager"]

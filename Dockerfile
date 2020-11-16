FROM --platform=$BUILDPLATFORM golang:alpine AS build

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "Build: $BUILDPLATFORM, target: $TARGETPLATFORM" > /log

FROM bcgdesign/alpine-s6:1.0.4
COPY --from=build /log /log

ARG TARGETPLATFORM

LABEL maintainer="Ben Green <ben@bcgdesign.com>" \
    org.label-schema.name=".NET" \
    org.label-schema.version="latest" \
    org.label-schema.vendor="Ben Green" \
    org.label-schema.schema-version="1.0"

# https://github.com/dotnet/dotnet-docker/blob/master/src/runtime-deps/3.1/alpine3.12/amd64/Dockerfile
RUN addgroup --gid 1000 www \
    && adduser --uid 1000 --no-create-home --disabled-password --ingroup www www \
    && rm -rf /var/cache/apk/* \
    && apk -U upgrade \
    && apk add \
        ca-certificates \
        krb5-libs \
        libgcc \
        libintl \
        libssl1.1 \
        libstdc++ \
        zlib

COPY ./VERSION /tmp/VERSION
COPY ./install /tmp/install
RUN chmod +x /tmp/install \
    && /tmp/install \
    && rm -rf /tmp/*

VOLUME [ "/src" ]

COPY ./overlay /

EXPOSE 5000

ENV \
    # Must be defined so the service can run the application
    DOTNET_RUN_ASSEMBLY= \
    # Configure web servers to bind to port 5000
    ASPNETCORE_URLS="http://+:5000" \
    # Otherwise it is set incorrectly to the S6 service directory
    ASPNETCORE_CONTENTROOT="/src" \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Set the invariant mode since icu_libs isn't included (see https://github.com/dotnet/announcements/issues/20)
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true

RUN chmod +x /usr/bin/healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=5 CMD [ "/usr/bin/healthcheck" ]

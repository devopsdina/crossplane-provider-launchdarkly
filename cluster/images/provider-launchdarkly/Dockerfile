FROM alpine:3.23.0
RUN apk --no-cache add ca-certificates bash && apk --no-cache upgrade

ARG TARGETOS
ARG TARGETARCH

ADD "bin/${TARGETOS}_${TARGETARCH}/provider" /usr/local/bin/provider

ENV USER_ID=65532

USER ${USER_ID}
EXPOSE 8080

ENTRYPOINT ["provider"]

FROM atareao/cronirs:latest

LABEL maintainer="Lorenzo Carbonell <a.k.a. atareao> lorenzo.carbonell.cerezo@gmail.com"

RUN apk add --update \
            --no-cache \
            postgresql15-client~=15.1 \
            run-parts~=4.11 && \
    rm -rf /var/cache/apk

COPY entrypoint.sh backup.sh /app/

ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["/app/cronirs"]

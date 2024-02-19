FROM alpine:latest

USER root

RUN apk add --update --no-cache curl logrotate tzdata
RUN adduser -D -g '' app
RUN mkdir /app

ADD duckdns.sh /app
ADD logrotate.conf /app
ADD init.sh /root

CMD /root/init.sh

FROM alpine:3.4
MAINTAINER Joonathan Mägi <joonathan@fiji.ee>

RUN apk add --update \
            ca-certificates \
            python \
            py-pip \
    && rm -rf /var/cache/apk/*

COPY . .

RUN pip install --upgrade pip \
    && pip install -r requirements.txt

EXPOSE 8000

CMD gunicorn -b 0.0.0.0:8000 app:app
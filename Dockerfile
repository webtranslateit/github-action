FROM ruby:alpine

RUN gem install web_translate_it --no-document \
 && apk add --no-cache git curl jq bash github-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

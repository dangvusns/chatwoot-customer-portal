ARG BASE_IMAGE=chatwoot-company:local
FROM ${BASE_IMAGE}

ENV RAILS_ENV=test \
    NODE_ENV=test \
    BUNDLE_WITHOUT="" \
    EXECJS_RUNTIME=Node

RUN apk add --no-cache postgresql-dev openssl-dev linux-headers
COPY Gemfile Gemfile.lock /app/
RUN bundle config unset without && bundle install --jobs 4
RUN node /usr/local/lib/node_modules/npm/bin/npm-cli.js install --global pnpm@10.2.0

COPY package.json pnpm-lock.yaml /app/
RUN pnpm install --frozen-lockfile
COPY . /app

CMD ["bundle", "exec", "rspec", "spec/custom"]

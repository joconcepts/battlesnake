FROM ruby:alpine

RUN mkdir /app
WORKDIR /app
ADD Gemfile client.rb /app/
RUN bundle install -j8

ENTRYPOINT ["bundle", "exec", "ruby", "client.rb"]

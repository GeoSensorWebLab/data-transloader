# Ruby 2.6 is the recommended version
FROM ruby:2.6

# Set the language to ensure encodings are handled properly.
# Otherwise the transloader tool will have errors parsing.
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

WORKDIR /usr/src/app

# Set up the gems for this image early, as it is slower
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy contents of the repository into the image
COPY . .

ENTRYPOINT ["ruby", "transload"]
CMD ["--help"]
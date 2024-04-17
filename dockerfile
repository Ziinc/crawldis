
ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.1
ARG DEBIAN_VERSION=bookworm-20240130

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_* && \
    mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

ENV MIX_ENV="prod"
COPY mix.exs mix.lock ./
RUN mkdir config
COPY config/runtime.exs config/config.exs config/${MIX_ENV}.exs config/
COPY apps apps
RUN  mix deps.get && mix deps.compile && mix compile && mix release crawldis

FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  tini \ 
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/crawldis ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
ENTRYPOINT ["tini", "--"]
WORKDIR "/app/bin"

CMD ["./crawldis", "start"]
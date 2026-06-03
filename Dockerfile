# syntax=docker/dockerfile:1

# First things first, we build an image which is where we're going to compile
# our static assets with. We use this stage in development.
FROM node:25.8.1-trixie AS static-deps

# Set our working directory to our src directory
WORKDIR /opt/warehouse/src/

# However, we do want to trigger a reinstall of our node.js dependencies anytime
# our package.json changes, so we'll ensure that we're copying that into our
# static container prior to actually installing the npm dependencies.
COPY package.json package-lock.json babel.config.js /opt/warehouse/src/

# Installing npm dependencies is done as a distinct step and *prior* to copying
# over our static files so that, you guessed it, we don't invalidate the cache
# of installed dependencies just because files have been modified.
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm ci




# This is our actual build stage, where we'll compile our static assets.
FROM static-deps AS static

# Actually copy over our static files, we only copy over the static files to
# save a small amount of space in our image and because we don't need them. We
# copy `webpack.config.js` last even though it's least likely to change, because
# it's very small so copying it needlessly isn't a big deal but it will save a
# small amount of copying when only `webpack.config.js` is modified.
COPY warehouse/static/ /opt/warehouse/src/warehouse/static/
COPY warehouse/admin/static/ /opt/warehouse/src/warehouse/admin/static/
COPY warehouse/locale/ /opt/warehouse/src/warehouse/locale/
COPY webpack.config.js /opt/warehouse/src/
COPY webpack.plugin.localize.js /opt/warehouse/src/

RUN NODE_ENV=production npm run build




# Create a base image that contains some helpers and settings for our python
# stages to inherit from.
FROM python:3.14.5-slim-trixie AS base

# Copy our helpers over into the base image
COPY bin/docker/* /usr/local/bin/

# By default, Docker has special steps to avoid keeping APT caches in the layers, which
# is good, but in our case, we're going to mount a special cache volume (kept between
# builds), so we WANT the cache to persist.
RUN set -eux; \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Pre-compile the stdlib bytecode to save time collectively on container boot!
RUN python -m compileall /usr/local/lib -j 0

# Set our working directory to our src directory
WORKDIR /opt/warehouse/src/

# Setup our $PATH so that it contains what will be our normal bin directory.
ENV PATH="/opt/warehouse/bin:${PATH}"




# We'll build a light-weight layer along the way with just docs stuff
FROM base AS docs

# Install System level build requirements, this is done before everything else
# because these are rarely ever going to change.
# Usages:
#  - build-essential: make
#  - git: mkdocs plugin uses this for created/updated
#  - libcairo2: mkdocs uses cairosvg
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
        apt-install \
            build-essential \
            git \
            libcairo2

# We create an /opt directory with a virtual environment in it to store our
# application in, we'll use --upgrade-deps to make sure we have the latest
# version of pip.
RUN --mount=type=cache,id=pkg,target=/root/.cache \
        create-venv /opt/warehouse

# Install the Python level Warehouse requirements, this is done after copying
# the requirements but prior to copying Warehouse itself into the container so
# that code changes don't require triggering an entire install of all of
# Warehouse's dependencies.
RUN --mount=type=cache,id=pkg,target=/root/.cache \
    --mount=type=bind,src=requirements/,dst=/opt/warehouse/src/requirements/ \
    pip-install \
        -r requirements/docs-dev.txt \
        -r requirements/docs-user.txt \
        -r requirements/docs-blog.txt

# We'll make the docs container run as a non-root user, ensure that the built
# documentation belongs to the same user on the host machine.
ARG USER_ID
ARG GROUP_ID
RUN groupadd -o -g $GROUP_ID -r docs
RUN useradd -o -m -u $USER_ID -g $GROUP_ID docs
RUN chown docs /opt/warehouse/src
USER docs




# Now we're going to build our actual application image
FROM base

# Setup some basic environment variables that are ~never going to change.
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/opt/warehouse/src/

# We create an /opt directory with a virtual environment in it to store our
# application in
RUN --mount=type=cache,id=pkg,target=/root/.cache \
        create-venv /opt/warehouse

# Define whether we're building a production or a development image. This will
# generally be used to control whether or not we install our development and
# test dependencies.
ARG DEVEL=no

# Install System level Warehouse requirements, this is done before everything
# else because these are rarely ever going to change.
# Usages:
#  - build-essential: make
#  - postgresql-client: make initdb and friends
#  - oathtool: make totp
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    set -x \
    && if [ "$DEVEL" = "yes" ]; then \
        apt-install \
           build-essential \
           postgresql-client \
           oathtool \
           fd-find \
        # Debian renames the `fd` binary to `fdfind`, so we'll rename it back to `fd`.
        && ln -s $(which fdfind) /usr/local/bin/fd; \
    fi

# Define whether we're building a CI image. This will include all the docs stuff
# as well for the matrix!
ARG CI=no

# Install the Python level Warehouse requirements, this is done after copying
# the requirements but prior to copying Warehouse itself into the container so
# that code changes don't require triggering an entire install of all of
# Warehouse's dependencies.
RUN --mount=type=cache,id=pkg,target=/root/.cache \
    --mount=type=bind,src=requirements/,dst=/opt/warehouse/src/requirements/ \
    pip-install \
        -r requirements/deploy.txt \
        -r requirements/main.txt \
        $(if [ "$DEVEL" = "yes" ]; then echo '-r requirements/dev.txt -r requirements/tests.txt -r requirements/lint.txt'; fi) \
        $(if [ "$CI" = "yes" ]; then echo '-r requirements/docs-dev.txt -r requirements/docs-user.txt -r requirements/docs-blog.txt'; fi )

# To enable Ipython in the development environment set to yes (for using ipython
# as the warehouse shell interpreter,
# i.e. 'docker compose run --rm web python -m warehouse shell --type=ipython')
ARG IPYTHON=no

# Install the IPython dependencies, which has to be done as it's own step because
# we don't have pinned hashes for IPython.
RUN --mount=type=cache,id=pkg,target=/root/.cache \
    --mount=type=bind,src=requirements/,dst=/opt/warehouse/src/requirements/ \
    if [ "$DEVEL" = "yes" ] && [ "$IPYTHON" = "yes" ]; then \
      pip-install -r requirements/ipython.txt; \
    fi

# Pre-compile our dependencies bytecode to save time collectively on container boot!
RUN python -m compileall /opt/warehouse/lib/ -j 0

# Copy our compiled static files. These should overlay cleanly on top of the
# virtual environment and even when that gets invalidated, copything these is
# super fast.
COPY --from=static /opt/warehouse/src/warehouse/static/dist/ /opt/warehouse/src/warehouse/static/dist/
COPY --from=static /opt/warehouse/src/warehouse/admin/static/dist/ /opt/warehouse/src/warehouse/admin/static/dist/

# Copy warehouse into the container, this is done last so that changes to
# Warehouse itself require the least amount of layers being invalidated from
# the cache. This is most important in development, but it also useful for
# deploying new code changes.
#
# We copy warehouse subdirectories separately to minimize cache invalidation:
# changes to one subdirectory won't invalidate the cache for others.
#
# NOTE: We copy bin/release on it's own so that we can still exclude the rest
#       of the bin/ directory when we copy over everything else.
COPY bin/release /opt/warehouse/src/bin/release

# Copy warehouse subdirectories individually for better cache utilization
COPY warehouse/accounts/ /opt/warehouse/src/warehouse/accounts/
COPY warehouse/admin/ /opt/warehouse/src/warehouse/admin/
COPY warehouse/api/ /opt/warehouse/src/warehouse/api/
COPY warehouse/attestations/ /opt/warehouse/src/warehouse/attestations/
COPY warehouse/authnz/ /opt/warehouse/src/warehouse/authnz/
COPY warehouse/banners/ /opt/warehouse/src/warehouse/banners/
COPY warehouse/billing/ /opt/warehouse/src/warehouse/billing/
COPY warehouse/cache/ /opt/warehouse/src/warehouse/cache/
COPY warehouse/captcha/ /opt/warehouse/src/warehouse/captcha/
COPY warehouse/classifiers/ /opt/warehouse/src/warehouse/classifiers/
COPY warehouse/cli/ /opt/warehouse/src/warehouse/cli/
COPY warehouse/email/ /opt/warehouse/src/warehouse/email/
COPY warehouse/events/ /opt/warehouse/src/warehouse/events/
COPY warehouse/forklift/ /opt/warehouse/src/warehouse/forklift/
COPY warehouse/helpdesk/ /opt/warehouse/src/warehouse/helpdesk/
COPY warehouse/i18n/ /opt/warehouse/src/warehouse/i18n/
COPY warehouse/integrations/ /opt/warehouse/src/warehouse/integrations/
COPY warehouse/ip_addresses/ /opt/warehouse/src/warehouse/ip_addresses/
COPY warehouse/legacy/ /opt/warehouse/src/warehouse/legacy/
COPY warehouse/legal/ /opt/warehouse/src/warehouse/legal/
COPY warehouse/locale/ /opt/warehouse/src/warehouse/locale/
COPY warehouse/macaroons/ /opt/warehouse/src/warehouse/macaroons/
COPY warehouse/manage/ /opt/warehouse/src/warehouse/manage/
COPY warehouse/metrics/ /opt/warehouse/src/warehouse/metrics/
COPY warehouse/migrations/ /opt/warehouse/src/warehouse/migrations/
COPY warehouse/mock/ /opt/warehouse/src/warehouse/mock/
COPY warehouse/observations/ /opt/warehouse/src/warehouse/observations/
COPY warehouse/oidc/ /opt/warehouse/src/warehouse/oidc/
COPY warehouse/organizations/ /opt/warehouse/src/warehouse/organizations/
COPY warehouse/packaging/ /opt/warehouse/src/warehouse/packaging/
COPY warehouse/rate_limiting/ /opt/warehouse/src/warehouse/rate_limiting/
COPY warehouse/referrer_metrics/ /opt/warehouse/src/warehouse/referrer_metrics/
COPY warehouse/rss/ /opt/warehouse/src/warehouse/rss/
COPY warehouse/search/ /opt/warehouse/src/warehouse/search/
COPY warehouse/sitemap/ /opt/warehouse/src/warehouse/sitemap/
COPY warehouse/sponsors/ /opt/warehouse/src/warehouse/sponsors/
COPY warehouse/static/ /opt/warehouse/src/warehouse/static/
COPY warehouse/subscriptions/ /opt/warehouse/src/warehouse/subscriptions/
COPY warehouse/templates/ /opt/warehouse/src/warehouse/templates/
COPY warehouse/tuf/ /opt/warehouse/src/warehouse/tuf/
COPY warehouse/utils/ /opt/warehouse/src/warehouse/utils/

# Copy warehouse top-level Python files
COPY warehouse/__init__.py /opt/warehouse/src/warehouse/__init__.py
COPY warehouse/__main__.py /opt/warehouse/src/warehouse/__main__.py
COPY warehouse/aws.py /opt/warehouse/src/warehouse/aws.py
COPY warehouse/b2.py /opt/warehouse/src/warehouse/b2.py
COPY warehouse/celery.py /opt/warehouse/src/warehouse/celery.py
COPY warehouse/config.py /opt/warehouse/src/warehouse/config.py
COPY warehouse/configure.py /opt/warehouse/src/warehouse/configure.py
COPY warehouse/constants.py /opt/warehouse/src/warehouse/constants.py
COPY warehouse/csp.py /opt/warehouse/src/warehouse/csp.py
COPY warehouse/csrf.py /opt/warehouse/src/warehouse/csrf.py
COPY warehouse/db.py /opt/warehouse/src/warehouse/db.py
COPY warehouse/errors.py /opt/warehouse/src/warehouse/errors.py
COPY warehouse/filters.py /opt/warehouse/src/warehouse/filters.py
COPY warehouse/forms.py /opt/warehouse/src/warehouse/forms.py
COPY warehouse/gcloud.py /opt/warehouse/src/warehouse/gcloud.py
COPY warehouse/http.py /opt/warehouse/src/warehouse/http.py
COPY warehouse/logging.py /opt/warehouse/src/warehouse/logging.py
COPY warehouse/predicates.py /opt/warehouse/src/warehouse/predicates.py
COPY warehouse/redirects.py /opt/warehouse/src/warehouse/redirects.py
COPY warehouse/referrer_policy.py /opt/warehouse/src/warehouse/referrer_policy.py
COPY warehouse/routes.py /opt/warehouse/src/warehouse/routes.py
COPY warehouse/sanity.py /opt/warehouse/src/warehouse/sanity.py
COPY warehouse/sentry.py /opt/warehouse/src/warehouse/sentry.py
COPY warehouse/sessions.py /opt/warehouse/src/warehouse/sessions.py
COPY warehouse/static.py /opt/warehouse/src/warehouse/static.py
COPY warehouse/tasks.py /opt/warehouse/src/warehouse/tasks.py
COPY warehouse/views.py /opt/warehouse/src/warehouse/views.py
COPY warehouse/wsgi.py /opt/warehouse/src/warehouse/wsgi.py

# Copy remaining top-level files
COPY --exclude=requirements \
     --exclude=bin \
     --exclude=docs \
     --exclude=warehouse \
     --exclude=babel.config.js \
     --exclude=eslint.config.mjs \
     --exclude=package-lock.json \
     --exclude=package.json \
     --exclude=webpack.config.js \
     --exclude=webpack.plugin.localize.js \
        . /opt/warehouse/src/


# Pre-compile our module's bytecode to save time collectively on container boot!
# NOTE: We only do this when we're not building a dev build, because a dev build
#       will likely have a checkout mounted over warehouse anyways, so these
#       *.pyc files won't be used in that case.
RUN if [ "$DEVEL" != "yes" ]; then python -m compileall warehouse/ -j 0; fi

# Pre-cache TLD list
# NOTE: We only do this when we're not building a dev build, because a dev build
#       doesn't need to keep an updated tldextract database an can fall back to
#       snapshot included in tldextract.
RUN if [ "$DEVEL" != "yes" ]; then tldextract --update; fi

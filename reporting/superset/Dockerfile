FROM python:3.10-slim-bookworm

# Superset version
ARG SUPERSET_VERSION=6.0.0

# Superset-patchup (Ketchup) version
ARG SUPERSET_PATCHUP_VERSION=master

# Default Superset files dir
ARG APP_DIR=/usr/local/lib/python3.10/site-packages/superset

# Configure environment
ENV GUNICORN_BIND=0.0.0.0:8088 \
    GUNICORN_LIMIT_REQUEST_FIELD_SIZE=0 \
    GUNICORN_LIMIT_REQUEST_LINE=0 \
    GUNICORN_TIMEOUT=60 \
    GUNICORN_WORKERS=2 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONPATH=/etc/superset:/home/superset \
    SUPERSET_REPO=apache/superset \
    SUPERSET_VERSION=${SUPERSET_VERSION} \
    SUPERSET_PATCHUP_VERSION=${SUPERSET_PATCHUP_VERSION} \
    SUPERSET_PATCHUP_REPO=https://github.com/OpenLMIS/superset-patchup.git@${SUPERSET_PATCHUP_VERSION} \
    SUPERSET_HOME=/var/lib/superset \
    APP_DIR=${APP_DIR} \
    WORKER_CLASS=gevent

ENV GUNICORN_CMD_ARGS="--workers ${GUNICORN_WORKERS} -k ${WORKER_CLASS} --timeout ${GUNICORN_TIMEOUT} --bind ${GUNICORN_BIND} --limit-request-line ${GUNICORN_LIMIT_REQUEST_LINE} --limit-request-field_size ${GUNICORN_LIMIT_REQUEST_FIELD_SIZE}"

COPY requirements.txt requirements.txt

# Create superset user
RUN useradd -U -m superset && \
    mkdir /etc/superset  && \
    mkdir ${SUPERSET_HOME} && \
    chown -R superset:superset /etc/superset && \
    chown -R superset:superset ${SUPERSET_HOME}

# Install OS dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        rsync \
        git \
        wget \
        unzip \
        build-essential \
        curl \
        pkg-config \
        default-libmysqlclient-dev \
        freetds-bin \
        freetds-dev \
        postgresql-client \
        libssl-dev \
        libffi-dev \
        python3-dev \
        libsasl2-dev \
        libldap2-dev \
        libjpeg-dev \
        libpng-dev \
        libgeos-dev && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade setuptools "pip<25" && \
    pip install --no-cache-dir \
        gunicorn==23.0.0 \
        gevent==24.2.1 \
        flask-mail==0.10.0 \
        Flask-Migrate==4.0.7 \
        alembic==1.13.1 \
        redis==5.0.4 \
        psycopg2-binary==2.9.9 \
        pillow

RUN pip install --no-cache-dir \
        apache-superset==${SUPERSET_VERSION} \
        apache-superset[cors]==${SUPERSET_VERSION}

RUN pip install --no-cache-dir \
        git+${SUPERSET_PATCHUP_REPO} \
    && sed -i 's/from superset import app/from flask import current_app as app/g' /usr/local/lib/python3.10/site-packages/superset_patchup/oauth.py \
    && sed -i 's/self.get_session/self.session/g' /usr/local/lib/python3.10/site-packages/superset_patchup/oauth.py

# Configure Filesystem
RUN find ${APP_DIR} \! -type l -print0 | xargs -0 chown superset:superset
COPY superset /usr/local/bin
VOLUME /etc/superset \
       /var/lib/superset
WORKDIR $APP_DIR

# Node & npm
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=v20.18.3

RUN curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash
RUN . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH=$NVM_DIR/versions/node/$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH

RUN node -v
RUN npm -v

# Installing dependencies via npm
RUN npm install -g po2json

# Fetching dependencies and first build
RUN wget -P /tmp https://github.com/apache/superset/archive/${SUPERSET_VERSION}.zip \
    && unzip /tmp/${SUPERSET_VERSION}.zip -d /tmp \
    && rsync -a \
        --remove-source-files \
        --chown=superset:superset \
        /tmp/superset-${SUPERSET_VERSION}/superset-frontend $APP_DIR \
    && rm -r /tmp/${SUPERSET_VERSION}.zip

USER superset:superset
RUN cd $APP_DIR/superset-frontend && npm ci

# Deploy application
EXPOSE 8088
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8088/health"]

# Use Redis for caching instead of the metadata database
ENV CACHE_CONFIG='{"CACHE_TYPE": "RedisCache", "CACHE_REDIS_URL": "redis://redis:6379/0"}'

CMD ["gunicorn", "superset:app"]

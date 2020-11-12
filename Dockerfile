FROM python:3.5
WORKDIR /tmp
###
ARG TAIGA_SCRIPT_REPOSITORY=git@github.com:taigaio/taiga-scripts.git
###
ARG TAIGA_BACK_REPOSITORY=git@github.com:taigaio/taiga-back.git
ENV TAIGA_BACK_REPOSITORY=$TAIGA_BACK_REPOSITORY
ARG TAIGA_BACK_BRANCH=stable
ENV TAIGA_BACK_BRANCH=$TAIGA_BACK_BRANCH
###
ARG TAIGA_FRONT_DIST_REPOSITORY=git@github.com:taigaio/taiga-front-dist.git
ENV TAIGA_FRONT_DIST_REPOSITORY=$TAIGA_FRONT_DIST_REPOSITORY
ARG TAIGA_FRONT_DIST_BRANCH=stable
ENV TAIGA_FRONT_DIST_BRANCH=$TAIGA_FRONT_DIST_BRANCH
###
ARG TAIGA_FRONT_REPOSITORY=git@github.com:taigaio/taiga-front.git
ENV TAIGA_FRONT_REPOSITORY=$TAIGA_FRONT_REPOSITORY
ARG TAIGA_FRONT_BRANCH=stable
ENV TAIGA_FRONT_BRANCH=$TAIGA_FRONT_BRANCH
###
ENV DEBIAN_FRONTEND noninteractive
# ENV NGINX_VERSION 1.15.5-1~stretch
# ###
# RUN apt-key adv \
#   --keyserver hkp://pgp.mit.edu:80 \
#   --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

# RUN echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list

RUN set -x; apt-get update
RUN apt-get install -y nodejs npm nginx
RUN npm install -g gulp npm@latest
RUN apt-get install -y --no-install-recommends \
        locales \
        gettext \
        ca-certificates \
        # nginx=${NGINX_VERSION} \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales

RUN git clone -b ${TAIGA_BACK_BRANCH} --single-branch ${TAIGA_BACK_REPOSITORY} taiga-back
RUN cp -r ./taiga-back /usr/src/taiga-back
RUN git clone -b ${TAIGA_FRONT_BRANCH} ${TAIGA_FRONT_REPOSITORY} taiga-front-dist
RUN cd ./taiga-front-dist && npm ci && npx gulp deploy
RUN mkdir -p /usr/src/taiga-front-dist && cp -r ./taiga-front-dist/dist /usr/src/taiga-front-dist
# COPY taiga-back /usr/src/taiga-back
# COPY taiga-front-dist/ /usr/src/taiga-front-dist
COPY docker-settings.py /usr/src/taiga-back/settings/docker.py
COPY conf/locale.gen /etc/locale.gen
COPY conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx/taiga.conf /etc/nginx/conf.d/default.conf
COPY conf/nginx/ssl.conf /etc/nginx/ssl.conf
COPY conf/nginx/taiga-events.conf /etc/nginx/taiga-events.conf

# Setup symbolic links for configuration files
RUN mkdir -p /taiga
COPY conf/taiga/local.py /taiga/local.py
COPY conf/taiga/conf.json /taiga/conf.json
RUN ln -s /taiga/local.py /usr/src/taiga-back/settings/local.py
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/conf.json

# Backwards compatibility
RUN mkdir -p /usr/src/taiga-front-dist/dist/js/
RUN ln -s /taiga/conf.json /usr/src/taiga-front-dist/dist/js/conf.json

WORKDIR /usr/src/taiga-back

# specify LANG to ensure python installs locals properly
# fixes benhutchins/docker-taiga-example#4
# ref benhutchins/docker-taiga#15
ENV LANG C

RUN pip install --no-cache-dir -r requirements.txt

RUN echo "LANG=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_TYPE=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_MESSAGES=POSIX" >> /etc/default/locale
RUN echo "LANGUAGE=en" >> /etc/default/locale

ENV LANG en_US.UTF-8
ENV LC_TYPE en_US.UTF-8

ENV TAIGA_SSL False
ENV TAIGA_SSL_BY_REVERSE_PROXY False
ENV TAIGA_ENABLE_EMAIL False
ENV TAIGA_HOSTNAME "localhost:8080"
ENV TAIGA_SECRET_KEY "!!!REPLACE-ME-j1598u1J^U*(y251u98u51u5981urf98u2o5uvoiiuzhlit3)!!!"

RUN python manage.py collectstatic --noinput

RUN locale -a

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

VOLUME /usr/src/taiga-back/media

COPY checkdb.py /checkdb.py
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

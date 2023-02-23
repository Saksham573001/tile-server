FROM ubuntu:22.04
RUN apt update
RUN apt install -y libboost-all-dev
RUN apt install -y  git-core
RUN apt install -y tar
RUN apt install -y unzip
RUN apt install wget
RUN apt install bzip2
RUN apt install -y build-essential
RUN apt install autoconf

RUN apt install libtool
RUN apt install libxml2-dev
RUN apt install -y libgeos-dev
RUN apt install -y libgeos++-dev
RUN apt install -y libpq-dev
RUN apt install -y libbz2-dev
RUN apt install -y libproj-dev
RUN apt install -y munin-node munin
RUN apt install -y libprotobuf-c-dev
RUN apt install -y protobuf-c-compiler
RUN apt install -y libfreetype6-dev
RUN apt install -y libtiff5-dev
RUN apt install -y libicu-dev
RUN apt install -y libgdal-dev
RUN apt install -y libcairo-dev
RUN apt install -y libcairomm-1.0-dev
RUN apt install -y apache2
RUN apt install -y apache2-dev
RUN apt install -y libagg-dev
RUN apt install -y liblua5.2-dev
RUN apt-get update
# RUN apt-get install -y ttf-unifont
RUN apt-get install -y fonts-unifont
RUN apt install -y lua5.1
RUN apt install -y munin-node
RUN apt install -y  munin
RUN apt install -y liblua5.1-dev
# RUN apt install -y libgeotiff-epsg
RUN apt install -y curl

#install and configure Postgres
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install postgresql
RUN apt-get -y install postgresql-contrib
RUN apt-get -y install postgis
RUN apt-get -y install postgresql-14-postgis-3
RUN apt-get -y install postgresql-14-postgis-scripts
USER postgres
RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -E UTF8 -O docker gis &&\
    psql --dbname=gis --command "CREATE EXTENSION hstore;" &&\
    psql --dbname=gis --command "CREATE EXTENSION postgis;" &&\
    psql --dbname=gis --command "ALTER TABLE geometry_columns OWNER TO docker;" &&\
    psql --dbname=gis --command "ALTER TABLE spatial_ref_sys OWNER TO docker;" &&\
    /etc/init.d/postgresql stop

#build osm2pgsql
USER root
RUN git clone https://github.com/openstreetmap/osm2pgsql.git ~postgres/src/osm2pgsql --depth 1
RUN apt-get -y install make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev\
  zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev osmctools
RUN cd ~postgres/src/osm2pgsql && mkdir build && cd build && cmake .. && make && make install

#install Mapnik
RUN apt-get -y install autoconf
RUN apt-get -y install apache2-dev
RUN apt-get -y install libtool
RUN apt-get -y install libxml2-dev
RUN apt-get -y install libbz2-dev
RUN apt-get -y install libgeos-dev
RUN apt-get -y install libgeos++-dev
RUN apt-get -y install libproj-dev
RUN apt-get -y install gdal-bin
RUN apt-get -y install libmapnik-dev
RUN apt -y install mapnik-utils
RUN apt -y install python3-mapnik
RUN apt-get -y install sudo

#build mod_tile and renderd
# Newer commits in mod_tile remove the renderd.init file since the project is now in Debian / Ubuntu
# official repositories, which provide their own init configuration, but those packages are only in
# newer versions. Once we update this container to use 22.04, or another newer Ubuntu version, we can
# install mod_tile that way and avoid having to build it ourselves entirely.

RUN apt install libtool
RUN apt-get -y install libiniparser-dev
RUN git init .
RUN git clone https://github.com/openstreetmap/mod_tile.git
# RUN cd /mod_tile && ./autogen.sh
RUN cd /mod_tile && ./autogen.sh && ./configure
RUN cd /mod_tile && make && make install && make install-mod_tile && ldconfig


# #build carto (map style configuration)
RUN apt-get install -y npm
RUN apt-get install -y nodejs
RUN apt-get install -y node-gyp
RUN apt-get install -y nodejs
RUN apt-get install -y libssl1.0
RUN npm install -g carto

# # install kosmtik
# RUN npm -g install kosmtik

# #install fonts
RUN apt-get -y install fonts-noto-cjk
# RUN apt-get -y install fonts-noto-cjk
RUN apt-get -y install fonts-noto-hinted
RUN apt-get -y install fonts-noto-unhinted
RUN apt-get -y install fonts-hanazono
# RUN apt-get -y install ttf-unifont

# RUN apt-get -y install ttf-dejavu
# RUN apt-get -y install ttf-dejavu-core
# RUN apt-get -y install ttf-dejavu-extra
RUN apt-get -y install cabextract

# # #configure renderd
USER root
COPY etc/renderd.conf /usr/local/etc/renderd.conf
RUN mkdir /var/lib/mod_tile && chown postgres:postgres /var/lib/mod_tile
RUN mkdir /var/run/renderd && chown postgres:postgres /var/run/renderd
COPY etc/default_renderd.sh /etc/default/renderd
RUN mkdir renderd
# RUN cp /mod_tile/debian/renderd.init /etc/init.d/renderd && chmod a+x /etc/init.d/renderd
# RUN rm /etc/apache2/sites-enabled/000-default.conf

# # # configure apache
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/tile.load
RUN a2enmod tile
RUN a2enmod proxy
RUN a2enmod proxy_http
COPY etc/apache2_renderd.conf /etc/apache2/sites-available/renderd.conf
# COPY etc/apache2_kosmtik.conf /etc/apache2/sites-available/kosmtik.conf

# # additional fonts requred for pre-rendering
RUN cd /usr/share/fonts/truetype/noto/ && \
  wget https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf

# # generate tile scripts
RUN apt-get -y install python-pip
RUN apt -y install pip
RUN pip install awscli
RUN aws configure set default.s3.max_concurrent_requests 100
COPY etc/generate_tiles.py /var/lib/postgresql/src/generate_tiles.py
RUN chmod a+x /var/lib/postgresql/src/generate_tiles.py

# # install and configure styles
RUN git clone https://github.com/jacobtoye/osm-bright.git /style --depth 1
COPY etc/configure.py /style/configure.py
COPY etc/osm-smartrak.osm2pgsql.mml /style/themes/osm-smartrak/osm-smartrak.osm2pgsql.mml
COPY etc/skate-style/img /style/themes/osm-smartrak/img

COPY etc/default-style/palette.mss /style/themes/default/palette.mss
COPY etc/default-style/labels.mss /style/themes/default/labels.mss
COPY etc/skate-style/palette.mss /style/themes/skate/palette.mss
COPY etc/skate-style/labels.mss /style/themes/skate/labels.mss
COPY etc/skate-style/base.mss /style/themes/skate/base.mss

# # fix permissions
RUN chown -R postgres:postgres ~postgres/
RUN chown -R postgres:postgres /style

# copy test pages
COPY ./local.html /var/www/html/
COPY ./prod.html /var/www/html/
COPY ./dev.html /var/www/html/
# simulate a health check
RUN touch /var/www/html/_health

# copy map data loader script
COPY ./load_map_data.sh /
RUN chmod +x load_map_data.sh

COPY ./docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]

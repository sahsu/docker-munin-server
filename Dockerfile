from ubuntu
MAINTAINER Sean Hsu <sahsu.mobi@gmail.com>

# most come from https://github.com/jekil/docker-munin-server

# Update
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y munin cron nginx spawn-fcgi libcgi-fast-perl &&  \
    apt-get clean && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*
# 2.99.2
RUN apt-get install -y wget && wget https://github.com/munin-monitoring/munin/archive/2.999.2.tar.gz && tar -xvf 2.999.2.tgz.gz


# Configure as cgi.
RUN sed -i 's/^#graph_strategy cron/graph_strategy cgi/g' /etc/munin/munin.conf 
RUN sed -i 's/^#html_strategy cron/html_strategy cgi/g' /etc/munin/munin.conf

# Disable localhost monitoring.
RUN sed -i 's/^\[localhost\.localdomain\]/#\[localhost\.localdomain\]/g' /etc/munin/munin.conf
RUN sed -i 's/^    address 127.0.0.1/#    address 127.0.0.1/g' /etc/munin/munin.conf
RUN sed -i 's/^    use_node_name yes/#    use_node_name yes/g' /etc/munin/munin.conf

# Create munin dirs.
RUN mkdir -p /var/run/munin
RUN chown -R munin:munin /var/run/munin

COPY run.sh /usr/local/bin/start-munin
COPY nginx.conf /etc/nginx/sites-available/default

VOLUME /var/lib/munin
VOLUME /var/log/munin
VOLUME /etc/munin

EXPOSE 80
CMD ["start-munin"]

from ubuntu:14.04
MAINTAINER Sean Hsu <sahsu.mobi@gmail.com>

# Update
RUN apt-get update -y && \
    apt-get install -y software-properties-common && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cron nginx spawn-fcgi libcgi-fast-perl &&  \
    apt-get clean && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# munin 2.0.55
RUN add-apt-repository -y ppa:pneu/munin && \
apt-get update -y && \
apt-get install munin -y && \
apt-get clean && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

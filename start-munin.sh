#!/bin/bash
NODES=${NODES:-}
# generate node list
for NODE in $NODES
do
  NAME=`echo $NODE | cut -d ":" -f1`
  HOST=`echo $NODE | cut -d ":" -f2`
  PORT=`echo $NODE | cut -d ":" -f3`
  if [ ${#PORT} -eq 0 ]; then
      PORT=4949
  fi
  if ! grep -q "'^$HOST$'" /etc/munin/munin.conf ; then
    cat << EOF >> /etc/munin/munin.conf
[$NAME]
    address ssh://munin-async@$HOST /usr/share/munin/munin-async --spooldir /var/lib/munin-async/ --spoolfetch
    use_node_name yes
    port $PORT

EOF
    echo "Added node '$NAME' '$HOST'"
    fi
done

[ -d /var/cache/munin/www ] || mkdir /var/cache/munin/www
# placeholder html to prevent permission error
if [ ! -e /var/cache/munin/www/index.html ]; then
cat << EOF > /var/cache/munin/www/index.html
<html>
<head>
  <title>Munin</title>
</head>
<body>
Munin has not run yet.  Please try again in a few moments.
</body>
</html>
EOF
chown munin:munin -R /var/cache/munin/www
chmod g+w /var/cache/munin/www/index.html
fi

# deploy ssh key
cd; echo -e "\n\n\n" | ssh-keygen -t rsa && cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
mkdir -p ~/munin/.ssh/ ~munin-async/.ssh/
cp ~/.ssh/id_rsa ~munin/.ssh/id_rsa
cp ~/.ssh/id_rsa.pub ~munin-async/.ssh/authorized_keys
chown -R munin-async ~munin-async
chown -R munin ~munin
# start ssh
service ssh start
# start async daemon
service munin-async start
# start rsyslogd
/usr/sbin/rsyslogd
# start cron
/usr/sbin/cron
# Issue: 'NUMBER OF HARD LINKS > 1' prevents cron exec in container
# https://github.com/phusion/baseimage-docker/issues/198
touch /etc/crontab /etc/cron.d/*
# start diskstats with root
echo '[diskstats]
user root' >> /etc/munin/plugin-conf.d/munin-node
# start local munin-node
/usr/sbin/munin-node
echo "Using the following munin nodes:"
echo $NODES
# start spawn-cgi to enable CGI interface with munin (dynamix graph generation)
spawn-fcgi -s /var/run/munin/fcgi-graph.sock -U munin -u munin -g munin /usr/lib/munin/cgi/munin-cgi-graph
# spawn in /etc/crontab
echo '* * * * * root spawn-fcgi -s /var/run/munin/fcgi-graph.sock -U munin -u munin -g munin /usr/lib/munin/cgi/munin-cgi-graph > /dev/null' >> /etc/crontab
echo '* * * * * root service munin-async status | grep "is running" > /dev/null || service munin-async restart > /dev/null' >> /etc/crontab

# start nginx
/usr/sbin/nginx
# start rrdcached
mkdir -p /var/lib/munin/rrdcached-journal/
/usr/bin/rrdcached \
  -p /run/munin/rrdcached.pid \
  -B -b /var/lib/munin/ \
  -F -j /var/lib/munin/rrdcached-journal/ \
  -m 0660 -l unix:/run/munin/rrdcached.sock \
  -w 1800 -z 1800 -f 3600
chgrp www-data /run/munin/rrdcached.sock

echo 'rrdcached_socket /run/munin/rrdcached.sock' >> /etc/munin/munin.conf

chmod 777 /var/log/munin/*log
su - munin --shell=/bin/bash -c /usr/bin/munin-cron

# show logs
echo "Tailing syslog and munin-update log..."
tail -F /var/log/syslog /var/log/munin/munin-update.log & pid=$!
echo "tail -F running in $pid"

sleep 1

trap "echo 'stopping processes' ; kill $pid $(cat /var/run/munin/munin-node.pid) $(cat /var/run/nginx.pid) $(cat /var/run/crond.pid) $(cat /var/run/rsyslogd.pid)" SIGTERM SIGINT

echo "Waiting for signal SIGINT/SIGTERM"
wait

#!/bin/bash
cp mailgraph-init /etc/init.d/mailgraph
chmod +x /etc/init.d/mailgraph

cp mailgraph.pl /usr/local/bin/mailgraph.pl
chmod +x /usr/local/bin/mailgraph.pl

cp write_static_site.pl ~/scripts/
chmod +x ~/scripts/write_static_site.pl


#### Install hpasmcli, hpacucli and curl.

**Ubuntu 16.04 :**

```
nano /etc/apt/sources.list.d/HP-mcp.list
# HP
deb http://downloads.linux.hpe.com/SDR/repo/mcp xenial/10.40 non-free
```

```
apt-get update
apt-get install hpasmcli hpacucli curl
```

```
git clone https://github.com/cyborg00222/InfluxHP/
cd InfluxHP
mkdir /root/scripts/
cp hpa* /root/scripts
```

#### Install crontab
```
crontab -e
*/1 * * * * /bin/bash /root/scripts/hpacucli.sh 0
*/1 * * * * /bin/bash /root/scripts/hpasmcli.sh
```

Now import the Grafana Dashboard and you should be ready to go :)

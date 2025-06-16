# Docker compose file for rucio server

1) Copy all these files in a folder such as

```
   cp -r ../LDCS_rucio ~
   cd ~/LDCS_rucio
```

2) Add values to the variables in `env` and rename the file to .env

```  
   mv env .env
```

3) Switch to root (mainly for access to port 443)

```
   sudo -s
```

4) Deploy and edit the relevant configuration files in ../configFiles. Create folders if needed.

5) Start the services with docker-compose

```
docker compose -f docker-compose-rucioserver-postgres.yml up -d

```

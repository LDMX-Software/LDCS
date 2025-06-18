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
Make sure passwords and paths match between the configFiles and the docker-compose file

5) Start all the services with docker-compose

```
docker compose -f docker-compose-rucioserver-postgres-daemons.yml up -d

```
6) To stop all the services:
```
docker compose -f docker-compose-rucioserver-postgres-daemons.yml down

```

Refer to docker compose documentation for further information on how to interact with each single service.


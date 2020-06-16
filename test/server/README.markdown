# Test SensorThings API Server

The Vagrantfile will create an Ubuntu 18.04 Server VM and install the open-source FROST SensorThings API server for local testing of the data-transloader.

```
$ vagrant up
```

The STA can then be accessed via the IP defined in the Vagrantfile: [http://192.168.33.77:8080/FROST-Server/v1.0](http://192.168.33.77:8080/FROST-Server/v1.0).

You can "reset" the STA to a blank slate by logging in to the VM and restarting docker-compose:

```
$ vagrant ssh
vm$ cd FROST
vm$ docker-compose down
vm$ docker volume prune -f
vm$ docker-compose up -d
```

Or shutdown the VM without deletion:

```
$ vagrant halt
```

Shutdown with deletion:

```
$ vagrant destroy
```

# docker-sshd
Docker container to run OpenSSH server with chrooted user access [WIP]

# Build

```Shell
docker build -t docker-sshd .
```

# Run

```Shell
docker create -v /jails --name docker-sshd-data docker-sshd
docker run --volumes-from docker-sshd-data docker-sshd
```

or

```Shell
docker run -v "./data:/jails" docker-sshd
```

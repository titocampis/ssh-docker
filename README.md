# Server with SSH Service running in a Docker Container

## Requirements
- Docker Installed
- Docker Compose Installed

## Content
1. [Generate SSH RSA key pair](#1-generate-ssh-rsa-key-pair)

2. [Build the ubuntu:ssh image](#2-build-the-ubuntussh-image)
    - 2.1 [Dockerfile](#21-dockerfile)
    - 2.2 [Building the image](#22-building-the-image)  
3. [Run the container using docker compose](#3-run-the-container-using-docker-compose)
4. [Connect via ssh with the container ssh server](#4-connect-via-ssh-with-the-container-ssh-server)

## 1. Generate SSH RSA key pair (only if you don't have one yet)
SSH protocol can use public key cryptography for authenticating hosts and users. This configuration improves security by avoiding the need to have password stored in files, and eliminated the possibility of a compromised server stealing the user’s password. For that reason, we should generate SSH public and private key on our client and authorize them into the host. We have choosen SSH RSA algorithm to encrypt the password, but there are others like ed25519.

1. Access / Create the `~/.ssh` folder:
```bash
cd ~/.ssh
```
2. Create the SSH RSA key pair:
```bash
ssh-keygen -t rsa -b 4096 -C your_user
```

>:paperclip: **NOTE:** There is no need to copy the configuration into the sever because we are going to share it using a volume when running the container.

## 2. Build the ubuntu:ssh image
### 2.1 Dockerfile
To run the ssh service inside a container, we have choosen the basic [ubuntu docker image](https://hub.docker.com/_/ubuntu/). We have configured the image in order to run the ssh service inside it, and to have the correct files to authenticate the ssh connectivity.

To check the modifications take a look into the [Dockerfile](Dockerfile).

I will highlight 2 steps:
- We modify the configuration of SSH to enable `RSAAuthentication` and `PubkeyAuthentication` while disable `PasswordAuthentication`. Also we configure it to ignore `Rhosts` and permissions to the folder:
```Dockerfile
RUN chown -R ${USER}:${USER} /home/${USER}/.ssh &&\
    echo "Host remotehost\n\tStrictHostKeyChecking no\n" >> /home/${USER}/.ssh/config &&\
    echo "RSAAuthentication yes\nPubkeyAuthentication yes\nPasswordAuthentication no\nIgnoreRhosts yes" >> /etc/ssh/sshd_config
```
- We add a symbolic link in the file `/home/${USER}/.ssh/authorized_keys` of the container pointing to the content of the secret `user_ssh_rsa` which is stored under `/run/secrets/user_ssh_rsa` because it is configured in [docker-compose.yaml](docker-compose.yaml) like secret inside the container
```Dockerfile
RUN ... ln -s /run/secrets/user_ssh_rsa /home/${USER}/.ssh/authorized_keys
```

### 2.2 Building the image
Build the docker image:
```bash
docker build -t ubuntu:ssh .
```
- user: alex
- password: securepassword

> :paperclip: **NOTE:** To create a custom user and password run the `docker build` command using `--build-arg` and modifying `custom_user` and `custom_password`:
>```bash
> docker build -t ubuntu:ssh --build-arg USER=custom_user --build-arg PSWD=custom_password
>```

## 3. Run the container using docker compose
We have generated a very simple [docker-compose.yaml](docker-compose.yaml) file configuring a **secret** inside the container with the content of the local file `~/.ssh/id_rsa_shared` and consumed by `~/.ssh/authorized_keys` file of the docker server.

```yaml
container:
    secrets:
      - user_ssh_rsa

secrets:
  user_ssh_rsa:
    file: ~/.ssh/id_rsa_shared.pub
```

Also, we are using an [.env](.env) to configure [docker-compose.yaml](docker-compose.yaml).

>:paperclip: **NOTE:** by default, docker compose uses the `.env` file for the configuration without use any flag, if we want to use another file we can use it:
>```bash
> docker compose --env-file my-conf-file up
>```

>:warning: **WARNING:** docker compose uses your linux env variables, and linux env vars take precedence over the ones configured in any file. To check the configuration taken by docker compose:
>```bash
> docker compose config
>```

:one: Run the container (as daemon) using `docker compose` with the `-env` configuration file:
```bash
docker compose up -d
```
:two: Check the container logs, you should see:

![im6.png](pictures/im6.png)

:three: Check the container is running:
```bash
docker ps
```
![im1.png](pictures/im1.png)

:four: Check the contents of the `/home/$user/.ssh/` folder
```bash
docker exec ubuntu_ssh ls -la /home/alex/.shh
```
![im7.png](pictures/im7.png)

:five: Check the container is running the ssh service
```bash
docker exec ubuntu_ssh service ssh status
```
![im2.png](pictures/im2.png)

:six: Check the connectivity using `ping`
```bash
ping -c5 localhost -p 2222
```
![im4.png](pictures/im4.png)


## 4. Connect via ssh with the container ssh server

By default, ssh check the following keys:
- `~/.ssh/id_ecdsa`
- `~/.ssh/id_ecdsa_sk`
- `~/.ssh/id_ed25519`
- `~/.ssh/id_ed25519_sk`
- `~/.ssh/id_xmss`
- `~/.ssh/id_xmss`
- `~/.ssh/id_dsa`
- `~/.ssh/id_rsa`

So if our SSH RSA key is not one of the following, the connection will be refused. However, we can pass using the flag `-i` to set the key used to stablish connection.

So run the following command to stablish connection:
```bash
ssh -oPort=2222 -i ~/.ssh/id_rsa_shared alex@localhost
```
![im8.png](pictures/im8.png)

>:paperclip: If you run the command without specifying user, ssh will take your Linux current user, in my case `acampos`:
> ![im10.png](pictures/im10.png)

If you use a different user:
```bash
ssh -oPort=2222 -i ~/.ssh/id_rsa_shared custom_user@localhost
```

> :paperclip: If you want to not pass every time the pubkey you can stored in your ssh default keys using the `ssh-agent`, [documentation](https://www.linode.com/docs/guides/using-ssh-agent/)
>
>Starting up ssh-agent:
>```bash
> eval `ssh-agent`
>```
>
> Check the `ssh-agent` is running:
>```bash
> echo $SSH_AUTH_SOCK
>```
>
> Add the key you want to 
>```bash
> ssh-add ~/.ssh/custom_key
>```
> 
> To get a list of all the keys added
>```bash
> ssh-add -l
>```

> :warning: **WARNING 1:** If the SSH RSA public and private key are not inside the `~/.ssh/` of the **local machine** and the SSH RSA public key content inside the `~/.ssh/authorized_keys` file of the remote machine the connection will be refused.

> :warning: **WARNING 2:** When changing the docker container configuration, you will receive the following error: **WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!**
> ![im9.png](pictures/im9.png)
>
> This message appears when you try and connect over SSH to a remote server, and there's a mismatch between the server's public key and what's stored on your local machine.
> To solve it, you shoul run the following command to reset the host configuration:
> ```bash
>ssh-keygen -f "/home/acampos/.ssh/known_hosts" -R "[localhost]:2222"
>```
> And run again the ssh command:
> ```bash
>ssh -oPort=2222 -i ~/.ssh/id_rsa_shared alex@localhost
>```
> You can configure your local host to skip this message and continue with ssh connection, just add to the `~/.ssh/config` file with the following lines:
>```config
>Host localhost
>    StrictHostKeyChecking no
>```
> Also, you can run the command with the following flag to skip always the keychecking:
>```bash
>ssh -oPort=2222 -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_shared alex@localhost
>``` 
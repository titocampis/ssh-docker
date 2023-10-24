# Download base image ubuntu 18.04
FROM ubuntu:latest

# Defining the user and password
ARG USER=alex
ARG PSWD=securepassword

# Update Software repository
RUN apt-get update && apt-get upgrade -y 

# Install openssh-client and vi (in different stages to cache the update)
RUN apt-get install -y openssh-server vim

# Create the user with home directory and password and the /home/${USER}/.ssh directory, creating /home/${USER}/.ssh and
# creating a symbolic link pointing to the secret file from ~/.ssh/authorized_keys
RUN useradd -m ${USER} && echo "${USER}:${PSWD}" | chpasswd &&\
    mkdir -p /home/${USER}/.ssh &&\
    ln -s /run/secrets/user_ssh_rsa /home/${USER}/.ssh/authorized_keys &&\
    chown -R ${USER}:${USER} /home/${USER}/.ssh/authorized_keys

# Configuring te server to no StringHostkeyChecking
# Configure server SSH service to only allow PubKeyAuthentication
RUN echo "Host remotehost\n\tStrictHostKeyChecking no\n" >> /home/${USER}/.ssh/config &&\
    sed -ri 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config &&\
    echo "RSAAuthentication yes" >> /etc/ssh/sshd_config &&\
    sed -ri 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config &&\
    sed -ri 's/#IgnoreRhosts yes/IgnoreRhosts yes/g' /etc/ssh/sshd_config

# Inform docker to expose port 22
EXPOSE 22

# Start the ssh service and tail -F anything to mantain the container alive
CMD /etc/init.d/ssh start ; tail -F anything
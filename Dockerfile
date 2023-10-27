# Download base image ubuntu 18.04
FROM centos/systemd:latest

# Defining the user and password
ARG USER=alex
ARG PSWD=securepassword

# Update Software repository
RUN yum -y update && yum -y upgrade && yum clean all 

# Install openssh-client and different useful binaries (in different stages to cache the update)
#   also configure sshd.service to start when the server boots
RUN yum -y install openssh-server vim sudo &&\
    systemctl enable sshd.service

# Create the user with home directory and password, give him sudo permissions
#   add him to the sudo group and create the -p /home/${USER}/.ssh with correct permissions 
RUN useradd -m ${USER} && echo "${USER}:${PSWD}" | chpasswd &&\
    usermod -aG wheel alex &&\
    mkdir -p /home/${USER}/.ssh &&\
    chown -R ${USER}:${USER} /home/${USER}/.ssh

# Configuring SSH to only allow PubKeyAuthentication
#   for centos is not possible to configure StrictHostKeyChecking no
RUN sed -ri 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config &&\
    echo "RSAAuthentication yes" >> /etc/ssh/sshd_config &&\
    sed -ri 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config &&\
    sed -ri 's/#IgnoreRhosts no/IgnoreRhosts yes/g' /etc/ssh/sshd_config

# Inform docker to expose port 22
EXPOSE 22

# Start the systemd
CMD /usr/sbin/init
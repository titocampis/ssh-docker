# Download base image ubuntu 18.04
FROM ubuntu:latest

# Defining the user and password
ARG USER=alex
ARG PSWD=securepassword

# Update Software repository
RUN apt-get update && apt-get upgrade -y 

# Install openssh-client and vi (in different stages to cache the update)
RUN apt-get install openssh-server -y &&\
    apt-get install vim -y

# Create the user with home directory and password, create the /home/${USER}/.ssh directory and
# give permissions to the user and configure no StringHostkeyChecking
RUN useradd -m ${USER} && echo "${USER}:${PSWD}" | chpasswd &&\
    mkdir -p /home/${USER}/.ssh &&\
    chown -R ${USER}:${USER} /home/${USER}/.ssh && echo "Host remotehost\n\tStrictHostKeyChecking no\n" >> /home/${USER}/.ssh/config

# Inform docker to expose port 22
EXPOSE 22

# Start the ssh service and tail -F anything to mantain the container alive
CMD /etc/init.d/ssh start ; tail -F anything
FROM phusion/baseimage

CMD ["/sbin/my_init"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install rsync -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -f /etc/service/sshd/down

ADD ./build_env.sh /tmp/build_env.sh
ADD ./users.txt /tmp/users.txt

RUN /tmp/build_env.sh && \
    rm -rf /tmp*

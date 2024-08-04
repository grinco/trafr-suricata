FROM ubuntu:jammy

LABEL authors vadim@grinco.eu 


RUN apt update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:oisf/suricata-stable 
RUN apt update
RUN apt dist-upgrade -y

COPY /update.yaml /etc/suricata/update.yaml
COPY /suricata.logrotate /etc/logrotate.d/suricata

RUN apt -y install suricata

RUN suricata-update update-sources && \
        suricata-update enable-source oisf/trafficid && \
        suricata-update --no-test --no-reload && \
        /usr/bin/suricata -V

RUN cp -a /etc/suricata /etc/suricata.dist && \
        chmod 600 /etc/logrotate.d/suricata

VOLUME /var/log/suricata
VOLUME /var/lib/suricata
VOLUME /var/run/suricata
VOLUME /etc/suricata

RUN mkdir /app/
RUN wget http://www.mikrotik.com/download/trafr.tgz -O /tmp/trafr.tgz
RUN apt install -y libc6-i386
RUN cd /app/ && tar -zvxf /tmp/trafr.tgz && rm /tmp/trafr.tgz

WORKDIR /app/

COPY ./suricata.sh /app/
RUN chmod 755 /app/suricata.sh
CMD /app/suricata.sh


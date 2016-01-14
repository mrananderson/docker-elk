FROM java:8
MAINTAINER William Durand <william.durand1@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install --no-install-recommends -y supervisor curl

# Elasticsearch
RUN \
    apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 46095ACC8548582C1A2699A9D27D666CD88E42B4 && \
    if ! grep "elasticsearch" /etc/apt/sources.list; then echo "deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main" >> /etc/apt/sources.list;fi && \
    if ! grep "logstash" /etc/apt/sources.list; then echo "deb http://packages.elasticsearch.org/logstash/1.5/debian stable main" >> /etc/apt/sources.list;fi && \
    apt-get update

RUN \
    apt-get install --no-install-recommends -y elasticsearch && \
    apt-get clean && \
    sed -i '/#cluster.name:.*/a cluster.name: logstash' /etc/elasticsearch/elasticsearch.yml && \
    sed -i '/#path.data: \/path\/to\/data/a path.data: /data' /etc/elasticsearch/elasticsearch.yml

ADD etc/supervisor/conf.d/elasticsearch.conf /etc/supervisor/conf.d/elasticsearch.conf

RUN apt-get -y install curl libcurl4-openssl-dev ruby ruby-dev make build-essential

# Install Fluentd.
ENV GEM_HOME /usr/lib/fluent/ruby/lib/ruby/gems/1.9.1/
ENV GEM_PATH /usr/lib/fluent/ruby/lib/ruby/gems/1.9.1/
ENV PATH /usr/lib/fluent/ruby/bin:$PATH

RUN gem install fluentd
RUN fluentd --setup=/etc/fluent && \
    /usr/lib/fluent/ruby/bin/fluent-gem install fluent-plugin-elasticsearch \
    fluent-plugin-secure-forward fluent-plugin-record-reformer fluent-plugin-exclude-filter && \
    mkdir -p /var/log/fluent

# Copy fluentd config
ADD etc/fluent/fluent.conf /etc/td-agent/td-agent.conf
ADD config/etc/fluent/fluent.conf /etc/fluent/fluent.conf

RUN /etc/init.d/td-agent restart


# Kibana
RUN \
    curl -s https://download.elasticsearch.org/kibana/kibana/kibana-4.1.2-linux-x64.tar.gz | tar -C /opt -xz && \
    ln -s /opt/kibana-4.1.2-linux-x64 /opt/kibana && \
    sed -i 's/port: 5601/port: 80/' /opt/kibana/config/kibana.yml

ADD etc/supervisor/conf.d/kibana.conf /etc/supervisor/conf.d/kibana.conf

# Expose Fluentd port.
EXPOSE 24224

EXPOSE 9200
EXPOSE 9300


EXPOSE 80

CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf" ]


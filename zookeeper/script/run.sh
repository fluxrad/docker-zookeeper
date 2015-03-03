#!/bin/bash

config_path=/opt/zookeeper/conf/zoo.cfg
temp_path=/tmp/zk/zoo.cfg

if [[ -z "$ZOOKEEPER_ID" ]] || [[-z "$ZOOKEEPER_COUNT"]]; then
  echo "ERROR: You must specify a zookeeper id and zookeeper count."
  exit 1
fi

# Poor man's service discovery. 
# If we're the first instance, find the list of linked containers
# and add their IPs in the config. They'll be different every time.
if [[ $ZOOKEEPER_ID -eq 1 ]]; then
  for i in `seq 1 $ZOOKEEPER_COUNT`; do
    leaderPort=$( expr 2888 + $i)
    electionPort=$(expr 3888 + $i)

    # Use each container's internal IP, or else grab our own
    if [[ $i -eq $ZOOKEEPER_ID ]]; then
      zk_host=$(ip -4 -o addr show eth0 | awk -F'[ \/]' '{ print $7}')
    else
      zk_host=$(grep "zookeeper${i}$" /etc/hosts | awk '{print $1}')
    fi

    # Upsert the server entry
    if ! grep -q "server.$i" ; then
      echo "Adding entry for server.${i}, ip: ${docker_ip}"
      echo "server.${i}=${zk_host}:${leaderPort}:${electionPort}" | tee -a $config_path
    else
      sed -i -e "s/^server.${i}=.*/server.${i}=${zk_host}:${leaderPort}:${electionPort}/g" $config_path
    fi
  done

  cp $config_path $temp_path
else
  sleep 10 && cp $temp_path $config_path
fi

echo $ZOOKEEPER_ID > /tmp/zookeeper/myid

clientPort=$( expr 2181 + $ZOOKEEPER_ID - 1)
echo "Setting clientPort to $clientPort"
sed -i -e "s/^clientPort=.*$/clientPort=$clientPort/g" /opt/zookeeper/conf/zoo.cfg

/opt/zookeeper/bin/zkServer.sh start-foreground

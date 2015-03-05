#!/bin/bash
# Riak multi node setup script for single host.

ROOT=$(cd `dirname $0`; pwd)

usage() {
  cat<<EOS

Riak multi node setup script for single host.
=============================================

usage
-----
  $0 create node_count riak_home
  $0 start_all
  $0 stop_all
  $0 join_all
  $0 ping_all
  $0 clean
  $0 list
  $0 transfers
  $0 tail-log <node_id>
  $0 [start|stop|restart|reboot|ping|console|attach|chkconfig|escript|version] <node_id>

example)
  $0 create 3 /usr/local/riak : create configurations for 3 nodes.
  $0 start_all                : start all nodes.
  $0 join_all                 : make cluster.
  $0 stop 2                   : stop second node.
  $0 start 2                  : start second node.
EOS
}

clean(){
  for node in `ls -1 $ROOT/nodes`;do
    echo "rm $ROOT/nodes/$node"
    rm -rf $ROOT/nodes/$node
  done
  rmdir $ROOT/nodes
}

create_nodes(){
  node_cnt=$1
  riak_home=$2

  mkdir -p $ROOT/nodes

  i=1
  while [[ $i -le $node_cnt ]];do
    node_root=$ROOT/nodes/$i
    if [ -d $node_root ]; then
      echo "ERROR: $node_root" already exists.
      exit 1
    fi
    echo "creating node$i"
    mkdir -pv $node_root

    for dir in $(ls -1 $riak_home|grep -v log) ;do
      cp -pr $riak_home/$dir $node_root/$dir
    done

    if [ -f $riak_home/etc/riak.conf ]; then
      echo "  updating $node_root/etc/riak.conf"
      incr=$((($i-1)*100))
      cat $riak_home/etc/riak.conf  |\
        sed "s|riak@127.0.0.1|riak${i}@127.0.0.1|" |\
        sed "s|8087|$((8087 + $incr))|g" |\
        sed "s|8098|$((8098 + $incr))|g" |\
        sed "s|8099|$((8099 + $incr))|g" |\
        sed "s|8093|$((8093 + $incr))|g" |\
        sed "s|8985|$((8085 + $incr))|g" \
        > $node_root/etc/riak.conf

      echo "handoff.port = $((8099 + $incr))" >> $node_root/etc/riak.conf
    else
      echo "  updating $node_root/etc/vm.args"
      cat $riak_home/etc/vm.args |\
        sed "s|riak@127.0.0.1|riak${i}@127.0.0.1|" \
        > $node_root/etc/vm.args

      echo "  updating $node_root/etc/app.config"
      incr=$((($i-1)*100))
      cat $riak_home/etc/app.config  |\
        sed "s|8087|$((8087 + $incr))|g" |\
        sed "s|8098|$((8098 + $incr))|g" |\
        sed "s|8099|$((8099 + $incr))|g" \
        > $node_root/etc/app.config
    fi


    i=$(($i+1))
  done
}

command_all(){
  cmd=$1
  for node in `ls -1 $ROOT/nodes`;do
    command $cmd $node
  done
}

command(){
  cmd=$1
  node=$2
  echo "-- send $cmd message to node$node --"
  $ROOT/nodes/$node/bin/riak $cmd
}

join_all(){
  is_first=true
  for node in `ls -1 $ROOT/nodes`;do
    if [[ $is_first  == true ]]; then
      is_first=false
      continue
    fi
    $ROOT/nodes/$node/bin/riak-admin cluster join riak1
  done
  $ROOT/nodes/1/bin/riak-admin cluster plan
  $ROOT/nodes/1/bin/riak-admin cluster commit
  $ROOT/nodes/1/bin/riak-admin member-status
}

show-nodes(){
  ls -1 $ROOT/nodes | xargs -n1 echo node
}

required_args(){
  actual=$1
  required=$2
  if [[ $actual -lt $required ]]; then
    usage
    exit 1
  fi
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

case $1 in
  create)
    required_args $# 3
    create_nodes $2 $3
    ;;
  clean)
    clean
    ;;
  start[-_]all)
    command_all "start"
    ;;
  stop[-_]all)
    command_all "stop"
    ;;
  ping[-_]all)
    command_all "ping"
    ;;
  start|stop|restart|reboot|ping|console|attach|chkconfig|escript|version)
    required_args $# 2
    command $1 $2
    ;;
  list)
    show-nodes
    ;;
  join[-_]all)
    join_all
    ;;
  transfers)
    watch -n1 "$ROOT/nodes/bin/$2/riak-admin transfers 2>&1"
    ;;
  tail[-_]log)
    tail -f $ROOT/nodes/$2/log/console.log
    ;;
  *)
    usage
    ;;
esac

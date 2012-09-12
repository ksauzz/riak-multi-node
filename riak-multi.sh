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
  $0 start node_id
  $0 start_all
  $0 stop node_id
  $0 stop_all
  $0 join_all
  $0 clean

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
    mkdir -pv $ROOT/nodes/$i

    for dir in $(ls -1 $riak_home|grep -v data|grep -v log) ;do
      cp -pr $riak_home/$dir $ROOT/nodes/$i/$dir
    done

    cat $riak_home/etc/vm.args |\
      sed "s|riak@127.0.0.1|riak${i}@127.0.0.1|" \
      > $ROOT/nodes/$i/etc/vm.args

    incr=$((($i-1)*100))
    cat $riak_home/etc/app.config  |\
      sed "s|8087|$((8087 + $incr))|g" |\
      sed "s|8098|$((8098 + $incr))|g" |\
      sed "s|8099|$((8099 + $incr))|g" \
      > $ROOT/nodes/$i/etc/app.config

    i=$(($i+1))
  done
}

start_all(){
  for node in `ls -1 $ROOT/nodes`;do
    start $node
  done
}

start(){
  node=$1
  echo "starting node$node"
  $ROOT/nodes/$node/bin/riak start
}

stop_all(){
  for node in `ls -1 $ROOT/nodes`;do
    stop $node
  done
}

stop(){
  node=$1
  echo "killing node$node"
  $ROOT/nodes/$node/bin/riak stop
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
  start_all)
    start_all
    ;;
  start)
    required_args $# 2
    start $2
    ;;
  stop_all)
    stop_all
    ;;
  stop)
    required_args $# 2
    stop $2
    ;;
  join_all)
    join_all
    ;;
  *)
    usage
    ;;
esac

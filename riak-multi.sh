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
  $0 start-all
  $0 stop-all
  $0 join-all
  $0 ping-all
  $0 clean
  $0 list
  $0 transfers
  $0 tail-log <node_id>
  $0 ring-size <ring size>
  $0 rename <node_id> <new nodename>
  $0 enable-leveldb
  $0 enable-serch
  $0 [start|stop|restart|reboot|ping|console|attach|chkconfig|escript|version] <node_id>

example)
  $0 create 3 /usr/local/riak : create configurations for 3 nodes.
  $0 start_all                : start all nodes.
  $0 join_all                 : make cluster.
  $0 stop 2                   : stop second node.
  $0 start 2                  : start second node.
EOS
}

ensure_file(){
  if [ `find $ROOT -name $1 | wc -l` -lt 1 ]; then
    echo "ERROR: $1 is not found"
    exit 1
  fi
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

      if [ -f $riak_home/etc/advanced.config ]; then
        echo "  updating $node_root/etc/advanced.config"
        cat $riak_home/etc/advanced.config  |\
          sed "s|9080|$((9080 + $incr))|g" \
          > $node_root/etc/advanced.config
      fi
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
        sed "s|8099|$((8099 + $incr))|g" |\
        sed "s|9080|$((9080 + $incr))|g" \
        > $node_root/etc/app.config
    fi

    i=$(($i+1))
  done
}

rename() {
  node=$1
  oldname=`nodename $node`
  newname=$2
  echo "changing nodename from $oldnode to $newname..."
  echo "WARN: some functionarities of this tool won't work due to the name"
  command stop $node 
  sed -i.back "s/$oldname/$newname/" $ROOT/nodes/$node/etc/riak.conf
  rm -vrf $ROOT/nodes/$node/data/ring
  command start $node
  adm_command $node wait-for-service riak_kv
  case "$node" in
    1)
      adm_command $node cluster join `nodename 2`
      ;;
    *)
      adm_command $node cluster join `nodename 1`
      ;;
  esac
  adm_command $node down $oldname
  adm_command $node cluster force-replace $oldname $newname
  adm_command $node cluster plan
  adm_command $node cluster commit
}

nodename() {
  node=$1
  grep nodename $ROOT/nodes/$node/etc/riak.conf | awk '{print $3}'
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

adm_command(){
  node=$1
  shift
  echo "-- send riak-admin "$@" message to node$node --"
  $ROOT/nodes/$node/bin/riak-admin "$@"
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
  rename)
    required_args $# 2
    ensure_file "riak.conf"
    shift
    rename $@
    ;;
  ring[-_]size)
    required_args $# 2
    ensure_file "riak.conf"
    find $ROOT -name riak.conf -exec sed -i.bak "s/## ring_size = 64/ring_size = $2/" {} \;
    ;;
  enable[-_]search)
    ensure_file "riak.conf"
    find $ROOT -name riak.conf -exec sed -i.bak 's/search = off/search = on/' {} \;
    find $ROOT -name riak.conf -exec sed -i.bak 's/-Xms1g -Xmx1g/-Xms256m -Xmx256m/' {} \;
    ;;
  enable[_-]leveldb)
    ensure_file "riak.conf"
    echo "Changing backend to leveldb..."
    find $ROOT -name riak.conf -exec sed -i.back 's/storage_backend = bitcask/storage_backend = leveldb/' {} \;
    ;;
  frequent[-_]aae)
    ensure_file "riak.conf"
    if [ `grep -c "# frequent aae setting" $ROOT/nodes/1/etc/riak.conf` -lt 0 ]; then
      echo "already changed."
    fi
    find $ROOT -name riak.conf -exec sh -c "echo '# frequent aae setting' >> {}" \;
    find $ROOT -name riak.conf -exec sh -c "echo 'anti_entropy.tree.build_limit.number = 1' >> {}" \;
    find $ROOT -name riak.conf -exec sh -c "echo 'anti_entropy.tree.build_limit.per_timespan = 5s' >> {}" \;
    find $ROOT -name riak.conf -exec sh -c "echo 'anti_entropy.tree.expiry = 30m' >> {}" \;
    find $ROOT -name riak.conf -exec sh -c "echo 'anti_entropy.concurrency_limit = 10' >> {}" \;
    find $ROOT -name riak.conf -exec sh -c "echo 'anti_entropy.trigger_interval = 1s' >> {}" \;
    ;;
  *)
    usage
    exit 1
    ;;
esac

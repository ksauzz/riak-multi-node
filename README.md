# Riak multi node setup script for single host.

This is the management tool that makes a riak cluster on localhost without `make devrel` in riak's repository.

## Getting Started

1. git clone this repo.

    ```
    git clone https://github.com/ksauzz/riak-multi-node.git
    cd riak-multi-node
    ```

2. download precompiled riak tarball

    ```
    curl -O http://s3.amazonaws.com/downloads.basho.com/riak/2.0/2.0.0rc1/osx/10.8/riak-2.0.0rc1-OSX-x86_64.tar.gz
    tar xzvf riak-2.0.0rc1-osx-x86_64.tar.gz
    ```

3. make 5 node cluster

    ```
    ./riak-multi.sh create 5 ../riak-2.0.0rc1
    ./riak-multi.sh start_all
    ./riak-multi.sh join_all
    ```
_checkout 1.4.x branch, if you run riak 1.4.x._

## Usage

```
% ./riak-multi.sh

Riak multi node setup script for single host.
=============================================

usage
-----
  ./riak-multi.sh create node_count riak_home
  ./riak-multi.sh start_all
  ./riak-multi.sh stop_all
  ./riak-multi.sh join_all
  ./riak-multi.sh ping_all
  ./riak-multi.sh clean
  ./riak-multi.sh list
  ./riak-multi.sh [start|stop|restart|reboot|ping|console|attach|chkconfig|escript|version] node_id

example)
  ./riak-multi.sh create 3 /usr/local/riak : create configurations for 3 nodes.
  ./riak-multi.sh start_all                : start all nodes.
  ./riak-multi.sh join_all                 : make cluster.
  ./riak-multi.sh stop 2                   : stop second node.
  ./riak-multi.sh start 2                  : start second node.
```

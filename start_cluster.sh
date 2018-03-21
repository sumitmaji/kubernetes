#!/bin/bash

[[ "TRACE" ]] && set -x

/bin/bash /cluster/setDns.sh
/bin/bash /cluster/install_haproxy.sh

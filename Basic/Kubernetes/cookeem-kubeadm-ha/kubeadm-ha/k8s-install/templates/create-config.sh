#!/bin/bash

# before you run this script, please run command below first
# sed -i '1,2d' create-config.sh && sh create-config.sh

sed -i '1,2d' keepalived/check_apiserver.sh
sed -i '1,2d' nginx-lb/nginx-lb.conf
chmod a+x keepalived/check_apiserver.sh
{{- range $i, $host := $.Values.kubernetesInfo.kubernetesHosts }}
mkdir -p config/{{ $host.hostName }}/{keepalived,nginx-lb}
cp keepalived/* config/{{ $host.hostName }}/keepalived/
cp nginx-lb/* config/{{ $host.hostName }}/nginx-lb/
{{- end }}
cp calico-v3.17.2/*.yaml config/
cp kubeadm-config.yaml config/

# create keepalived.conf files
{{ $authPass := randAlphaNum 24 }}
{{- range $i, $host := $.Values.kubernetesInfo.kubernetesHosts }}
cat << EOF > config/{{ $host.hostName }}/keepalived/keepalived.conf
! #########################
! Configuration File for keepalived
! #########################
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 5
    weight -60
    fall 2
    rise 2
}
vrrp_instance VI_1 {
    state BACKUP
    mcast_src_ip {{ $host.hostIP}}
    interface {{ $host.hostNetworkInterface}}
    priority {{ $host.keepalivedPriority}}
    authentication {
        auth_type PASS
        auth_pass {{ $authPass }}
    }
    virtual_ipaddress {
        {{ $.Values.kubernetesInfo.kubernetesVip }}
    }
    virtual_router_id 51
    advert_int 5
    track_script {
       check_apiserver
    }
}
EOF
{{- end }}

{{- range $i, $host := $.Values.kubernetesInfo.kubernetesHosts }}
ssh {{ $host.hostName }} mkdir -p /etc/kubernetes/
scp -r config/{{ $host.hostName }}/nginx-lb root@{{ $host.hostName }}:/etc/kubernetes/
scp -r config/{{ $host.hostName }}/keepalived/ root@{{ $host.hostName }}:/etc/kubernetes/
ssh {{ $host.hostName }} "cd /etc/kubernetes/keepalived/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"
ssh {{ $host.hostName }} "cd /etc/kubernetes/nginx-lb/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"
{{- end }}

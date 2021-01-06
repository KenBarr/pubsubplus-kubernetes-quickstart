#!/bin/sh
APP=`basename "$0"`

ansible_workspace="/tmp/ansible_workspace"
solace_pw=`cat /mnt/disks/secrets/username_admin_password`
solace_primary_broker=${STATEFULSET_NAME}-0.${STATEFULSET_NAME}-discovery.${STATEFULSET_NAMESPACE}.svc
solace_backup_broker=${STATEFULSET_NAME}-1.${STATEFULSET_NAME}-discovery.${STATEFULSET_NAMESPACE}.svc
loop_guard=60
pause=10
count=0
resync_step=""
role=""
#find active broker
while [ ${count} -lt ${loop_guard} ]; do 
    run_time=$((${count} * ${pause}))
    health_result_primary=`curl -s -o /dev/null -w "%{http_code}"  http://${solace_primary_broker}:5550/health-check/guaranteed-active`
    health_result_backup=`curl -s -o /dev/null -w "%{http_code}"  http://${solace_backup_broker}:5550/health-check/guaranteed-active`

    if [[ ${health_result_primary} == "200" ]]; then
        solace_active_broker=${solace_primary_broker}
        echo "`date` INFO: ${APP}- Setting active broker to ${solace_primary_broker}"
        break
    fi
    if [[ ${health_result_backup} == "200" ]]; then
        solace_active_broker=${solace_backup_broker}
        echo "`date` INFO: ${APP}- Setting active broker to ${solace_backup_broker}"
        break
    fi
    echo "`date` INFO: ${APP}-Waited ${run_time} seconds, Primary: ${solace_primary_broker} reports: ${health_result_primary} Backup: ${solace_backup_broker} reports: ${health_result_backup}"
    let "count=count+1"
    sleep ${pause}
done

echo "`date` INFO: ${APP}- Setting sempv2_host to: ${solace_active_broker}"

mkdir ${ansible_workspace}
cd ${ansible_workspace}
cp /mnt/disks/solace/broker_inventory.yml  ${ansible_workspace}/broker_inventory.yml

sed -i "s/sempv2_host: localhost/sempv2_host: ${solace_active_broker}/" ${ansible_workspace}/broker.inventory.yml
sed -i "s/sempv2_password: admin/sempv2_password: ${solace_pw}/" ${ansible_workspace}/broker.inventory.yml

export ANSIBLE_SOLACE_ENABLE_LOGGING=True
export ANSIBLE_SOLACE_LOG_PATH="$WORKING_DIR/ansible-solace.log"
ansible-playbook -i "${ansible_workspace}/broker.inventory.yml" "/mnt/disks/solace/playbook.yml"  --extra-vars "AUTO_RUN=$AUTO_RUN"
  code=$?; if [[ $code != 0 ]]; then echo ">>> ERROR - $code"; exit 1; fi

while [ 1 ]; do
 sleep 30
done

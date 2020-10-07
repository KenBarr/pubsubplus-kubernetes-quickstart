#!/bin/sh
APP=`basename "$0"`
#Set up Python
PYTHONUNBUFFERED=1
apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
python3 -m ensurepip
pip3 install --no-cache --upgrade pip setuptools
#Install Ansible
apk add ansible
#Add Solace and tools
pip3 install --upgrade ansible-solace
apk add curl
apk add bash

ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

cd ~
#wget https://raw.githubusercontent.com/solace-iot-team/ansible-solace/master/project-template/playbook.yml
cp /mnt/disks/solace/playbook.yml .
wget https://raw.githubusercontent.com/solace-iot-team/ansible-solace/master/project-template/broker.inventory.yml
wget https://raw.githubusercontent.com/solace-iot-team/ansible-solace/master/project-template/run.sh
wget https://raw.githubusercontent.com/solace-iot-team/ansible-solace/master/.lib/run.project-env.sh
wget https://raw.githubusercontent.com/solace-iot-team/ansible-solace/master/.lib/functions.sh
mkdir .lib
mv run.project-env.sh .lib
mv functions.sh .lib
chmod +x run.sh
# comment out wait4key
sed -i 's/x=$(showEnv)/#x=$(showEnv)/' run.sh
sed -i 's/x=$(wait4Key)/#x=$(wait4Key)/' run.sh

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
sed -i "s/sempv2_host: localhost/sempv2_host: ${solace_active_broker}/" broker.inventory.yml
sed -i "s/sempv2_password: admin/sempv2_password: ${solace_pw}/" broker.inventory.yml

./run.sh

while [ 1 ]; do
 sleep 30
done
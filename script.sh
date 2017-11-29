#!/bin/bash

clear
echo "Bienvenidos al script para libvirt"

user=$(whoami)

if [ "$user" != "root" ]; then
	echo "No eres root, tienes que ser root para ejecutar este script"
	exit
fi


sleep 2s
clear


#creacion de la red virtual
echo "Vamos a comprobar que haya una red virtual"
red=$(virsh net-list | grep active |wc -l)
sleep 2s
clear


if [ $red = 0 ]; then
	echo "No hay redes virtuales creadas"
	sleep 2s
	clear
	echo "Vamos a crear una"
	virsh net-create /home/dani/Documentos/HLC/nat.xml
	sleep 2s
	clear
	echo "Red creada:"
else
	echo "Hay redes virtuales creadas"
fi
sleep 3s
clear

echo "Red virtual actual"
echo ""
virsh net-list | grep active
sleep 4s
clear



echo "Vamos a comprobar si las maquina MV1 esta encendida"
sleep 2s
clear


#obtencion de ip de la primera maquina

ip=$(virsh net-dhcp-leases nat |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')


estado=$(virsh list --all | grep running)
if [ "$estado" = "" ]; then
	echo "La maquina MV1 esta apagada, vamos a encenderla"
	sleep 2s
	clear
	virsh start mv1
	sleep 10s
	echo "Maquina encendida"
else
	echo "La maquina esta encendida"
fi
sleep 3s
clear



echo "Procedemos a añadirle un volumen y a montarlo"
echo ""
lsblk | grep disco
sleep 4s
clear

#añadir volumen a la maquina virtual
virsh -c qemu:///system attach-disk mv1 /dev/mapper/ASIR-disco vdb
sleep 2s
#montaje del volumen
ssh root@192.168.26.118 mount /dev/vdb /var/www/html




#reglas de iptables
iptables -I FORWARD -d 192.168.26.118/24 -p tcp --dport 80 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.26.118:80









#comprobación en firefox
echo "Vamos a comprobar que funciona nuestra pagina"
firefox www.mv1.org &>/dev/null &
sleep 15s
pkill -KILL firefox
#kill -9 `ps aux | grep "firefox-esr www.mv1.org" | tr -s " " | cut -d ' ' -f2 | head -n1`
sleep 1s
clear



echo "Momento de pausa para verificar todo"
echo "Por favor dale a enter"
read conf





#control de ram
mem=$(ssh root@192.168.26.118 cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
a=$(cat a)
while [ $a -ge 204800 ]; do
	echo "El consumo de RAM no superado el 60%"
	sleep 5s
	mem=$(ssh root@192.168.26.118 cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
	a=$(cat a)
done

rm -r a
clear
echo "¡¡¡¡¡¡¡¡¡¡¡¡¡¡NIVEL CRITICO!!!!!!!!!!!!!!!"
echo "   El consumo de RAM ha superado el 60%"
sleep 3s
clear
#
#
#
#
#stress -d 1000 --timeout 10
#
#
#
#
#desmontaje, desasociación y redimensión del volumen
echo "Procedemos a migrar la aplicación a nuestra segunda máquina"
sleep 2s
clear
ssh root@192.168.26.118 umount /var/www/html
sleep 3s
virsh -c qemu:///system detach-disk mv1 /dev/mapper/ASIR-disco
sleep 2s
virsh shutdown mv1
echo "Redimensionando el disco en 50M"
lvresize -L +50M /dev/ASIR/disco
mount /dev/ASIR/disco /mnt/
xfs_growfs /dev/ASIR/disco 
umount /mnt/

sleep 3s
clear
echo "Vamos a arrancar la otra máquina"
virsh start mv2
sleep 10s
clear



echo "Vamos a comprobar si la maquina MV2 se ha encendido"
sleep 2s
clear


#obtencion de ip de la segunda maquina

ip=$(virsh net-dhcp-leases nat |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')


estado=$(virsh list --all | grep running)
if [ "$estado" = "" ]; then
	echo "La maquina MV2 esta apagada, vamos a encenderla"
	sleep 2s
	clear
	virsh start mv2
	sleep 15s
	echo "Maquina encendida"
	sleep 2s
	clear
else
	echo "La maquina se encendio correctamente"
	sleep 2s
	clear
fi


echo "Procedemos a añadirle el volumen que hemos quitado a mv1 anteriomente, que ya esta redimensionando y vamos a montarlo"
echo ""
lsblk | grep disco
sleep 5s
clear

#añadir volumen a la maquina virtual
virsh -c qemu:///system attach-disk mv2 /dev/mapper/ASIR-disco sdb
sleep 3s

#montaje del volumen
ssh root@192.168.26.156 mount /dev/sdb /var/www/html
sleep 2s

#reglas de iptables
iptables -t nat -D PREROUTING `iptables -t nat -L --line-number | egrep 192.168.26.118 | cut -d " " -f 1`
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.26.156:80




#control de ram
mem=$(ssh root@192.168.26.156 cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
a=$(cat a)
while [ $a -ge 204800 ]; do
	echo "El consumo de RAM no superado el 80%"
	sleep 8s
	mem=$(ssh root@192.168.26.156 cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
	a=$(cat a)
done

rm -r a
clear
echo "¡¡¡¡¡¡¡¡¡¡¡¡¡¡NIVEL CRITICO!!!!!!!!!!!!!!!"
echo "   El consumo de RAM ha superado el 80%"
sleep 3s
clear

#aumentar ram de mv2
echo "Vamos a aumentar el tamaño de la ram de 1Gb a 2Gb"
sleep 3s
clear
echo "Memoria RAM actual:"
ssh mv2@192.168.26.156 cat /proc/meminfo | grep MemTotal
sleep 3s
echo ""
echo ""
echo "Memoria RAM actual despues de aumentar la RAM"
virsh setmem mv2 2G
ssh mv2@192.168.26.156 cat /proc/meminfo | grep MemTotal
sleep 5s
clear
echo "Momento de pausa para verificar todo"
echo "Por favor dale a enter"
read conf
clear

echo "FIN DEL SCRIPT"
sleep 2s
clear


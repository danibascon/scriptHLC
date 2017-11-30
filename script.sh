#!/bin/bash

clear
echo "Bienvenidos al script para libvirt"

user=$(whoami)

if [ "$user" = "root" ]; then

	sleep 2s
	clear


	#creacion de la red virtual
	echo "Vamos a comprobar que haya una red virtual"
	red=$(virsh net-list | grep active |wc -l)
	sleep 3s
	clear


	while [ $red = 0 ]; do
		echo "No hay redes virtuales creadas"
		sleep 2s
		clear
		echo "Vamos a crear una"
		virsh net-create /home/dani/Documentos/HLC/nat.xml
		sleep 2s
		clear
		red=$(virsh net-list | grep active |wc -l)
	done

	clear
	echo "Red creada"
	sleep 3s
	clear
	echo "Red virtual actual"
	echo ""
	virsh net-list | grep active
	sleep 4s
	clear
	cont=1

	while [ $cont != 3 ]; do
		if [ $cont = 1 ]; then
			var='primera'
		else
			var='segunda'
		fi

		echo "Vamos a comprobar que la $var esta encendida"
		estado=""
		estado=$(virsh list --all | grep -o running)
		echo $estado
		sleep 5s
		clear
		while [ "$estado" = "" ]; do
			echo "La $var maquina esta apagada, vamos a encenderla"
			sleep 2s
			clear
			virsh start mv$cont
			sleep 10s
			estado=$(virsh list --all | grep -o running)
		done
		clear "Maquina encendida, obteniendo ip"
		sleep 2s
		#obtencion de ip de la maquina
		ip=""
		acum=0
		while [ $acum = 0 ]; do
			echo "Obteniendo ip de la maquina..."
			acum=$(virsh net-dhcp-leases nat |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | wc -l)
			sleep 3s
			done

		ip=$(virsh net-dhcp-leases nat |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
		clear
		echo "La $var maquina se encendio correctamente y tiene la ip: $ip"
		sleep 3s
		clear

		#Montaje del volumen
		echo "Procedemos a añadirle un volumen y a montarlo"
		sleep 3s
		echo "volumen que vamos a añadir a nuestra maquina"
		echo ""
		lsblk | grep disco
		sleep 4s
		clear

		#añadir volumen a la maquina virtual
		if [ $cont = 1 ]; then
			virsh -c qemu:///system attach-disk mv$cont /dev/mapper/ASIR-disco vdb
			sleep 7s
			montaje=$(ssh root@"$ip" lsblk -f | grep vdb)
			if [ "$montaje" = "" ]; then
				echo "El volumen no se ha añadido bien, hazlo manualmente"
				echo "Presione enter para continuar"
				read conf
			fi
			#montaje del volumen
			ssh root@$ip mount /dev/vdb /var/www/html
			sleep 5s
			montaje=$(ssh root@"$ip" lsblk -f | grep /var/www/html)
			if [ "$montaje" = "" ]; then
				echo "El volumen no se ha montado bien, hazlo manualmente"
				echo "Presione enter para continuar"
				read conf
			fi
		else
			virsh -c qemu:///system attach-disk mv$cont /dev/mapper/ASIR-disco sdb
			sleep 7s
			montaje=$(ssh root@"$ip" lsblk -f | grep sdb)
			if [ "$montaje" = "" ]; then
				echo "El volumen no se ha añadido bien, hazlo manualmente"
				echo "Presione enter para continuar"
				read conf
			fi
			#montaje del volumen
			ssh root@$ip mount /dev/sdb /var/www/html
			sleep 2s
			montaje=$(ssh root@"$ip" lsblk -f | grep /var/www/html)
			if [ "$montaje" = "" ]; then
				echo "El volumen no se ha montado bien, hazlo manualmente"
				echo "Presione enter para continuar"
				read conf
			fi
		fi
		clear

		
		#reglas de iptables
		echo "Vamos las reglas iptables, precione enter para continuar"
		read conf
		clear
		if [ $cont = 1 ]; then
			echo "Añadiendo iptables"
			sleep 2s
			iptables -I FORWARD -d $ip/24 -p tcp --dport 80 -j ACCEPT
			iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $ip:80
		else
			iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.26.156:80
		fi

		sleep 3s
		clear

		echo "Momento de pausa para verificar todo"
		echo "Por favor dale a enter"
		read conf
		clear

		echo "Vamos a comprobar el consumo de la RAM"
		echo ""
		#control de ram
		mem=$(ssh root@"$ip" cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
		a=$(cat a)
		while [ $a -ge 204800 ]; do
			echo "El consumo de RAM no ha superado el 60%"
			sleep 5s
			mem=$(ssh root@"$ip" cat /proc/meminfo| grep MemAvailable | egrep -o "[0-9]{1,8}" > a)
			a=$(cat a)
		done

		rm -r a
		clear
		echo "¡¡¡¡¡¡¡¡¡¡¡¡¡¡NIVEL CRITICO!!!!!!!!!!!!!!!"
		echo "El consumo de RAM de mv$cont ha superado el 60%"
		sleep 3s
		clear

		if [ $cont = 1 ]; then

			#desmontaje, desasociación y redimensión del volumen
			echo "Procedemos a migrar la aplicación a nuestra segunda máquina"
			sleep 2s
			clear
			ssh root@$ip umount /var/www/html
			sleep 3s
			virsh -c qemu:///system detach-disk mv$cont /dev/mapper/ASIR-disco
			sleep 2s
			virsh shutdown mv$cont
			clear
			echo "Redimensionando el disco en 50M"
			sleep 2s
			lvresize -L +50M /dev/ASIR/disco
			mount /dev/ASIR/disco /mnt/
			xfs_growfs /dev/ASIR/disco 
			umount /mnt/
			iptables -t nat -D PREROUTING `iptables -t nat -L --line-number | egrep $ip | cut -d " " -f 1`
			sleep 3s
			clear


		else	
			#aumentar ram de mv2
			echo "Vamos a aumentar el tamaño de la ram de 1Gb a 2Gb"
			sleep 3s
			clear
			echo "Memoria RAM actual:"
			ssh mv$cont@$ip cat /proc/meminfo | grep MemTotal
			sleep 3s
			echo ""
			echo ""
			echo "Memoria RAM actual despues de aumentar la RAM"
			virsh setmem mv$cont 2G
			ssh mv$cont@$ip cat /proc/meminfo | grep MemTotal
			sleep 5s
			clear
			echo "Momento de pausa para verificar todo"
			echo "Por favor dale a enter"
			read conf
			clear
			virsh shutdown mv$cont
			echo "FIN DEL SCRIPT"
			sleep 2s
			clear
		fi
		let cont=cont+1
		clear
	done
else
	echo "No eres root, tienes que ser root para ejecutar este script"
fi



#mv1
#	stress -d 1000 --timeout 10


#mv2
#	stress -d 5000 --timeout 10

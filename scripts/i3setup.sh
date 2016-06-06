#!/bin/bash

rootcheck()
{
	# Check if script is running as root
	if [[ $UID != "0" ]]; then
		echo "Sorry, must sudo or be root to run this script."
		exit
	fi
}

dmicheck()
{
	# Need dmidecode before being able to set variables
	ISTHERE=$(pacman -Q dmidecode | cut -d' ' -f1)
	if [[ $ISTHERE != "dmidecode" ]]; then
		echo "This script requires dmidecode...  Installing..."
		pacman -S --noconfirm dmidecode
	else 
		echo "Found package dmidecode...  We can proceed."
	fi
}

install()
{
	rootcheck
	dmicheck

	# Variables
	DTREM='blueman bluez-libs bluez crda wireless-regdb'
	LTREM='dmraid dnsmasq flashplugin hexchat manjaro-welcome mousepad palemoon-bin pamac subversion xf86-input-elographics xf86-input-joystick moc'
	LAPTOP=$(dmidecode --string chassis-type)
	VBOX=$(grep 'Vendor: VBOX' /proc/scsi/scsi | cut -d' ' -f4)
	HPART=$(df | grep home | cut -d'/' -f4)
	BAT=$(ls /sys/class/power_supply | grep BAT | cut -d'T' -f2)

	#Check if script is running on a laptop, if not, remove certain pacakges, if so, remove different packages
	if [[ $LAPTOP != "Laptop" ]]; then
		pacman -Rs --noconfirm $DTREM
	fi
	pacman -Rs --noconfirm $LTREM

	# Check if running on virtual box.  If so, mount shared folder
	if [[ $VBOX == "VBOX" ]]; then
		echo 'Mounting Virutal Box shared folder...'
		mkdir /vboxshare
		mount -t vboxsf vboxshare /vboxshare
		echo "vboxshare        /vboxshare        vboxsf    defaults 0 0" >> /etc/fstab
	fi

	# Change keyserver
	sed -i "s/keyserver hkp:\/\/pool.sks-keyservers.net/keyserver hkp:\/\/keyserver.kjsl.com:80/" /etc/pacman.d/gnupg/gpg.conf

	# Update all software
	echo 'Updating system before installing software...'
	pacman-mirrors -g 
	pacman -S archlinux-keyring --noconfirm
	pacman -Syyuu --noconfirm


	echo 'Installing software...'
	pacman -S --noconfirm chromium dnsutils dropbox freerdp keepass vim openssh remmina nmap tmux weechat lynx newsbeuter
	sudo -u $SUDO_USER yaourt -S --noconfirm keepass-plugin-http scudcloud

	if [[ $VBOX != "VBOX" ]]; then
		pacman -S --noconfirm virtualbox clamav
	fi

	rm -rf /home/$SUDO_USER/.moonchild\ productions/
	rm -rf /home/$SUDO_USER/.config/hexchat/

	# Run pacdiff to update files
	pacdiff

	if [[ $VBOX == "VBOX" ]]; then
		rm /etc/X11/xorg.conf.d/90-mhwd.conf
	fi
}

configure()
{
	LAPTOP=$(dmidecode --string chassis-type)
	HPART=$(df --output=target | grep home)
	VBOX=$(grep 'Vendor: VBOX' /proc/scsi/scsi | cut -d' ' -f4)
	BAT=$(ls /sys/class/power_supply | grep BAT | cut -d'T' -f2)
	rootcheck
	# Assume git clone has already been done.
	echo 'Setting up user environment'
	rm /home/$SUDO_USER/.bashrc
	rm /home/$SUDO_USER/.tmux.conf
	rm -r /home/$SUDO_USER/.remmina
	rm -r /home/$SUDO_USER/.i3
	ln -s /home/$SUDO_USER/dotfiles/tssbashrc /home/$SUDO_USER/.bashrc
	ln -s /home/$SUDO_USER/dotfiles/tmux.conf /home/$SUDO_USER/.tmux.conf
	ln -s /home/$SUDO_USER/dotfiles/remmina /home/$SUDO_USER/.remmina
	ln -s /home/$SUDO_USER/dotfiles/i3 /home/$SUDO_USER/.i3
	mkdir -p /home/$SUDO_USER/.newsbeuter
	ln -s /home/$SUDO_USER/dotfiles/newsbeuter/urls /home/$SUDO_USER/.newsbeuter/urls
	ln -s /home/$SUDO_USER/dotfiles/scripts /home/$SUDO_USER/scripts
	ln -s /home/$SUDO_USER/dotfiles/basetmux.conf /home/$SUDO_USER/basetmux.conf

	# Confiuring Conky
	echo 'Configuring conky...'
	sed -i "/time %A/d" /usr/share/conky/conky_grey
	sed -i "/time %e/d" /usr/share/conky/conky_grey
	sed -i "/time %b/d" /usr/share/conky/conky_grey
	sed -i "/time %Y/d" /usr/share/conky/conky_grey

	# Config for i3status
	echo 'Configuring i3 status bar...'
	if [[ $HPART == "/home" ]]; then
		sed -i 's/# order += "disk \/home"/order += "disk \/home"/' /etc/i3status.conf
	fi 

	if [[ $BAT == "0@" ]]; then
		sed -i 's/# order += "battery 1/# order += "battery 0/' /etc/i3status.conf
		sed -i 's/battery 1 {/battery 0 {/' /etc/i3status.conf
	fi
	if [[ $LAPTOP != "Laptop" ]]; then
		sed -i 's/order += "battery/# order += "battery/' /etc/i3status.conf
	fi


	# Misc config
	echo 'Configuring random crap...'
	sed -i "/# Misc options/a ILoveCandy" /etc/pacman.conf
	sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub
	git config --global user.email "me@scottsexton.net"
	git config --global user.name "Scott Sexton"

	# Copy files from Dropbox
	echo "**** WARNING! **** If you haven't logged into dropbox yet, do so before continuing!!"
	echo 'Press any key to continue...'
	read ANSWER

	mkdir /home/$SUDO_USER/.weechat
	cp -r /home/$SUDO_USER/Dropbox/i3files/weechat/* /home/$SUDO_USER/.weechat
	cp -r /home/$SUDO_USER/Dropbox/i3files/backgrounds /home/$SUDO_USER/
	cp /home/$SUDO_USER/Dropbox/i3files/rwallpaper /usr/bin/

	if [[ $LAPTOP == 'Laptop' ]]; then
		rm /home/$SUDO_USER/backgrounds/1920x1200*
	fi

	if [[ $VBOX == 'VBOX' ]]; then
		rm /home/$SUDO_USER/backgrounds/1600x900*
	fi 

	# Fix ownership
	chown $SUDO_USER:users /home/$SUDO_USER -R
}

security()
{
	VBOX=$(grep 'Vendor: VBOX' /proc/scsi/scsi | cut -d' ' -f4)
	rootcheck
	# Security Section
	echo "Setting up security..."

	if [[ $VOX != 'VBOX' ]]; then
		echo 'Configuring Clam Anti Virus...'
		cp /etc/clamav/clamd.conf.sample /etc/clamav/clamd.conf
		cp /etc/clamav/freshclam.conf.sample /etc/clamav/freshclam.conf
		sed -i '/Example config file/d' /etc/clamav/clamd.conf
		sed -i '/Example/d' /etc/clamav/clamd.conf
		sed -i '/# Comment or remove/d' /etc/clamav/clamd.conf
		sed -i 's/#PidFile \/var\/run\/clamd.pid/PidFile \/run\/clamav\/clamd.pid/' /etc/clamav/clamd.conf
		sed -i 's/#LocalSocket /LocalSocket /' /etc/clamav/clamd.conf
		sed -i 's/#TCPSocket 3310/TCPSocket 3310/' /etc/clamav/clamd.conf
		sed -i '/Example config file/d' /etc/clamav/freshclam.conf
		sed -i '/Example/d' /etc/clamav/freshclam.conf
		sed -i '/# Comment or remove/d' /etc/clamav/freshclam.conf
		sed -i 's/#PidFile/PidFile/' /etc/clamav/freshclam.conf
		touch /var/lib/clamav/clamd.sock
		chown clamav:clamav /var/lib/clamav/clamd.sock
		freshclam -v
		freshclam -d
		systemctl enable clamd 
		systemctl enable freshclamd
		systemctl start clamd
		systemctl start freshclamd
	fi

	# Lock out the user for 10 minutes after 3 failed attempts

	# Make a backup copy of the original file
	cp /etc/pam.d/system-login $TMP/pam.d_system-login.orig
	sed -i 's/auth       required   pam_tally.so/#auth       required   pam_tally.so/' /etc/pam.d/system-login
	echo 'auth       required   pam_tally.so deny=2 unlock_time=600 onerr=succeed file=/var/log/faillog' >> /etc/pam.d/system-login

	# Reset the failed login attempts or pam will stop users from logging in
	pam_tally --reset

	# Set default Umask to 077
	sed -i 's/umask 022/umask 077/' /etc/profile

	# Ensure kernel is set to protect against security issues with sim and hard links
	hardlink=$(cat /proc/sys/fs/protected_hardlinks)
	symlink=$(cat /proc/sys/fs/protected_symlinks)
	if [[ $hardlink != "1" ]]; then
        	sysctl -w fs.protected_hardlinks=1
        	sed -i 's/fs.protected_hardlinks = 0/fs.protected_hardlinks = 1/' /usr/lib/sysctl.d/50-default.conf
	fi

	if [[ $symlink != "1" ]]; then
        	sysctl -w fs.protected_symlinks=1
        	sed -i 's/fs.protected_symlinks = 0/fs.protected_symlinks = 1/' /usr/lib/sysctl.d/50-default.conf
	fi

	# Setting visudo to use rnano

	awk '/# Defaults!REBOOT !log_output/ { print; print "Defaults editor=/usr/bin/rnano"; next }1' /etc/sudoers > $TMP/newsudoers
	rm /etc/sudoers
	cp $TMP/newsudoers /etc/sudoers
	chmod 440 /etc/sudoers

	# Set rvim as editor when sudo editing a file
	echo "# This entry added by the ezsec script" >> /etc/bash.bashrc
	echo "export SUDO_EDITOR=rvim" >> /etc/bash.bashrc

	# Restricting root login
	sed -i 's/%wheel ALL=(ALL) ALL/wheel ALL=(ALL) ALL/' /etc/sudoers
	sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

	# Restrict access to kernel log
	DMESG=$(sysctl kernel.dmesg_restrict | grep 1)
	if [[ $DMESG != "1" ]]; then
        	sysctl -w kernel.dmesg_restrict=1
        	echo "kernel.dmesg_restrict = 1" > /etc/sysctl.d/50-dmesg-restrict.conf
	fi

	# This section will setup iptables with a simple stateful firewall
	# as described here:
	#
	#          https://wiki.archlinux.org/index.php/Simple_stateful_firewall
 
	if [[ $VBOX != "VBOX" ]]; then
	echo "Setting up firewall rules..."
	iptables -F
	iptables -X
	iptables -N TCP
	iptables -N UDP
	iptables -P FORWARD DROP
	iptables -P OUTPUT ACCEPT
	iptables -P INPUT DROP
	iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
	iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
	iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
	iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
	iptables -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
	iptables -A INPUT -p tcp -j REJECT --reject-with tcp-rst
	iptables -A INPUT -j REJECT --reject-with icmp-proto-unreachable

	# If you are running a server or need to ssh into your box, uncomment the appropriate port
	#iptables -A TCP -p tcp --dport 80 -j ACCEPT
	#iptables -A TCP -p tcp --dport 443 -j ACCEPT
	#iptables -A TCP -p tcp --dport 22 -j ACCEPT
	#iptables -A UDP -p udp --dport 53 -j ACCEPT

	# Setup rules to trip up port scanners
	iptables -I TCP -p tcp -m recent --update --seconds 60 --name TCP-PORTSCAN -j REJECT --reject-with tcp-rst
	iptables -D INPUT -p tcp -j REJECT --reject-with tcp-rst
	iptables -A INPUT -p tcp -m recent --set --name TCP-PORTSCAN -j REJECT --reject-with tcp-rst
	iptables -I UDP -p udp -m recent --update --seconds 60 --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
	iptables -D INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
	iptables -A INPUT -p udp -m recent --set --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
	iptables -D INPUT -j REJECT --reject-with icmp-proto-unreachable
	iptables -A INPUT -j REJECT --reject-with icmp-proto-unreachable

	# Save the rules for reboots
	iptables-save > /etc/iptables/iptables.rules
	fi
}

both()
{
	rootcheck
	install
	configure
}

everything()
{
	rootcheck
	install
	configure
	security
}

"$@"

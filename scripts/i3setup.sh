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
	LTREM='dmraid dnsmasq flashplugin hexchat manjaro-welcome mousepad palemoon-bin pamac subversion xf86-input-elographics xf86-input-joystick'
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

	# Update all software
	echo 'Updating system before installing software...'
	pacman-mirrors -g 
	pacman -Syyuu --noconfirm

	# Run pacdiff to update files
	pacdiff

	echo 'Installing software...'
	pacman -S --noconfirm chromium dnsutils dropbox freerdp keepass vim openssh remmina tmux weechat lynx newsbeuter
	sudo -u $SUDO_USER yaourt -S --noconfirm keepass-plugin-http scudcloud

	if [[ $VBOX != "VBOX" ]]; then
		pacman -S --noconfirm virtualbox clamav
	fi
}

configure()
{
	# Assume git clone has already been done.
	echo 'Setting up user environment'
	rm /home/$SUDO_USER/.bashrc
	rm /home/$SUDO_USER/.tmux.conf
	rm -r /home/$SUDO_USER/.remmina
	rm -r /home/$SUDO_USER/.i3

# Confiuring Conky
echo 'Configuring conky...'
# Getting rid of the shortcuts conky
sed -i "/conky1/d" /usr/bin/start_conky_grey
sed -i "/time %A/d" /usr/share/conky/conky_grey
sed -i "/time %e/d" /usr/share/conky/conky_grey
sed -i "/time %b/d" /usr/share/conky/conky_grey
sed -i "/time %Y/d" /usr/share/conky/conky_grey

# Config for i3status
echo 'Configuring i3 status bar...'
if [[ $HPART == "home" ]]; then
	sed -i 's/# order += "disk \/home"/order += "disk \/home"/' /etc/i3status.conf
fi 

#if [[ $BAT == "0" ]]; then
#	sed -i "/battery 1 {/battery 0 {" /etc/i3status.conf
#fi
if [[ $LAPTOP != "Laptop" ]]; then
	sed -i 's/order += "battery/# order += "battery/' /etc/i3status.conf
fi

# Tmux config
echo '# Send Prefix' > /home/$SUDO_USER/.tmux.conf
echo 'unbind-key C-a' >> /home/$SUDO_USER/.tmux.conf
echo 'unbind-key C-b' >> /home/$SUDO_USER/.tmux.conf
echo 'set-option -g prefix C-a' >> /home/$SUDO_USER/.tmux.conf
echo 'bind-key C-a send-prefix' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Colors!' >> /home/$SUDO_USER/.tmux.conf
echo 'set -g default-terminal "screen-256color"' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Use Alt-arrow keys to switch panes' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n M-Left select-pane -L' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n M-Right select-pane -R' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n M-Up select-pane -U' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n M-Down select-pane -D' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Shift Arrow to switch windows' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n S-Left previous-window' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n S-Right next-window' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Mouse Mode' >> /home/$SUDO_USER/.tmux.conf
echo 'set -g mouse on' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Set easier window split keys' >> /home/$SUDO_USER/.tmux.conf
echo 'bind-key v split-window -h' >> /home/$SUDO_USER/.tmux.conf
echo 'bind-key h split-window -v' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Easy config reload' >> /home/$SUDO_USER/.tmux.conf
echo 'bind-key r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded."' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Sync Panes' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n S-Up setw synchronize-panes on' >> /home/$SUDO_USER/.tmux.conf
echo 'bind -n S-Down setw synchronize-panes off' >> /home/$SUDO_USER/.tmux.conf
echo '' >> /home/$SUDO_USER/.tmux.conf
echo '# Set window and pane index to 1 (0 by default)' >> /home/$SUDO_USER/.tmux.conf
echo 'set-option -g base-index 1' >> /home/$SUDO_USER/.tmux.conf
echo 'setw -g pane-base-index 1' >> /home/$SUDO_USER/.tmux.conf

# Misc config
echo 'Configuring random crap...'
sed -i "/# Misc options/a ILoveCandy" /etc/pacman.conf
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub

echo 'Enter location of tar file, if any: '
read TARLOC

if [[ $TARLOC != '' ]]; then
	cp $TARLOC /home/$SUDO_USER
	tar xvf *.tar
	cp /home/$SUDO_USER/usr/bin/rwallpaper /usr/bin
	cp /home/$SUDO_USER/etc/basetmux.conf /etc
	cp /home/$SUDO_USER/usr/local/bin/update /usr/local/bin
	rm -rf /home/$SUDO_USER/etc
	rm -rf /home/$SUDO_USER/usr
fi

if [[ $LAPTOP == 'Laptop' ]]; then
	rm /home/$SUDO_USER/backgrounds/1920x1200*
fi

if [[ $VBOX == 'VBOX' ]]; then
	rm /home/$SUDO_USER/backgrounds/1600x900*
fi 

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

# Enforcing "strong" passwords with pam_cracklib
#
# This will enforce the following policy:
#
# Prompt twice for password in case of error
# 10 characters minimum length (minlen option)
# 6 characters should be different from old passwords (difok option)
# Must have 1 digit (dcredit option)
# Must have 1 uppercase letter (ucredit option)
# Must have 1 other character (ocredit option)
# Must have 1 lowercase letter (lcredit option)

#####################################
# T H I S  B R E A K S  P A S S W D #
#####################################

# Enable the policy
#sed -i 's/password        required        pam_unix.so sha512 shadow nullok/#password        required        pam_unix.so sha512 shadow nullok/' /etc/pam.d/passwd
#echo 'password        required        pam_cracklib retry=2 minlen=10 difok=6 dcredit=-1 ucredit=-1 lcredit=-1' >> /etc/pam.d/passwd
#echo 'password        required        pam_unix.so use_authtok sha512 shadow' >> /etc/pam.d/passwd

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

# Clean up...
echo 'Cleaning up...'

rm -rf /home/$SUDO_USER/.moonchild\ productions/
rm -rf /home/$SUDO_USER/.config/hexchat/
rm /home/$SUDO_USER/*.tar

echo "Do you want to keep the original files this script changed? "
read ORIGFILES
if [[ $ORIGFILES = 'n' ]]; then
	rm -rf /home/$SUDO_USER/temp
fi

echo 'Everything is set. Reboot and you should be good!'

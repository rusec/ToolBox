#!/bin/bash
# Dependencies: Lynis, rkhunter
# Requires root permissions

# Ensures script is run as root
[ "$(id -u)" != 0 ] && exec sudo "$0"

# Copy sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config_old
sudo mv ./sshd_config /etc/ssh/sshd_config
sudo systemctl restart ssh
chown root:root /etc/ssh/sshd_config
chmod og-rwx /etc/ssh/sshd_config

# Copy sysctl.conf
sudo cp /etc/sysctl.conf /etc/sysctl_old.conf
sudo mv ./sysctl.conf /etc/sysctl.conf
sudo sysctl -p
#sudo sysctl fs.suid_dumpable=0

# TODO: Copy system.conf

# TODO: Remove SUID/GUID/PrivEsc vulnerabilities
sudo chmod 0755 /usr/bin/pkexec 

# UFW Configuration
sudo apt install ufw -y
sudo ufw enable
# Loopback traffic
ufw allow in on lo
ufw allow out on lo
ufw deny in from 127.0.0.0/8
ufw deny in from ::1
#ufw default deny incoming
#ufw default deny outgoing
#ufw default deny routed

# Misc. Hardening
sudo chmod 027 /etc/login.defs

# Run rkhunter
#rkhunter &

# TODO: Run Lynis as background and output to log file
#lynis audit system &

# Passwords
sudo useradd -D -f 30
echo "PASS_MAX_DAYS 90" >> /etc/login.defs
echo "PASS_MIN_DAYS 1" >> /etc/login.defs
echo "password required pam_pwhistory.so remember=5" >> /etc/pam.d/password-auth
echo "password required pam_pwhistory.so remember=5" >> /etc/pam.d/system-auth
# Password hashing
awk -F: '( $3<''$(awk '/^s*UID_MIN/{print $2}' /etc/login.defs)'' && $1 !~ /^(nfs)?nobody$/ && $1 != 'root' ) { print $1 }' /etc/passwd | xargs -n 1 chage -d 0
sudo apt install libpam-pwquality -y
echo "minlen = 14" >> /etc/security/pwquality.conf
echo "minclass = 4" >> /etc/security/pwquality.conf

# Create sudo log file
#echo "Defaults logfile='/var/log/sudo.log'" >> /etc/sudoers

# Restrict access to su command
echo "auth required pam_wheel.so" >> /etc/pam.d/su

# Ensure AppArmor is enabled
sudo apt install apparmor-utils -y
sudo systemctl enable apparmor
sudo systemctl start apparmor
sudo cp -R /etc/apparmor.d /etc/apparmor.d.bak # Backup AppArmor config
aa-enforce /etc/apparmor.d/* # All profiles enforcing

# Disable automatic error reporting
sudo service apport stop

# Install AIDE
sudo apt-get install aide -y

# Remove Avahi
#sudo apt-get remove avahi-daemon -y

# Remove CUPS
#sudo apt-get remove cups-common libcups2 -y

# Remove telnet
#sudo apt-get remove telnet -y

# Systemd Journal Remote
sudo apt-get install systemd-journal-remote -y
sudo systemctl enable systemd-journal-upload.service
sudo systemctl start systemd-journal-upload.service

# Managing /tmp separate partition
#sudo mkdir /tmp_bak
#rsync -avz /tmp/ /tmp_bak
#sudo umount /tmp
#sudo rm -r /tmp
#sudo mkdir /tmp

# Bootloader config
chown root:root /boot/grub/grub.cfg
chmod u-x,go-rwx /boot/grub/grub.cfg
sudo chown root:root /boot/grub2/grub.cfg 
sudo chmod og-rwx /boot/grub2/grub.cfg

# Login banners
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue.net

# NTP (or chrony)
sudo apt install ntp -y
sudo systemctl enable ntp
sudo systemctl start ntp

# iptables
sudo apt install iptables -y
sudo systemctl enable iptables
sudo systemctl start iptables

# auditd and audit rules
sudo apt install auditd -y
sudo systemctl enable auditd
sudo systemctl start auditd
sudo sed -i "s/max_log_file = 8/max_log_file = 20/g" /etc/audit/auditd.conf
sudo sed -i "s/max_log_file_action = ROTATE/max_log_file_action = KEEP_LOGS/g" /etc/audit/auditd.conf
echo "-w /etc/sudoers -p wa -k scope" >> /etc/audit/audit.rules
echo "-w /etc/sudoers.d -p wa -k scope" >> /etc/audit/audit.rules
echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/rules.d/time-change.rules
echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/rules.d/time-change.rules
echo "-w /etc/localtime -p wa -k time-change" >> /etc/audit/rules.d/time-change.rules
echo "-w /var/run/utmp -p wa -k session" >> /etc/audit/audit.rules
echo "-w /var/log/wtmp -p wa -k session" >> /etc/audit/audit.rules
echo "-w /var/log/btmp -p wa -k session" >> /etc/audit/audit.rules
echo "-w /var/log/lastlog -p wa -k logins" >> /etc/audit/rules.d/50-logins.rules 
echo "-w /var/run/faillock/ -p wa -k logins" >> /etc/audit/rules.d/50-logins.rules
printf '
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
' >> /etc/audit/rules.d/50-system_local.rules
printf '
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
' >> /etc/audit/rules.d/50-identity.rules
printf '
-w /etc/selinux -p wa -k MAC-policy
-w /usr/share/selinux -p wa -k MAC-policy
' >> /etc/audit/rules.d/50-MAC-policy.rules
echo "-e 2" >> /etc/audit/rules.d/99-finalize.rules # Immutable audit configuration
augenrules --load
sudo chmod go-w /sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules
sudo chown root /sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules
printf '
# Audit Tools
/sbin/auditctl p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/auditd p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/ausearch p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/aureport p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/autrace p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/augenrules p+i+n+u+g+s+b+acl+xattrs+sha512
' >> /etc/aide.conf

# Cron files
chown root:root /etc/crontab
chmod u-x,og-rwx /etc/crontab
chown root:root /etc/cron.hourly/
chmod og-rwx /etc/cron.hourly/
chown root:root /etc/cron.daily
chmod og-rwx /etc/cron.daily
chown root:root /etc/cron.weekly/
chmod og-rwx /etc/cron.weekly/
chown root:root /etc/cron.monthly 
chmod og-rwx /etc/cron.monthly
chown root:root /etc/cron.d
chmod og-rwx /etc/cron.d
rm /etc/cron.deny
touch /etc/cron.allow
chown root:root /etc/cron.allow
chmod u-x,og-rwx /etc/cron.allow

# Crontab filesystem integrity
echo "0 5 * * * /usr/bin/aide.wrapper --config /etc/aide/aide.conf --check" >> /etc/crontab
#!/bin/bash

##########################################################################################
##         Xibo server installation script for Ubuntu 16.04 LTS by VPARRES              ##
##               Uses Ondrej PPA to get the old and outdated PHP 5.6                    ##
## Configs were tweaked by myself and are based on Xibo's documentation recommendations ##
##########################################################################################

# Some usefuls vars ...
XIBO_VERSION=1.8.2 # Feel free to change version number if the script is outdated
WEBROOT=/var/www   # Do not forget to adapt nginx vhost config if you change this !

# Error handling function
errhand() {
    if [ "$1" != "0" ]; then
	printf "Failed.\n"
	exit 2
    fi
    if [ -z "$2" ]; then
	printf "Success.\n"
    fi
}

# Privilege check
if [ "$USER" != "root" ]; then
    echo "Root privileges required." >&2
    exit 1
fi

# Asking user for confirmation ...
echo "Xibo server installation script for Ubuntu 16.04"
echo "==========================================================="
echo "This script will install nginx, MySQL, PHP 5.6"
echo "and some required modules required to run Xibo first,"
echo "then it will install Xibo along with tweaked config files"
echo "-----------------------------------------------------------"
read -p "Are you sure you want to continue ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then

  # Phase 1 : updating system to avoid conflicts and more security breachs
  echo "====== Step 1 : Updating system ... ======"
  printf "Updating packages list ... "
  apt-get update > /dev/null 2>&1
  errhand "$?"

  printf "Upgrading packages (This may take a while) ... "
  apt-get upgrade -y > /dev/null 2>&1
  errhand "$?"

  # Phase 2 : Adding the new PPA ...
  echo "====== Step 2 : Add required repos ======"
  printf "Adding ondrej ppa for php 5.6 :\n\tPrerequisities ... "
  apt-get install -y python-software-properties > /dev/null 2>&1
  errhand "$?"
  printf "\tImporting GPG key ... "
  apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 4F4EA0AAE5267A6C > /dev/null 2>&1
  errhand "$?"
  printf "\tAdding repository ... "
  add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
  true > /dev/null 2>&1 # I Need that to fix add-apt-repository's issue, but it kills errhand usefulness
  errhand "$?"
  printf "\tRefreshing packages list ... "
  apt-get update > /dev/null 2>&1
  errhand "$?"

  # Phase 3 : Installing NMP ...
  echo "======  Step 3 : Installing base  ======="
  printf "Installing nginx ... "
  apt-get install -y nginx-full > /dev/null 2>&1
  errhand "$?"

  printf "Installing mysql ... "
  echo "mysql-server-5.6 mysql-server/root_password password root" | sudo debconf-set-selections > /dev/null 2>&1
  echo "mysql-server-5.6 mysql-server/root_password_again password root" | sudo debconf-set-selections > /dev/null 2>&1
  apt-get install -y mysql-server > /dev/null 2>&1
  errhand "$?"

  printf "Installing PHP 5.6 and required modules ... "
  apt-get install -y php5.6-fpm php5.6-cli php5.6-phar php5.6-soap php5.6-gd php5.6-dom php5.6-mcrypt php5.6-zip php5.6-mysql php5.6-curl > /dev/null 2>&1
  errhand "$?"

  printf "Installing php-zmq ... "
  apt-get install -y php-zmq > /dev/null 2>&1
  errhand "$?"

  # Phase 4 : Get Xibo and install it ...
  echo "====== Step 4 : Xibo installation  ======"
  printf "Downloading latest Xibo version ... "
  wget -q https://github.com/xibosignage/xibo-cms/releases/download/$XIBO_VERSION/xibo-cms-$XIBO_VERSION.tar.gz -O /tmp/xibo-$XIBO_VERSION.tgz
  errhand "$?"

  printf "Extracting Xibo ... "
  tar xvf /tmp/xibo-$XIBO_VERSION.tgz -C $WEBROOT > /dev/null 2>&1
  errhand "$?"

  # Phase 5 : Conf them all ! ...
  echo "======  Step 5 : Retrieving confs  ======"
  printf "nginx conf :\n\tBackup ... "
  mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old # Make a backup first, it's mandatory
  errhand "$?"
  printf "\tDownload and install ... "
  wget -q https://github.com/vparres/xiboserver_installer/raw/master/confs/nginx.conf -O /etc/nginx/nginx.conf # Get latest conf from repo
  errhand "$?"

  printf "nginx vhost conf :\n\tDownload ... "
  wget -q https://github.com/vparres/xiboserver_installer/raw/master/confs/xibo_vhost_conf -O /etc/nginx/sites-available/xibo_vhost_conf
  errhand "$?"
  printf "\tDeactivating all servers ... "
  rm /etc/nginx/sites-enabled/* # Deactivate any another servers, yeah i know, this sucks, but better safe than sorry ...
  errhand "$?"
  printf "\tEnabling Xibo's server ..."
  ln -s /etc/nginx/sites-available/xibo_vhost_conf /etc/nginx/sites-enabled/xibo_vhost_conf # Then enable Xibo's conf.
  errhand "$?"
  printf "\tChecking if nginx config is OK ... "
  nginx -t > /dev/null 2>&1
  errhand "$?"
  printf "\tReloading nginx ... "
  systemctl reload nginx
  errhand "$?"

  printf "PHP conf :\n\tBackup ... "
  mv /etc/php/5.6/fpm/php.ini /etc/php/5.6/fpm/php.ini.old
  errhand "$?"
  printf "\tDownload and Install ... "
  wget -q https://github.com/vparres/xiboserver_installer/raw/master/confs/xibo_php.ini -O /etc/php/5.6/fpm/php.ini
  errhand "$?"
  printf "\tReloading PHP-FPM service ... "
  systemctl reload php5.6-fpm
  errhand "$?"

  echo "==========================================================="
  echo "Server installation is complete, you may now finish Xibo's"
  echo "installation using http://localhost or http://$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')"
  echo "MySQL root's password is 'root' ... Don't forget to change."
  echo "==========================================================="
fi

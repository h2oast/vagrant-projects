#!/bin/bash
#
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# 
# INSTALL PostgreSQL by source code
#
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#

# Abort on any error
set -e

mv /etc/apt/sources.list           /etc/apt/sources.list.backup
cp /vagrant/etc/apt/sources.list   /etc/apt/sources.list

# Permit root/user login with password
# root password is vagrant
echo -e "vagrant\nvagrant" | passwd root
echo    "PermitRootLogin yes" >> /etc/ssh/sshd_config
sed -in 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart ssh

apt-get update  -y
apt-get upgrade -y
echo 'INSTALLER: System updated'

echo LANG=en_US.utf-8   >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment
# set system time zone
sudo timedatectl set-timezone $SYSTEM_TIMEZONE
echo "INSTALLER: System time zone set to $SYSTEM_TIMEZONE"
# Install PostgreSQL Database prerequisites to compile it
apt-get install -y  lz4                 liblz4-dev                           \
			        libreadline-dev                                          \
			        zlib1g-dev                                               \
			        libxml2-dev                                              \
			        libssl-dev                                               \
			        build-essential                                          \
			        pkg-config                                               \
			        flex                                                     \
			        bison                                                    \
			        llvm                                                     \
			        lldb                                                     \
			        clang                                                    \
			        clangd*                                                  \
			        emacs                                                    \
			        git                                                      \
			        ccache                                                   \
			        bear
# On debian 10 there three clangd alternatives: clangd-8, clangd-11, and clangd-13
# And we choose the newest one clangd-13
update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-13 100
echo 'INSTALLER: PostgreSQL prerequisites complete'

# create directories
POSTGRE_HOME=$POSTGRE_BASE/soft/$POSTGRE_VERSION
POSTGRE_CODE=$POSTGRE_BASE/code/postgresql-$POSTGRE_VERSION
POSTGRE_DATA=$POSTGRE_BASE/data/$POSTGRE_VERSION
mkdir -p $POSTGRE_HOME
mkdir -p $POSTGRE_CODE
mkdir -p $POSTGRE_DATA
# mkdir -p /opt/application/postgresql
# ln -s $POSTGRE_BASE /opt/application/postgresql

# create postgre user
useradd -s /bin/bash -m $POSTGRE_USER
echo -e "$POSTGRE_PASSWORD\n$POSTGRE_PASSWORD" | sudo passwd $POSTGRE_USER

echo 'INSTALLER: PostgreSQL directories created'

# set environment variables
echo "export POSTGRE_BASE=$POSTGRE_BASE"     >> /home/postgre/.bashrc
echo "export POSTGRE_HOME=$POSTGRE_HOME"     >> /home/postgre/.bashrc
echo "export PATH=\$PATH:\$POSTGRE_HOME/bin" >> /home/postgre/.bashrc

echo 'INSTALLER: Environment variables set'

# Install PostgreSQL

tar -xjf /vagrant/postgresql-$POSTGRE_VERSION.tar.bz2 -C $POSTGRE_BASE/code/
chown $POSTGRE_USER:$POSTGRE_GROUP -R $POSTGRE_BASE

su -l $POSTGRE_USER -c "cd $POSTGRE_CODE && CFLAGS='-O0 -g' ./configure --enable-debug --prefix=$POSTGRE_HOME"
su -l $POSTGRE_USER -c "cd $POSTGRE_CODE && make -j $(nproc)"
su -l $POSTGRE_USER -c "cd $POSTGRE_CODE && make check"
su -l $POSTGRE_USER -c "cd $POSTGRE_CODE && make check -C src/test/isolation"
su -l $POSTGRE_USER -c "cd $POSTGRE_CODE && make install"

echo 'INSTALLER: PostgreSQL software installed'

#
# Create database
#

#    
# Create DB
su -l $POSTGRE_USER -c "echo $POSTGRE_PASSWORD > $POSTGRE_HOME/password.txt"
su -l $POSTGRE_USER -c "$POSTGRE_HOME/bin/initdb -D $POSTGRE_DATA --pwfile $POSTGRE_HOME/password.txt -E $POSTGRE_CHARACTERSET"
su -l $POSTGRE_USER -c "rm $POSTGRE_HOME/password.txt"

#
# Configure PostgreSQL to allowing connection from remote host
#
# pg_hba.conf
#
su -l $POSTGRE_USER -c "echo '
#
# Allowing connection from remote host
# 
host    all             all             0.0.0.0/0               md5
' >> $POSTGRE_DATA/pg_hba.conf"


#
# Configure PostgreSQL to 
#   1) listen on all address
#   2) write debug log to file
#
# postgresql.conf
#
su -l $POSTGRE_USER -c "cat >> $POSTGRE_DATA/postgresql.conf << EOF
#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION changes
#------------------------------------------------------------------------------
#
# listen on all addresses
listen_addresses = '*'

#------------------------------------------------------------------------------
# REPORTING AND LOGGING changes
#------------------------------------------------------------------------------
#
# This is used when logging to stderr:
logging_collector = on                  # Enable capturing of stderr, jsonlog,
                                        # and csvlog into log files. Required
                                        # to be on for csvlogs and jsonlogs.
                                        # (change requires restart)

# These are only used if logging_collector is on:
log_directory = 'pg_log'                # directory where log files are written,
                                        # can be absolute or relative to PGDATA
EOF"


echo 'INSTALLER: Database created'

#
# configure systemd to start PostgreSQL instance on startup
sudo cp /vagrant/scripts/postgresql.service /etc/systemd/system/
sudo sed -i -e "s|###POSTGRE_USER###|$POSTGRE_USER|g" /etc/systemd/system/postgresql.service
sudo sed -i -e "s|###POSTGRE_HOME###|$POSTGRE_HOME|g" /etc/systemd/system/postgresql.service
sudo sed -i -e "s|###POSTGRE_DATA###|$POSTGRE_DATA|g" /etc/systemd/system/postgresql.service
sudo systemctl daemon-reload
sudo systemctl enable postgresql
sudo systemctl start  postgresql
echo "INSTALLER: Created and enabled PostgreSQL systemd's service"

echo "PostgreSQL PASSWORD FOR superuser: $POSTGRE_PASSWORD";

echo "INSTALLER: Installation complete, database ready to use!";

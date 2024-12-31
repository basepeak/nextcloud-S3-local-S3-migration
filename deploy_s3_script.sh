#!/bin/sh
set -eu

if [ -f /usr/src/nextcloud-s3-local-s3-migration-in-container/localtos3.php ]; then
    echo "Deploying localtos3.php script at initial run"
    cp /usr/src/nextcloud-s3-local-s3-migration-in-container/localtos3.php /var/www/html/
    chmod +x /var/www/html/localtos3.php
fi

if [ -f /usr/src/nextcloud-s3-local-s3-migration-in-container/s3tolocal.php ]; then
    echo "Deploying s3tolocal.php script at initial run"
    cp /usr/src/nextcloud-s3-local-s3-migration-in-container/s3tolocal.php /var/www/html/
    chmod +x /var/www/html/s3tolocal.php
fi

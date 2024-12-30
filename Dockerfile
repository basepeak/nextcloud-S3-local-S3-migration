FROM nextcloud:30.0-fpm-alpine

# Set environment variables
ENV PATH_BASE=/var/www \
    PATH_NEXTCLOUD=/var/www/html \
    OCC_BASE='sudo -u 33 php -d memory_limit=1024M /var/www/html/occ' \
    TEST=2 \
    SQL_DUMP_USER='' \
    SQL_DUMP_PASS='' \
    PREVIEW_MAX_AGE=0 \
    PREVIEW_MAX_DEL=0.005 \
    SET_MAINTENANCE=1 \
    SHOWINFO=1 \
    CONFIG_OBJECTSTORE='/var/www/html/config/s3.config.php' \
    DO_FILES_CLEAN=0 \
    DO_FILES_SCAN=0

# Install any necessary dependencies (if required)
RUN apk add --no-cache mariadb-client  # mysqldump

# Blocking entrypoint script to continue with the storage migration script
RUN sed -i 's/^exec .*/exec ash/' /entrypoint.sh

# Copy the PHP script into the container
COPY localtos3.php /usr/src/nextcloud/
COPY s3tolocal.php /usr/src/nextcloud/

# Command to run the PHP script
# ENTRYPOINT ["ash", "-c"]
# CMD ["php", "localtos3.php"]
# nextcloud S3 local S3 migration in container

Containerization of the project fork from [Script for migrating Nextcloud primary storage from S3 to local to S3 storage](https://github.com/mrAceT/nextcloud-S3-local-S3-migration)

## 🏍️ Motivations

[mrAceT](https://github.com/mrAceT/nextcloud-S3-local-S3-migration/commits?author=mrAceT) has created an excellent migration script in moving primary storage of Nextcloud from local to s3 (or in reverse), with sophisticated code in operating the database and file transfer, phased execution and interruption-resume tolerance.

I would like to migrate from local storage to s3 compatible storage to enjoy the benefit of Cloud in terms of scalability and broad network access, and I found this lovely script. However, I run Nextcloud in docker and had a quite different environment than the original writer of the script, so I would like to contribute by containerizing it and share with those who also prefer to run the migration script, regardless of the environmental difference, in containers.

## 📖 Usage

Assume that:

1. docker engine and docker compose were installed.
2. s3 bucket has been provisioned and permission properly set (You can test s3 connection using s3-browser)

Steps:

1. Configure a lab env for Nextcloud in docker-compose.yml

| Environment Variable           | Default Value                |
|--------------------------------|------------------------------|
| MYSQL_PASSWORD                 | nextcloud                    |
| MYSQL_DATABASE                 | nextcloud                    |
| MYSQL_USER                     | nextcloud                    |
| MYSQL_HOST                     | db                           |
| NEXTCLOUD_ADMIN_USER           | nextcloudadmin               |
| NEXTCLOUD_ADMIN_PASSWORD       | installnextcloud             |
| OBJECTSTORE_S3_BUCKET          | <bucket-name-without-s3://>  |
| OBJECTSTORE_S3_AUTOCREATE      | <true\|false>                |
| OBJECTSTORE_S3_KEY             | <access-key>                 |
| OBJECTSTORE_S3_SECRET          | <secret-key>                 |
| OBJECTSTORE_S3_HOST            | <s3-hostname>                |
| OBJECTSTORE_S3_PORT            | <s3-port>                    |
| OBJECTSTORE_S3_SSL             | <true\|false>                |
| OBJECTSTORE_S3_REGION          | <s3-region-mandatory>        |
| OBJECTSTORE_S3_USEPATH_STYLE   | <true\|false>                |

Then, run install a fresh Nextcloud

```bash
# Pull and start 
cd ./example && sudo docker compose up -d db redis
sudo docker compose up run --rm -ti app
```

2. By now the container should perform a fresh installation of Nextcloud and bring you into an ash shell.
Play and run the script.

```bash
TEST=2
php localtos3.php

TEST=test_username
php localtos3.php
```

3. Configure the script using environment variables in docker compose / inside container ash shell

| Environment Variable     | Default Value                            | Explanation                             |
|--------------------------|------------------------------------------|-----------------------------------------|
| PATH_BASE                | /var/www                                 | Path to the base of the main Nextcloud directory |
| PATH_NEXTCLOUD           | /var/www/html                            | Path of the public Nextcloud directory   |
| OCC_BASE                 | php -d memory_limit=1024M /var/www/html/occ | Allocate more memory to php             |
| TEST                     | 2                                        | Start with 2 for complete dry run, then user_name for single user (migration) test, 1 for all data (preprocess): NO db modifications, with file modifications/uploads/removal, finally 0 for LIVE migration. |
| SQL_DUMP_USER            | ''                                       | Leave both empty if Nextcloud user has enough rights. |
| SQL_DUMP_PASS            | ''                                       |                                          |
| PREVIEW_MAX_AGE          | 0                                        | Max age (days) of preview images (EXPERIMENTAL! 0 = no delete) |
| PREVIEW_MAX_DEL          | 0.005                                    | Max amount of previews to delete at a time (when < 1 & > 0 => percentage!) |
| SET_MAINTENANCE          | 1                                        |                                          |
| SHOWINFO                 | 1                                        | Set to 0 to force much less info (while testing) |
| CONFIG_OBJECTSTORE       | /var/www/html/config/s3.config.php       | Default s3 config file from Nextcloud container that reads from container env variable |
| DO_FILES_CLEAN           | 0                                        | Perform occ files:cleanup (can take a while on large accounts, should not be necessary but cannot hurt, not working while in maintenance) |
| DO_FILES_SCAN            | 0                                        | Perform occ files:scan --all (can take a while on large accounts, should not be necessary but cannot hurt, not working while in maintenance) |
| MULTIPART_THRESHOLD_MB   | 100                                      | S3 multipart threshold in Megabytes      |
| MULTIPART_RETRY          | 10                                       | Number of retry attempts (set to 0 for just one try) |

4. Familiarization with the testing lab, create testing user, files, perform simulation of migration in small scale

5. Switch to connect to production datasource.

Exit from the testing container after familiarization with the env

```bash
exit
sudo docker compose down -d db redis

# To remove everything from the lab
# sudo docker compose down -v
```

Comment out env variables from docker compose to skip re-inialization of Nextcloud installation `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`

| Environment Variable           | Default Value                |
|--------------------------------|------------------------------|
| # NEXTCLOUD_ADMIN_USER         | nextcloudadmin               |
| # NEXTCLOUD_ADMIN_PASSWORD     | installnextcloud             |

Adjust the docker volume of nextcloud to connect to your local storage (e.g. my_data volume / folder) of nextcloud.

```yml
  app:
    image: ghcr.io/timycyip/nextcloud-s3-local-s3-migration-container:0.42.3
    restart: always
    ports:
      - 8080:80
    depends_on:
      - redis
      - db
    volumes:
      - nextcloud:/var/www/html
      - config:/var/www/html/config
      - data:/var/www/html/data
      # - ./data:/var/www/html/data
```

Make sure the volume mount are properly set with permission. For example, the html root folder, `./apps`, `./config`, `./data`, `../bak` folders are are owned by www-data (uid: 82). Run command accordingly.

```bash
sudo docker compose up run -ti app
cd /var/www/html/
ls -l
chown -R www-data:www-data ./apps
chown -R www-data:www-data ./config
chown -R www-data:www-data ./data
chown -R www-data:www-data ./bak
exit
```

Adjust the db connection in docker-compose.yml to your production nextcloud db. Remember to do backup before any actual migration. Test restore as well.

```bash
TEST=2
php localtos3.php

TEST=test_username
php localtos3.php
```

Run nextcloud container connected to production db and local storage.
It took me 2 days to upload files to s3. The more user files uploaded to s3 in the preprocess (before TEST=0), the faster TEST=0 phase would be.
Be expect to watch, and resume if the upload / container process got interrupted.

Find the storage id of the object storage from warning similar to below, delete records with the particular storage id in `oc_filecache`.

```
WARNING: if this is for a full migration remove all data with `storage` = ?? in your `oc_filecache` !!!!
```

In the final run (TEST=0), running the container as user www-data (uid: 82) is required to run php occ.

```bash
# Pull and start 
cd ./example
sudo docker compose up run -u 82 -ti app

# Inside the container
TEST=2
php localtos3.php

TEST=test_username_small
php localtos3.php

TEST=test_username_large1...3
php localtos3.php

TEST=1
php localtos3.php

TEST=0
php localtos3.php
```

6. There is a bug 🐛 :

* duplicated record are prevented by MySQL when replacing `home::<username>` with `object::user:<username>` in nextcloud db table `oc_storages`, as `object::user:<username>` already exists. At the moment the simplest method I could think of is to manually remove those records starting with `object::user:`.

## 🎉 What's new

### Version 0.42.4

#### Script improvement (s3tolocal.php)

* Prevent sql execution failure in duplicating oc_storage id and db key fs_storage_path_hash clashes.
  * 94b208d3de14a81334525dfd27ad7392edf16381
  * 4d0721d764004a8d451cfdda7c7f85621b7850fa
  * ff6b1dac9ed2273355077ff3fbb5576e5598f755

#### Workflow Update (README.md)

* Remind that oc_filecache has to be manually cleared before actual migration (TEST=0)
  * dfc9b9c389f6feedc34a2e2f490322cacef175d4
* Configure folder permission by instructions and update examples
  * 9b408e666808cec1549acb6f19b136df3909f027

#### Backup Management (README.md)

* Enhance backup file management by naming backup with timestamp.
  * d5edda631101089310e74bc2164e525849a2b4d7
* Persists backup data with docker volume.
  * ed09556dac393cad0cfe16915a3974667dfa6a06

#### Containerization (Dockerfile)

* Keep base nextcloud container up-to-date with production tag
  * 1eea81ab751934f6ecc4616abd65f12586a415fe

### Version 0.42.3

#### Containerization (localtos3.php & s3tolocal.php)

* Containerized script, packaged with required php lib and runtime
  * 170b3e01f66c0bff7a749890a2bca900669d2c28
  * 85bcbdace7a9e306a3f9a1585d502495f5856b5d
* Decouple hard code variables to env variables, demonstrate how env variables can be set externally by docker-compose
  * f5500e487a9f3811c45ac1b37875003b189d554d
  * 84169cdbe173da1a2b8ac48c35e56b5499731cb8
  * 56f7e848b481dc9ced76ccab7ffad53515862eaf
  * 71f2837dc3c547de01e843532faaab7f9d3bb417
* Reduce dependency requirement by replacing mysqli with Doctrine\DBAL
  * ff7dcaf4677c68eaae5b0e52544a88782df5d98e
* Include mysqldump dependency for sql backup
  * 9b1516d1a10f9f7407fd130fd8c7190dfe109a44

### s3tolocal.php

#### Script reliability enhancement

* Autocreate sql backup folder
  * b30b65dc41ce31784f04ab39a064b4b3e8f6eeb1
  * a9ee334059af7476ad7f9c0c3cf5459f185337d7
* Improve occ command string to handle missing trailing space in env input
  * ecb5e87c5a894552d2e917f830a55a492670bb42
* Default s3 upload by multipart and enable retry to improve reliability
  * 23cc9849ed80a57f316f33f50bcd3da4c204d784
  * 0367724b97a269260667a303b2865e2048bc6512

######################## UPSTREAM ##########################

# Nextcloud S3 to local to S3 storage migration script

<h1 align="center">:cloud: to :floppy_disk: to :cloud:</h1>

## S3 Best practice: start clean

It is always best to start with the way you want to go. [Nextcloud](https://nextcloud.com/) default for the primary storage is 'local'.
To start out with 'S3' from the start these are the steps I took:

1. download [setup-nextcloud.php](https://github.com/nextcloud/web-installer/blob/master/setup-nextcloud.php)
2. upload the file and execute it (for current folder use . )
3. **before** step 2: go to folder'config' and add file storage.config.php with

```<?php
$CONFIG = array (
  'objectstore' => array(
          'class' => 'OC\\Files\\ObjectStore\\S3',
          'arguments' => array(
                  'bucket' => '**bucket**', // your bucket name
                  'autocreate' => true,
                  'key' => '**key**', // your key
                  'secret' => '**secret**', // your secret
                  'hostname' => '**host**', // your host
                  'port' => 443,
                  'use_ssl' => true,
                  'region' => '**region**', // your region
                  'use_path_style' => false
// required for some non Amazon S3 implementations
// 'use_path_style' => true
          ),
  ),
);
```

4. click 'next'
5. follow the instructions..

# A friendly note before you start migrating

Officially it is not supported to change the primary storage in Nextcloud.
However, it's very well possible and these unofficial scripts will help you in doing so.

**TIP**: When you can, install a “test nextcloud”, configured just like your “real one” and go through the steps.. I have tried to make it al as generic as possible, but you never know.. and I wouldn’t want to be the cause of your data loss…

In theory nothing much could go wrong, as the script does not remove your local/S3 data and only uploads/downloads it all to your s3 bucket/local drive and does database changes (which are backed up)..but there might just be that one thing I didn’t think of.. or did that little alteration that I haven’t tested..

<p align="center">:warning: These scripts are written with the best of intentions and have both been tested thoroughly. :warning:</p>
<p align="center">:warning: <strong>But</strong> it may fail and lead to data loss. :warning:</p>
<p align="center">:warning: <strong>Use at your own risk!</strong> :warning:</p>

## S3 to local

It will transfer files from **S3** based primary storage to a **local** primary storage.

The basics were inspired upon the work of [lukasmu](https://github.com/lukasmu/nextcloud-s3-to-disk-migration/).

1. the only 'external thing' you need is 'aws/aws-sdk-php' (runuser -u clouduser -- composer require aws/aws-sdk-php)
2. set & check all the config variables in the beginning of the script!
3. start with the highest $TEST => choose a 'small test user"
4. set $TEST to 1 and run the script again
5. when 4. was completely successful move the data in folder $PATH_DATA to $PATH_DATA_BKP !
6. set $TEST to 0 and run the script again (this is LIVE, nextcloud will be set into maintenance:mode --on while working !)

**DO NOT** skip ahead and go live ($TEST=0) as the first step.. then your downtime will be very long!

With performing 'the move' at step 5 you will decrease the downtime (with maintenance mode:on) immensely!
This because the script will first check if it already has the latest file, then it only needs to move the file and does not need to (slowly) download it form your S3 bucket!
With a litte luck the final run (with $TEST=0) can be done within a minute!

**NOTE** step 4 will take a very long time when you have a lot of data to download!

If everything worked you might want to delete the backup folder and S3 instance manually.
Also you probably want to delete this script after running it.

### S3 to local version history

v0.34 Read config bucket_endpoint & use_path_style_endpoint\
v0.33 Added support for optional ssl and port for S3 connection\
v0.32 Set 'mount_provider_class' and add option to chown files if clouduser has no command line rights\
v0.31 Added endpoint path style option\
v0.30 first github release

:warning: check <https://github.com/mrAceT/nextcloud-S3-local-S3-migration/issues/11> if you need the option stated in v0.32 **work in progress..**

## local to S3

Transfer files from **local** based primary storage to a **S3** primary storage.

The basics were inspired upon the script s3tolocal.php (mentioned above), but there are **a lot** of differences..

Before you start, it is probably wise to set $DO_FILES_CLEAN (occ files:cleanup)
and $DO_FILES_SCAN (occ files:scan --all) to '1' once, let the 'Nextcloud' do some checking.. then you'll start out as clean as possible

1. Get localtos3.php and composer.json and composer.lock to a newly created folder in the container, e.g. /var/www/migrate
2. place `storage.config.php` in the same folder as localtos3.php (and fill it with your S3 config/credentials!)
3. set & check all the config environment variables in the beginning of the script!
4. start with the highest $TEST => 2 (complete dry run, just checks en dummy uploads etc. NO database changes what so ever!)
5. set $TEST to a "small test user", upload the data to S3 for only that user (NO database changes what so ever!)
6. set $TEST to 1 and run the script yet again, upload (**and check**) all the data to S3 (NO database changes what so ever!)
7. set $TEST to 0 and run the script again (this is LIVE, nextcloud will be set into maintenance:mode --on while working ! **database changes!**)

**DO NOT** skip ahead and go live ($TEST=0) as the first step.. then your downtime will be very long!

With performing 'the move' at step 6 you will decrease the downtime (with maintenance mode:on) immensely!
This because the script will first check if it already has uploaded the latest file, then it can skip to the next and does not need to (slowly) upload it to your S3 bucket!
With a litte luck the final run (with $TEST=0) can be done within a minute!

**NOTE** step 6 will take a very long time when you have a lot of data to upload!

If everything worked you might want to delete the data in data folder.
Also you probably want to delete this script (and the 'storage.config.php') after running it.
If all went as it should the config data in 'storage.config.php' is included in the 'config/config.php'. Then the 'storage.config.php' can also be removed from your config folder (no sense in having a double config)

## S3 sanity check

When you

1. have S3 as your primary storage
2. set $TEST to 0
3. **optionally** set $SET_MAINTENANCE to 0
4. (have set/checked all the other variables..)

Then the script 'localtos3.php' will:

* look for entries in S3 and not in the database and vice versa **and remove them**.
This can happen sometimes upon removing an account, preview files might not get removed.. stuff like that..

* check for canceled uploads.
Inspired upon [otherguy/nextcloud-cleanup](https://github.com/otherguy/nextcloud-cleanup/blob/main/clean.php). I have not had this problem, so can not test.. => check only!

* preview cleanup.
Removes previews of files that no longer exist.
There is some initial work for clearing previews.. that is a work in progress, use at your own risc!

The script will do the "sanity check" when migrating also (we want a good and clean migrition, won't we? ;)

### local to S3 version history

v0.41 Read config bucket_endpoint & use_path_style_endpoint\
v0.40 Added support for customer provided encryption keys (SSE-C)
v0.39 Added support for optional ssl and port for S3 connection\
v0.38 Added support for retries\
v0.37 Added endpoint path style option\
v0.36 added detection for 'illegal files' in S3 bucket\
v0.35 added some more info at the end of $TEST=0 (and a bit of code cleanup)\
v0.34 added support for 'MultipartUploader'\
v0.33 some improvements on 'preview management'\
v0.32 more (size) info + added check for canceled uploads\
v0.31 first github release

# I give to you, you

I built this to be able to migrate if the one or the other is needed for what ever reason I could have in the future.
You might have that same reason, so here it is!
**Like the work?** You'll be surprised how much time goes into things like this..

Be my hero, think about the time this script saved you, and (offcourse) how happy you are now that you migrated this smoothly.
Support my work, buy me a cup of coffee, give what its worth to you, or give me half the time this script saved you ;)

* [donate with ko-fi](https://ko-fi.com/mrAceT)
* [donate with paypal](https://www.paypal.com/donate?hosted_button_id=W52D2EYLREJU4)

## Contributing

If you find this script useful and you make some modifications please make a pull request so that others can benefit from it. This would be highly appreciated!

## License

This script is open-sourced software licensed under the GNU GENERAL PUBLIC LICENSE. Please see [LICENSE](LICENSE.md) for details.

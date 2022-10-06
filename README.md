#  Payara Server Community Edition

Updated repository for Payara Dockerfiles. This repository is for the **Full Profile** of [Payara Server](http://www.payara.fish).

# Supported tags and respective `Dockerfile` links

-	[`latest`](https://github.com/jniltinho/docker-payaraserver-full/blob/main/Dockerfile)


# Usage

## Quick start

To boot the default domain with HTTP listener exported on port 8080:

```
docker run -p 8080:8080 rockylinux-payaraserver
```

The Docker container specifies the default entry point, starts the domain `production` in foreground so that Payara Server becomes the main process. The tini tool is used to guarantee that the Payara Server process runs seamlessly as the main docker process.

## Open ports

Most common default open ports that can be exposed outside of the container:

 - 8080 - HTTP listener
 - 8181 - HTTPS listener
 - 4848 - HTTPS admin listener
 - 9009 - Debug port

## Administration

To boot and export admin interface on port 4848 (and also the default HTTP listener on port 8080):

```
docker run -p 4848:4848 -p 8080:8080 rockylinux-payaraserver
```

Because Payara Server doesn't allow insecure remote admin connections (outside of a Docker container), the admin interface is secured by default, accessible using HTTPS on the host machine: [https://localhost:4848](https://localhost:4848) The default user and password is `admin`.

## Application deployment


### Deploy appllications from a folder on startup

The default Docker entry point will scan the folder `$DEPLOY_DIR` (by default points to `/opt/payara/deployments`) for files and folders and deploy them automatically after the domain is started. If RAR files are found in that directory, they will be deployed before any other file.

In order to deploy applications, you can mount the `$DEPLOY_DIR` (`/opt/payara/deployments`) folder as a docker volume to a directory, which contains your applications. The following will run Payara Server in the docker and will start applications that exist in the directory `~/payara/apps` on the local file-system:

```
docker run -p 8080:8080 -v ~/payara/apps:/opt/payara/deployments rockylinux-payaraserver
```

In order to build a Docker image that contains your applications and starts them automatically, you can copy the applications into the `$DEPLOY_DIR` directory. and run the resulting docker image instead of the original one.

The following example Dockerfile will build an image that starts Payara Server and deploys `myapplication.war` when the Docker container is started:

```
FROM payara/server-full

COPY myapplication.war $DEPLOY_DIR
```

You can now build the Docker image and run the application `myapplication.war` with the following commands:

```
docker build --no-cache -t rockylinux-payaraserver .
```

```
docker run -p 8080:8080 rockylinux-payaraserver
```

### Remote deployment

If admin port is exposed, it is possible to deploy applications remotely, outside of the docker container, by means of admin console and asadmin tool as usual. See the *Administration* section above for information how to access the admin interface remotely.

## Configuration

### Environment Variables

The following environment variables are available to configure Payara Server. When edited either in a `Dockerfile` or before the `startInForeground.sh` script is ran, they will change the behaviour of the Payara Server instance.

- `JVM_ARGS` - Specifies a list of JVM arguments which will be passed to Payara in the `startInForeground.sh` script.
- `DEPLOY_PROPS` - Specifies a list of properties to be passed with the deploy commands generated in the `generate_deploy_commands.sh` script, For example `'--properties=implicitCdiEnabled=false'`.
- `POSTBOOT_COMMANDS` - The name of the file containing post boot commands for the Payara Server instance. This is the file written to in the `generate_deploy_commands.sh` script.
- `PREBOOT_COMMANDS` - The name of the file containing pre boot commands for the Payara Server instance.
- `PAYARA_ARGS` - additional arguments to the `start-domain` command that starts the server. Use this only if it's not enough to specify the configuration using the `POSTBOOT_COMMANDS` or `PREBOOT_COMMANDS` file
- `AS_ADMIN_MASTERPASSWORD` - The master password to pass to Payara Server. This is overriden if one is specified in the `$PASSWORD_FILE`.

The following environment variables shouldn't be changed, but may be helpful in your Dockerfile.

|  Variable name  |           Value            | Description |
| --------------- | -------------------------- | ----------- |
| `HOME_DIR`      | `/opt/payara`              | The home directory for the `payara` user |
| `PAYARA_DIR`    | `/opt/payara/appserver`    | The root directory of the Payara installation |
| `SCRIPT_DIR`    | `/opt/payara/scripts`      | The directory where the `generate_deploy_commands.sh` and `startInForeground.sh` scripts can be found. |
| `CONFIG_DIR`    | `/opt/payara/config`       | The directory where the post and pre boot files are generated to by default. |
| `DEPLOY_DIR`    | `/opt/payara/deployments`  | The directory where applications are searched for in `generate_deploy_commands.sh` script. |
| `PASSWORD_FILE` | `/opt/payara/passwordFile` | The location of the password file for asadmin. This can be passed to asadmin using the `--passwordfile` parameter. |

### Custom asadmin commands at server startup time

It's possible to run a set of custom asadmin commands during Payara server startup. You can either by specify the `PREBOOT_COMMANDS` or `POSTBOOT_COMMANDS` environment variables to point to the absolute path of your custom boot command file, or you can just copy a custom file to the expected path (default paths are `$CONFIG_DIR/post-boot-commands.asadmin` and `$CONFIG_DIR/pre-boot-commands.asadmin`).

For example, the following command will execute commands defined in the `/local/path/with/boot/file` directory mounted as a volume:

```
docker run -p 8080:8080 -v /local/path/with/boot/file:/config -e POSTBOOT_COMMANDS=/config/post-boot-commands.asadmin rockylinux-payaraserver
```

Alternatively, the following Dockerfile will build an image which will execute the commands in the `post-boot-commands.asadmin` file:

```
FROM payara/server-full

COPY post-boot-commands.asadmin $POSTBOOT_COMMANDS
```

### Testing, browsing and configuring a container instance

For testing or other purposes, you can override the default entrypoint. For example, the following command will start the container at a bash prompt, without starting Payara server. It allows you to browse the image and configure the Payara Server instance as you like:

```
docker run -p 8080:8080 -it rockylinux-payaraserver bash
```


### Build Docker

```
git clone https://github.com/jniltinho/docker-payaraserver-full.git
cd docker-payaraserver-full
docker build --no-cache -t rockylinux-payaraserver .
docker run -d --name payara -p 4848:4848 -p 8080:8080 -p 8181:8181 rockylinux-payaraserver
```


# Details

Payara Server installation is located in the `/opt/payara` directory. This directory is the default working directory of the docker image. The directory name is deliberately free of any versioning so that any scripts written to work with one version can be seamlessly migrated to the latest docker image.

- Full and Web editions are derived from the OpenJDK 11 images with a RockyLinux 8 base
- Micro editions are built on OpenJDK 11 images with an Alpine Linux base to keep image size as small as possible.

Payara Server is a patched, enhanced and supported application server derived from GlassFish Server Open Source Edition 5.x. Visit [www.payara.fish](http://www.payara.fish) for full 24/7 support and lots of free resources.

Full Payara Server and Payara Micro documentation: [https://docs.payara.fish/](https://docs.payara.fish/)

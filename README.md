# wp-control

There are many ways to run your **WordPress** site, without any technical ability required. There are cheap and flaky services like **[wordpress.com](https://wordpress.com/)**, which negate the need for infrastructure. Some of us still want to or need to manage our own WordPress site, on our own servers, or our local development environment; and it's those people who wp-control was created for.

The project is designed to be implemented with a WordPress "skeleton" repository for specific WordPress installations. The hope is that you can start your own WordPress projects, using a skeleton (Such one made from  [jesse-greathouse/wordpress-skeleton](https://github.com/jesse-greathouse/wordpress-skeleton) ) as the foundation to track your own custom code. This project contains the executables to incorporate your WordPress Skeleton files into a live WordPress site.

If you have any questions or concerns please feel free to contact me: <jesse.greathouse@gmail.com>.

## Installation

### Create a Skeleton from a template

At [jesse-greathouse/wordpress-skeleton](https://github.com/jesse-greathouse/wordpress-skeleton) you can select the "Use this template" button to set up a distinct project of your own on github. Your new "skeleton" repository is where you will save all of your customized code for your site.

### Clone wp-control

`git clone git@github.com:jesse-greathouse/wp-control.git`

`cd wp-control`

The first step to installing the project, is the **install** script.

`bin/install`

#### Install Operations

- **Install system dependencies** There are a number of system dependencies required to build the system. Dependencies will be installed via your system package manager.
- **Build Openresty** Openresty is Nginx packaged with a number of modules for using LuaJIT, and the Lua programming language, within the Nginx workers. If you're unaware of how all this works, don't worry, just think of it as Nginx.
- **Build PHP** The PHP installation will be precisely built to spec according to the exact modules/extensions that PHP needs to power Wordpress. [You can read more about this here](https://make.wordpress.org/hosting/handbook/server-environment/).
- **Build ImageMagick Extension** Wordpress makes great use of [ImageMagick](https://imagemagick.org/index.php). This extension is very good to have in your Wordpress installation.
- **Download and Install the Wordpress CLI** The Wordpress command line interface is a shell utility that is commonly used to do a number of things with wordpress. [You can find out more about it here](https://wp-cli.org/).

## Configure

At the completion of the **install** script, the **configure** script will be kicked off automatically. If you want to run the configure script independently, you can run it with the following command:

`bin/configure`

You will be prompted to provide:

| Prompt                           | Description                                                                |
| -------------------------------- | -------------------------------------------------------------------------- |
| **Site Label**                   | Internal label used to namespace supervisor services, sockets, etc.        |
|                                  | *Required*                                                                 |
| **Server Host Names**            | Domain names for nginx `server_name`. Separate multiple names with spaces. |
|                                  | *Default*: `127.0.0.1 localhost`                                           |
| **Enable SSL (HTTPS)**           | Configure HTTPS support. Accepts `y` or `n`.                               |
|                                  | *Default*: `n`                                                             |
| **SSL Certificate Path**         | Path to `.cert` file (only shown if HTTPS is enabled).                     |
|                                  | *Default*: `etc/ssl/certs/wp-control.cert`                                 |
| **SSL Key Path**                 | Path to `.key` file (only shown if HTTPS is enabled).                      |
|                                  | *Default*: `etc/ssl/private/wp-control.key`                                |
| **Web Server Port**              | Port the web server listens on.                                            |
|                                  | *Default*: `8181`                                                          |
| **Supervisor Control Port**      | Supervisor's HTTP control port.                                            |
|                                  | *Default*: `randomized`                                                    |
| **Admin Email Address**          | Used in certs, notifications, and default WordPress admin.                 |
|                                  | *Required*                                                                 |
| **Site Title**                   | Title of your WordPress site.                                              |
|                                  | *Default*: `Just another WordPress Site`                                   |
| **Site URL (WordPress siteurl)** | The full URL of your WordPress installation (including https\:// if used). |
|                                  | *Default*: `https://localhost:8181`                                        |
| **Enable Debugging**             | Enable WordPress and PHP debugging (recommended for development).          |
|                                  | *Default*: `y`                                                             |
| **Database Host**                | Hostname or IP address of the MySQL server.                                |
|                                  | *Default*: `127.0.0.1`                                                     |
| **Database Name**                | Schema name for your WordPress database.                                   |
|                                  | *Required*                                                                 |
| **Database Username**            | Database user to connect with.                                             |
|                                  | *Required*                                                                 |
| **Database Password**            | Password for the above database user.                                      |
|                                  | *Required*                                                                 |
| **Database Port**                | Port used for the database connection.                                     |
|                                  | *Default*: `3306`                                                          |
| **Redis Host**                   | Hostname or IP of Redis server.                                            |
|                                  | *Default*: `127.0.0.1`                                                     |
| **Redis Port**                   | Port for Redis service.                                                    |
|                                  | *Default*: `6379`                                                          |
| **Redis Password**               | Redis password, or `null` if none is required.                             |
|                                  | *Default*: `null`                                                          |
| **Redis DB Index**               | Numeric Redis DB index (usually 0).                                        |
|                                  | *Default*: `0`                                                             |

## Run

You can start, stop, restart, or kill the entire system using one top-level command:

`bin/wp-control start`

## Other Commands

```bash
bin/wp-control restart     # Gracefully restart services
bin/wp-control stop        # Gracefully stop services
bin/wp-control kill        # Stop allservices and kill the supervisor
bin/wp-control help        # Show available options
```

## Logs

### To monitor runtime errors

`tail -f var/log/error.log`

### To vew the webserver access log

`tail -f var/log/access.log`

### Superrvisor output

`tail -f var/log/supervisord.log`

## Notes

- The difference between stop and kill is that kill also shuts down the Supervisor daemon, which is necessary after making changes to configuration or .ini files.
- You do not need to run bin/web directly—bin/wp-control provides a unified interface for managing your WordPress site lifecycle.

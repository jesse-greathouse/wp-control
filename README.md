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

- **Site Name**: This is the colloquial name of your site. It doesn't have anything to do with a Wordpress configuration, rather it's how your site is identified to the wp-control system.
- **Domains**: The domains with which your site is identified to the web server. If your site has multiple domains you should list them delimited by a space. e.g.:
  - `mysite.com www.mysite.com subdomain.mysite.com`
- **Port**: This is the port by which your site will be served from the web server.
  - *Note: If you use port 80, 443 (SSL), or any port 1024 or under, the system will require you to use your sudo password, to set up an [authbind](http://manpages.ubuntu.com/manpages/impish/man1/authbind.1.html) configuration for the port ports. The wp-control system runs as a regular user, without elevated privileges, so authbind is required to bind with ports that would normally require elevated privileges.
- **Database Host**: This is the hostname or IP address of your database.
- **Database Name**: The name of the schema you intend to use.
- **Database User**: The database user name which is intended to use your schema.
- **Database Password**: The password of your database user.
- **Database Port**: I do not think Wordpress has functionality for changing the database port. I recommend leaving this at 3306.
- **Redis Host**: If you intend to use Redis with your application, you can enter the redis hostname or IP address here.
- **Use HTTPS**: If you are running this web server to be accessed using https (ssl) , select y for this answer. If you answer yes to this question, it will go through some steps to configure your SSL security certificate and key.
- **Debug**: This will indicate whether you are running your application in "debug mode". This is not recommended for a production environment.
  - *Note: If you intend to do PHP development in this project, it is recommended to use debug mode. If the project is not in debug mode, the PHP code will be cached via Opcache, and therefore a change to the PHP code will require a server restart to be changed in memory.

## Run

`bin/web start`

You can monitor the error log with:

`tail -f var/log/error.log`

## Stop

`bin/web stop`

## Restart

`bin/web restart`

## Kill

`bin/web kill`

The difference between stop and kill is that kill will shut down the supervisor daemon by killing its process. This is useful and even necessary if you change the configuration.

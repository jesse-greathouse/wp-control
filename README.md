# wp-control

Now days, there are many ways to run your **Wordpress** site, without any technical ability required. There are wonderful sites like **[wordpress.com](https://wordpress.com/)** where you can start your site, and run it, without needing any underlying infrastructure. For some of us, we still want to or need to manage our own Wordpress site, on our own servers, or our local development environment; and it's those people who wp-control was created for.

## A Little history
My name is Jesse Greathouse. Over the years I have done countless projects for people and businesses where WordPress was an integral part of their marketing strategy. After doing so many WordPress projects, consulting for so many people, I slowly formed a series of scripts and configurations to streamline the setup and deployment of these Wordpress sites. 

After so many years of helping and setting up professional WordPress installations, I decided to release my system, to the general public, as an open-source project. If you are a person like me, who needs to deploy and maintain WordPress projects to private servers, and on local development environments, then this system may be helpful to you. I have built and deployed this system on Ubuntu, Amazon Linux, Centos, MacOS and with Docker. It has all of the correct configurations and security protocols to safely deploy and manage WordPress in production. It also allows a simple setup locally.

The project is designed to be implemented with a WordPress "skeleton" repository for specific WordPress installations. The hope is that you can start your own WordPress projects, using a skeleton (Such one made from  [jesse-greathouse/wordpress-skeleton](https://github.com/jesse-greathouse/wordpress-skeleton) ) as the foundation to track your own custom code. This project contains the executables to incorporate your WordPress Skeleton files into a live WordPress site.

If you have any questions or concerns please feel free to contact me: jesse.greathouse@gmail.com.

# Installation

## Create a Skeleton from a template.

### Create your skeleton repository
At [jesse-greathouse/wordpress-skeleton](https://github.com/jesse-greathouse/wordpress-skeleton) you can select the "Use this template" button to set up a distinct project of your own on github. Your new "skeleton" repository is where you will save all of your customized code for your site.

## Clone your new repository

In your new repository page, on github, press the "Code" button and copy the url to your clipboard.
![Copy the url of the repository](https://i.imgur.com/mMOYJmn.png)

In the command prompt, on your computer, use the "git clone" command:

    git clone https://github.com/Acme-Sprocket-Co/acme-sprocket-website.git
The repository will be downloaded into the current working directory.
![Git clone the repository](https://i.imgur.com/Pa5bQb5.png)

Now you can jump into your project folder:

    cd acme-sprocket-website

## Install

The first step to installing the project, is the **install** script. Makes perfect sense, right?
This project supports installing on the following operating systems:

 - Ubuntu 20.04
 - CentOS 7
 - Amazon Linux 2
 - macOS Big Sur 11.4 X86  (Currently ARM CPUs are not officially supported sorry :-( )
 - Red Hat Enterprise Linux 8 (Need help with RHEL please contact me: jesse.greathouse@gmail.com)
 - Docker (Alpine Linux 3.11)

If you intend to use Docker, you can skip this step. There is a docker image available which requires no installation. If you are using any of the supported operating systems you will find the install script, for that system, under bin/. In this example, I am using macOS so I will use the following command:

    bin/install-macos.sh

#### *Note to macOS users
Homebrew is required to install the dependencies for the system. Unfortunately I cannot offer support without Homebrew. If you do not have the Homebrew package manager installed, you can find it [here](https://brew.sh/).

### What's happening here?
You may be noticing that there are a bunch of dependencies being upgraded and installed on the system. You may also see that you are required to give your sudo password. This system requires a number of dependencies to be installed on your computer/server. Don't worry, this will be the only point in which elevated privileges are required. Once the dependency installations are complete, wp-control will never require elevated privileges to operate.

The system operations, taking place during install, are completely transparent in the script itself. The entire system is written in bash scripts so that you can see what's happening and tweak it to your liking. I will give a brief overview here, but I encourage everyone to read and understand the scripts if you would like.

 - **Install dependencies** There are a number of system dependencies required to build the system. Dependencies will be installed via your system package manager.
 - **Build Openresty** Openresty is Nginx packaged with a number of modules for using LuaJIT, and the Lua programming language, within the Nginx workers. If you're unaware of how all this works, don't worry, just think of it as Nginx.
 - **Build PHP** The PHP installation will be precisely built to spec according to the exact modules/extensions that PHP needs to power Wordpress. You can read more about this [here](https://make.wordpress.org/hosting/handbook/server-environment/).
 - **Build PEAR** Unfortunately, at this time, the best way to install the ImageMagick PHP extension is to use pecl with the PEAR library.
 - **Build ImageMagick Extension** Wordpress makes great use of [ImageMagick](https://imagemagick.org/index.php). This extension is very good to have in your Wordpress installation.
 - **Download and Install Wordpress** The install script will always download the latest version of Wordpress, and install it.
 - **Download and Install the Wordpress CLI** The Wordpress command line interface is a shell utility that is commonly used to do a number of things with wordpress. You can find out more about it [here](https://wp-cli.org/).
 - **Run the Configure Script** The next stage in the installation process is to run the configure script. Once the installation script is finished it will immediately ask you to start configuring your site.

### Why does it compile PHP and Nginx from source?
An important part about running multiple applications on the same computer/server, is that the application configurations, binaries and libraries do not clash with each other. Developers have solved this problem by using containerization, but it can also be solved by isolating the the applications (Nginx and PHP) into the project directory. wp-control does this by compiling the application from source, and using the project repository folder as the directory prefix for those applications.

You can see that under the project directory, is a folder called opt, and inside opt, is a project-specific build of Nginx and PHP. It has precisely the correct version and configuration of PHP and PHP extensions, along with a web server and openssl configuration specific to that project alone. It also runs as the user it was installed by, without any elevated privileges, which is more secure than configuring multiple users to use shared system files.

Whenever you run a project with wp-control, that project can run independently from other projects running on the same computer/server, because they're not using the same libraries/binaries/configurations as other projects. There is no cross-contamination between other projects, because they are completely isolated from each other in their runtime and in the file system.

## Configure

At the completion of the **install** script, the **configure** script will be kicked off automatically. If you want to run the configure script independently, you can run it with the following command:

    bin/configure-macos.sh
*Run the configure specific configure script meant for your operating system.

The role of the configure script is to create a run script. It's interactive, which means it will ask you questions about your configuration, which you should answer.
![Run the configure script](https://i.imgur.com/4kOUo5Y.png)
The configure options, and explanations of them, are as follows:

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

When you have answered all of the questions, the script will ask you to confirm all of the values.
![Confirm configuration values](https://i.imgur.com/A24YEqT.png)
If you made a mistake, you can type: n and the script will exit without any effect. You may then restart the configure script and do it again, if you would like.

If all of the values are correct you can type: y and it will create your "run script".
![Creating the run script](https://i.imgur.com/XIz0VTs.png)

The run script is created and it gives you two options for running your site.
To run once, you can simply run the script in this example:

    /Users/jessegreathouse/acme-sprocket-website/bin/run-macos.sh
If you want to set up the site as a service, that will restart when the computer/server boots, you can run the second line:

    sudo cp -f /Users/jessegreathouse/acme-sprocket-website/etc/com.jesse-greathuse.wp-control.plist /Library/LaunchDaemons

*Note: This example is using the macOS script. If you use a different operating system, your service setup line will be different than this. The configure script will tell you how to do it.

## Run
When you use the "run once" script, the output of the server is streamed to the console.

![Run script output to console](https://i.imgur.com/JFCh8e6.png)

wp-control uses a program called "[supervisor](https://medium.com/@joor.loohuis/using-supervisor-for-process-management-66a5cc3d3dfa)" to manage multiple processes at once. One of those processes simply tails the error.log to stdout.

If you are running the project as a service or in a docker container, you won't see the output in the console. If you want to see the output, in these circumstances, you can simply use the following command:

    tail -f error.log

If you want to see the access logs, of your server, you can run this command:

    tail -f var/logs/access.log
![access log](https://i.imgur.com/LD0X7Nk.png)

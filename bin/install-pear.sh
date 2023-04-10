#!/usr/bin/expect -f
set OPT [lindex $argv 0]
spawn mkdir $OPT/pear
expect eof
cd $OPT/pear

spawn curl -O https://pear.php.net/go-pear.phar
expect eof

spawn $OPT/php/bin/php -d detect_unicode=0 go-pear.phar

expect "1-12, 'all' or Enter to continue:"
send "1\r"
expect "Installation base (\$prefix) *:"
send "${OPT}/pear\r"
expect "1-12, 'all' or Enter to continue:"
send "\r"
expect "Press Enter to continue:"
send "\r"
expect eof

spawn rm go-pear.phar
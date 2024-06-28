With this script, you will be able to detect every IP that failed to login the server with ssh, it queries to AbuseIP to get the country, counts how many tryies did the attacker and this information is stored in a database.
<br><br>To deploy the database, you must install SQLite.

Steps:
1. chmod +x ./script_ssh.sh
2. Scan
   <br>2.1. Run the first scan "./script_ssh.sh 'rute/auth.log'" (route example: "/var/log/auth.log.1")
3. Report IPs
   <br>3.1 Run "./script_ssh.sh report"

More information: https://jordipare.com/articles/ssh-attack-analysis-identifying-hacker-origins-and-frequencies/

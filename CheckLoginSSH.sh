#! /bin/bash
database="ips.db"
db_table="connections"
api_key="<yourKey>"

#Query the AbuseIP's API.
#Be aware that if you have the basic plan, you can't do more than 1.000 querys x day.
GetCountry() {
        local ip=$1
        resposta=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
                --data-urlencode "ipAddress=$1" \
                -d maxAgeInDays=90 \
                -d verbose \
                -H "Key: $api_key"\
                -H "Accept: application/json")
        pais=$(echo "$resposta" | jq -r '.data.countryName')
        echo $pais
}

#Visit the page if you want. I must practice and be better!
presentation() {
        echo "*****************************"
        echo "*                           *"
        echo "*    Welcome to my script   *"
        echo "*                           *"
        echo "*****************************"
        echo "*    Feel free to visit:    *"
        echo "*   https://jordipare.com   *"
        echo "*****************************"
}

#Captures the lines which indicates a bad user&password.
#Will return the full list of IP's.
GetIPsSSH() {
        local ruta=$1
        ssh_net=$(cat "$ruta" | grep -E "Failed password|Invalid user" | grep -oP 'from \K[^ ]+(?= port)')
        #ssh_net=$(echo "$ssh_logs" | grep "authentication failure" | grep -oP 'from \K[^ ]+(?= port)')
        echo "$ssh_net"
}

#Captures the lines which contains "message repeated 2 times".
#That line is also detected in the function GetIPsSSH
#However, it's necessary to detect again this specific line to set
#The correct counter.
#Will return the full list of IP's.
GetIPsSSHxTowo() {
        local ruta=$1
        ssh_net=$(cat "$ruta" | grep -E ": message repeated 2 times:" | grep -oP 'from \K[^ ]+(?= port)')
        echo "$ssh_net"
}

#Checks if the IP is stored in the DB.
#If yes, 2 is returned
#If no, 1 is returned.
CheckDB() {
        local ip=$1
        #local pais=$2
        consulta=$(sqlite3 "$database" "select ip from $db_table where ip like '$1'")
        if [ "$consulta" != "$1" ]; then
                echo "1"
        else
                echo "2"
        fi
}

#Insert the IP that has been sent to the function to DB.
#By default, counter is 1.
AddNewIP() {
        local ip=$1
        current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        pais=$(GetCountry "$1")
        sqlite3 "$database" <<EOF
#$1 = IP
#$pais = country
#1 = counter
#0 = not reported to abuseIP
insert into "$db_table" values ('$1','$pais',1, 0, '$current_date');
EOF
}

#Update the count table depending on the IP that has been sent to the function.
AddCount() {
        local ip=$1
        count_str=$(sqlite3 "$database" "select count from $db_table where ip like '$1'")
        count=$count_str
        count=$((count + 1))
        sqlite3 "$database" <<EOF
        UPDATE "$db_table" SET count = '$count' WHERE ip = '$1';
EOF

        current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        sqlite3 "$database" "update $db_table set date = '$current_date' where ip like '$1'"
}

ReportAbuseIP(){
        IFS=$'\n' read -d '' -r -a list_ip < <(sqlite3 "$database" "SELECT ip FROM $db_table WHERE report=0" && printf '\0')
        if [ ${#list_ip[@]} -ge 1000 ]; then
                for ((i = 1; i <= 1000; i++)); do
                        ip="${list_ip[$i]}"
                        timestamp=$(sqlite3 "$database" "select date from $db_table where ip like '$ip'")
                        curl -s -o /dev/null https://api.abuseipdb.com/api/v2/report \
                                --data-urlencode "ip=$ip" \
                                -d categories=18,22 \
                                --data-urlencode "comment=SSH login attempts" \
                                --data-urlencode "timestamp=$timestamp" \
                                -H "Key: $api_key" \
                                -H "Accept: application/json"
                        sqlite3 "$database" "update $db_table set report = 1 where ip like '$ip'"
                        echo "[Report $i/1000] The IP $ip has been reported because of 'SSH login attempts' at $timestamp"
                done
        else
                for ((i = 1; i <= ${#list_ip[@]}; i++)); do
                        ip="${list_ip[$i]}"
                        timestamp=$(sqlite3 "$database" "select date from $db_table where ip like '$ip'")
                        curl -s -o /dev/null https://api.abuseipdb.com/api/v2/report \
                                --data-urlencode "ip=$ip" \
                                -d categories=18,22 \
                                --data-urlencode "comment=SSH login attempts" \
                                --data-urlencode "timestamp=$timestamp" \
                                -H "Key: $api_key" \
                                -H "Accept: application/json"
                        sqlite3 "$database" "update $db_table set report = 1 where ip like '$ip'"
                        echo "[Report $i/${#list_ip[@]}] The IP $ip has been reported because of 'SSH login attempts' at $timestamp"
                done
        fi
}

main() {
        entrada=$1

        #Will show the banner
        echo "$(presentation)"
        #Indicates the file that's going to be analyzed

        if [ "$entrada" = "report" ]; then
                #report
                ReportAbuseIP
                echo "Report seleccionat"
        else
                echo "The file that's going to be read is: $entrada"
                #Parse into array variable the IP's which failed user&password attemptps
                mapfile -t IPs < <(GetIPsSSH "$entrada")

                #Parse into array variable the IP's which failed 3 times the login in.
                mapfile -t IPsx2 < <(GetIPsSSHxTowo "$entrada")

                #If CheckDB returns 1, is a new IP. It will be added in the DB
                #If CheckDB returns 2, the IP was already registered in DB. It will update the counter.
                for IP in "${IPs[@]}"; do
                        if [ "$(CheckDB "$IP")" = "1" ]; then
                                echo "[New IP] $IP has been added to DB"
                                AddNewIP "$IP"
                        elif [ "$(CheckDB "$IP")" = "2" ] && [ -n "$IP" ]; then
                                #If you want to see those IP's which are already added but
                                #Counters arn't updated, you can set an echo like this (uncomment):
                                #echo "[Counter update] $IP incremented by 1 the counter"
                                AddCount "$IP"
                        fi
                done

                #Add +1 to counter to those IP's who failed 3 times in a row the login
                #This is because in logs, 3 login failures are represented in two lines.
                for IP in "${IPsx2[@]}"; do
                        AddCount "$IP"

                done
        fi
}

#When the script is executed, it's mandatory to pass the file rute.
#EX: ./script_ssh.sh /var/log/auth.log.1
main "$1"

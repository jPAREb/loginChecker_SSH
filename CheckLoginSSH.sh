#! /bin/bash
echo "The script is going to initialize"
echo "Feel Free to visit https://jordipare.com"
GetCountry() {
        local ip=$1
        resposta=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
                --data-urlencode "ipAddress=$1" \
                -d maxAgeInDays=90 \
                -d verbose \
                -H "Key: YOUR_KEY" \
                -H "Accept: application/json")
        pais=$(echo "$resposta" | jq -r '.data.countryName')
        echo $pais
}
presentation() {
        echo "*****************************"
        echo "*                           *"
        echo "*    Welcome to my script   *"
        echo "*                           *"
        echo "*****************************"
        echo
        echo "Feel free to visit my website:"
        echo "https://jordipare.com"
        echo
}

GetIPsSSH() {
        ssh_net=$(cat /var/log/auth_1.log | grep -E "Failed password|Invalid user" | grep -oP 'from \K[^ ]+(?= port)')
        #ssh_net=$(echo "$ssh_logs" | grep "authentication failure" | grep -oP 'from \K[^ ]+(?= port)')
        echo "$ssh_net"
}

GetIPsSSHxTowo() {
        ssh_net=$(cat /var/log/auth.log | grep -E ": message repeated 2 times:" | grep -oP 'from \K[^ ]+(?= port)')
        echo "$ssh_net"
}

CheckDB() {
        local ip=$1
        #local pais=$2
        consulta=$(sqlite3 ips.db "select ip from connexions where ip like '$1'")
        if [ "$consulta" != "$1" ]; then
                echo "1"
        else
                echo "2"
        fi
}

AddNewIP() {
        local ip=$1
        pais=$(GetCountry "$1")
        sqlite3 "ips.db" <<EOF
insert into connexions values ('$1','$pais',1);
EOF
}

AddCount() {
        local ip=$1
        count_str=$(sqlite3 ips.db "select count from connexions where ip like '$1'")
        count=$count_str
        count=$((count + 1))
        sqlite3 ips.db <<EOF
UPDATE connexions SET count = '$count' WHERE ip = '$1';
EOF
}

main() {
        # Banner
        echo "$(presentation)"

        # Extract IP's that tryied to log in (ssh)

        mapfile -t IPs < <(GetIPsSSH)
        mapfile -t IPsx2 < <(GetIPsSSHxTowo)

        for IP in "${IPs[@]}"; do
                if [ "$(CheckDB "$IP")" = "1" ]; then
                        echo "L'IP $IP no està afegida"
                        AddNewIP "$IP"
                elif [ "$(CheckDB "$IP")" = "2" ] && [ -n "$IP" ]; then
                        echo "L'IP $IP existeix"
                        AddCount "$IP"
                fi
        done

        for IP in "${IPsx2[@]}"; do
                echo "L'IP $IP duplicada, reportada"
                AddCount "$IP"

        done
}
main

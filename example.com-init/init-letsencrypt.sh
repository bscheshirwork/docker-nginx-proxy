#!/bin/bash

domains=(example.com www.example.com)
cert_name="example.com"
rsa_key_size=4096
data_path="../data/certbot"
email="tech@example.com" #Adding a valid address is strongly recommended
staging=0 #Set to 1 if you're just testing your setup to avoid hitting request limits

url_ssl="https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf"
url_dhparams="https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem"


echo "### Preparing directories in $data_path ..."
rm -Rf "$data_path/www"
rm -Rf "$data_path/conf/live/$domains"
rm -Rf "$data_path/conf/archive/$domains"
rm -Rf "$data_path/conf/renewal/$domains.conf"
mkdir -p "$data_path/www"
mkdir -p "$data_path/conf/live/$domains"


echo "### Creating dummy certificate ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$path"
docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:1024 -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Testing options-ssl-nginx.conf in $url_ssl for download..."
  if curl --output /dev/null --silent --head --fail "$url_ssl"; then
    echo "URL exists: $url_ssl"
  else
    echo "URL does not exist: $url_ssl"
    exit
  fi
  echo "### Testing ssl-dhparams.pem in $url_dhparams for download..."
  if curl --output /dev/null --silent --head --fail "$url_dhparams"; then
    echo "URL exists: $url_dhparams"
  else
    echo "URL does not exist: $url_dhparams"
    exit
  fi

  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s "$url_ssl" > "$data_path/conf/options-ssl-nginx.conf"
  curl -s "$url_dhparams" > "$data_path/conf/ssl-dhparams.pem"
  echo
fi


echo "### Starting nginx ..."
docker-compose up -d nginx


echo "### Deleting dummy certificate ..."
sudo rm -Rf "$data_path/conf/live/$domains"


echo "### Requesting initial certificate ..."

#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

#Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

#fill --cert-name arg
case "$cert_name" in
  "") cert_name_arg="" ;;
  *) cert_name_arg="--cert-name $cert_name" ;;
esac

#Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--dry-run"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    $cert_name_arg \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot

docker-compose stop nginx

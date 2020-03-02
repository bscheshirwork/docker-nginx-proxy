# docker-nginx-proxy
example for nginx proxy within ssl 

Steps to use
1. Create init folder for each correponded domain name  
2. Run init script from init folder with specific domain name settings for get ssl cert from letsencrypt  
3. Add corresponded `server`block with path to  into common `nginx` config  
4. Add `docker network` for connect this nginx-proxy composition and application composition  
5. Add `docker-compose down && docker-compose up -d` command into cron with `@reboot` alias instead of time

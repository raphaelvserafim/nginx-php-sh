#!/bin/bash

# Função: Atualização do sistema
update_system() {
    curl -4 ifconfig.me 

    sudo apt update && sudo apt upgrade -y
}

# Função: Instalar Nginx
install_nginx() {
    sudo apt install nginx -y
    sudo systemctl enable nginx
    sudo systemctl start nginx
}

# Função: Instalar Certbot
install_certbot() {
   sudo apt install certbot python3-certbot-nginx -y
}



# Função: Instalar PHP
install_php() {
     sudo apt install php libapache2-mod-php php-mysql php-fpm php-mysql php-curl php-xml php-mbstring php-zip -y
     sudo apt install --no-install-recommends php8.1 -y
     sudo apt-get install -y php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath -y
}



# Função: Instalar MySQL e configurar usuário
install_mysql() {
    sudo apt install mysql-server -y
    sudo systemctl enable mysql
    sudo systemctl start mysql

    sudo mysql_secure_installation

    read -p "Informe o nome do novo usuário do MySQL: " MYSQL_USER
    read -s -p "Informe a senha para o novo usuário: " MYSQL_PASS
    echo

    sudo mysql -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED WITH authentication_plugin BY '${MYSQL_PASS}';
    GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;"

    echo "Usuário '${MYSQL_USER}' criado com sucesso no MySQL."

    sudo sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
}

# Função: Instalar phpMyAdmin
install_phpmyadmin() {
     
    sudo apt install phpmyadmin php-mbstring php-zip php-gd php-json php-curl -y
    sudo phpenmod mbstring
    
    read -p "Informe o subdomínio para phpMyAdmin (ex: mysql.seusite.com): " SUBDOMINIO

    sudo tee /etc/nginx/sites-available/$SUBDOMINIO > /dev/null <<EOF
server {

    server_name $SUBDOMINIO;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    access_log /var/log/nginx/$SUBDOMINIO.access.log;
    error_log /var/log/nginx/$SUBDOMINIO.error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$SUBDOMINIO /etc/nginx/sites-enabled/
    sudo systemctl reload nginx

    sudo chown -R www-data:www-data /usr/share/phpmyadmin

    echo "phpMyAdmin configurado com sucesso em http://$SUBDOMINIO"
}


# Função: Adicionar domínio principal
add_domain_site() {
    read -p "Informe o domínio (ex: seusite.com): " DOMINIO

    if [ -f "/etc/nginx/sites-available/$DOMINIO.conf" ]; then
    echo "Domínio já configurado. Abortando."
    return
    fi

    RAIZ="/var/www/$DOMINIO"
    
    sudo mkdir -p $RAIZ
    sudo chown -R www-data:www-data $RAIZ

    sudo tee /etc/nginx/sites-available/$DOMINIO.conf > /dev/null <<EOF
server {
     
    server_name $DOMINIO www.$DOMINIO;
    root $RAIZ;
    index index.php index.html;

    access_log /var/log/nginx/$DOMINIO.access.log;
    error_log /var/log/nginx/$DOMINIO.error.log;

    
    client_max_body_size 100M;


    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    # Protege arquivos sensíveis
    location ~ /\.(ht|git|svn|env|DS_Store|idea) {
        deny all;
    }

    # Bloqueia acesso a arquivos de backup ou temporários
    location ~* \.(bak|config|sql|fla|psd|ini|log|sh|swp|dist|gitignore|lock|tgz|gz|zip|tar)$ {
        deny all;
    }

    # Desativa execução de PHP em diretórios de upload
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }

}
EOF

    sudo ln -s /etc/nginx/sites-available/$DOMINIO.conf /etc/nginx/sites-enabled/
    sudo systemctl reload nginx

    echo "Domínio http://$DOMINIO configurado com sucesso!"
}

# Função: Adicionar subdomínio
add_subdomain_site() {
    read -p "Informe o subdomínio (ex: blog.seusite.com): " SUBDOMINIO

    if [ -f "/etc/nginx/sites-available/$SUBDOMINIO.conf" ]; then
    echo "Domínio já configurado. Abortando."
    return
    fi

    RAIZ="/var/www/$SUBDOMINIO"
    
    sudo mkdir -p $RAIZ
    sudo chown -R www-data:www-data $RAIZ

    sudo tee /etc/nginx/sites-available/$SUBDOMINIO.conf > /dev/null <<EOF
server {
    
    server_name $SUBDOMINIO;
    root $RAIZ;
    index index.php index.html;

    access_log /var/log/nginx/$SUBDOMINIO.access.log;
    error_log /var/log/nginx/$SUBDOMINIO.error.log;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    # Protege arquivos sensíveis
    location ~ /\.(ht|git|svn|env|DS_Store|idea) {
        deny all;
    }

    # Bloqueia acesso a arquivos de backup ou temporários
    location ~* \.(bak|config|sql|fla|psd|ini|log|sh|swp|dist|gitignore|lock|tgz|gz|zip|tar)$ {
        deny all;
    }

    # Desativa execução de PHP em diretórios de upload
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }

}
EOF

    sudo ln -s /etc/nginx/sites-available/$SUBDOMINIO.conf /etc/nginx/sites-enabled/
    sudo systemctl reload nginx

    echo "Subdomínio http://$SUBDOMINIO configurado com sucesso!"
}

 # 🌐 Main Menu
while true; do
    echo ""
    echo "🔧 Select the step you want to execute:"
    echo "1) 🔄 Update system"
    echo "2) 🌐 Install Nginx"
    echo "3) 🐘 Install PHP"
    echo "4) 🗄️ Install MySQL + create user"
    echo "5) 🧰 Install phpMyAdmin"
    echo "6) 🚀 Run all steps"
    echo "7) ➕ Add domain"
    echo "8) 🧩 Add subdomain"
    echo "9) 🔐 Install Certbot (SSL)"
    echo "0) ❌ Exit"
    read -p "Option: " option

    case $option in
        1) update_system ;;
        2) install_nginx ;;
        3) install_php ;;
        4) install_mysql ;;
        5) install_phpmyadmin ;;
        6) update_system; install_nginx; install_php; install_mysql; install_phpmyadmin ;;
        7) add_domain_site ;;
        8) add_subdomain_site ;;
        9) install_certbot ;;
        0) echo "Exiting... 👋"; break ;;
        *) echo "❗ Invalid option. Please try again." ;;
    esac
done

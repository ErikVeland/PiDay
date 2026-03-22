# Server Setup — piday.glasscode.academy

The website now runs as a standalone Next.js server so the homepage can proxy Pi lookups
server-side and mirror the app's bundled-vs-live behavior.

## 1. Create app directory

Run from your local machine:

```bash
ssh glasscode "sudo mkdir -p /var/www/piday.glasscode.academy/app && sudo chown svc_epstein:svc_epstein /var/www/piday.glasscode.academy/app"
```

## 2. Add nginx vhost

On the server, create `/etc/nginx/sites-available/piday.glasscode.academy`:

```nginx
server {
    listen 80;
    server_name piday.glasscode.academy;

    location /_next/static/ {
        alias /var/www/piday.glasscode.academy/app/.next/static/;
        access_log off;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Enable, test, and reload:

```bash
sudo ln -s /etc/nginx/sites-available/piday.glasscode.academy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 3. systemd service

Create `/etc/systemd/system/piday-website.service`:

```ini
[Unit]
Description=PiDay website
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/piday.glasscode.academy/app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
Environment=PORT=3000
Environment=HOSTNAME=0.0.0.0

[Install]
WantedBy=multi-user.target
```

Then enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now piday-website.service
sudo systemctl status piday-website.service
```

## 4. DNS

Add a CNAME or A record for `piday.glasscode.academy` pointing to the glasscode server IP.

## 5. SSL

```bash
ssh glasscode "sudo certbot --nginx -d piday.glasscode.academy"
```

## 6. Deploy

From the `website/` directory:

```bash
bash deploy.sh
ssh glasscode "sudo systemctl restart piday-website.service"
```

## 7. Post-deploy smoke test

```bash
curl -I https://piday.glasscode.academy
curl https://piday.glasscode.academy/robots.txt
curl "https://piday.glasscode.academy/api/pi-date?date=2026-03-22"
```

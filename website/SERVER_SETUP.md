# Server Setup — piday.glasscode.academy

## 1. Create web root directory

Run from your local machine:

```bash
ssh glasscode "sudo mkdir -p /var/www/piday.glasscode.academy && sudo chown $USER:$USER /var/www/piday.glasscode.academy"
```

## 2. Add nginx vhost

On the server, create `/etc/nginx/sites-available/piday.glasscode.academy`:

```nginx
server {
    listen 80;
    server_name piday.glasscode.academy;
    root /var/www/piday.glasscode.academy;
    index index.html;
    location / {
        try_files $uri $uri/ $uri.html =404;
    }
}
```

Enable, test, and reload:

```bash
sudo ln -s /etc/nginx/sites-available/piday.glasscode.academy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 3. DNS

Add a CNAME or A record for `piday.glasscode.academy` pointing to the glasscode server IP. Changes typically propagate within minutes but can take up to 48 hours.

## 4. SSL (after DNS propagates)

```bash
ssh glasscode "sudo certbot --nginx -d piday.glasscode.academy"
```

## 5. Deploy

From the `website/` directory:

```bash
bash deploy.sh
```

## 6. Pre-launch checklist

- [ ] Replace `APP_STORE_URL = '#'` in `src/lib/config.ts` with the live App Store link
- [ ] Design and commit a real `public/og.png` (1200×630) — dark background, π symbol, digit stream
- [ ] Update contact email in `src/app/privacy/page.tsx` from placeholder to real address
- [ ] Set `metadataBase` in `src/app/layout.tsx` to `new URL('https://piday.glasscode.academy')` for proper OG image URLs
- [ ] DNS propagated and pointing to server
- [ ] nginx vhost configured and reloaded
- [ ] SSL certificate issued via certbot

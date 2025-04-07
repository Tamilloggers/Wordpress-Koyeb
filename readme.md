# WordPress on Koyeb/Render with Aiven MySQL

## 🛠 Requirements
- Docker
- Aiven MySQL DB
- Koyeb or Render account

## 🚀 Deployment Steps

### 1. Setup Aiven DB
- Create a MySQL service at [Aiven.io](https://aiven.io)
- Copy connection details

### 2. Clone This Repo
```bash
git clone https://github.com/your-username/wordpress-aiven-deploy.git
cd wordpress-aiven-deploy
```

### 3. Set Environment Variables on Koyeb/Render
Use `.env.sample` as reference:
```env
WORDPRESS_DB_HOST=mysql-xxxx.aivencloud.com:12345
WORDPRESS_DB_NAME=defaultdb
WORDPRESS_DB_USER=avnadmin
WORDPRESS_DB_PASSWORD=your-password
```

### 4. Deploy on Koyeb
- Go to [Koyeb](https://app.koyeb.com/)
- Create new app > Docker build > Connect your GitHub repo
- Add all environment variables
- Mount persistent volume to `/var/www/html/wp-content`

### 5. Done 🎉
Your WordPress is now live with Aiven as backend!

---

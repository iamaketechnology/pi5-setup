# Pi5 Setup 🚀

Scripts d’installation et de configuration pour **Raspberry Pi 5 (16 Go)** en mode serveur de développement auto-hébergé.  

## 📅 Plan de progression
- **Semaine 1** : Base serveur (Docker, Portainer, UFW, Fail2ban)  
- **Semaine 2** : Supabase (Postgres, Auth, Realtime, Studio) + pgAdmin  
- **Semaine 3** : Accès externe & HTTPS (Caddy/Nginx, Cloudflare Tunnel)  
- **Semaine 4** : Dev collaboratif (Gitea, Code-Server, CI/CD)  
- **Semaine 5** : Cloud perso (Nextcloud, MinIO, sauvegardes)  
- **Semaine 6** : Multimédia & IoT (Jellyfin, Pi-hole, Home Assistant, MQTT, Node-RED)  

## 🛠️ Utilisation
Exemple pour installer la Semaine 1 :

```bash
curl -fsSL https://raw.githubusercontent.com/TON_USER/pi5-setup/main/setup-week1.sh -o setup-week1.sh \
&& chmod +x setup-week1.sh \
&& sudo MODE=beginner ./setup-week1.sh

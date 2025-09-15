
  # 1. Nettoyer l'installation existante
  curl -fsSL [https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/cleanup-week2-supabase.sh](https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/cleanup-week2-supabase.sh) | sudo bash

  # 2. Installer avec tous les correctifs ARM64

  curl -fsSL <https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-week2-supabase-final.sh> | sudo bash


   🧹 Nettoyage Recommandé

  # 1. Arrêter tous les services Supabase
  cd /home/pi/stacks/supabase  # ou votre répertoire projet
  sudo docker compose down

  # 2. Nettoyer les volumes problématiques
  sudo rm -rf volumes/db/data

  # 3. Nettoyer les images Docker pour forcer le téléchargement des nouvelles
  sudo docker system prune -f
  sudo docker volume prune -f

  # 4. Optionnel : Supprimer complètement l'ancien projet
  sudo rm -rf /home/pi/stacks/supabase

   🎯 Séquence complète après reset :

  # 1. Reset complet (supprime TOUT : Docker, services, configs)
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/pi5-com
  plete-reset.sh | sudo bash
  curl -fsSL <https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/pi5-complete-reset.sh> | sudo bash
  sudo reboot

  # 3. Week 1 Enhanced (Docker, sécurité, optimisations base)
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-w
  eek1-enhanced.sh | sudo bash

  curl -fsSL <https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-week1-enhanced.sh> | sudo bash
  eek2-supabase-final.sh | sudo bash

  🚀 Alternative plus rapide (sans reset complet) :

  Si vous voulez juste tester les corrections Supabase sans tout refaire :

  # Option A: Cleanup Supabase seulement (garde Week 1)
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/cleanup
  -week2-supabase.sh | sudo bash

  # Puis relancer Week 2 amélioré
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-w
  eek2-supabase-final.sh | sudo bash

  📊 Recommandation :
  - Reset complet = Test le plus propre (recommandé pour validation finale)
  - Cleanup Supabase seulement = Plus rapide si Week 1 fonctionne bien
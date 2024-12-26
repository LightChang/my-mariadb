#!/bin/bash

# MariaDB 連線資訊
DB_HOST=${DB_HOST:-db}
ROOT_USER="root"
ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD}"
BACKUP_DIR=${BACKUP_DIR:-/backup}

# 等待 MySQL 伺服器啟動
until mysql -h "$DB_HOST" -u "$ROOT_USER" -p"$ROOT_PASSWORD" -e "select 1" > /dev/null 2>&1; do
  echo "等待 MySQL 伺服器啟動中..."
  sleep 5
done

# 開始循環備份
while true; do

  echo "MySQL 伺服器已啟動，開始備份..."
  # 設定日期格式
  DATE=$(date +%Y%m%d_%H%M)
  # 刪除過舊的執行紀錄檔
  find /log -type f -name "*.log" -mtime +30 -exec rm -f {} \;
  # 取得所有非系統使用者
  USERS=$(mysql -h $DB_HOST -u$ROOT_USER -p$ROOT_PASSWORD -se "SELECT user FROM mysql.user WHERE user NOT IN ('root', 'healthcheck', 'mariadb.sys')" 2>&1 | grep -v "Warning")
  # 遍歷每個使用者
  for USER in $USERS; do
    echo ''
    echo '========='
    echo $USER;
    echo '========='
    # 取得該使用者有權限的資料庫
    DBS=$(mysql -h $DB_HOST -u$ROOT_USER -p$ROOT_PASSWORD -se "SELECT DISTINCT table_schema FROM information_schema.SCHEMA_PRIVILEGES WHERE grantee = CONCAT(\"'\", '$USER', \"'@'\", '%', \"'\")" 2>&1 | grep -v "Warning" | grep -Ev '(information_schema|performance_schema|mysql|sys)')
    # 為每個資料庫進行備份
    for DB in $DBS; do
        USER_BACKUP_DIR="$BACKUP_DIR/$USER"
        mkdir -p $USER_BACKUP_DIR
        mysqldump --column-statistics=0 -h $DB_HOST -u$ROOT_USER -p$ROOT_PASSWORD $DB > $USER_BACKUP_DIR/${DB}_${DATE}.sql 2>&1 | grep -v "Warning"
        echo "備份完成：$DB"
    done
  done

  echo "本輪備份完成，等待下次備份..."
  sleep $((${EVERY_N_HR_BACKUP} * 3600))
done

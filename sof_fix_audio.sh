#!/bin/bash
# Скрипт для автоматической настройки SOF HDA DSP и создания автозагрузки через systemd

# Проверка наличия hda-verb
if ! command -v hda-verb &> /dev/null; then
    echo "Ошибка: hda-verb не найден. Установите alsa-tools."
    exit 1
fi

# Берём первую карту SOF
CARD=$(aplay -l | grep -i sof-hda-dsp | head -n1 | awk -F':' '{print $1}' | awk '{print $2}')
if [ -z "$CARD" ]; then
    echo "SOF HDA DSP карта не найдена."
    exit 1
fi

echo "Используем карта $CARD (SOF HDA DSP)"

# Сканируем Node ID пинов
NODES=$(grep -Po "Node 0x[0-9a-f]{2}" /proc/asound/card$CARD/codec* | sort | uniq | awk '{print $2}')

# Функция для установки пина
set_pin() {
    local NODE=$1
    local VALUE=$2
    hda-verb $CARD $NODE SET_PIN_WIDGET_CONTROL $VALUE &> /dev/null
    echo "Пин $NODE → $VALUE"
}

# Настройка пинов
for NODE in $NODES; do
    case $NODE in
        0x17|0x1e|0x14)
            set_pin $NODE 0x40 ;; # Встроенные динамики
        0x21|0x22)
            set_pin $NODE 0x40 ;; # Наушники
        0x19)
            set_pin $NODE 0x40 ;; # Микрофон
        *)
            set_pin $NODE 0x00 ;; # Не подключено
    esac
done

echo "✅ Настройка SOF HDA DSP завершена!"

# --- Создаём systemd сервис для автозагрузки ---
SERVICE_FILE="/etc/systemd/system/sof_fix_audio.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "Создаём systemd-сервис для автозагрузки..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Auto fix SOF HDA DSP audio
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sof_fix_audio_auto.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable sof_fix_audio.service
    echo "✅ Сервис создан и включен в автозагрузку."
else
    echo "Сервис уже существует, пропускаем создание."
fi

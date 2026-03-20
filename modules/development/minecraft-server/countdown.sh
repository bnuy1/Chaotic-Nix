#!/usr/bin/env bash

total="${1:-60}"

Statement="${2:-Scheduled Server restart is in}"
Countdown="${3:-Restarting in}"
Command="${4:-sudo systemctl restart docker-minecraft.service}"

echo "Validating command..."
# Extract the first word of the command
FIRST_WORD=$(echo "$Command" | awk '{print $1}')
if ! command -v "$FIRST_WORD" >/dev/null 2>&1; then
  echo "ERROR: Command '$FIRST_WORD' is not a valid executable."
  exit 1
fi

echo "Countdown started for $total seconds..."

for ((t = total; t > 0; t--)); do
  if ((t % 3600 == 0 && t != 0)); then
    string="${Statement} $((t / 3600)) Hours(s)"
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  elif ((t % 300 == 0 && t != 0)); then
    string="${Statement} $((t / 60)) Minutes(s)"
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  elif ((t == 60)); then
    string="${Statement} $((t / 60)) Minutes(s)"
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  elif ((t == 30)); then
    string="${Statement} $t SECONDS"
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  elif ((t == 15)); then
    string="${Statement} $t SECONDS"
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  elif ((t <= 10)); then
    string="${Countdown} $t..."
    sudo docker exec minecraft rcon-cli say "$string"
    echo "$string"
  fi

  sleep 1
done
echo "executing the command '$4'"
eval "$4"

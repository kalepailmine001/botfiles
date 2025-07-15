#!/bin/bash

# 🎨 Colors and Symbols
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
RESET='\033[0m'
CHECK="✅"
INFO="🔹"
WAIT="⏳"
CROSS="❌"

# 📁 Files and Constants
COOKIE_FILE="cookies.txt"
DATA_FILE="data.txt"
BASE_URL="https://ltc-trx-faucet.xyz"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"

# 🧠 Prompt for Cookie and Email (Fallback)
prompt_cookies() {
  echo -e "${YELLOW}$INFO Please paste your cookie string (ci_session + csrf_cookie_name):${RESET}"
  read -rp "> " COOKIE_INPUT
  echo "$COOKIE_INPUT" > "$COOKIE_FILE"
  echo -e "${GREEN}$CHECK Cookies saved.${RESET}"
}

prompt_email() {
  echo -e "${YELLOW}$INFO Please enter your withdrawal email:${RESET}"
  read -rp "> " EMAIL_INPUT
  if [[ -z "$EMAIL_INPUT" ]]; then
    echo -e "${RED}$CROSS Email is required. Exiting.${RESET}"
    exit 1
  fi
  echo "$EMAIL_INPUT" > "$DATA_FILE"
  echo -e "${GREEN}$CHECK Email saved.${RESET}"
}

# 🧠 Handle Args or Prompt for Cookies & Email
if [[ -n "$1" && -n "$2" ]]; then
  echo "$1" > "$COOKIE_FILE"
  echo "$2" > "$DATA_FILE"
  echo -e "${GREEN}$CHECK Cookie and email set from command line.${RESET}"
fi

# Load cookie and email (after CLI or fallback)
[[ -f "$COOKIE_FILE" ]] || prompt_cookies
[[ -f "$DATA_FILE" ]] || prompt_email

COOKIES=$(cat "$COOKIE_FILE")
CSRF=$(echo "$COOKIES" | grep -oP 'csrf_cookie_name=\K[^;]+')
EMAIL=$(cat "$DATA_FILE")

# Validate
if [[ -z "$COOKIES" || -z "$CSRF" || -z "$EMAIL" ]]; then
  echo -e "${RED}$CROSS Missing or invalid cookie/email. Exiting.${RESET}"
  exit 1
fi

# 👤 Get Username
USERNAME=$(curl "$BASE_URL/profile" -b "$COOKIES" -H "user-agent: $UA" -s --compressed | grep "mt-2 text-success" | sed -E 's/.*>([^<]+)<.*/\1/')
echo -e "${CYAN}$INFO Logged in as: ${YELLOW}$USERNAME${RESET}"

# 🕒 Track withdraw time
LAST_WITHDRAW_TIME=0

# 🔁 Main Loop
while true; do
  NOW=$(date +%s)
  echo -e "\n${CYAN}$WAIT Checking balance...$(date +" [%H:%M:%S]")${RESET}"

    attempt=1
  BALANCE=""
  while [[ -z "$BALANCE" && $attempt -le 3 ]]; do
    if (( attempt > 1 )); then
      sleep 3
    fi
    BALANCE=$(curl "$BASE_URL/lottery" \
      -b "$COOKIES" \
      -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9" \
      -H "upgrade-insecure-requests: 1" \
      -H "user-agent: $UA" \
      -s --compressed | grep -oP '\$\d+\.\d+' | head -n 1)
    ((attempt++))
  done

  if [[ -n "$BALANCE" ]]; then
    echo -e "${GREEN}$CHECK Balance = $BALANCE${RESET}"
  else
    echo -e "${RED}$CROSS Failed to fetch balance after 3 attempts.${RESET}"
    sleep 60
    continue
  fi


  # 🎁 Claim reward
  echo -e "${CYAN}$WAIT Claiming reward...${RESET}"
  curl "$BASE_URL/lottery/claim_reward" \
    -b "$COOKIES" \
    -H "user-agent: $UA" \
    --data-raw "csrf_token_name=$CSRF" -s > /dev/null
  echo -e "${GREEN}$CHECK Reward claimed.${RESET}"

  # 💸 Withdraw if 30 mins passed
  if (( NOW - LAST_WITHDRAW_TIME >= 1500 )); then
    AMOUNT=$(echo "$BALANCE" | grep -oP '\d+\.\d+')
    if [[ -n "$AMOUNT" ]]; then
      echo -e "${CYAN}$WAIT Withdrawing ${YELLOW}$AMOUNT${RESET} to ${YELLOW}$EMAIL${RESET}"
      curl "$BASE_URL/dashboard/withdraw" \
        -b "$COOKIES" \
        -H "content-type: application/x-www-form-urlencoded" \
        -H "user-agent: $UA" \
        --data-raw "csrf_token_name=$CSRF&method=1&amount=$AMOUNT&wallet=$EMAIL" -s > /dev/null
      echo -e "${GREEN}$CHECK Withdrawal requested.${RESET}"
      LAST_WITHDRAW_TIME=$NOW
    else
      echo -e "${RED}$CROSS Invalid amount for withdrawal.${RESET}"
    fi
  fi

  # ⏳ Countdown 60s
  for i in {60..1}; do
    printf "\r${WAIT} Next claim in %02d seconds..." "$i"
    sleep 1
  done
  echo ""
done


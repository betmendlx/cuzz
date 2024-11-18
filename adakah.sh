#!/bin/bash

# simple ji script nya cess ... :)
# Pastikan tools berikut sudah terinstall nah: subfinder, httx, nmap, nuclei, ffuf, subjack, dalfox

# Warna untuk output
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${GREEN}Automation Tool${RESET}"

# Memastikan target diberikan
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <target.com>${RESET}"
    exit 1
fi

TARGET=$1
OUTPUT_DIR="bugbounty_results"
WORDLIST="wordlists/onelistforallmicro.txt"
THREADS=50

# Minta input URL Burp Collaborator
read -p "Masukkan URL Burp Collaborator (misalnya, https://your-burp-collaborator): " BURP_COLLABORATOR

# Validasi URL Burp Collaborator
if [[ -z "$BURP_COLLABORATOR" ]]; then
    echo -e "${RED}URL Burp Collaborator tidak boleh kosong! Mohon masukkan URL yang valid.${RESET}"
    exit 1
fi

if [[ ! "$BURP_COLLABORATOR" =~ ^https?:// ]]; then
    echo -e "${RED}URL Burp Collaborator tidak valid! Pastikan URL dimulai dengan http:// atau https://.${RESET}"
    exit 1
fi

# Log file
LOG_FILE="$OUTPUT_DIR/automation.log"
exec > >(tee -a $LOG_FILE) 2>&1

# Membuat direktori output
mkdir -p $OUTPUT_DIR

# Fungsi untuk memeriksa apakah alat tersedia
check_tool() {
    local tool=$1
    if ! command -v $tool >/dev/null 2>&1; then
        echo -e "${RED}$tool tidak ditemukan! Silakan instal terlebih dahulu.${RESET}"
        exit 1
    fi
}

# Memeriksa ketersediaan alat-alat yang diperlukan
check_tool subfinder
check_tool httx
check_tool nmap
check_tool nuclei
check_tool ffuf
check_tool dalfox

# 1. Enumerasi Subdomain
echo -e "${GREEN}[1/6] Enumerasi subdomain dengan Subfinder...${RESET}"
if ! subfinder -d $TARGET -silent | tee $OUTPUT_DIR/subdomains.txt; then
    echo -e "${RED}Subfinder gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# 2. Hapus duplikat dan cek subdomain aktif
echo -e "${GREEN}[2/6] Memeriksa subdomain aktif dengan httx...${RESET}"
if ! cat $OUTPUT_DIR/subdomains.txt | sort | uniq | httx -silent -threads $THREADS | tee $OUTPUT_DIR/live-subdomains.txt; then
    echo -e "${RED}httx gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# 3. Pemindaian Port dengan Nmap
echo -e "${GREEN}[3/6] Melakukan pemindaian port dengan Nmap...${RESET}"
if ! nmap -iL $OUTPUT_DIR/live-subdomains.txt -p 80,443 -oG $OUTPUT_DIR/nmap-results.txt; then
    echo -e "${RED}Nmap gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# 4. Periksa keamanan dengan Nuclei
echo -e "${GREEN}[4/6] Memeriksa kerentanan menggunakan Nuclei...${RESET}"
if ! nuclei -l $OUTPUT_DIR/live-subdomains.txt -t cves/ -o $OUTPUT_DIR/nuclei-results.txt; then
    echo -e "${RED}Nuclei gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# 5. Brute-forcing direktori dengan FFUF
echo -e "${GREEN}[5/6] Melakukan brute-forcing direktori dengan FFUF...${RESET}"
if ! cat $OUTPUT_DIR/live-subdomains.txt | xargs -P 10 -I {} ffuf -w $WORDLIST -u {}/FUZZ -c -e .php,.html,.js,.txt,.asp,.zip,.gz,.tar -o $OUTPUT_DIR/ffuf-results.txt; then
    echo -e "${RED}FFUF gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# 6. Pemindaian XSS dengan Dalfox
echo -e "${GREEN}[6/6] Memindai potensi XSS dengan Dalfox...${RESET}"
if ! cat $OUTPUT_DIR/live-subdomains.txt | xargs -P 10 -I {} dalfox url {} -b $BURP_COLLABORATOR -o $OUTPUT_DIR/dalfox-results.txt; then
    echo -e "${RED}Dalfox gagal! Periksa koneksi internet atau konfigurasi.${RESET}"
    exit 1
fi

# Bersihkan file sementara
rm -f $OUTPUT_DIR/subdomains.txt

# Ringkasan hasil
echo -e "${GREEN}--- Ringkasan Hasil ---${RESET}"
echo -e "1. Subdomain aktif: $OUTPUT_DIR/live-subdomains.txt"
echo -e "2. Hasil Nmap: $OUTPUT_DIR/nmap-results.txt"
echo -e "3. Hasil Nuclei: $OUTPUT_DIR/nuclei-results.txt"
echo -e "4. Hasil FFUF: $OUTPUT_DIR/ffuf-results.txt"
echo -e "5. Hasil Dalfox: $OUTPUT_DIR/dalfox-results.txt"

echo -e "${GREEN}Selesai! Periksa hasil di folder $OUTPUT_DIR.${RESET}"

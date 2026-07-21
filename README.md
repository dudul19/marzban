# Autoscript Panel Marzban

Proyek ini merupakan modifikasi dari [Marzban](https://github.com/Gozargah/Marzban) dengan tambahan konfigurasi **Nginx** untuk mendukung koneksi **WebSocket**, **HTTP Upgrade**, dan **XHTTP TLS**.

> **Disclaimer**
> Proyek ini hanya untuk pembelajaran dan komunikasi pribadi. Mohon jangan digunakan untuk tujuan ilegal.
> Semua kredit tetap kepada [Gozargah Marzban](https://github.com/Gozargah), saya hanya menyederhanakan instalasi untuk pemula.
> Penambahan SSH Panel Hanya Sebatas CLI Saja.

---

## 📖 Table of Contents
- [Fitur yang Didukung](#-fitur-yang-didukung)
- [Sistem yang Dapat Digunakan](#-sistem-yang-dapat-digunakan)
- [Persiapan Sebelum Instalasi](#-persiapan-sebelum-instalasi)
- [Instalasi](#-instalasi)
- [Manajemen Service Marzban](#-manajemen-service-marzban)
- [Konfigurasi Cloudflare](#-konfigurasi-cloudflare)
- [Donasi](#-donasi)
- [Youtube Channel](#-youtube-channel)
- [Telegram Support](#-telegram-support)
- [Contributors](#-contributors)
- [Report Bug](#-report-a-bug)
- [Host Setting](#-setting-host)
---

## **Fitur yang Didukung**
- **Protocol:** VLess, VMess, Trojan, SSH
- **Network:** WebSocket, HTTP Upgrade, XHTTP
- **Port:**
  - WebSocket: `443 (TLS)`, `80 (HTTP)`, **Wildcard path** → `/enter-your-custom-path/trojanws`
  - HTTP Upgrade: `443 (TLS)`, `80 (HTTP)`, **Wildcard path** → `/enter-your-custom-path/trojanhu`
  - XHTTP: `443 (TLS)`, `80 (HTTP)`, **Wildcard path** → `/enter-your-custom-path/xtrojan`
  - Dropbear: `109`
  - OpenSSH: `3303`
  - SSH WebSocket & Multi Path SSH WebSocket
  - OpenVPN TCP & UDP: `1194`, `2200`
  - Open HTTP Puncher: `8181`, `8282`, `8383`
  - HTTP Proxy / SQUID: `8080`, `3128`
  - UDP CUSTOM: `1-65535`
- **Tunnel:**
  - STRX WS
  - XLITE
  - v2RAYNG
  - Dark Tunnel
  - HTTP CUSTOM
  - HTTP INJECTOR
  - UDP CUSTOM

---
## **Sistem yang Dapat Digunakan**

Berikut adalah daftar sistem operasi, penyedia layanan (ISP), dan jenis virtualisasi yang didukung.

## ✅ OS yang Didukung:
| OS           | Status |
|-------------|--------|
| Debian 12   | ✅ |
| Debian 13   | ✅ **Recommended** |
| Ubuntu 24.04 | ✅ **Recommended** |
| Ubuntu 25.04 | ✅ |

## 🌐 ISP yang Didukung:
| No | Provider        |
|----|-----------------|
| 1  | AWS             |
| 2  | Azure           |
| 3  | Digital Ocean   |
| 4  | OVH             |
| 5  | Herza           |
| 6  | Nusa.id         |
| 7  | Nusahost        |
| 8  | Warna Host      |
| 9  | Linode          |
| 10 | Dewaweb         |
| 11 | Rumah Web       |
| 12 | Alibaba         |
| 13 | Tencent         |
| 14 | HostPapa        |
| 15 | Hostdata        |
- **Etc.** (Silakan coba dan laporkan jika ada kendala)

## Virtualisasi yang Didukung:
| Virtualisasi | Status |
|-------------|--------|
| **KVM**     | ✅ Supported |
| Qemu        | ✅ Supported |
| OpenVZ 7    | ✅ Supported |
| VMWare      | ❌ Not Supported |

Jika ada pertanyaan atau kendala, jangan ragu untuk mengajukan issue atau pull request! 🚀
---

## **Persiapan Sebelum Instalasi**
- **VPS** dengan minimal **1 Core CPU & 1 GB RAM**
- **Domain** yang sudah di-pointing ke **Cloudflare**
- **Pemahaman dasar Linux**

---

## **Instalasi**
1. **Update dan install dependensi**
   ```sh
   apt-get update && apt install -y curl wget tmux dnsutils && apt --purge remove apache2 -y
   ```
2. **Jalankan script instalasi**
   > Pastikan Anda sudah login sebagai `root` sebelum menjalankan perintah berikut:
   ```sh
   tmux new -s fn "wget https://raw.githubusercontent.com/risqinf/marzban/main/install.sh && chmod +x install.sh && ./install.sh"
   ```
3. **Akses panel Marzban**
   - Buka browser dan kunjungi: `https://domainmu/dashboard`

4. **Jika Disconect Selama Proses Installasi**
   ```sh
   tmux attach-session -t fn
   ```
5. **Setelah Installasi Lakukan Renew Certificate Di menu**
   ```
   crt
   ```

---

## **Manajemen Service Marzban**
| Perintah | Fungsi |
|----------|--------|
| `marzban restart` | Restart service Marzban |
| `marzban logs` | Cek log service |
| `marzban update` | Update service |
---

## 🔧 **Konfigurasi Cloudflare**
1. Pastikan **SSL/TLS** di **Cloudflare** diatur menjadi **Full**
   ![Cloudflare SSL](https://github.com/GawrAme/MarLing/assets/97426017/3aeedf09-308e-41b0-9640-50e4abb77aa0)
2. Aktifkan **WebSocket** dan **gRPC** di **Cloudflare**
   ![Cloudflare Network](https://github.com/GawrAme/MarLing/assets/97426017/65d9b413-fda4-478a-99a5-b33d8e5fec3d)

---

# 🌐 **Setting Host**

 Saat masuk ke panel, setting host di menu kanan atas <br>
 ![image](https://github.com/GawrAme/MarLing/assets/97426017/6b96bce7-39c7-4b5c-b01e-8dfdea91cb47) </br>

Lalu ubah variabel {SERVER_IP} dibawah menjadi domain yang sudah di pointing tadi <br>
# CONTOH
![image](https://github.com/GawrAme/MarLing/assets/97426017/191a485c-07a7-4a28-88d3-b66fa403abc7)
</br>

---

## **Donasi**
- **[SAWERIA](https://saweria.co/Melon3D)**

---

## **Youtube Channel**
- [FarellVPN](https://youtube.com/@farellvpn)
- [Rerechan02](https://youtube.com/@Rerechan02) *(Jika 404, kemungkinan suspend)*

---

## **Telegram Support**
- [Farell Aditya](https://t.me/farelvpn)
- [Rerechan02](https://t.me/Rerechan02)
- [system.notes.labs](https://t.me/systems_notes)
---

## **Contributors**
- [Rerechan02](https://github.com/FN-Rerechan02)
- [RISQI](https://github.com/risqinf)

### **Special Thanks To**
- [Gozargah](https://github.com/Gozargah/Marzban)
- [hamid-gh98](https://github.com/hamid-gh98)
- [x0sina](https://github.com/x0sina/marzban-sub)
- [Marling](https://github.com/GawrAme/MarLing)
- [MarLum](https://github.com/Farell-VPN/mar-lum)

## **Report a Bug**

Jika Anda menemukan bug, silakan laporkan dengan mengklik tombol di bawah ini:

[![Report Bug](https://img.shields.io/badge/Report%20Bug-%23D73A49?style=for-the-badge&logo=github)](https://github.com/risqinf/marzban/issues/new?assignees=&labels=bug&template=bug_report.md&title=%5BBug%5D+)

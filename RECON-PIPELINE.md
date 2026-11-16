# Recon Pipeline — Amass + Agentic-Bug-Hunter (Muse Free)

Script: `recon.sh` (di folder ini). Dibuat 2026-11-16.

## Pakai

```bash
./recon.sh target.com                 # default: amass PASSIVE + subfinder (cepat)
./recon.sh target.com --deep          # amass full enum (lebih lama, lebih dalam)
./recon.sh target.com --nuclei        # + nuclei ringan (severity medium+) di live hosts
./recon.sh target.com --deep --nuclei # kombinasi
```

Hasil di `recon_<target>/`: `all_subs.txt`, `resolved.txt`, `live.txt`,
`interesting.txt`, `nuclei.txt` (kalau --nuclei), `SUMMARY.md`.

## Cara kasih hasil ke Muse (hemat token)

Jangan paste mentah semua output tool. Kasih 3 file ini saja:

1. `SUMMARY.md` — ringkasan angka + daftar host menarik
2. `live.txt` — host hidup (status/title/tech)
3. `interesting.txt` — host yang layak diburu (admin/api/staging/dev/login/dll)

Muse baca file itu buat analisis + prioritasi, baru hunting fokus:

```bash
bughunter hunt <host-menarik>          # 1 host / 1 vuln class per sesi
bughunter validate "deskripsi finding" # setelah validasi manual
bughunter report
```

Jangan langsung `bughunter hunt target.com` habis recon besar — boros context.

## Catatan

- Amass config `~/.config/amass/config.yaml` belum ada — script jalan tanpa
  `-config` (pakai datasource default). Isi config kalau mau tambah API key
  datasource sendiri (via Secure Vault, jangan taruh key di file biasa).
- `anew` belum terinstall — script pakai `sort -u` sebagai gantinya.
- Semua tool dari `bin/` (batch 1, 2026-11-16): amass, subfinder, dnsx,
  httpx, nuclei — terverifikasi jalan.
- Jangan jalankan ke target tanpa scope/izin program bounty yang berlaku.

# 9Router diganti fork serenhope (di-vendor)

Repo ini memakai **9Router fork serenhope** sebagai pengganti paket npm
`9Router` upstream. Source fork disalin utuh ke folder **`9router/`** di
repo ini (vendored, bukan git submodule dan bukan paket npm), supaya hasil
gabungan ini bisa langsung di-push sebagai satu repo baru dan di-clone
tanpa dependensi ke repo fork saat install.

## Sumber

| | |
|---|---|
| Hermuse (dasar) | https://github.com/imkofty/Hermuse — commit `0d72e79` |
| 9Router fork | https://github.com/serenhope/9router — branch `master`, commit `fb3a5f6` |
| Fork dari | Decolua/9router (upstream) |
| Versi fork | `0.5.319` (`9router/package.json`) |
| Versi npm lama yang diganti | `9router@0.5.104` (di-pin di `scripts/install.sh` dulu) |

Yang ditambahkan fork ini dibanding upstream (ringkas, dari README fork):
kontrol per-key (limit token, interval reset, expiry, allow-list model),
custom model & plugin, backup terjadwal ke Telegram/GitHub, proxy pool,
security log, tema menyeluruh, dan banner update di dashboard.

## Kenapa di-vendor sebagai subfolder

- Fork ini **bukan paket npm** — ia aplikasi Next.js lengkap, jadi tidak
  bisa dipasang dengan `npm install -g 9router@x`.
- Menyalinnya ke `9router/` menghindari tabrakan nama file di root
  (kedua repo sama-sama punya `README.md`, `LICENSE`, `CHANGELOG.md`,
  `scripts/`, `tests/`, `docs/`).
- Satu clone = semua source lengkap; tidak perlu submodule / clone kedua.

## Yang berubah dari Hermuse asli

| File | Perubahan |
|---|---|
| `9router/` (baru) | Seluruh source fork serenhope (tanpa `.git`). |
| `scripts/install.sh` | Tidak lagi `npm install -g 9router@0.5.104`. Sebagai gantinya: `npm install` + `npm run build` di `./9router` (build diulang bila `.next/BUILD_ID` belum ada atau `package.json` lebih baru). Tambah `build-essential python3` ke apt (untuk compile modul native `better-sqlite3`). Wrangler tetap paket npm ter-pin (`4.151.2`). |
| `start-9router.sh` | Tidak lagi menjalankan binary `9router -p 20128 -H 127.0.0.1 -n -l --skip-update`. Sekarang menjalankan `node 9router/custom-server.js --port 20128 --hostname 127.0.0.1` dengan `PORT=20128`, `HOSTNAME=127.0.0.1`, `NODE_ENV=production`, `DATA_DIR=${DATA_DIR:-$HOME/.9router}`. Cek fail-closed `.dashboard-pw` tetap di awal, sebelum cek folder/build (supaya `tests/launcher-smoke.sh` tetap lolos). |
| `restart-9router.sh` | Pola kill lama (`[9]router -p`) diganti `pkill -f "custom-server[.]js --port 20128"` — hanya instance Hermuse ini yang kena. |
| `scripts/doctor.sh` | Assertion 3 tidak lagi cek `command -v 9router`; sekarang cek `9router/package.json` + `9router/.next/BUILD_ID` ada (built). |
| `scripts/doctor.test.sh` | Fixture assertion 3 diganti: `9router/package.json` + `.next/BUILD_ID` palsu di `DOCTOR_DIR`; shim binary `9router` dihapus. |
| `tests/installer-version.test.sh` | Ekstraksi fungsi installer berakhir di `ensure_pkg "wrangler"` (satu-satunya paket npm ter-pin yang tersisa). |
| `.gitignore` | Tambah `9router/.next/`, `9router/.next-dev/`, `9router/node_modules/`, `9router/package-lock.json`, `9router/.test-data/`. |
| `README.md`, `README.id.md` | Verifikasi install, tabel layout, dan catatan fork diperbarui. README bahasa lain (ms/vi/hi/ja) belum disinkronkan — masih menyebut alur npm lama. |
| `AGENTS.md`, `CHANGELOG.md` | Dicatat penggantian fork ini. |

## Kontrak runtime (tidak berubah dari luar)

- **Port/host:** `127.0.0.1:20128` — sama seperti sebelumnya. `watchdog.sh`,
  `scripts/start-all.sh`, dan `tunnel-client.mjs` tidak berubah karena
  mereka hanya mengecek/meneruskan HTTP ke port itu.
- **Dashboard:** `http://127.0.0.1:20128/dashboard` — `doctor.sh` tetap
  menganggap `200`/`307` sebagai sehat.
- **Password dashboard:** isi `.dashboard-pw` (chmod 600) diteruskan
  sebagai `INITIAL_PASSWORD`. Password default bawaan fork (`seren123`)
  **tidak** dipakai selama `INITIAL_PASSWORD` ter-set. Fail-closed tetap
  berlaku: bila `.tunnel-url` ada tapi `.dashboard-pw` hilang/kosong,
  `start-9router.sh` menolak jalan.
- **Data:** `~/.9router` (SQLite, secret JWT, backup) — default `DATA_DIR`
  fork. Bisa di-override dengan env `DATA_DIR`.
- **Endpoint:** OpenAI-compatible di `/v1`, Claude-compatible di
  `/v1/messages`, health di `/api/health` — sama seperti upstream.

## Perbedaan penting yang ditangani

1. **`npm run start` membekukan `--port 20127`.** `start-9router.sh`
   sengaja TIDAK memakai `npm run start`; ia memanggil `node
   custom-server.js` langsung dengan `--port 20128 --hostname 127.0.0.1`
   plus env `PORT`/`HOSTNAME` (jalur build standalone membaca env,
   jalur non-standalone membaca argv).
2. **Build wajib sebelum start.** `npm run build` menjalankan postbuild
   (`scripts/copy-standalone-assets.mjs`) yang menyiapkan
   `.next/standalone` + `custom-server.js` + tree `src/`/`scripts/`.
   `start-9router.sh` menolak jalan bila `.next/BUILD_ID` tidak ada.
3. **Build butuh toolchain native.** `better-sqlite3` perlu
   `python3` + `make` + `g++` — installer kini memasangnya via apt.
4. **Tidak ada `package-lock.json` yang di-commit** (upstream juga
   mengabaikannya). `npm install` di mesin target me-resolve dependensi
   sesuai rentang di `9router/package.json` — sama seperti Dockerfile
   fork itu sendiri.

## Jebakan gitignore (penting — jangan kembalikan)

Saat repo gabungan ini pertama dibuat, 19 file hasil clone upstream
**tidak ikut ter-stage** karena aturan ignore yang bertabrakan — dan
salah satunya kode runtime:

- Aturan root `logs/` (tanpa slash) meng-ignore **semua** folder bernama
  `logs` di kedalaman berapa pun — termasuk source
  `9router/src/app/(dashboard)/dashboard/logs/` (`LogsClient.js`,
  `page.js`) dan `9router/src/app/api/*/logs/route.js`. Tanpa file-file
  itu, `next build` gagal dan halaman logs dashboard hilang.
  **Perbaikan:** aturan root diubah menjadi `/logs/` (root saja).
  Hal yang sama untuk `.vscode/` → `/.vscode/`
  (`9router/.vscode/settings.json` di-track upstream).
- Aturan fork sendiri `9router-*` meng-ignore `9router/skills/*/SKILL.md`,
  dan `docs/*` meng-ignore `9router/docs/superpowers/*` +
  `9router/docs/images/*` — padahal upstream men-track file-file itu
  (di-force-add di sana). **Perbaikan:** file-file itu di-`git add -f`
  di repo ini; aturan `.gitignore` fork tidak diubah.
- Setelah perbaikan: **2.074 file di disk = 2.074 file ter-stage,
  0 untracked, 0 ignored.** Cek ulang sebelum commit berikutnya dengan
  `git status --porcelain` dan
  `git ls-files --others --ignored --exclude-standard`
  (harus kosong).

## Cara update fork

Pakai scriptnya — jangan ganti folder `9router/` manual:

```bash
bash scripts/update-9router.sh            # update ke master terbaru
bash scripts/update-9router.sh <ref>      # atau commit/tag/branch tertentu
DRY_RUN=1 bash scripts/update-9router.sh  # cek dulu tanpa mengubah apa-apa
```

Script itu: clone dangkal `serenhope/9router` ke temp dir, bandingkan
commit + versi dengan yang sedang di-vendor (bila sama, berhenti tanpa
mengubah apa-apa), ganti isi `9router/`, lalu perbarui tabel "Sumber"
di atas (commit + versi). Ia menolak jalan bila ada perubahan lokal
yang belum di-stage di `9router/`/`VENDORED-9ROUTER.md`, dan tidak
pernah men-commit/push sendiri — periksa dulu dengan `git diff --stat`.

Setelah update, di mesin target:

1. Jalankan ulang `bash scripts/install.sh` — build ulang otomatis
   karena `package.json` lebih baru dari `.next/BUILD_ID`.
2. `bash scripts/doctor.sh` harus `0 FAIL`, lalu `bash restart-9router.sh`.
3. Commit hasilnya, mis. `git commit -m "Update 9router (serenhope) ke <versi> (<commit>)"`.

Catatan: untuk ref berupa commit SHA, pakai SHA lengkap (40 karakter) —
SHA pendek tidak bisa di-fetch dari GitHub. Branch/tag bisa dipakai
apa adanya. Bila upstream sudah jauh lebih baru dari versi yang
di-vendor, baca dulu `9router/CHANGELOG.md` hasil update: fork ini
aktif dikembangkan dan skema datanya bisa berubah antar versi.

## Yang TIDAK berubah

Hermes Agent, Telegram gateway, tunnel Cloudflare Pages + D1,
`watchdog.sh`, `gateway-watch.sh`, dan semua skrip `tunnel/` — tidak ada
yang disentuh.

## Verifikasi (tanpa menjalankan stack penuh)

```bash
bash -n scripts/install.sh start-9router.sh restart-9router.sh scripts/doctor.sh
bash tests/launcher-smoke.sh          # fail-closed .dashboard-pw
bash tests/installer-version.test.sh   # pin wrangler
bash scripts/doctor.test.sh           # 14/14, termasuk fixture 9router baru
bash scripts/check-i18n.sh            # tidak ada key i18n baru
```

Build + boot penuh (`bash scripts/install.sh`, lalu
`bash restart-9router.sh` dan `curl http://127.0.0.1:20128/dashboard`)
dilakukan di mesin target (VPS), karena butuh `sudo`, login Hermes,
dan token Telegram/Cloudflare — tidak dilakukan di VM ini.

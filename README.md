# Jenius Tryout by Jenius Edu

Website publik multi-halaman berdasarkan tujuh referensi UI/UX yang diberikan.

## Halaman

- `index.html`: Beranda
- `kategori.html`: Kategori Tryout
- `jadwal.html`: Jadwal dan filter kategori, kalender navigasi
- `harga.html`: Paket dan perbandingan fitur
- `tentang.html`: Tentang platform
- `faq.html`: FAQ, filter dan pencarian
- `detail-tryout.html`: Detail kategori dan informasi program

## Teknologi

HTML statis per halaman, CSS bersama di `css/style.css`, dan renderer/interaksi di `js/site.js`. Cocok untuk Vercel static hosting. Responsif untuk desktop dan mobile.

## Penting

Ini adalah implementasi tampilan publik tahap pertama. Belum ada sistem login, pembayaran, pendaftaran, ujian CBT, data nyata, video, notifikasi, ataupun backend. Angka, harga, diskon, jadwal, peserta, dan testimoni ilustrasi tidak ditampilkan sebagai fakta. Semua transaksi dinonaktifkan sampai backend dan kebijakan bisnis tersedia.

Ilustrasi gambar referensi belum diubah menjadi aset website; hero sementara memakai visual CSS dan emoji agar tidak memakai gambar tanpa lisensi. Seluruh administrasi nantinya melalui Panel Pengelola `Alfin354313/panel-baru`.

Branch: `feature/full-public-ui-reference`; preview terlebih dahulu sebelum merge ke main.


## Portal Peserta (Prototype)

New pages: `daftar.html`, `login.html`, `dashboard.html`, `ujian.html`, `hasil.html`, `pembahasan.html`, `pembayaran.html`, `profil.html`.

These implement a **frontend-only demonstrator**: local nickname, five sample questions, ten-minute timer, answer navigation, automatic score, explanations, profile and a clearly disabled payment page. LocalStorage holds demo data **only on the visitor's device**. It is not real authentication: the access-code input is not checked against any server and is never stored. Do not use real personal information. The sample exam is not an official examination and must not be used for actual paid attempts.

**Before production**: integrate Supabase Auth and RLS-backed tables; server-authoritative exam attempts/timing/scoring; approved question bank; admin API with role enforcement and audit trail; payment gateway with verified webhook and idempotency; user data policies, backups and abuse controls; end-to-end tests. Admin remains centralized in `panel-baru`. Do not claim payment, accounts, or CBT are live until these are complete.

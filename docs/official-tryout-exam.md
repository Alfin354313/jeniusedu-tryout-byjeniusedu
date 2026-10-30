# Ujian resmi Tryout

Aktivasi: jalankan `supabase/migrations/20261030_exam_runtime.sql` pada Supabase bersama panel setelah migrasi integrasi `20261029_panel_integration.sql`. Skrip ini belum dijalankan oleh agen pada database aktif. Tidak memerlukan service-role key di browser.

1. Pengelola membuat paket, memasukkan soal, menentukan jadwal dan menerbitkannya.
2. Pengelola mendaftarkan akun peserta ke paket melalui Peserta Tryout.
3. Peserta membuka Jadwal & Ujian → Buka Ruang Ujian → Mulai Ujian.
4. Jawaban tersimpan ke server setiap perubahan. Muat ulang melanjutkan attempt dan timer yang sama.
5. Kumpulkan Ujian menilai jawaban di server. Waktu habis menutup jawaban dan menilai data yang sudah tersimpan saat permintaan berikutnya; browser yang terbuka mengirim permintaan otomatis ketika timer habis.
6. Nilai tampil setelah dikumpulkan. Kunci/pembahasan baru dikirim setelah jadwal paket berakhir, melalui tombol Lihat Jawaban & Pembahasan.

Snapshot menyimpan soal/kunci dan deadline saat mulai. Perubahan bank soal tidak mengubah penilaian attempt berjalan. Satu attempt per peserta/paket dibuat melalui RPC yang dilindungi advisory lock. Riwayat lama tanpa snapshot tidak diubah dan tidak dipaksa diulang; hubungi pengelola jika mencoba melanjutkan riwayat lama.

Tabel snapshot tidak dapat dibaca langsung peserta. RPC memeriksa identitas, pendaftaran, publikasi, jadwal, batas opsi, revision, dan deadline server. Kunci dan pembahasan tidak ada dalam respons sebelum waktu rilis. Pengiriman ulang submit tidak menilai ulang. Data jawaban yang belum terkirim disimpan sementara di browser per attempt, tanpa kunci; konflik tab ditolak untuk mencegah penimpaan.

Batas: pilihan ganda 2–8 opsi; paket snapshot maksimal 8 MB. Tidak ada pembayaran otomatis, pengulangan attempt, ujian uraian, atau sistem pengawasan tambahan dalam perubahan ini. Jangan hapus soal yang sudah digunakan oleh attempt; FK jawaban yang sudah tersimpan menjaga relasinya.

Validasi lokal:

```sh
PGLITE_MODULE=/path/to/@electric-sql/pglite node tests/exam-runtime.cjs
JSDOM_MODULE=/path/to/jsdom node tests/exam-runner-ui.cjs
```

PGlite memeriksa migrasi ulang, pendaftaran, kepemilikan, snapshot, kunci privat, resume, revision, penilaian, rilis pembahasan dan waktu habis. DOM fixture menguji mulai eksplisit, render gambar, simpan jawaban dan kumpulkan. Login/database produksi dan tampilan browser nyata belum diuji.

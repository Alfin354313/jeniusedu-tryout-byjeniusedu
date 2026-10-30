# Alur paket peserta Tryout

Daftar/login → akun peserta → Paket Tryout → pilih paket → checkout → unggah bukti melalui struk → Pengelola menyetujui → enrollment aktif → Tryout Saya.

Paket Tryout menyediakan delapan kategori, pencarian, harga database, informasi durasi/jadwal, rincian publik dan tombol checkout. Paket terbit yang belum melewati tanggal selesai dapat dipilih. Jika ada pesanan pending/awaiting_review/rejected, tombol melanjutkan ke struk yang sama. Paket aktif mengarahkan ke Tryout Saya. Pembayaran tetap menyimpan seluruh riwayat/status transaksi.

Tryout Saya, jumlah paket dashboard, dan Jadwal & Ujian kini mengikuti enrollment active saja. Pesanan belum lunas, enrollment cancelled dan riwayat attempt tanpa akses aktif tidak menambah daftar ini. Hasil/Pembahasan tetap memuat riwayat milik peserta. Akses pemberian manual Pengelola dan klaim voucher gratis yang sah juga tetap dapat aktif.

Tombol daftar/beli publik mengarah ke akun/menu paket. Konteks paket dipertahankan melalui login, daftar dan OAuth; intent checkout lama tetap diterima dan diarahkan ke menu paket sebelum membeli. Checkout dan nominal/voucher/order SQL tidak diubah. Pesanan lama tidak dihitung ulang.

Halaman Pembayaran sudah memeriksa status setiap 30 detik saat terlihat. Menu Paket Tryout, Tryout Saya dan Jadwal & Ujian menyegarkan akses setiap 30 detik dan/atau melalui tombol. Struk memeriksa perubahan status dan menawarkan tautan Tryout Saya jika enrollment benar-benar aktif. Tidak memulai ujian secara otomatis.

Memakai SQL checkout, payment_access dan exam_runtime yang sudah disiapkan. Tidak ada SQL baru untuk perubahan menu ini. Aktivasi pembayaran di database tetap bergantung pada migrasi payment_access; ujian membutuhkan exam_runtime. Kode ini tidak memberi akses hanya berdasarkan status label di browser.

Validasi jsdom: delapan kategori, link checkout, kelanjutan order pending, pemisahan pesanan dari paket aktif, exclusion cancelled/history, penyegaran aktivasi, konteks login/signup/Google, serta regresi harga/CMS/ruang ujian. Pemeriksaan browser signed-in dan transaksi nyata belum dilakukan. Preview saja.

## Tampilan kartu kategori

Halaman Paket Tryout menampilkan delapan kartu kategori lengkap: header gradasi biru, penjelasan dari CMS kategori, rincian durasi/jadwal, fasilitas, harga database dan tindakan pembelian. Jika hanya ada satu paket tersedia, kartu kategori memakai paket tersebut dan langsung menawarkan checkout/status pesanan/akses aktif. Jika ada beberapa paket, tombol membuka pilihan paket kategori. Kategori tanpa paket tetap tampil dengan status belum tersedia dan tombol nonaktif. Pencarian, dropdown kategori dan tombol Semua Kategori tetap tersedia. Daftar paket terfilter memakai desain kartu yang sama.

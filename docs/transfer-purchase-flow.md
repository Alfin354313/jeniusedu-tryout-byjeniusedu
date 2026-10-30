# Pembelian dengan transfer BCA

Alur: kartu Paket Tryout → halaman detail beli → Beli Paket → modal metode pembayaran/voucher → Beli Paket Sekarang → struk/instruksi transfer BCA → unggah bukti → Pengelola verifikasi → akses aktif di Tryout Saya.

Checkout memakai harga paket dari database, biaya admin dan RPC voucher yang sudah ada. Membuka modal atau memeriksa voucher belum membuat pesanan. RPC jt_create_order baru dipanggil setelah konfirmasi. Selama permintaan berlangsung, tombol dikunci untuk mencegah klik ganda. Akun yang sudah aktif atau memiliki pesanan diarahkan melanjutkan akses/pesanan tersebut.

Metode saat ini hanya transfer BCA ke rekening yang sudah digunakan. Nomor rekening dan total resmi ditampilkan pada struk setelah order tersimpan. Tombol salin rekening/nominal serta Cek Status Pembayaran tersedia. Proof upload tetap memakai bucket privat jt-payment-proofs dan RPC jt_submit_proof. Bukti terkirim bukan status lunas.

Verifikasi tetap manual melalui Pengelola. Halaman struk memeriksa status setiap 30 detik saat terlihat dan menyediakan pemeriksaan manual. Tidak ada QRIS, virtual account, countdown kedaluwarsa atau klaim verifikasi otomatis yang ditambahkan. Voucher gratis yang menghasilkan total nol tetap menggunakan aturan checkout server.

Tidak memerlukan SQL baru. Tetap memerlukan SQL checkout, voucher dan payment_access yang sudah disiapkan. Tidak ada transaksi uang asli atau SQL production dijalankan dalam perubahan ini.

Validasi jsdom: detail → modal, total BCA/admin, voucher server/free claim, konfirmasi satu kali, pesanan/akses lama, login dan perubahan harga; struk/instruksi/nominal, cek status, unggah proof privat, aktivasi sesuai enrollment. Regresi kartu dan alur paket peserta lulus. Tampilan browser dan transfer nyata belum diverifikasi.

# Portal peserta Tryout

Portal kini menggunakan Supabase Auth getUser dan tabel jt_profiles, jt_exams, jt_attempts, jt_orders dengan filter akun dan RLS yang sudah dirancang. Tidak membaca hasil atau profil demo localStorage. Keluar memakai signOut.

Halaman internal: dashboard, tryout-saya, jadwal-ujian, hasil, pembahasan, profil, bantuan. Jadwal publik jadwal.html tetap. ujian.html menampilkan informasi/kesiapan, tanpa menjalankan demo CBT. Profil menyimpan nama ke jt_profiles; email mengikuti Auth. Nilai null tetap menunggu penilaian. FAQ bantuan berada di dalam portal.

Batas integrasi: migrasi schema 20261026 harus sudah dijalankan pada Supabase tujuan dan kebijakan RLS sesuai. Agen belum mengubah database nyata. Jika tabel/akses gagal, UI menampilkan kesalahan, bukan data contoh. Tryout Saya berasal dari order atau attempt; belum ada tabel enrollment terpisah. Tidak ada write ke nilai/order/attempt dan tidak membaca jt_questions maupun jt_answers.

Layanan server untuk eligibility, mulai ujian, sanitasi soal, autosave, submit, grading, serta penerbitan pembahasan belum tersedia. Tidak ada tombol palsu untuk memulai ujian atau jawaban demo. Belum dapat melaksanakan ujian resmi atau pembahasan per soal. Implementasi itu perlu dilanjutkan sebelum peluncuran.

Validasi: syntax module dan fixture DOM delapan route, per-user read, navigasi internal, nilai null, status jadwal, profile upsert, escaped text, dan error state. Belum diuji end-to-end terhadap Supabase nyata/akun login browser.

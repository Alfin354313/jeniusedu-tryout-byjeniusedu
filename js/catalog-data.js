import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const db=createClient('https://emcchkpdgwkjovdylcth.supabase.co','sb_publishable_S_c2Lqt84z8XOgq6btW60g_Fz3rhrCe');
const page=document.body.dataset.page,main=document.getElementById('main-content');
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const date=v=>v?new Date(v).toLocaleString('id-ID',{timeZone:'Asia/Jakarta'}):'Belum ditentukan';
if(main&&['home','kategori','jadwal','detail'].includes(page)){
 const section=document.createElement('section');section.className='section';section.innerHTML='<div class="container"><h2>Paket Tryout Terbit</h2><p role="status">Memuat paket...</p></div>';
 if(page==='home'){main.querySelector('section')?.after(section)}else if(page==='jadwal'){const target=main.querySelector('.schedule-empty');target?.before(section)}else if(page==='kategori'){main.querySelector('.category-benefits')?.before(section)}else{main.querySelector('#sesi')?.append(section)}
 try{
 const [c,e]=await Promise.all([db.from('jt_categories').select('id,title,slug,description').eq('is_published',true),db.from('jt_exams').select('id,title,category_id,duration_minutes,starts_at,ends_at').eq('is_published',true).order('starts_at',{ascending:true})]);if(c.error||e.error)throw Error();
 const categories=c.data||[],params=new URLSearchParams(location.search),id=params.get('exam'),category=params.get('kategori');
 const rows=(e.data||[]).filter(x=>(!id||x.id===id)&&(!category||categories.some(y=>y.id===x.category_id&&[y.title,y.slug,y.id].includes(category))));
 const cards=rows.map(x=>'<article class="panel" style="padding:24px"><span class="eyebrow">'+esc(categories.find(y=>y.id===x.category_id)?.title||'Tryout')+'</span><h3>'+esc(x.title)+'</h3><p>Durasi: '+esc(x.duration_minutes)+' menit</p><p>Mulai: '+esc(date(x.starts_at))+'</p><p>Selesai: '+esc(date(x.ends_at))+'</p><a class="btn primary" href="'+(page==='detail'?'login.html':'detail-tryout.html?exam='+encodeURIComponent(x.id))+'">'+(page==='detail'?'Masuk ke Akun Peserta':'Lihat Detail')+'</a></article>').join('');
 if(!rows.length){section.remove();return;}
 if(page==='jadwal'){const empty=main.querySelector('.schedule-empty');if(empty)empty.hidden=true;const note=main.querySelector('.schedule-calendar>p');if(note)note.textContent='Tanggal pelaksanaan tersedia pada daftar paket.';}
 section.innerHTML='<div class="container"><h2>'+(page==='jadwal'?'Jadwal Tryout':page==='detail'?'Detail Paket Tryout':'Paket Tryout Terbit')+'</h2><p>Pilih paket untuk melihat informasi pelaksanaan.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px">'+(cards||'<div class="panel" style="padding:24px">Belum ada paket terbit yang sesuai.</div>')+'</div></div>';
 }catch{section.remove();return;section.innerHTML='<div class="container"><h2>Paket belum dapat dimuat</h2><p>Periksa koneksi atau coba lagi nanti.</p><a class="btn" href="login.html">Masuk ke Akun Peserta</a></div>'}
}

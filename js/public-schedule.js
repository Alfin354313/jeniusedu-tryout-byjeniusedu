(async function(){
 const page=document.body.dataset.page;if(!['jadwal','detail'].includes(page))return;
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&quot;'}[c]));
 const fmt=v=>v?new Date(v).toLocaleString('id-ID',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Jakarta'})+' WIB':'Belum ditentukan';
 let data;
 try{const r=await fetch('/api/public-schedule',{cache:'no-store'});data=await r.json();if(!r.ok)throw Error(data.error||'Gagal mengambil data')}catch(e){
  const target=document.querySelector(page==='jadwal'?'.schedule-empty':'#tentang-tryout');
  if(target)target.insertAdjacentHTML('beforeend','<p role="alert" style="color:#a33939">Jadwal belum dapat dimuat: '+escape(e.message)+'</p>');return;
 }
 const exams=data.exams||[],cats=data.categories||[];
 const category=e=>cats.find(c=>c.id===e.category_id)?.title||'Tryout';
 if(page==='jadwal'){
  const content=document.querySelector('.schedule-empty'),calendar=document.querySelector('.schedule-calendar');
  if(!content)return;
  const search=document.querySelector('#scheduleSearch');
  const render=()=>{
   const selected=document.querySelector('.schedule-filter.selected')?.dataset.filter||'all';
   const q=(search?.value||'').trim().toLowerCase();
   const filtered=exams.filter(e=>(selected==='all'||category(e).toLowerCase()===selected)&&(!q||(e.title+' '+category(e)).toLowerCase().includes(q)));
   content.innerHTML=filtered.length?'<div class="jt-live-list">'+filtered.map(e=>'<article class="jt-live-card"><span class="eyebrow">'+escape(category(e))+'</span><h3>'+escape(e.title)+'</h3><p>Mulai: '+escape(fmt(e.starts_at))+'</p><p>Selesai: '+escape(fmt(e.ends_at))+'</p><p>Durasi: '+escape(e.duration_minutes)+' menit</p><a class="btn" href="detail-tryout.html?exam='+encodeURIComponent(e.id)+'">Lihat Detail →</a></article>').join('')+'</div>':'<h3>Belum ada jadwal sesuai filter</h3><p>Silakan pilih kategori atau kata kunci lainnya.</p>';
   if(calendar){let note=calendar.querySelector('.jt-live-note');if(!note){note=document.createElement('p');note.className='jt-live-note';calendar.append(note)}note.textContent=filtered.length+' jadwal diterbitkan';}
  };
  document.querySelectorAll('.schedule-filter').forEach(b=>b.addEventListener('click',()=>setTimeout(render,0)));
  search?.addEventListener('input',render);render();
 }
 if(page==='detail'){
  const params=new URLSearchParams(location.search),id=params.get('exam');
  const exam=exams.find(e=>e.id===id);
  if(!exam)return;
  const title=document.querySelector('#detailTitle'),cat=document.querySelector('#detailCategory');
  if(title)title.textContent=exam.title;if(cat)cat.textContent=category(exam);
  const about=document.querySelector('#tentang-tryout');
  if(about){const p=about.querySelector('p.muted');if(p)p.textContent='Durasi '+exam.duration_minutes+' menit. Mulai '+fmt(exam.starts_at)+'. Selesai '+fmt(exam.ends_at)+'.';}
  const sessions=document.querySelector('#sesi .notice');
  if(sessions)sessions.textContent='Mulai: '+fmt(exam.starts_at)+' | Selesai: '+fmt(exam.ends_at)+' | Durasi: '+exam.duration_minutes+' menit';
 }
})();
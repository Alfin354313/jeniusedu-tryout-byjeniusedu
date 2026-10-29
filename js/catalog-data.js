import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const db=createClient('https://emcchkpdgwkjovdylcth.supabase.co','sb_publishable_S_c2Lqt84z8XOgq6btW60g_Fz3rhrCe');
const page=document.body.dataset.page,main=document.getElementById('main-content');
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm=v=>String(v||'').trim().toLocaleLowerCase('id-ID').replace(/[^a-z0-9]/g,'');
const date=v=>v?new Date(v).toLocaleString('id-ID',{timeZone:'Asia/Jakarta'}):'Jadwal menyusul';
function dayKey(value){if(!value)return '';const d=new Date(value);if(isNaN(d))return '';const p=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Jakarta',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(d);return ['year','month','day'].map(k=>p.find(x=>x.type===k).value).join('-')}
async function init(){
if(!main||!['home','kategori','jadwal','detail'].includes(page))return;
try{
 const [c,e]=await Promise.all([db.from('jt_categories').select('id,title,slug,description').eq('is_published',true),db.from('jt_exams').select('id,title,category_id,duration_minutes,starts_at,ends_at').eq('is_published',true).order('starts_at',{ascending:true})]);
 if(c.error||e.error)throw Error('Data belum dapat dimuat');
 const categories=c.data||[],exams=e.data||[],params=new URLSearchParams(location.search);
 const category=exam=>categories.find(x=>x.id===exam.category_id);
 const matches=(exam,key)=>{const cat=category(exam);return key==='all'||!!cat&&[cat.title,cat.slug,cat.id].some(v=>norm(v)===norm(key))};
 const cards=rows=>rows.map(exam=>'<article class="schedule-item"><div class="avatar" aria-hidden="true">▣</div><div><span class="eyebrow">'+esc(category(exam)?.title||'Tryout')+'</span><h3>'+esc(exam.title)+'</h3><p>Durasi '+esc(exam.duration_minutes)+' menit</p></div><div class="schedule-meta">Mulai: '+esc(date(exam.starts_at))+'<br>Selesai: '+esc(date(exam.ends_at))+'</div><div class="schedule-price"><a class="btn soft" href="detail-tryout.html?exam='+encodeURIComponent(exam.id)+'">Lihat Detail →</a></div></article>').join('');
 if(page==='kategori'){
  main.querySelectorAll('.category-card').forEach(card=>{const key=card.querySelector('h3')?.textContent||'',count=exams.filter(x=>matches(x,key)).length,body=card.querySelector('.category-card-body');
   card.href='detail-tryout.html?kategori='+encodeURIComponent(key);
   const label=document.createElement('small');label.className='catalog-package-count';label.textContent=count?count+' paket terbit':'Paket sedang disiapkan';body?.append(label)});
 }
 if(page==='jadwal'){
  const empty=main.querySelector('.schedule-empty'),content=main.querySelector('.schedule-content'),calendar=main.querySelector('#calendar'),search=main.querySelector('#scheduleSearch'),filters=main.querySelector('.schedule-filters');
  if(!empty||!content||!calendar||!search||!filters)return;
  const list=document.createElement('div');list.className='catalog-schedule-list';empty.before(list);
  const status=document.createElement('p');status.className='search-results';status.setAttribute('role','status');main.querySelector('.schedule-heading').after(status);
  categories.forEach(cat=>{if([...filters.querySelectorAll('[data-filter]')].some(b=>norm(b.dataset.filter)===norm(cat.title)||norm(b.dataset.filter)===norm(cat.slug)))return;const b=document.createElement('button');b.type='button';b.className='schedule-filter';b.dataset.filter=cat.title;b.textContent=cat.title;b.setAttribute('aria-pressed','false');filters.append(b)});
  let selected=params.get('kategori')||'all',selectedDay='',monthKey=dayKey(new Date()).slice(0,7);
  const filtered=()=>exams.filter(x=>matches(x,selected)&&[x.title,category(x)?.title].join(' ').toLocaleLowerCase('id-ID').includes(search.value.trim().toLocaleLowerCase('id-ID')));
  function renderList(){const rows=filtered().filter(x=>!selectedDay||dayKey(x.starts_at)===selectedDay);list.innerHTML=cards(rows);list.hidden=!rows.length;empty.hidden=!!rows.length;
   status.textContent=selectedDay?'Tanggal '+selectedDay+' · '+rows.length+' jadwal.':rows.length?rows.length+' jadwal ditemukan.':'';
   const message=empty.querySelector('#scheduleCount');if(message)message.textContent=selectedDay?'Belum ada jadwal pada tanggal dan kategori ini.':'Belum ada jadwal yang sesuai dengan pencarian atau kategori pilihanmu.';
  }
  function renderCalendar(){const [year,month]=monthKey.split('-').map(Number),first=new Date(Date.UTC(year,month-1,1)),days=new Date(Date.UTC(year,month,0)).getUTCDate(),rows=filtered();
   calendar.innerHTML='<div class="monthbar"><button type="button" data-month="-1" aria-label="Bulan sebelumnya">‹</button><strong>'+new Intl.DateTimeFormat('id-ID',{month:'long',year:'numeric',timeZone:'UTC'}).format(first)+'</strong><button type="button" data-month="1" aria-label="Bulan berikutnya">›</button></div><div class="calendar-grid">'+['Min','Sen','Sel','Rab','Kam','Jum','Sab'].map(x=>'<span><b>'+x+'</b></span>').join('')+Array.from({length:first.getUTCDay()},()=>'<span></span>').join('')+Array.from({length:days},(_,i)=>{const key=monthKey+'-'+String(i+1).padStart(2,'0'),events=rows.filter(x=>dayKey(x.starts_at)===key);return '<button type="button" class="catalog-day '+(events.length?'has-events ':'')+(selectedDay===key?'is-selected':'')+'" data-day="'+key+'" aria-pressed="'+(selectedDay===key)+'" aria-label="'+key+', '+events.length+' jadwal" title="'+esc(events.map(x=>x.title).join(', '))+'">'+(i+1)+(events.length?'<i aria-hidden="true"></i>':'')+'</button>'}).join('')+'</div>';
   calendar.querySelectorAll('[data-month]').forEach(b=>b.onclick=()=>{const d=new Date(Date.UTC(year,month-1+Number(b.dataset.month),1));monthKey=d.getUTCFullYear()+'-'+String(d.getUTCMonth()+1).padStart(2,'0');selectedDay='';renderCalendar();renderList()});
   calendar.querySelectorAll('[data-day]').forEach(b=>b.onclick=()=>{selectedDay=selectedDay===b.dataset.day?'':b.dataset.day;renderCalendar();renderList()});
   const note=main.querySelector('.schedule-calendar>p');if(note)note.textContent=rows.some(x=>dayKey(x.starts_at))?'Titik biru menandai jadwal terbit. Pilih tanggal untuk melihat paket.':'Belum ada jadwal terbit untuk kategori pilihanmu.';
  }
  filters.querySelectorAll('[data-filter]').forEach(b=>b.addEventListener('click',()=>{selected=b.dataset.filter;selectedDay='';filters.querySelectorAll('[data-filter]').forEach(x=>{const active=x===b;x.classList.toggle('selected',active);x.setAttribute('aria-pressed',String(active))});renderCalendar();renderList()}));
  search.addEventListener('input',()=>{selectedDay='';renderCalendar();renderList()});
  filters.querySelectorAll('[data-filter]').forEach(b=>{const active=norm(b.dataset.filter)===norm(selected);b.classList.toggle('selected',active);b.setAttribute('aria-pressed',String(active))});renderCalendar();renderList();
 }
 if(page==='detail'){
  const id=params.get('exam'),key=params.get('kategori'),rows=exams.filter(x=>(!id||x.id===id)&&(!key||matches(x,key))),target=main.querySelector('#tentang-tryout'),session=main.querySelector('#sesi');
  const icon=(name)=>{const paths={book:'<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z"/>',calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/>',clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'};return '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+paths[name]+'</svg>'};
  const header=(name,title,desc)=>'<div class="jt-section-head"><span class="jt-section-icon">'+icon(name)+'</span><div><h2>'+title+'</h2><p class="muted">'+desc+'</p></div></div>';
  if(target&&!id){
    target.innerHTML=header('book','Tryout '+esc(key||'Tersedia'),'Pilih paket untuk melihat rincian ujian dan pendaftaran.')+
      '<div class="jt-package-grid">'+(rows.map(exam=>
      '<a class="jt-package-card" href="detail-tryout.html?exam='+encodeURIComponent(exam.id)+'">'+
      '<span class="jt-package-category">'+esc(category(exam)?.title||'Tryout')+'</span>'+
      '<strong>'+esc(exam.title)+'</strong>'+
      '<span class="jt-package-duration">'+icon('clock')+'<span>'+esc(exam.duration_minutes)+' menit</span></span>'+
      '<span class="jt-package-link">Lihat informasi paket →</span></a>').join('')||'<p class="notice">Belum ada paket diterbitkan untuk kategori ini.</p>')+'</div>';
  }
  if(session){
    session.innerHTML=header('calendar','Jadwal & Sesi','Periode pelaksanaan paket yang sudah diterbitkan.')+
      (rows.length?'<div class="jt-session-list">'+rows.map(exam=>
      '<div class="jt-session-row"><div class="jt-session-date">'+icon('calendar')+
      '<span>'+esc(exam.starts_at?new Date(exam.starts_at).toLocaleDateString('id-ID',{day:'2-digit',month:'short',timeZone:'Asia/Jakarta'}):'—')+'</span></div>'+
      '<div class="jt-session-info"><strong>'+esc(exam.title)+'</strong>'+
      '<span>Mulai: '+esc(date(exam.starts_at))+'</span>'+
      '<span>Selesai: '+esc(date(exam.ends_at))+'</span></div>'+
      '<span class="jt-session-duration">'+icon('clock')+'<span>'+esc(exam.duration_minutes)+' menit</span></span></div>').join('')+'</div>':
      '<div class="notice">Jadwal belum tersedia.</div>')+
      '<a class="btn soft jt-calendar-link" href="jadwal.html'+(key?'?kategori='+encodeURIComponent(key):'')+'">Lihat Kalender →</a>';
  }
  if(id){const exam=rows[0];if(target)target.innerHTML=exam?'<span class="eyebrow">'+esc(category(exam)?.title||'Tryout')+'</span><h2>'+esc(exam.title)+'</h2><p>Durasi '+esc(exam.duration_minutes)+' menit.</p><p>Mulai: '+esc(date(exam.starts_at))+'</p><p>Selesai: '+esc(date(exam.ends_at))+'</p><a class="btn primary" href="login.html">Masuk ke Akun Peserta</a>':'<h2>Paket belum tersedia</h2><p>Paket belum diterbitkan atau sudah dinonaktifkan.</p>'}
 }
 if(page==='home'&&exams.length){const section=document.createElement('section');section.className='section';section.innerHTML='<div class="container"><div class="row-head"><h2>Tryout Terbaru</h2><a class="btn soft" href="jadwal.html">Lihat Jadwal</a></div><div class="catalog-schedule-list">'+cards(exams.slice(0,3))+'</div></div>';main.querySelector('section')?.after(section)}
}catch{const message=main.querySelector('#scheduleCount');if(message)message.textContent='Jadwal belum dapat dimuat. Coba lagi nanti.';}
}
init();

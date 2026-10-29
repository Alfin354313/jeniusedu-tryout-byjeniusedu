// Public, read-only schedule endpoint. Supabase RLS must allow SELECT on published rows.
module.exports=async(req,res)=>{
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='GET')return res.status(405).json({error:'Method not allowed'});
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL||process.env.SUPABASE_URL;
 const key=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||process.env.SUPABASE_ANON_KEY;
 const keyType=key?.startsWith('sb_publishable_')?'publishable':key?.startsWith('eyJ')?'legacy-jwt':'other';
 if(!url||!key)return res.status(503).json({error:'Konfigurasi database Tryout belum tersedia pada deployment ini.'});
 try{
  const headers={apikey:key,Accept:'application/json'};
  // sb_publishable_* is an API key, not a JWT. Supabase gateway handles its anonymous role.
  if(!key.startsWith('sb_publishable_'))headers.Authorization='Bearer '+key;
  const base=url.replace(/\/$/,'')+'/rest/v1/';
  const [er,cr]=await Promise.all([
   fetch(base+'jt_exams?select=id,title,category_id,duration_minutes,starts_at,ends_at,is_published&is_published=eq.true&order=starts_at.asc',{headers}),
   fetch(base+'jt_categories?select=id,title,slug&is_published=eq.true',{headers})
  ]);
  if(!er.ok||!cr.ok){const failed=er.ok?cr:er;const table=er.ok?'jt_categories':'jt_exams';let code='unknown';try{const body=await failed.json();code=String(body.code||body.error_code||body.error||'unknown').slice(0,80)}catch(_){}return res.status(502).json({error:'Supabase HTTP '+failed.status,diagnostic:{table,code,keyType,hint:failed.status===401?'Periksa pasangan SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY pada proyek Supabase yang sama.':'Periksa kebijakan SELECT publik pada tabel.'}});}
  const exams=await er.json(),categories=await cr.json();
  return res.status(200).json({exams,categories});
 }catch(e){return res.status(502).json({error:'Gagal memuat jadwal publik: '+e.message})}
};
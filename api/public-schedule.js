// Public, read-only schedule endpoint. Supabase RLS must allow SELECT on published rows.
module.exports=async(req,res)=>{
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='GET')return res.status(405).json({error:'Method not allowed'});
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL||process.env.SUPABASE_URL;
 const key=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||process.env.SUPABASE_ANON_KEY;
 if(!url||!key)return res.status(503).json({error:'Konfigurasi database Tryout belum tersedia pada deployment ini.'});
 try{
  const headers={apikey:key,Authorization:'Bearer '+key,Accept:'application/json'};
  const base=url.replace(/\/$/,'')+'/rest/v1/';
  const [er,cr]=await Promise.all([
   fetch(base+'jt_exams?select=id,title,category_id,duration_minutes,starts_at,ends_at,is_published&is_published=eq.true&order=starts_at.asc',{headers}),
   fetch(base+'jt_categories?select=id,title,slug&is_published=eq.true',{headers})
  ]);
  if(!er.ok||!cr.ok)throw Error('Supabase HTTP '+(er.ok?cr.status:er.status));
  const exams=await er.json(),categories=await cr.json();
  return res.status(200).json({exams,categories});
 }catch(e){return res.status(502).json({error:'Gagal memuat jadwal publik: '+e.message})}
};
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const db=createClient('https://emcchkpdgwkjovdylcth.supabase.co','sb_publishable_S_c2Lqt84z8XOgq6btW60g_Fz3rhrCe',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const safeLink=value=>{try{const url=new URL(value,location.origin);return url.protocol==='https:'||(value.startsWith('/')&&!value.startsWith('//'))?url.href:null}catch{return null}};
const fallback={title:'Siapkan langkahmu bersama Jenius Tryout',description:'Temukan kategori latihan sesuai jenjang dan tujuan belajarmu.',button_label:'Jelajahi Kategori',target_url:'/kategori.html'};
const node=(tag,text,cls)=>{const e=document.createElement(tag);if(text)e.textContent=text;if(cls)e.className=cls;return e};
export async function mountPromotions(){
 if(document.body.dataset.page!=='home'||document.getElementById('jtPublicPromotions'))return;
 const main=document.getElementById('main-content');if(!main)return;
 let banners;try{const r=await db.from('jt_promotions').select('id,title,description,image_url,image_alt,button_label,target_url,sort_order').eq('is_published',true).order('sort_order').order('id').limit(10);if(r.error)throw r.error;banners=r.data||[]}catch{banners=[fallback]}
 if(!banners.length)return;
 const section=node('section',null,'jt-promo-section');section.id='jtPublicPromotions';section.setAttribute('aria-label','Promosi Jenius Tryout');
 const container=node('div',null,'container'),frame=node('div',null,'jt-promo-frame'),controls=node('div',null,'jt-promo-controls');container.append(frame,controls);section.append(container);
 let position=0;function render(){const b=banners[position];frame.replaceChildren();const copy=node('div',null,'jt-promo-copy');copy.append(node('span','JENIUS TRYOUT'),node('h2',b.title),node('p',b.description));const href=safeLink(b.target_url||'');if(href){const a=node('a',b.button_label||'Lihat Selengkapnya');a.href=href;copy.append(a)}const visual=node('div',null,'jt-promo-image');if(b.image_url&&/^https:\/\//i.test(b.image_url)){const img=node('img');img.src=b.image_url;img.alt=b.image_alt||'';img.loading='lazy';img.onerror=()=>visual.replaceChildren(node('span','Jenius', 'jt-promo-art'));visual.append(img)}else visual.append(node('span','Jenius','jt-promo-art'));frame.append(copy,visual);controls.replaceChildren();if(banners.length>1){const prev=node('button','‹'),next=node('button','›'),count=node('span',(position+1)+' / '+banners.length);prev.type=next.type='button';prev.setAttribute('aria-label','Promosi sebelumnya');next.setAttribute('aria-label','Promosi berikutnya');count.setAttribute('aria-live','polite');prev.onclick=()=>{position=(position-1+banners.length)%banners.length;render();controls.children[0]?.focus?.()};next.onclick=()=>{position=(position+1)%banners.length;render();controls.children[2]?.focus?.()};controls.append(prev,count,next)}}
 render();main.querySelector('section')?.after(section);
}
mountPromotions();

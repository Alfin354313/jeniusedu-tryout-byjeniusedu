import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const client=createClient("https://emcchkpdgwkjovdylcth.supabase.co","sb_publishable_S_c2Lqt84z8XOgq6btW60g_Fz3rhrCe");
const root=document.getElementById("portal");if(root)root.textContent="Memeriksa sesi peserta...";
try{const {data:{user},error}=await client.auth.getUser();if(error||!user){location.replace("login.html")}else{
const {data:profile}=await client.from("jt_profiles").select("display_name").eq("user_id",user.id).maybeSingle();
const name=profile?.display_name||user.user_metadata?.display_name||user.email?.split("@")[0]||"Peserta";
let demo={};try{demo=JSON.parse(localStorage.getItem("jeniustryout_demo_v1")||"{}")}catch{}
localStorage.setItem("jeniustryout_demo_v1",JSON.stringify({...demo,name}));
await import("./portal.js");
const logout=document.createElement("button");logout.type="button";logout.textContent="Keluar Akun";logout.className="portal-btn secondary";logout.style.margin="12px";logout.addEventListener("click",async()=>{await client.auth.signOut();localStorage.removeItem("jeniustryout_demo_v1");location.replace("login.html")});document.querySelector(".portal-nav")?.append(logout);
}}catch(e){if(root)root.textContent="Tidak dapat memeriksa sesi. Periksa koneksi internet dan muat ulang halaman."}

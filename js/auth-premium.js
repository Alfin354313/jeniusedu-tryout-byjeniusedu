import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
const supabase=createClient("https://emcchkpdgwkjovdylcth.supabase.co","sb_publishable_S_c2Lqt84z8XOgq6btW60g_Fz3rhrCe");
const page=document.body.dataset.auth;
const form=document.getElementById("authForm"),pass=document.getElementById("code"),show=document.getElementById("showPassword"),feedback=document.getElementById("authError");
show?.addEventListener("click",()=>{const visible=pass.type==="text";pass.type=visible?"password":"text";show.textContent=visible?"Lihat":"Sembunyikan";show.setAttribute("aria-label",visible?"Tampilkan password":"Sembunyikan password")});
const googleButton=document.getElementById("googleSignIn");
googleButton?.addEventListener("click",async()=>{googleButton.disabled=true;feedback.textContent="Menghubungkan ke Google...";try{const redirectTo=new URL("login.html",location.href).href;const {error}=await supabase.auth.signInWithOAuth({provider:"google",options:{redirectTo}});if(error)throw error}catch(error){feedback.textContent=error.message||"Login Google gagal. Silakan coba lagi.";googleButton.disabled=false}});
(async()=>{if(page!=="login")return;const {data:{session},error}=await supabase.auth.getSession();if(error||!session?.user)return;const name=session.user.user_metadata?.display_name||session.user.user_metadata?.full_name||session.user.email?.split("@")[0]||"Peserta";try{localStorage.setItem("jeniustryout_demo_v1",JSON.stringify({name}))}catch{}location.replace("dashboard.html")})();
form?.addEventListener("submit",async event=>{event.preventDefault();const button=form.querySelector('button[type="submit"]');button.disabled=true;feedback.textContent="Memproses...";try{
const email=document.getElementById("email")?.value.trim(),password=pass.value;
if(!email||password.length<8)throw new Error("Isi email dan password minimal 8 karakter.");
if(page==="daftar"){
 const name=document.getElementById("name")?.value.trim();if(!name)throw new Error("Nama lengkap wajib diisi.");if(!document.getElementById("terms")?.checked)throw new Error("Setujui syarat penggunaan.");
 const {data,error}=await supabase.auth.signUp({email,password,options:{data:{display_name:name},emailRedirectTo:new URL("login.html",location.href).href}});if(error)throw error;
 if(data.session){const {error:profileError}=await supabase.from("jt_profiles").upsert({user_id:data.user.id,display_name:name},{onConflict:"user_id"});if(profileError)throw profileError;location.assign("dashboard.html");return}
 feedback.textContent="Pendaftaran diterima. Periksa email untuk konfirmasi akun sebelum masuk.";
}else{
 const {data,error}=await supabase.auth.signInWithPassword({email,password});if(error)throw error;
 const name=data.user.user_metadata?.display_name||email.split("@")[0];
 try{localStorage.setItem("jeniustryout_demo_v1",JSON.stringify({name}))}catch{}
 location.assign("dashboard.html");return;
}
}catch(error){feedback.textContent=error.message||"Terjadi kesalahan. Silakan coba lagi."}finally{button.disabled=false}});

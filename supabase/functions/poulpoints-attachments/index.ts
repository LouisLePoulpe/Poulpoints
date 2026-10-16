const base = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const bucket = 'poulpoints-attachments';
const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-gc-token', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
async function api(path: string, method='GET', body?: unknown) {
 const r = await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});
 if(!r.ok) throw new Error(`Storage service ${r.status}`);
 const text=await r.text(); return text?JSON.parse(text):null;
}
const rpc=(name:string,body:unknown)=>api('/rest/v1/rpc/'+name,'POST',body);
const query=(values:Record<string,string>)=>new URLSearchParams(values).toString();
const reply=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{...cors,'Content-Type':'application/json'}});
async function remove(path:string) { await api('/storage/v1/object/'+bucket,'DELETE',{prefixes:[path]}); }
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return reply({error:'POST required'},405);
 try {
  const gc=req.headers.get('x-gc-token');
  if(gc){
   if(!await rpc('poulpoints_attachment_gc_authorized',{token:gc})) return reply({error:'Forbidden'},403);
   // Expired uploads are never made downloadable; grace exceeds the upload timeout.
   await api('/rest/v1/poulpoints_attachments?'+query({ready:'eq.false',deleted_at:'is.null',created_at:'lt.'+new Date(Date.now()-900000).toISOString()}),'PATCH',{deleted_at:new Date().toISOString()});
   const jobs=await api('/rest/v1/poulpoints_attachments?'+query({select:'id,path',deleted_at:'not.is.null',or:'(ready.eq.true,deleted_at.lt.'+new Date(Date.now()-120000).toISOString()+')',limit:'100',order:'deleted_at.asc'}));
   let removed=0;
   for(const job of jobs){try{await remove(job.path);await api('/rest/v1/poulpoints_attachments?'+query({id:'eq.'+job.id}),'DELETE');removed++;}catch{/* Durable row retained for next retry. */}}
   return reply({removed,pending:jobs.length-removed});
  }
  const auth=req.headers.get('authorization')??'';
  const u=await fetch(base+'/auth/v1/user',{headers:{apikey:key,Authorization:auth}});
  if(!u.ok)return reply({error:'Authentication required'},401);
  const user=(await u.json()).id;
  const access=await api('/rest/v1/poulapp_access?'+query({select:'user_id',user_id:'eq.'+user,app_id:'eq.poulpoints'}));
  if(!access.length)return reply({error:'Access denied'},403);
  if(req.headers.get('content-type')?.startsWith('multipart/form-data')){
   if(Number(req.headers.get('content-length')??0)>10500000)return reply({error:'10 MiB maximum'},413);
   const form=await req.formData();const file=form.get('file');const task=form.get('task');
   if(!(file instanceof File)||typeof task!=='string'||task.length>128||file.size<1||file.size>10485760)return reply({error:'Invalid file (10 MiB maximum)'},400);
   const name=file.name.replace(/[\x00-\x1f/\\]/g,'_').slice(0,255)||'document';
   const row=await rpc('poulpoints_attachment_reserve',{owner_id:user,task,filename:name,bytes:file.size});
   try{
    const uploaded=await fetch(base+'/storage/v1/object/'+bucket+'/'+row.path,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/octet-stream','Cache-Control':'no-store'},body:await file.arrayBuffer(),signal:AbortSignal.timeout(90000)});
    if(!uploaded.ok)throw new Error('Upload failed');
    if(!await rpc('poulpoints_attachment_ready',{attachment_id:row.id,owner_id:user}))throw new Error('Task already completed');
    return reply({id:row.id,name,size:row.size});
   }catch(e){await api('/rest/v1/poulpoints_attachments?'+query({id:'eq.'+row.id,user_id:'eq.'+user}),'PATCH',{deleted_at:new Date().toISOString()});throw e;}
  }
  const body=await req.json();
  if(typeof body.task!=='string'||body.task.length>128)return reply({error:'Invalid task'},400);
  const tasks=await api('/rest/v1/poulpoints_task_records?'+query({select:'payload,deleted',user_id:'eq.'+user,task_id:'eq.'+body.task}));
  if(!tasks.length||tasks[0].deleted||tasks[0].payload.done)return reply({items:[]});
  const rows=await api('/rest/v1/poulpoints_attachments?'+query({select:'id,name,size,path',user_id:'eq.'+user,task_id:'eq.'+body.task,cycle:'eq.'+(tasks[0].payload.attachmentCycle??0),ready:'eq.true',deleted_at:'is.null',order:'created_at.asc'}));
  if(body.action==='list')return reply({items:rows.map(({id,name,size}:any)=>({id,name,size}))});
  const row=rows.find((a:any)=>a.id===body.id);if(!row)return reply({error:'Not found'},404);
  if(body.action==='remove'){
   await api('/rest/v1/poulpoints_attachments?'+query({id:'eq.'+row.id,user_id:'eq.'+user}),'PATCH',{deleted_at:new Date().toISOString()});
   try{await remove(row.path);}catch{/* Cron retries. */}return reply({ok:true});
  }
  if(body.action==='open'){
   const signed=await api('/storage/v1/object/sign/'+bucket+'/'+row.path,'POST',{expiresIn:30});
   return reply({url:base+'/storage/v1'+signed.signedURL+'&download='+encodeURIComponent(row.name)});
  }
  return reply({error:'Unknown action'},400);
 }catch{return reply({error:'Action impossible. Vérifiez la connexion, la synchronisation et les limites (10 fichiers par tâche, 100 Mo par compte).'},400);}
});

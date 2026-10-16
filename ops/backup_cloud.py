#!/usr/bin/env python3
"""Encrypted PostgreSQL + Poulpoints Storage snapshot. Never prints credentials."""
import argparse, hashlib, json, os, pathlib, subprocess, tarfile, tempfile, urllib.request, urllib.parse

def api(config, path, payload=None):
    request = urllib.request.Request(config['supabase_url'].rstrip('/') + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'apikey': config['service_role_key'], 'Authorization': 'Bearer '+config['service_role_key'], 'Content-Type':'application/json'})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()

def objects(config, prefix=''):
    offset=0
    while True:
        page=json.loads(api(config,'/storage/v1/object/list/poulpoints-attachments',{'prefix':prefix,'limit':100,'offset':offset,'sortBy':{'column':'name','order':'asc'}}))
        for item in page:
            name=(prefix+'/' if prefix else '')+item['name']
            if item.get('id') is None:
                yield from objects(config,name)
            else:
                yield {'name':name,'id':item['id'],'updated_at':item.get('updated_at'),'size':item.get('metadata',{}).get('size')}
        if len(page)<100: return
        offset+=len(page)

def run(config_path):
    config=json.loads(config_path.read_text())
    if config_path.stat().st_mode & 0o077: raise RuntimeError('Configuration must be private (chmod 600)')
    if 'A_RENSEIGNER' in json.dumps(config): raise RuntimeError('Configuration incomplete')
    if not config['supabase_url'].startswith('https://'): raise RuntimeError('HTTPS required')
    destination=pathlib.Path(config['destination']);destination.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    for key,value in config['postgres'].items(): env['PG'+key.upper()]=str(value)
    env['PGCONNECT_TIMEOUT']='20'
    with tempfile.TemporaryDirectory(prefix='poulpoints-backup-') as temporary:
        stage=pathlib.Path(temporary);os.chmod(stage,0o700)
        before=sorted(objects(config),key=lambda o:o['name'])
        subprocess.run(['pg_dump','--format=custom','--no-owner','--file',str(stage/'database.dump')],env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        subprocess.run(['pg_restore','--list',str(stage/'database.dump')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        entries=[]
        for item in before:
            data=api(config,'/storage/v1/object/authenticated/poulpoints-attachments/'+urllib.parse.quote(item['name'],safe='/'))
            digest=hashlib.sha256(data).hexdigest();target=stage/'objects'/digest;target.parent.mkdir(exist_ok=True);target.write_bytes(data)
            entries.append({**item,'sha256':digest,'bytes':len(data),'file':'objects/'+digest})
        after=sorted(objects(config),key=lambda o:o['name'])
        if before!=after: raise RuntimeError('Storage changed during backup; retry when idle')
        manifest={'format':1,'scope':'Full project PostgreSQL dump; Poulpoints attachment bucket only','objects':entries,'database_sha256':hashlib.sha256((stage/'database.dump').read_bytes()).hexdigest()}
        (stage/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        archive=stage/'payload.tar'
        with tarfile.open(archive,'w') as output:
            for name in ['database.dump','manifest.json','objects']:
                if (stage/name).exists(): output.add(stage/name,arcname=name)
        # Only encrypted bytes ever reach the synchronized folder.
        from datetime import datetime, timezone
        name='Poulpoints-cloud-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'.tar.gpg'
        partial=destination/(name+'.partial');final=destination/name
        try:
            subprocess.run(['gpg','--batch','--pinentry-mode','loopback','--passphrase-file',config['passphrase_file'],'--symmetric','--cipher-algo','AES256','--output',str(partial),str(archive)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            partial.chmod(0o600)
            # Verify full decryption before publishing the completed file.
            restored=stage/'verified.tar'
            subprocess.run(['gpg','--batch','--pinentry-mode','loopback','--passphrase-file',config['passphrase_file'],'--output',str(restored),'--decrypt',str(partial)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            if hashlib.sha256(restored.read_bytes()).digest()!=hashlib.sha256(archive.read_bytes()).digest(): raise RuntimeError('Encryption verification failed')
            partial.rename(final)
            (destination/(name+'.sha256')).write_text(hashlib.sha256(final.read_bytes()).hexdigest()+'  '+name+'\n')
            print('Backup complete and decryption verified:',final.name, 'attachments:',len(entries))
        finally:
            partial.unlink(missing_ok=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--config',type=pathlib.Path,required=True);args=parser.parse_args()
    try: run(args.config)
    except Exception as exc:
        # HTTP errors and command exceptions may carry private connection details.
        print('Backup failed ('+type(exc).__name__+'). Check private configuration, connectivity and permissions. No backup was marked complete.')
        raise SystemExit(1)

#!/usr/bin/env python3
"""Decrypt and restore ONLY Poulpoints tables into a disposable local database."""
import argparse, hashlib, io, json, os, pathlib, subprocess, tarfile, tempfile

def verify(archive, passphrase, source):
    with tempfile.TemporaryDirectory(prefix='poulpoints-restore-') as temporary:
        root=pathlib.Path(temporary);os.chmod(root,0o700);tar=root/'backup.tar'
        subprocess.run(['gpg','--batch','--pinentry-mode','loopback','--passphrase-file',str(passphrase),'--output',str(tar),'--decrypt',str(archive)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        with tarfile.open(tar) as data:
            for entry in data.getmembers():
                if entry.issym() or entry.islnk() or pathlib.PurePosixPath(entry.name).is_absolute() or '..' in pathlib.PurePosixPath(entry.name).parts: raise ValueError('Unsafe archive')
            data.extractall(root/'payload',filter='data')
        payload=root/'payload';manifest=json.loads((payload/'manifest.json').read_text())
        if hashlib.sha256((payload/'database.dump').read_bytes()).hexdigest()!=manifest['database_sha256']:raise ValueError('Database checksum')
        for item in manifest['objects']:
            # Derive the file path from validated hex, never trust archive manifest paths.
            digest=item['sha256']
            if len(digest)!=64 or any(c not in '0123456789abcdef' for c in digest):raise ValueError('Invalid checksum')
            content=(payload/'objects'/digest).read_bytes()
            if hashlib.sha256(content).hexdigest()!=digest or len(content)!=item['bytes']:raise ValueError('Object checksum')
        env={k:v for k,v in os.environ.items() if not k.startswith('PG')};socket=root/'socket';socket.mkdir()
        env.update(PGHOST=str(socket),PGPORT='55449',PGUSER=os.environ['USER'],PGDATABASE='poulpoints_restore')
        def command(args,**kw): return subprocess.run(args,env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kw)
        command(['initdb','-D',str(root/'db'),'--auth=trust'])
        command(['pg_ctl','-D',str(root/'db'),'-l',str(root/'pg.log'),'-o',f"-k {socket} -p 55449 -h ''",'start'])
        try:
            command(['createdb','poulpoints_restore'])
            sql="create role anon; create role authenticated; create role service_role bypassrls; create schema auth; create table auth.users(id uuid primary key); create function auth.uid() returns uuid language sql as $$select null::uuid$$; create schema storage; create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint);"
            command(['psql','-X','-v','ON_ERROR_STOP=1'],input=sql.encode())
            for name in ['001_poulapp_access.sql','002_poulpoints_tables.sql','20261016113643_task_attachments.sql']:
                command(['psql','-X','-v','ON_ERROR_STOP=1','-f',str(source/'supabase/migrations'/name)])
            args=['pg_restore','--exit-on-error','--no-owner','--no-acl','--data-only','--disable-triggers','--dbname=poulpoints_restore']
            for table in ['poulpoints_task_records','poulpoints_project_records','poulpoints_attachments']:args+=['--table',table]
            command(args+[str(payload/'database.dump')])
            # Read every restored file and compare to attachment references; no production writes.
            result=command(['psql','-X','-At','-c',"select path from public.poulpoints_attachments where ready and deleted_at is null"]).stdout.decode().splitlines()
            names={o['name'] for o in manifest['objects']}
            if not set(result).issubset(names):raise ValueError('Active attachment missing in backup')
            print('PASS: local database restored; all active attachments present; every object checksum verified. No production database changed.')
        finally: command(['pg_ctl','-D',str(root/'db'),'stop','-m','fast'])

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('archive',type=pathlib.Path);p.add_argument('--passphrase-file',required=True,type=pathlib.Path);a=p.parse_args()
    try:verify(a.archive,a.passphrase_file,pathlib.Path(__file__).resolve().parent.parent)
    except Exception as e:
        print('Verification failed ('+type(e).__name__+'). Production was not restored or modified.');raise SystemExit(1)

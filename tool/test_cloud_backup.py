"""Run against a disposable database from test_attachments_database.sh only."""
import importlib.util, json, os, pathlib, secrets, tempfile
root=pathlib.Path(__file__).resolve().parent.parent

def load(name):
 spec=importlib.util.spec_from_file_location(name,root/'ops'/f'{name}.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

backup=load('backup_cloud');verify=load('verify_cloud_backup')
# Never read production credentials. The test uses only fixture connection variables.
assert os.environ['PGDATABASE']=='poulpoints_fixture'
content=b'Poulpoints fictional attachment for restoration test.\n'
item={'name':'fixture/document.txt','id':'fixture-object','updated_at':'2026-10-16T00:00:00Z','metadata':{'size':len(content)}}
def fake_api(config,path,payload=None):
 if '/object/list/' in path:return json.dumps([item] if payload['offset']==0 else []).encode()
 return content
backup.api=fake_api
with tempfile.TemporaryDirectory() as folder:
 p=pathlib.Path(folder);key=p/'key';key.write_text(secrets.token_urlsafe(40));key.chmod(0o600)
 config=p/'config.json';config.write_text(json.dumps({'postgres':{'host':os.environ['PGHOST'],'port':int(os.environ['PGPORT']),'user':os.environ['PGUSER'],'database':'poulpoints_fixture'},'supabase_url':'https://fixture.invalid','service_role_key':'fixture','destination':str(p/'encrypted'),'passphrase_file':str(key)}));config.chmod(0o600)
 backup.run(config)
 archive=next((p/'encrypted').glob('*.gpg'));verify.verify(archive,key,root)
 print('PASS: encrypted database + file backup and isolated restore fixture.')

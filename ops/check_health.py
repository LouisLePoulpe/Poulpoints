#!/usr/bin/env python3
"""Write aggregate health status; exit nonzero for actionable issues."""
import argparse,json,os,pathlib,subprocess,datetime
p=argparse.ArgumentParser();p.add_argument('--config',required=True,type=pathlib.Path);a=p.parse_args()
try:
 c=json.loads(a.config.read_text());env=os.environ.copy()
 for key,value in c['postgres'].items():env['PG'+key.upper()]=str(value)
 env['PGCONNECT_TIMEOUT']='20'
 r=subprocess.run(['psql','-X','-At','-v','ON_ERROR_STOP=1','-f',str(pathlib.Path(__file__).with_name('cloud_health.sql'))],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 status=json.loads(next(line for line in r.stdout.decode().splitlines() if line.startswith('{')))
 alerts=[]
 if status['database_bytes']>400_000_000:alerts.append('Database above 400 MB warning threshold')
 if status['attachment_bytes']>800_000_000:alerts.append('Attachments above 800 MB warning threshold')
 if status['overdue_deletions']:alerts.append('Attachment cleanup overdue')
 if status['failed_cleanup_last_hour']:alerts.append('Attachment cleanup job failed')
 files=list(pathlib.Path(c['destination']).glob('Poulpoints-cloud-*.tar.gpg'))
 latest=max((f.stat().st_mtime for f in files),default=0)
 if datetime.datetime.now().timestamp()-latest>172800:alerts.append('No completed backup in the last 48 hours')
 status['alerts']=alerts
 target=a.config.with_name('health.json');target.write_text(json.dumps(status,indent=2)+'\n');target.chmod(0o600)
 print('Poulpoints health: '+('; '.join(alerts) if alerts else 'OK'))
 raise SystemExit(1 if alerts else 0)
except Exception as e:
 print('Poulpoints health check unavailable ('+type(e).__name__+').');raise SystemExit(1)

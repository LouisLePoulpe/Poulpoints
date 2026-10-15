import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import helper

class CompanionTests(unittest.TestCase):
    def test_multiple_reminders_and_snooze_are_independent(self):
        task={'id':'a','remindAt':1000,'remindAts':[1000,2000,3000]}
        calls=[]
        first=helper.notify_due({'tasks':[task]},set(),1500,lambda t:calls.append(t['remindAt']) or True)
        second=helper.notify_due({'tasks':[task]},first,3500,lambda t:calls.append(t['remindAt']) or True)
        self.assertEqual(calls,[1000,2000,3000])
        self.assertEqual(len(second),3)
    def test_background_launch_does_not_request_a_window(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(helper,'ROOT',Path(folder)), patch('helper.subprocess.Popen') as spawn:
            (Path(folder)/'launch.sh').touch()
            helper.launch(background=True)
            self.assertEqual(spawn.call_args.args[0], [str(Path(folder)/'launch.sh'),'--background'])
    def test_delivery_once_and_reschedule(self):
        task={'id':'a','title':'Titre','list':'Personnel','remindAt':1000}
        calls=[]
        notify=lambda t: calls.append(t['id']) or True
        first=helper.notify_due({'tasks':[task]},set(),2000,notify)
        self.assertEqual(calls,['a'])
        self.assertEqual(helper.notify_due({'tasks':[task]},first,3000,notify),first)
        self.assertEqual(calls,['a'])
        task['remindAt']=4000
        second=helper.notify_due({'tasks':[task]},first,4500,notify)
        self.assertEqual(second,{'a:4000'})
        self.assertEqual(calls,['a','a'])
    def test_failed_notification_retries_and_deleted_task_cancels(self):
        task={'id':'a','remindAt':1000}
        self.assertEqual(helper.notify_due({'tasks':[task]},set(),2000,lambda t:False),set())
        self.assertEqual(helper.notify_due({'tasks':[]},{'a:1000'},2000,lambda t:self.fail()),set())
        self.assertEqual(helper.notify_due({'tasks':[task]},set(),90000000,lambda t:self.fail()),set())
    def test_commands_are_durable_and_do_not_modify_projection(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(helper,'ROOT',Path(folder)):
            helper.atomic(Path(folder)/'snapshot.json',{'version':1,'tasks':[]})
            before=(Path(folder)/'snapshot.json').read_bytes()
            token=helper.enqueue('complete',{'id':'quote";$(touch unsafe)','revision':'42'})
            command=json.loads((Path(folder)/'commands'/(token+'.json')).read_text())
            self.assertEqual(command['revision'],'42')
            self.assertEqual((Path(folder)/'snapshot.json').read_bytes(),before)
            self.assertEqual((Path(folder)/'commands'/(token+'.json')).stat().st_mode & 0o777,0o600)
    def test_no_shell_interpretation_or_option_injection(self):
        with patch('helper.subprocess.run') as run:
            run.return_value.returncode=0
            self.assertTrue(helper.notify({'title':'--help $(touch unsafe)','list':'<b>Personnel</b>'}))
            args=run.call_args.args[0]
            self.assertIn('--',args)
            self.assertEqual(args[-1],'&lt;b&gt;Personnel&lt;/b&gt;')
            self.assertNotIn('shell',run.call_args.kwargs)
    def test_empty_first_launch_and_reject_invalid_command(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(helper,'ROOT',Path(folder)):
            self.assertEqual(helper.read_snapshot()['tasks'],[])
            with self.assertRaises(ValueError):helper.enqueue('delete')
            with self.assertRaises(ValueError):helper.enqueue('complete',{'id':1,'revision':0})

if __name__=='__main__':unittest.main()

import unittest
from server import merge


def t(id, rev, title='A'):
    return {'id': id, 'updatedAt': rev, 'title': title}


class MergeTests(unittest.TestCase):
    def test_merges_changes_from_both_devices(self):
        value = merge({'tasks': [t('a', 10)], 'projects': ['One'], 'deleted': {}},
                      {'tasks': [t('b', 20)], 'projects': ['Two'], 'deleted': {}})
        self.assertEqual([x['id'] for x in value['tasks']], ['a', 'b'])
        self.assertEqual(value['projects'], ['One', 'Two'])

    def test_task_metadata_survives_sync(self):
        task = dict(t('a', 30), priority=True, location='Gare de Lyon',
                    recurrence='custom', recurrenceRule={'unit': 'weekly', 'interval': 2, 'days': [1, 2], 'monthDay': 1, 'ordinal': 1, 'weekday': 6, 'monthMode': 'date'}, dueDate='2026-10-15T14:35:00.000',
                    hasDueTime=True, subtasks=[{'id': 's', 'title': 'Billet', 'done': False}])
        value = merge({'tasks': [], 'deleted': {}, 'projects': []},
                      {'tasks': [task], 'deleted': {}, 'projects': []})
        self.assertEqual(value['tasks'][0], task)

    def test_newer_version_wins(self):
        value = merge({'tasks': [t('a', 20, 'new')], 'deleted': {}, 'projects': []},
                      {'tasks': [t('a', 10, 'old')], 'deleted': {}, 'projects': []})
        self.assertEqual(value['tasks'][0]['title'], 'new')

    def test_deletion_prevents_resurrection(self):
        value = merge({'tasks': [], 'deleted': {'a': 30}, 'projects': []},
                      {'tasks': [t('a', 20)], 'deleted': {}, 'projects': []})
        self.assertFalse(value['tasks'])


if __name__ == '__main__':
    unittest.main()

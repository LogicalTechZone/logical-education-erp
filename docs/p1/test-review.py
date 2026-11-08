"""Regression tests for user-required P1 security rules; offline only."""
from pathlib import Path
import runpy
import unittest

validate = runpy.run_path(str(Path(__file__).with_name('check-review.py')))['validate']
SQL = Path(__file__).with_name('database-foundation.review.sql').read_text()


class P1ReviewRules(unittest.TestCase):
    def test_current_draft_passes(self):
        self.assertEqual(validate(SQL), 120)

    def test_no_service_role_table_or_sequence_privileges(self):
        for grant in ('GRANT SELECT ON public.tenants TO service_role;',
                      'GRANT SELECT (id) ON public.tenants TO service_role;',
                      'GRANT SELECT ON public.audit_logs TO service_role;',
                      'GRANT USAGE ON SEQUENCE public.audit_logs_id_seq TO service_role;'):
            with self.subTest(grant=grant), self.assertRaises(AssertionError):
                validate(SQL + '\n' + grant)

    def test_no_authenticated_insert_update_delete_truncate(self):
        for privilege in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'):
            with self.subTest(privilege=privilege), self.assertRaises(AssertionError):
                validate(SQL.replace('GRANT SELECT ON public.tenants TO authenticated;', f'GRANT {privilege} ON public.tenants TO authenticated;'))

    def test_all_12_tables_must_keep_rls_enabled(self):
        with self.assertRaises(AssertionError):
            validate(SQL.replace('ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;', ''))

    def test_zero_policies(self):
        with self.assertRaises(AssertionError):
            validate(SQL + '\nCREATE POLICY forbidden ON public.tenants FOR SELECT TO authenticated USING (true);')


if __name__ == '__main__':
    unittest.main()
"""Offline draft-rule tests only; never connects to or executes SQL."""
from pathlib import Path
import re
import unittest

SQL = Path(__file__).with_name('p3-registration-v2.review.sql').read_text()


def module_rows(sql):
    match = re.search(r'INSERT INTO public.registration_module_choices\(key,name,release_priority\) VALUES\s*(.*?);', sql, re.S)
    if match is None:
        return {}
    return dict((key, priority) for key, _, priority in re.findall(r"\('([^']+)','([^']+)','([^']+)'\)", match.group(1)))


class P3ReviewRules(unittest.TestCase):
    def test_platform_foundation_not_customer_selectable(self):
        self.assertNotIn('platform_foundation', module_rows(SQL))

    def test_commercial_console_not_customer_selectable(self):
        self.assertNotIn('saas_commercial_console', module_rows(SQL))

    def test_original_customer_priorities_preserved(self):
        self.assertEqual(module_rows(SQL), {
            'crm_admissions': 'P0', 'course_program_management': 'P0',
            'scheduling_booking': 'P0', 'learner_management': 'P0',
            'fees_payment_tracking': 'P0', 'attendance': 'P0',
            'operational_dashboards': 'P0', 'notifications': 'P1',
            'assessment_certificates': 'P1', 'corporate_training': 'P1',
            'customer_support': 'P1', 'accounting': 'P2',
            'hr_payroll': 'P2; localization required',
            'procurement_inventory': 'P2', 'advanced_analytics': 'P2',
            'ai_channel_automation': 'P1/P2 by integration readiness',
        })

    def test_no_application_registration_execution(self):
        self.assertEqual(re.findall(r'^GRANT EXECUTE[^;]*;', SQL, re.M), [])
        command = SQL.split('CREATE FUNCTION public.create_organization(', 1)[1].split('$create$;', 1)[0]
        self.assertLess(command.index("RAISE EXCEPTION 'REGISTRATION_NOT_AUTHORIZED'"), command.index('INSERT INTO public.profiles'))

    def test_no_legacy_country_currency_arrays(self):
        self.assertNotRegex(SQL, r'p_(?:country|currency)\s*=\s*ANY\s*\(ARRAY')
        self.assertEqual(re.findall(r'^INSERT INTO public.registration_(?:country|currency)_codes', SQL, re.M), [])
        self.assertIn("c.classification='active_business_currency'", SQL)

    def test_preserve_p1_p2_objects(self):
        statements = re.findall(r'^(?:CREATE(?: OR REPLACE)?|ALTER|DROP)\s+(?:TABLE|FUNCTION|POLICY|TRIGGER)\s+([^\s(]+)', SQL, re.M)
        self.assertFalse(any(name.startswith(('public.p1_', 'public.p2_')) for name in statements))
        self.assertEqual(re.findall(r'^ALTER TABLE public\.(tenants|profiles|memberships|roles|audit_logs)\b', SQL, re.M), [])

    def test_no_client_or_service_dml_grants(self):
        self.assertEqual(re.findall(r'^GRANT\s+(?:ALL|INSERT|UPDATE|DELETE|TRUNCATE)\b[^;]*;', SQL, re.M), [])
        self.assertEqual(re.findall(r'^GRANT[^;]*\bTO\s+service_role\b[^;]*;', SQL, re.M), [])


if __name__ == '__main__':
    unittest.main()
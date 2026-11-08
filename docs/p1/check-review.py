"""Static review only: never connects to or mutates any database.
Requires pglast on PYTHONPATH; run from project root.
"""
from pathlib import Path
import re
from pglast import parse_sql

sql = Path('docs/p1/database-foundation.review.sql').read_text()
statements = len(parse_sql(sql))
tables = re.findall(r'^CREATE TABLE public\.(\w+)', sql, re.M)
assert len(tables) == 12
assert sql.count('ENABLE ROW LEVEL SECURITY') == 12
assert not re.search(r'^CREATE POLICY', sql, re.M)
for table in tables:
    create = sql.index('CREATE TABLE public.' + table + ' (')
    revoke = sql.index('REVOKE ALL ON public.' + table + ' FROM PUBLIC, anon, authenticated, service_role;', create)
    grant = sql.index('GRANT SELECT', revoke)
    rls = sql.index('ALTER TABLE public.' + table + ' ENABLE ROW LEVEL SECURITY;', grant)
    assert create < revoke < grant < rls
# Parse grants across lines; reject broad grants and any application DML.
grants = re.findall(r'^GRANT\s+.*?;', sql, re.M | re.S)
assert not any(re.search(r'\b(ALL|INSERT|UPDATE|DELETE|TRUNCATE|REFERENCES|TRIGGER|EXECUTE|USAGE)\b', g) for g in grants)
service = [g for g in grants if 'TO service_role;' in g]
assert len(service) == 2
expected = 'GRANT SELECT (id, name, slug, country, timezone, default_currency, contact_email, contact_phone, status, created_at, updated_at) ON public.tenants TO service_role;'
assert ' '.join(service[0].split()) == expected
assert ' '.join(service[1].split()) == 'GRANT SELECT ON public.audit_logs TO service_role;'
assert not any('SEQUENCE' in g or 'FUNCTION' in g for g in grants)
functions = re.findall(r'^CREATE FUNCTION public\.(\w+)\(\)', sql, re.M)
assert len(functions) == 4
for function in functions:
    assert f'REVOKE ALL ON FUNCTION public.{function}() FROM PUBLIC, anon, authenticated, service_role;' in sql
assert sql.count('SECURITY DEFINER') == 1
assert sql.count("SET search_path = ''") == 4
invite = sql.split('CREATE TABLE public.invitations (', 1)[1].split('CREATE TABLE public.invitation_branches (', 1)[0]
assert not re.search(r'\binvited_by\b', re.sub(r'--[^\n]*', '', invite))
assert 'FOREIGN KEY (tenant_id, inviter_membership_id)' in invite
assert 'REFERENCES public.memberships(tenant_id, id) ON DELETE RESTRICT' in invite
assert "'token_hash','inviter_membership_id'" in sql
assert 'created_by uuid NOT NULL,' in sql
assert 'user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT' in sql
assert 'id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE' in sql
assert "installed_schema <> 'extensions'" in sql
assert 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;' in sql
assert 'ALTER EXTENSION' not in sql
assert len(re.findall(r'^CREATE INDEX ', sql, re.M)) == 16
assert len(re.findall(r'^CREATE UNIQUE INDEX ', sql, re.M)) == 2
assert re.findall(r'^INSERT INTO public\.(\w+)', sql, re.M) == ['roles', 'permissions', 'role_permissions']
print(f'PASS: PostgreSQL outer SQL grammar ({statements} statements).')
print('PASS: 12 tables, grants/revokes before RLS, zero policies, 16 indexes + 2 partial unique indexes.')
print('PASS: no broad/DML/sequence/function grants; exactly 2 least-privilege service SELECT grants.')
print('PASS: 4 trigger EXECUTE revocations include service_role; 1 fixed-path definer routine.')
print('PASS: canonical inviter, same-tenant FK, historical creator and restrictive deletion chain.')
print('PASS: citext placement guard and extensions-qualified types; no extension relocation.')
print('PASS: only the 3 approved catalog INSERT statements; no business/admin seeds.')
print('NOT RUN: PL/pgSQL compilation/runtime, migration, live ACL/RLS/FK/trigger behavior, account deletion, Owner concurrency, invitation authorization, Auth or deployment tests.')

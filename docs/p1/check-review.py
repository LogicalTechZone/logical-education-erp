"""Offline draft checks only; never connects to a database. Requires pglast.

Run: PYTHONPATH=/tmp/p1-review-deps python3 docs/p1/check-review.py
Optional argument: another SQL draft to validate (used for regression checks).
"""
from pathlib import Path
import re
import sys
from pglast import parse_sql


def validate(sql):
    parsed = parse_sql(sql)
    tables = re.findall(r'^CREATE TABLE public\.(\w+)', sql, re.M)
    assert len(tables) == 12 and len(set(tables)) == 12, 'Expected exactly 12 unique tables'
    assert sql.count('ENABLE ROW LEVEL SECURITY') == 12, 'Expected 12 RLS enablements'
    assert not any(type(r.stmt).__name__ == 'CreatePolicyStmt' for r in parsed), 'P1 must have zero policies'
    grants = [r.stmt for r in parsed if type(r.stmt).__name__ == 'GrantStmt' and r.stmt.is_grant]
    assert len(grants) == 12, 'Expected exactly 12 authenticated SELECT grants'
    granted_tables = []
    for grant in grants:
        grantees = [g.rolename for g in grant.grantees]
        assert grantees == ['authenticated'], 'Only authenticated may receive P1 grants; no service_role or PUBLIC grants'
        assert grant.objtype.name == 'OBJECT_TABLE', 'No sequence/function/other object grants'
        assert not grant.grant_option, 'No grant option'
        assert grant.privileges and all(p.priv_name.lower() == 'select' for p in grant.privileges), 'Only SELECT allowed; no authenticated DML/TRUNCATE or ALL'
        assert len(grant.objects) == 1, 'One explicit table per grant'
        obj = grant.objects[0]
        assert obj.schemaname == 'public' and obj.relname in tables, 'Grant must target a P1 table'
        granted_tables.append(obj.relname)
        columns = [c.sval for p in grant.privileges for c in (p.cols or ())]
        if obj.relname == 'invitations':
            assert columns == ['id', 'tenant_id', 'email', 'role_id', 'status', 'inviter_membership_id', 'expires_at', 'accepted_by', 'accepted_at', 'created_at', 'updated_at'], 'Invitation safe projection must exclude token_hash'
        else:
            assert not columns, 'Other authenticated SELECT grants are table-level'
    assert sorted(granted_tables) == sorted(tables), 'Exactly one SELECT grant per table'
    for table in tables:
        create = sql.index('CREATE TABLE public.' + table + ' (')
        revoke = sql.index('REVOKE ALL ON public.' + table + ' FROM PUBLIC, anon, authenticated, service_role;', create)
        grant = next(r for r in parsed if type(r.stmt).__name__ == 'GrantStmt' and r.stmt.is_grant and r.stmt.objects[0].relname == table)
        rls = sql.index('ALTER TABLE public.' + table + ' ENABLE ROW LEVEL SECURITY;', create)
        assert create < revoke < grant.stmt_location < rls, 'CREATE / REVOKE / GRANT / RLS order required'
    assert 'REVOKE ALL ON SEQUENCE public.audit_logs_id_seq FROM PUBLIC, anon, authenticated, service_role;' in sql, 'Identity sequence must revoke all client/service privileges'
    assert not any(type(r.stmt).__name__ in ('AlterDefaultPrivilegesStmt', 'GrantRoleStmt', 'AlterOwnerStmt') for r in parsed), 'No default privilege, role membership or ownership changes'
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
    return len(parsed)


if __name__ == '__main__':
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('docs/p1/database-foundation.review.sql')
    statements = validate(path.read_text())
    print(f'PASS: PostgreSQL outer SQL grammar ({statements} statements).')
    print('PASS: exactly 12 unique tables, explicit revocations and authenticated SELECT before 12 RLS enablements; zero policies.')
    print('PASS: no service_role grants on tables, columns, sequences, functions or other objects; all 12 table ACLs and audit sequence explicitly revoked.')
    print('PASS: exactly 12 authenticated SELECT grants; no INSERT, UPDATE, DELETE, TRUNCATE, ALL, REFERENCES, TRIGGER, EXECUTE, USAGE or grant option.')
    print('PASS: invitation projection excludes token_hash; no role membership, ownership or default privilege changes.')
    print('PASS: 4 trigger EXECUTE revocations include service_role; 1 fixed-path definer routine.')
    print('PASS: canonical inviter, same-tenant FK, historical creator and restrictive deletion chain.')
    print('PASS: citext placement guard; 16 indexes + 2 partial unique indexes; only 3 catalog INSERT statements.')
    print('NOT RUN: PL/pgSQL compilation/runtime, migration, live ACL/RLS/FK/trigger behavior, account deletion, Owner concurrency, invitation authorization, Auth or deployment tests.')
-- UNAPPLIED P3 REVIEW V2: Logical Education ERP; Dev ojozmvvdpjmvsxmpgrul only.
-- NOT APPROVED FOR EXECUTION OR EXPOSURE. No changes to P1/P2 objects.
-- V1 SHA256: 1ad7cc88a4e89359e5544a4b25fc08f8615e3ef8596a5799d47c705bbd652d6d.
-- Earlier organization draft SHA256: 8c3cdea4674e989bbee86df0a0d06a0c072b9f68e678de18ad432168f80401c9.
-- Both originals are unchanged. This complete draft is deliberately non-operational.
-- COMMAND HARD GATE: unconditional denial plus NO application EXECUTE grant.
-- Owner must separately decide pilot/public boundary, Enterprise provisioning,
-- pending operational access, profile amendment, code-source scope and S08.
-- The retained active-workspace body is ONLY an unreachable alternative for review,
-- not a selection of that alternative. Inquiry-only/no-operational-access choices
-- require a subsequent version; they cannot be implemented by granting EXECUTE.
-- Six additive tables: four request tables and two controlled code catalogues.
-- No competing profile, tenant, membership, subscription or entitlement model.
-- Codes deliberately have NO seeds: source/release/curation not yet approved.
-- Country: propose versioned ISO 3166-1 alpha-2 release from approved publisher.
-- Currency: propose SIX ISO 4217 current currency & funds publication, curated
-- to approved active business currencies; historic/metal/test/special-unit/fund
-- exclusions require documented classification, not alphabetic-code format alone.
-- Each reviewed code row requires source_name/source_version/source_sha256,
-- and source_url; retire through reviewed maintenance, never rewrite tenant history.
-- No approved reusable catalogue found in supplied dictionary/P1/P2 source files;
-- this is not a fresh live-database discovery. Recheck before authorizing creation.
-- Exact input bounds retained from V1 remain proposed technical review values.
-- Execute only via separately evidenced one-transaction runner; no runner guarantee
-- follows from this file. BEGIN/COMMIT deliberately omitted for runner ownership.
-- Preflight uses read-only catalog comparisons; it does not simulate trigger behavior.
-- Abort on drift, do not auto-fix. Isolation/runtime/runner tests NOT EXECUTED.

SET LOCAL search_path = pg_catalog, public, extensions;

DO $preflight$
DECLARE r record; v_oid oid; v_cols text[]; v_role text; v_priv text;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'Reviewed postgres session and execution identity required';
  END IF;
  IF pg_catalog.current_setting('session_replication_role') <> 'origin' THEN
    RAISE EXCEPTION 'Ordinary trigger execution required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='citext' AND n.nspname='extensions') THEN
    RAISE EXCEPTION 'Installed extensions.citext required; no extension mutation here';
  END IF;
  IF pg_catalog.to_regprocedure('auth.uid()') IS NULL OR pg_catalog.to_regprocedure('pg_catalog.gen_random_uuid()') IS NULL THEN
    RAISE EXCEPTION 'Auth/UUID dependency missing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname='create_organization' OR p.proname LIKE 'p3_%')) THEN
    RAISE EXCEPTION 'Existing P3 command/helper needs separate reconciliation';
  END IF;
  FOR r IN SELECT x AS name FROM pg_catalog.unnest(ARRAY['registration_package_choices','registration_module_choices','organization_registrations','organization_registration_modules','registration_country_codes','registration_currency_codes']) x LOOP
    IF pg_catalog.to_regclass('public.'||r.name) IS NOT NULL THEN RAISE EXCEPTION 'New-name conflict: %',r.name; END IF;
  END LOOP;
  -- All twelve dependency tables: RLS/ownership plus no unexpected app DML.
  FOR r IN SELECT c.*,n.nspname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=ANY(ARRAY['tenants','branches','profiles','roles','permissions','role_permissions','memberships','membership_branches','invitations','invitation_branches','audit_logs','platform_admins']) LOOP
    IF r.relkind<>'r' OR NOT r.relrowsecurity OR r.relforcerowsecurity OR pg_catalog.pg_get_userbyid(r.relowner)<>'postgres' THEN RAISE EXCEPTION 'Foundation ownership/RLS drift: %',r.relname; END IF;
    FOREACH v_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      FOREACH v_priv IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
        IF pg_catalog.has_table_privilege(v_role,r.oid,v_priv) THEN RAISE EXCEPTION 'Effective forbidden table grant: %.% %',v_role,r.relname,v_priv; END IF;
      END LOOP;
      IF pg_catalog.has_any_column_privilege(v_role,r.oid,'INSERT') OR pg_catalog.has_any_column_privilege(v_role,r.oid,'UPDATE') OR pg_catalog.has_any_column_privilege(v_role,r.oid,'REFERENCES') THEN RAISE EXCEPTION 'Forbidden column write grant'; END IF;
      IF v_role IN ('anon','service_role') AND pg_catalog.has_any_column_privilege(v_role,r.oid,'SELECT') THEN RAISE EXCEPTION 'Forbidden baseline read grant'; END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(r.relacl,pg_catalog.acldefault('r',r.relowner))) a WHERE a.grantee=0) THEN RAISE EXCEPTION 'Unexpected PUBLIC baseline table grant'; END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=ANY(ARRAY['tenants','branches','profiles','roles','permissions','role_permissions','memberships','membership_branches','invitations','invitation_branches','audit_logs','platform_admins']))<>12 THEN RAISE EXCEPTION 'Missing baseline table'; END IF;
  -- Exact column types/nullability/default expressions for command write targets
  -- and authorization/audit dependencies. Extra required columns also fail.
  FOR r IN SELECT * FROM (VALUES
    ('tenants','id','uuid',true,'gen_random_uuid()'),
    ('tenants','name','text',true,NULL::text),
    ('tenants','slug','extensions.citext',true,NULL::text),
    ('tenants','country','character(2)',true,NULL::text),
    ('tenants','timezone','text',true,NULL::text),
    ('tenants','default_currency','character(3)',true,NULL::text),
    ('tenants','contact_email','extensions.citext',false,NULL::text),
    ('tenants','contact_phone','text',false,NULL::text),
    ('tenants','status','public.tenant_status',true,'''active''::tenant_status'),
    ('tenants','settings','jsonb',true,'''{}''::jsonb'),
    ('tenants','created_by','uuid',true,NULL::text),
    ('tenants','creation_key','uuid',true,NULL::text),
    ('tenants','active_owner_count','integer',true,'0'),
    ('tenants','created_at','timestamp with time zone',true,'now()'),
    ('tenants','updated_at','timestamp with time zone',true,'now()'),
    ('branches','id','uuid',true,'gen_random_uuid()'),
    ('branches','tenant_id','uuid',true,NULL::text),
    ('branches','name','text',true,NULL::text),
    ('branches','code','text',true,NULL::text),
    ('branches','address_line1','text',false,NULL::text),
    ('branches','address_line2','text',false,NULL::text),
    ('branches','city','text',false,NULL::text),
    ('branches','state','text',false,NULL::text),
    ('branches','postal_code','text',false,NULL::text),
    ('branches','country','character(2)',true,NULL::text),
    ('branches','phone','text',false,NULL::text),
    ('branches','email','extensions.citext',false,NULL::text),
    ('branches','timezone','text',true,NULL::text),
    ('branches','status','public.record_status',true,'''active''::record_status'),
    ('branches','created_at','timestamp with time zone',true,'now()'),
    ('branches','updated_at','timestamp with time zone',true,'now()'),
    ('profiles','id','uuid',true,NULL::text),
    ('profiles','full_name','text',false,NULL::text),
    ('profiles','avatar_url','text',false,NULL::text),
    ('profiles','phone','text',false,NULL::text),
    ('profiles','theme_preference','text',true,'''light''::text'),
    ('profiles','last_tenant_id','uuid',false,NULL::text),
    ('profiles','created_at','timestamp with time zone',true,'now()'),
    ('profiles','updated_at','timestamp with time zone',true,'now()'),
    ('roles','id','uuid',true,'gen_random_uuid()'),
    ('roles','tenant_id','uuid',false,NULL::text),
    ('roles','key','text',true,NULL::text),
    ('roles','name','text',true,NULL::text),
    ('roles','description','text',false,NULL::text),
    ('roles','scope','public.role_scope',true,NULL::text),
    ('roles','is_system','boolean',true,'false'),
    ('roles','rank','integer',true,NULL::text),
    ('roles','created_at','timestamp with time zone',true,'now()'),
    ('roles','updated_at','timestamp with time zone',true,'now()'),
    ('permissions','key','text',true,NULL::text),
    ('permissions','module','text',true,NULL::text),
    ('permissions','action','text',true,NULL::text),
    ('permissions','description','text',true,NULL::text),
    ('role_permissions','role_id','uuid',true,NULL::text),
    ('role_permissions','permission_key','text',true,NULL::text),
    ('memberships','id','uuid',true,'gen_random_uuid()'),
    ('memberships','tenant_id','uuid',true,NULL::text),
    ('memberships','user_id','uuid',true,NULL::text),
    ('memberships','role_id','uuid',true,NULL::text),
    ('memberships','status','public.membership_status',true,'''invited''::membership_status'),
    ('memberships','invited_by','uuid',false,NULL::text),
    ('memberships','joined_at','timestamp with time zone',false,NULL::text),
    ('memberships','created_at','timestamp with time zone',true,'now()'),
    ('memberships','updated_at','timestamp with time zone',true,'now()'),
    ('membership_branches','tenant_id','uuid',true,NULL::text),
    ('membership_branches','membership_id','uuid',true,NULL::text),
    ('membership_branches','branch_id','uuid',true,NULL::text),
    ('invitations','id','uuid',true,'gen_random_uuid()'),
    ('invitations','tenant_id','uuid',true,NULL::text),
    ('invitations','email','extensions.citext',true,NULL::text),
    ('invitations','role_id','uuid',true,NULL::text),
    ('invitations','token_hash','text',true,NULL::text),
    ('invitations','status','public.invitation_status',true,'''pending''::invitation_status'),
    ('invitations','inviter_membership_id','uuid',true,NULL::text),
    ('invitations','expires_at','timestamp with time zone',true,'(now() + ''7 days''::interval)'),
    ('invitations','accepted_by','uuid',false,NULL::text),
    ('invitations','accepted_at','timestamp with time zone',false,NULL::text),
    ('invitations','created_at','timestamp with time zone',true,'now()'),
    ('invitations','updated_at','timestamp with time zone',true,'now()'),
    ('invitation_branches','tenant_id','uuid',true,NULL::text),
    ('invitation_branches','invitation_id','uuid',true,NULL::text),
    ('invitation_branches','branch_id','uuid',true,NULL::text),
    ('audit_logs','id','bigint',true,NULL::text),
    ('audit_logs','tenant_id','uuid',false,NULL::text),
    ('audit_logs','actor_id','uuid',false,NULL::text),
    ('audit_logs','action','text',true,NULL::text),
    ('audit_logs','entity_type','text',true,NULL::text),
    ('audit_logs','entity_id','uuid',false,NULL::text),
    ('audit_logs','metadata','jsonb',true,'''{}''::jsonb'),
    ('audit_logs','ip','inet',false,NULL::text),
    ('audit_logs','created_at','timestamp with time zone',true,'now()'),
    ('platform_admins','user_id','uuid',true,NULL::text),
    ('platform_admins','granted_by','uuid',false,NULL::text),
    ('platform_admins','created_at','timestamp with time zone',true,'now()')
  ) e(tbl,col,typ,nn,def) LOOP
    v_oid:=pg_catalog.to_regclass('public.'||r.tbl);
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=v_oid AND a.attname=r.col AND NOT a.attisdropped AND a.atttypid=pg_catalog.to_regtype(r.typ) AND a.attnotnull=r.nn AND (r.typ NOT LIKE 'character(%)' OR pg_catalog.format_type(a.atttypid,a.atttypmod)=r.typ) AND (CASE WHEN d.oid IS NULL THEN NULL ELSE pg_catalog.pg_get_expr(d.adbin,d.adrelid) END) IS NOT DISTINCT FROM r.def) THEN RAISE EXCEPTION 'Column/type/default drift: %.%',r.tbl,r.col; END IF;
  END LOOP;
  FOR r IN SELECT * FROM (VALUES
    ('tenants',15),
    ('branches',16),
    ('profiles',8),
    ('roles',10),
    ('permissions',4),
    ('role_permissions',2),
    ('memberships',9),
    ('membership_branches',3),
    ('invitations',12),
    ('invitation_branches',3),
    ('audit_logs',9),
    ('platform_admins',3)
  ) e(tbl,cnt) LOOP
    IF (SELECT count(*) FROM pg_catalog.pg_attribute WHERE attrelid=pg_catalog.to_regclass('public.'||r.tbl) AND attnum>0 AND NOT attisdropped)<>r.cnt THEN RAISE EXCEPTION 'Unexpected baseline column: %',r.tbl; END IF;
  END LOOP;
  -- Managed Auth is read-only: verify the representations actually consumed.
  FOR r IN SELECT * FROM (VALUES ('id','uuid'),('email','character varying'),('email_confirmed_at','timestamp with time zone'),('deleted_at','timestamp with time zone'),('banned_until','timestamp with time zone'),('is_anonymous','boolean')) e(col,typ) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a WHERE a.attrelid='auth.users'::regclass AND a.attname=r.col AND NOT a.attisdropped AND pg_catalog.format_type(a.atttypid,a.atttypmod)=r.typ) THEN RAISE EXCEPTION 'Auth representation drift: %',r.col; END IF;
  END LOOP;
  -- Required immediate, valid uniqueness by columns, not trusted object names.
  FOR r IN SELECT * FROM (VALUES
    ('tenants',ARRAY['id']),('tenants',ARRAY['slug']),('tenants',ARRAY['creation_key']),
    ('profiles',ARRAY['id']),('memberships',ARRAY['id']),('memberships',ARRAY['tenant_id','user_id']),('memberships',ARRAY['tenant_id','id']),
    ('roles',ARRAY['id']),('roles',ARRAY['tenant_id','key']),('roles',ARRAY['tenant_id','id']),
    ('permissions',ARRAY['key']),('role_permissions',ARRAY['role_id','permission_key']),('audit_logs',ARRAY['id'])
  ) e(tbl,cols) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_index i WHERE i.indrelid=pg_catalog.to_regclass('public.'||r.tbl) AND i.indisunique AND i.indisvalid AND i.indisready AND i.indimmediate AND i.indpred IS NULL AND i.indexprs IS NULL AND i.indnkeyatts=pg_catalog.cardinality(r.cols) AND ARRAY(SELECT a.attname::text FROM pg_catalog.unnest(i.indkey::smallint[]) WITH ORDINALITY k(num,pos) JOIN pg_catalog.pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=k.num WHERE k.pos<=i.indnkeyatts ORDER BY k.pos)=r.cols) THEN RAISE EXCEPTION 'Required uniqueness missing: % %',r.tbl,r.cols; END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_index i WHERE i.indexrelid=pg_catalog.to_regclass('public.roles_system_key_unique') AND i.indrelid='public.roles'::regclass AND i.indisunique AND i.indisvalid AND i.indisready AND i.indimmediate AND i.indnkeyatts=1 AND pg_catalog.pg_get_expr(i.indpred,i.indrelid)='(tenant_id IS NULL)' AND (SELECT attname FROM pg_catalog.pg_attribute WHERE attrelid=i.indrelid AND attnum=i.indkey[0])='key') THEN RAISE EXCEPTION 'System role uniqueness drift'; END IF;
  FOR r IN SELECT * FROM (VALUES
    ('profiles','profiles_id_fkey','FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE'),
    ('profiles','profiles_last_tenant_id_fkey','FOREIGN KEY (last_tenant_id) REFERENCES tenants(id) ON DELETE SET NULL'),
    ('memberships','memberships_tenant_id_fkey','FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
    ('memberships','memberships_user_id_fkey','FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE RESTRICT'),
    ('memberships','memberships_role_id_fkey','FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT'),
    ('role_permissions','role_permissions_role_id_fkey','FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE'),
    ('role_permissions','role_permissions_permission_key_fkey','FOREIGN KEY (permission_key) REFERENCES permissions(key) ON DELETE RESTRICT'),
    ('audit_logs','audit_logs_tenant_id_fkey','FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT')
  ) e(tbl,nm,definition) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c WHERE c.conrelid=pg_catalog.to_regclass('public.'||r.tbl) AND c.conname=r.nm AND c.convalidated AND NOT c.condeferrable AND pg_catalog.pg_get_constraintdef(c.oid)=r.definition) THEN RAISE EXCEPTION 'FK drift: %',r.nm; END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute WHERE attrelid='public.audit_logs'::regclass AND attname='id' AND attidentity='a') OR pg_catalog.pg_get_serial_sequence('public.audit_logs','id') IS NULL THEN RAISE EXCEPTION 'Audit identity drift'; END IF;
  FOREACH v_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
    IF pg_catalog.has_sequence_privilege(v_role,pg_catalog.pg_get_serial_sequence('public.audit_logs','id'),'USAGE,SELECT,UPDATE') THEN RAISE EXCEPTION 'Forbidden audit sequence grant'; END IF;
  END LOOP;
  -- Functions: expected source fingerprints derived offline from the unchanged
  -- applied migration files, including the corrected Owner invariant. A source
  -- match is NOT runtime or race evidence. Do not auto-replace on mismatch.
  FOR r IN SELECT * FROM (VALUES
    ('p1_guard_identity()','trigger','plpgsql',false,'v','d43f4f0325f6916141187a20d93ef7db'),
    ('p1_validate_fields()','trigger','plpgsql',false,'v','949253d322315a81cc00ae07d3737e97'),
    ('p1_validate_role_assignment()','trigger','plpgsql',true,'v','9e88f53a0810b01f4229fad5abab8981'),
    ('p1_touch_updated_at()','trigger','plpgsql',false,'v','56215512bc036bab9a482fc8a6be5bff'),
    ('p2_private_user_is_verified(uuid)','boolean','sql',true,'s','04ec3d3a23c381ed87d3d5978ec21297'),
    ('p2_current_user_is_verified()','boolean','sql',true,'s','583f00b967707506ac02737aaf03177d'),
    ('p2_is_active_member(uuid)','boolean','sql',true,'s','2972c46b63d4f47e410af268a6a581f7'),
    ('p2_has_org_permission(uuid,text)','boolean','sql',true,'s','cadf70284fe24dc6f6f9ca945caadfd7'),
    ('p2_has_tenant_permission(uuid,text)','boolean','sql',true,'s','f88d945372e5ec4ddb29d62c9d32d2bd'),
    ('p2_has_branch_permission(uuid,uuid,text)','boolean','sql',true,'s','a2cecbf41f52430d777f212d22c94962'),
    ('p2_has_any_permission(text)','boolean','sql',true,'s','e55e8b1cd339788f61cfcf51f3682f6b'),
    ('p2_can_view_role(uuid)','boolean','plpgsql',true,'s','aef1c49d2d588aa4d28db47f9adbefc0'),
    ('p2_can_view_membership(uuid)','boolean','plpgsql',true,'s','03aee98401192afca318e126cf3c1aaa'),
    ('p2_can_view_invitation(uuid)','boolean','plpgsql',true,'s','13ce08f74c6a49e87ed90a6ecb6877a7'),
    ('p2_is_platform_admin()','boolean','sql',true,'s','3490fa758e8de18ece87c7e197c827f8'),
    ('p2_private_validate_membership_branches(uuid)','void','plpgsql',true,'s','335a1ea4edc76cfd299f4450519c1fdd'),
    ('p2_private_validate_invitation_branches(uuid,boolean)','void','plpgsql',true,'s','cb0650dc7b066e17c3d601b1a144f0fd'),
    ('p2_lock_branch_tenant()','trigger','plpgsql',true,'v','b0c3c6f8284de76d270c2594a222600e'),
    ('p2_guard_new_branch_link()','trigger','plpgsql',true,'v','b6002ac2f3f328ec0f3be3a102532f1e'),
    ('p2_validate_branch_sets()','trigger','plpgsql',true,'v','864c409afd3cb5917b7d208bddf7e1b1'),
    ('p2_prevent_last_owner_loss()','trigger','plpgsql',true,'v','dd8e0c6294ee23695d76a79c4c383354'),
    ('p2_sync_active_owner()','trigger','plpgsql',true,'v','8171889bd0a1b0b72efd84535438e94f'),
    ('p2_guard_owner_counter()','trigger','plpgsql',true,'v','27a8052a2ac71b8fadaa2a73b5a1afff'),
    ('p2_check_owner_invariant()','trigger','plpgsql',true,'v','edc5cd6ec2ffbb5b2c20859d50857494'),
    ('p2_append_audit(uuid,text,text,uuid,jsonb)','void','plpgsql',true,'v','cc4d40a260637e1f81a08f6ba8b18fa4'),
    ('p2_audit_tenant()','trigger','plpgsql',true,'v','32e0aab19b1adec03fc30f7fd7df444e'),
    ('p2_audit_branch()','trigger','plpgsql',true,'v','5fd953e934bcdeb514dab51008d8f1b9'),
    ('p2_audit_membership()','trigger','plpgsql',true,'v','0b10704746097358aa8851a885176332'),
    ('p2_audit_membership_branch()','trigger','plpgsql',true,'v','6851c65fcf3ff0a586b7e820988ca91c'),
    ('p2_audit_invitation()','trigger','plpgsql',true,'v','589ed558ace6f5c70869e10bd8ce8321'),
    ('p2_audit_invitation_branch()','trigger','plpgsql',true,'v','d4db5264e636ac779ead40febc8db6c0'),
    ('p2_guard_audit_immutable()','trigger','plpgsql',true,'v','5b6af4480591ab9eb743255d25c5c8ef'),
    ('p2_guard_audit_truncate()','trigger','plpgsql',true,'v','40b02c161cecb4dbfa613b473cb8488b'),
    ('p2_guard_system_catalog()','trigger','plpgsql',true,'v','4b49447e4660f881e2bc4f76a03c1106'),
    ('p2_guard_system_catalog_truncate()','trigger','plpgsql',true,'v','8244d7f159e4c2c91feddbca026c804c')
  ) e(sig,ret,lang,sec,vol,src_md5) LOOP
    v_oid:=pg_catalog.to_regprocedure('public.'||r.sig);
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_language l ON l.oid=p.prolang WHERE p.oid=v_oid AND pg_catalog.pg_get_userbyid(p.proowner)='postgres' AND p.prorettype=pg_catalog.to_regtype(r.ret) AND l.lanname=r.lang AND p.prosecdef=r.sec AND p.provolatile::text=r.vol AND p.proconfig=ARRAY['search_path=""'] AND pg_catalog.md5(pg_catalog.regexp_replace(pg_catalog.btrim(p.prosrc),'\s+',' ','g'))=r.src_md5) THEN RAISE EXCEPTION 'Function prerequisite drift: %',r.sig; END IF;
    FOREACH v_role IN ARRAY ARRAY['anon','service_role'] LOOP
      IF pg_catalog.has_function_privilege(v_role,v_oid,'EXECUTE') THEN RAISE EXCEPTION 'Forbidden dependency execution grant'; END IF;
    END LOOP;
    IF r.ret IN ('trigger','void') OR r.sig LIKE 'p2_private_%' THEN
      IF pg_catalog.has_function_privilege('authenticated',v_oid,'EXECUTE') THEN RAISE EXCEPTION 'Private dependency exposed'; END IF;
    ELSE
      IF NOT pg_catalog.has_function_privilege('authenticated',v_oid,'EXECUTE') THEN RAISE EXCEPTION 'Read-helper access missing'; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a WHERE p.oid=v_oid AND a.grantee=0) THEN RAISE EXCEPTION 'PUBLIC dependency execute grant'; END IF;
  END LOOP;
  -- Complete baseline trigger manifest: events/UPDATE OF/arguments, enabled
  -- binding and deferred flags; extra non-internal baseline triggers also fail.
  FOR r IN SELECT * FROM (VALUES
    ('tenants','tenants_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','slug','created_by','creation_key','created_at']::text[]),
    ('branches','branches_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','tenant_id','created_at']::text[]),
    ('profiles','profiles_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','created_at']::text[]),
    ('roles','roles_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','tenant_id','key','scope','is_system','rank','created_at']::text[]),
    ('memberships','memberships_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','tenant_id','user_id','created_at']::text[]),
    ('membership_branches','membership_branches_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['tenant_id','membership_id','branch_id']::text[]),
    ('invitations','invitations_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['id','tenant_id','email','role_id','token_hash','inviter_membership_id','expires_at','created_at']::text[]),
    ('invitation_branches','invitation_branches_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['tenant_id','invitation_id','branch_id']::text[]),
    ('platform_admins','platform_admins_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['user_id','granted_by','created_at']::text[]),
    ('role_permissions','role_permissions_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['role_id','permission_key']::text[]),
    ('permissions','permissions_identity_guard','p1_guard_identity',19,false,ARRAY[]::text[],ARRAY['key','module','action']::text[]),
    ('tenants','tenants_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('branches','branches_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('profiles','profiles_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('roles','roles_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('permissions','permissions_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitations','invitations_field_validation','p1_validate_fields',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('memberships','memberships_role_integrity','p1_validate_role_assignment',23,false,ARRAY['role_id','tenant_id']::text[],ARRAY[]::text[]),
    ('invitations','invitations_role_integrity','p1_validate_role_assignment',23,false,ARRAY['role_id','tenant_id']::text[],ARRAY[]::text[]),
    ('tenants','tenants_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('branches','branches_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('profiles','profiles_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('roles','roles_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('memberships','memberships_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitations','invitations_touch','p1_touch_updated_at',19,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('branches','branches_00_tenant_lock','p2_lock_branch_tenant',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitations','invitations_00_tenant_lock','p2_lock_branch_tenant',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('membership_branches','membership_branches_00_tenant_lock','p2_lock_branch_tenant',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitation_branches','invitation_branches_00_tenant_lock','p2_lock_branch_tenant',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('membership_branches','membership_branches_new_link_guard','p2_guard_new_branch_link',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitation_branches','invitation_branches_new_link_guard','p2_guard_new_branch_link',23,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('memberships','memberships_branch_set_validation','p2_validate_branch_sets',29,true,ARRAY[]::text[],ARRAY[]::text[]),
    ('membership_branches','membership_branches_set_validation','p2_validate_branch_sets',29,true,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitations','invitations_branch_set_validation','p2_validate_branch_sets',29,true,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitation_branches','invitation_branches_set_validation','p2_validate_branch_sets',29,true,ARRAY[]::text[],ARRAY[]::text[]),
    ('branches','branches_membership_set_validation','p2_validate_branch_sets',17,true,ARRAY['status']::text[],ARRAY[]::text[]),
    ('memberships','memberships_owner_transition_lock','p2_prevent_last_owner_loss',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('memberships','memberships_owner_counter_sync','p2_sync_active_owner',29,false,ARRAY['role_id','status']::text[],ARRAY[]::text[]),
    ('tenants','tenants_owner_counter_guard','p2_guard_owner_counter',23,false,ARRAY['active_owner_count']::text[],ARRAY[]::text[]),
    ('memberships','memberships_owner_invariant','p2_check_owner_invariant',29,true,ARRAY['role_id','status']::text[],ARRAY[]::text[]),
    ('tenants','tenants_owner_invariant','p2_check_owner_invariant',21,true,ARRAY['status','active_owner_count']::text[],ARRAY[]::text[]),
    ('tenants','tenants_audit','p2_audit_tenant',29,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('branches','branches_audit','p2_audit_branch',29,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('memberships','memberships_audit','p2_audit_membership',29,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('membership_branches','membership_branches_audit','p2_audit_membership_branch',13,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitations','invitations_audit','p2_audit_invitation',29,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('invitation_branches','invitation_branches_audit','p2_audit_invitation_branch',13,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('audit_logs','audit_logs_immutable','p2_guard_audit_immutable',27,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('audit_logs','audit_logs_truncate_guard','p2_guard_audit_truncate',34,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('roles','roles_system_catalog_guard','p2_guard_system_catalog',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('permissions','permissions_system_catalog_guard','p2_guard_system_catalog',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('role_permissions','role_permissions_system_catalog_guard','p2_guard_system_catalog',31,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('roles','roles_system_catalog_truncate_guard','p2_guard_system_catalog_truncate',34,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('permissions','permissions_system_catalog_truncate_guard','p2_guard_system_catalog_truncate',34,false,ARRAY[]::text[],ARRAY[]::text[]),
    ('role_permissions','role_permissions_system_catalog_truncate_guard','p2_guard_system_catalog_truncate',34,false,ARRAY[]::text[],ARRAY[]::text[])
  ) e(tbl,nm,fn,flags,deferred,upd,args) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger t WHERE t.tgrelid=pg_catalog.to_regclass('public.'||r.tbl) AND t.tgname=r.nm AND NOT t.tgisinternal AND t.tgenabled='O' AND t.tgfoid=pg_catalog.to_regprocedure('public.'||r.fn||'()') AND t.tgtype=r.flags AND t.tgdeferrable=r.deferred AND t.tginitdeferred=r.deferred AND ARRAY(SELECT a.attname::text FROM pg_catalog.unnest(t.tgattr::smallint[]) WITH ORDINALITY k(num,pos) JOIN pg_catalog.pg_attribute a ON a.attrelid=t.tgrelid AND a.attnum=k.num ORDER BY k.pos)=r.upd AND t.tgnargs=pg_catalog.cardinality(r.args) AND t.tgargs=pg_catalog.decode(COALESCE((SELECT pg_catalog.string_agg(pg_catalog.encode(pg_catalog.convert_to(x,'UTF8'),'hex')||'00','' ORDER BY pos) FROM pg_catalog.unnest(r.args) WITH ORDINALITY z(x,pos)),''),'hex') AND t.tgqual IS NULL) THEN RAISE EXCEPTION 'Trigger prerequisite drift: %.%',r.tbl,r.nm; END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal) <> 55 THEN RAISE EXCEPTION 'Unexpected application triggers; reconcile before execution'; END IF;
  FOR r IN SELECT * FROM (VALUES
    ('tenants','tenants_select_member','p2_has_tenant_permissionid,''organization.view'''),
    ('branches','branches_select_scoped','p2_has_branch_permissiontenant_id,id,''branch.view'''),
    ('profiles','profiles_select_self','id=auth.uid'),
    ('roles','roles_select_catalog','p2_can_view_roleid'),
    ('permissions','permissions_select_catalog','p2_has_any_permission''role.view'''),
    ('role_permissions','role_permissions_select_scoped','p2_can_view_rolerole_id'),
    ('memberships','memberships_select_scoped','p2_can_view_membershipid'),
    ('membership_branches','membership_branches_select_scoped','p2_can_view_membershipmembership_idANDp2_has_branch_permissiontenant_id,branch_id,''branch.view'''),
    ('invitations','invitations_select_scoped','p2_can_view_invitationid'),
    ('invitation_branches','invitation_branches_select_scoped','p2_can_view_invitationinvitation_idANDp2_has_branch_permissiontenant_id,branch_id,''branch.view'''),
    ('audit_logs','audit_logs_select_organization','tenant_idISNOTNULLANDp2_has_org_permissiontenant_id,''audit.view'''),
    ('platform_admins','platform_admins_select_self','p2_current_user_is_verifiedANDuser_id=auth.uid')
  ) e(tbl,nm,expr) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policies p WHERE p.schemaname='public' AND p.tablename=r.tbl AND p.policyname=r.nm AND p.cmd='SELECT' AND p.permissive='PERMISSIVE' AND p.roles=ARRAY['authenticated']::name[] AND p.with_check IS NULL AND pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.replace(pg_catalog.replace(p.qual,'public.',''),'::text',''),'[\s()]','','g'))=pg_catalog.lower(r.expr)) THEN RAISE EXCEPTION 'Policy prerequisite drift: %',r.nm; END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname='public')<>12 THEN RAISE EXCEPTION 'Unexpected public policy'; END IF;
  SELECT ARRAY['id','name','slug','country','timezone','default_currency','contact_email','contact_phone','status','created_at','updated_at'] INTO v_cols;
  IF pg_catalog.has_table_privilege('authenticated','public.tenants','SELECT') THEN RAISE EXCEPTION 'Broad tenant read grant'; END IF;
  FOR r IN SELECT attname FROM pg_catalog.pg_attribute WHERE attrelid='public.tenants'::regclass AND attnum>0 AND NOT attisdropped LOOP
    IF pg_catalog.has_column_privilege('authenticated','public.tenants',r.attname,'SELECT') IS DISTINCT FROM (r.attname::text=ANY(v_cols)) THEN RAISE EXCEPTION 'Tenant safe projection drift'; END IF;
  END LOOP;
  IF pg_catalog.has_column_privilege('authenticated','public.invitations','token_hash','SELECT') THEN RAISE EXCEPTION 'Invitation secret exposed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key='organization.view' AND module='organization' AND action='view') OR (SELECT count(*) FROM public.roles WHERE tenant_id IS NULL AND key='owner' AND is_system AND scope='organization' AND rank=100)<>1 OR NOT EXISTS (SELECT 1 FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id WHERE r.tenant_id IS NULL AND r.key='owner' AND r.is_system AND r.scope='organization' AND r.rank=100 AND rp.permission_key='organization.view') THEN RAISE EXCEPTION 'Owner organization.view contract missing'; END IF;
END;
$preflight$;

CREATE TABLE public.registration_package_choices (
  key text PRIMARY KEY, name text NOT NULL,
  offering_kind text NOT NULL CHECK (offering_kind IN ('standard','enterprise_inquiry')),
  selectable boolean NOT NULL DEFAULT true,
  CHECK (key ~ '^[a-z][a-z0-9_]{1,49}$')
);
REVOKE ALL ON public.registration_package_choices FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT (key,name,offering_kind,selectable) ON public.registration_package_choices TO anon,authenticated;
ALTER TABLE public.registration_package_choices ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_packages_public_read ON public.registration_package_choices FOR SELECT TO anon,authenticated USING (selectable);

CREATE TABLE public.registration_module_choices (
  key text PRIMARY KEY, name text NOT NULL, release_priority text NOT NULL,
  priority_basis text NOT NULL DEFAULT 'Blueprint v1 section 3: proposed; not release status',
  selectable boolean NOT NULL DEFAULT true,
  CHECK (key ~ '^[a-z][a-z0-9_]{1,49}$')
);
REVOKE ALL ON public.registration_module_choices FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT (key,name,release_priority,priority_basis,selectable) ON public.registration_module_choices TO anon,authenticated;
ALTER TABLE public.registration_module_choices ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_modules_public_read ON public.registration_module_choices FOR SELECT TO anon,authenticated USING (selectable);

INSERT INTO public.registration_package_choices(key,name,offering_kind) VALUES
 ('starter','Starter','standard'),('growth','Growth','standard'),
 ('business','Business','standard'),('enterprise','Enterprise','enterprise_inquiry');
-- Customer request vocabulary only. Internal capabilities are deliberately absent.
INSERT INTO public.registration_module_choices(key,name,release_priority) VALUES
 ('crm_admissions','CRM & admissions','P0'),
 ('course_program_management','Course & program management','P0'),
 ('scheduling_booking','Scheduling & booking','P0'),
 ('learner_management','Learner management','P0'),
 ('fees_payment_tracking','Fees & payment tracking','P0'),
 ('attendance','Attendance','P0'),('operational_dashboards','Operational dashboards','P0'),
 ('notifications','Notifications','P1'),('assessment_certificates','Assessment & certificates','P1'),
 ('corporate_training','Corporate training','P1'),('customer_support','Customer support','P1'),
 ('accounting','Accounting','P2'),('hr_payroll','HR & payroll','P2; localization required'),
 ('procurement_inventory','Procurement & inventory','P2'),('advanced_analytics','Advanced analytics','P2'),
 ('ai_channel_automation','AI & channel automation','P1/P2 by integration readiness');

-- Proposed maintainable reference catalogues; EMPTY until exact publisher release,
-- hash, curated business scope, maintenance responsibility and refresh cadence
-- receive approval. No hard-coded legacy ISO-derived array is used at runtime.
CREATE TABLE public.registration_country_codes (
  code text PRIMARY KEY, name text NOT NULL,
  classification text NOT NULL,
  selectable boolean NOT NULL DEFAULT false,
  source_name text NOT NULL, source_version text NOT NULL,
  source_sha256 text NOT NULL, source_url text NOT NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  CHECK (code ~ '^[A-Z]{2}$'), CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
  CHECK (source_url ~ '^https://[^[:space:]@]+$'),
  CHECK (NOT selectable OR classification='country')
);
REVOKE ALL ON public.registration_country_codes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT (code,name,classification,selectable,source_name,source_version,source_sha256,source_url,reviewed_at) ON public.registration_country_codes TO anon,authenticated;
ALTER TABLE public.registration_country_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_country_codes_public_read ON public.registration_country_codes FOR SELECT TO anon,authenticated USING (selectable);
ALTER TABLE public.registration_country_codes OWNER TO postgres;
COMMENT ON TABLE public.registration_country_codes IS 'Proposed reviewed versioned reference source, no seeds approved; classified business selections only. Not a country-currency legal tender mapping.';

CREATE TABLE public.registration_currency_codes (
  code text PRIMARY KEY, name text NOT NULL,
  classification text NOT NULL,
  selectable boolean NOT NULL DEFAULT false,
  source_name text NOT NULL, source_version text NOT NULL,
  source_sha256 text NOT NULL, source_url text NOT NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  CHECK (code ~ '^[A-Z]{3}$'), CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
  CHECK (source_url ~ '^https://[^[:space:]@]+$'),
  CHECK (NOT selectable OR classification='active_business_currency')
);
REVOKE ALL ON public.registration_currency_codes FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT (code,name,classification,selectable,source_name,source_version,source_sha256,source_url,reviewed_at) ON public.registration_currency_codes TO anon,authenticated;
ALTER TABLE public.registration_currency_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_currency_codes_public_read ON public.registration_currency_codes FOR SELECT TO anon,authenticated USING (selectable);
ALTER TABLE public.registration_currency_codes OWNER TO postgres;
COMMENT ON TABLE public.registration_currency_codes IS 'Proposed reviewed versioned reference source, no seeds approved; classified business selections only. Not a country-currency legal tender mapping.';

-- One extension of existing tenants, not a competing organization/profile model.
-- Contact identity/name/phone already live in Auth/profiles/tenants, not duplicated.
CREATE TABLE public.organization_registrations (
  tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE RESTRICT,
  package_key text NOT NULL REFERENCES public.registration_package_choices(key) ON DELETE RESTRICT,
  organization_type text NOT NULL,
  city text NOT NULL, business_address text NOT NULL, website text,
  registration_status text NOT NULL DEFAULT 'submitted' CHECK (registration_status='submitted'),
  approval_status text NOT NULL DEFAULT 'pending' CHECK (approval_status='pending'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (char_length(btrim(organization_type)) BETWEEN 2 AND 120),
  CHECK (char_length(btrim(city)) BETWEEN 1 AND 120),
  CHECK (char_length(btrim(business_address)) BETWEEN 1 AND 500),
  CHECK (website IS NULL OR (char_length(website)<=2048 AND website ~ '^https?://[^[:space:]@]+$'))
);
REVOKE ALL ON public.organization_registrations FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.organization_registrations TO authenticated;
ALTER TABLE public.organization_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_read_organization ON public.organization_registrations FOR SELECT TO authenticated USING (public.p2_has_org_permission(tenant_id,'organization.view'));

CREATE TABLE public.organization_registration_modules (
  tenant_id uuid NOT NULL REFERENCES public.organization_registrations(tenant_id) ON DELETE RESTRICT,
  module_key text NOT NULL REFERENCES public.registration_module_choices(key) ON DELETE RESTRICT,
  PRIMARY KEY (tenant_id,module_key)
);
REVOKE ALL ON public.organization_registration_modules FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.organization_registration_modules TO authenticated;
ALTER TABLE public.organization_registration_modules ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_modules_read_organization ON public.organization_registration_modules FOR SELECT TO authenticated USING (public.p2_has_org_permission(tenant_id,'organization.view'));
CREATE INDEX registration_package_idx ON public.organization_registrations(package_key);
CREATE INDEX registration_module_key_idx ON public.organization_registration_modules(module_key);

-- Submitted registration snapshots and catalog changes are migration-controlled.
-- No approval, edit, entitlement or catalog-management endpoint in this slice.
CREATE FUNCTION public.p3_guard_registration_snapshot() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Registration review records are immutable' USING ERRCODE='23514'; END;
$$;
REVOKE ALL ON FUNCTION public.p3_guard_registration_snapshot() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER registration_immutable BEFORE UPDATE OR DELETE ON public.organization_registrations FOR EACH ROW EXECUTE FUNCTION public.p3_guard_registration_snapshot();
CREATE TRIGGER registration_no_truncate BEFORE TRUNCATE ON public.organization_registrations FOR EACH STATEMENT EXECUTE FUNCTION public.p3_guard_registration_snapshot();
CREATE TRIGGER registration_modules_immutable BEFORE UPDATE OR DELETE ON public.organization_registration_modules FOR EACH ROW EXECUTE FUNCTION public.p3_guard_registration_snapshot();
CREATE TRIGGER registration_modules_no_truncate BEFORE TRUNCATE ON public.organization_registration_modules FOR EACH STATEMENT EXECUTE FUNCTION public.p3_guard_registration_snapshot();

-- New private row producer; existing P2 audit functions/allowlists unchanged.
-- Payload contains no Owner/contact/business details, package/modules or secrets.
CREATE FUNCTION public.p3_audit_registration() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Registration audit requires actor' USING ERRCODE='42501'; END IF;
  INSERT INTO public.audit_logs(tenant_id,actor_id,action,entity_type,entity_id,metadata,ip)
  VALUES(NEW.tenant_id,auth.uid(),'registration.submitted','organization_registration',NEW.tenant_id,'{}'::jsonb,NULL);
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.p3_audit_registration() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER registration_audit AFTER INSERT ON public.organization_registrations FOR EACH ROW EXECUTE FUNCTION public.p3_audit_registration();

CREATE FUNCTION public.create_organization(
  p_creation_key uuid, p_name text, p_slug text, p_country text,
  p_timezone text, p_currency text, p_contact_email text, p_contact_phone text,
  p_owner_full_name text, p_owner_phone text, p_organization_type text,
  p_city text, p_business_address text, p_package_key text, p_module_keys text[],
  p_website text DEFAULT NULL
) RETURNS TABLE(organization_id uuid,organization_name text,organization_slug text,
  selected_package text,selected_modules text[],registration_status text,approval_status text,replayed boolean)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $create$
DECLARE
  v_actor uuid := auth.uid(); v_tenant public.tenants%ROWTYPE;
  v_registration public.organization_registrations%ROWTYPE; v_owner uuid;
  v_name text := pg_catalog.btrim(p_name); v_email text := pg_catalog.btrim(p_contact_email);
  v_phone text := pg_catalog.btrim(p_contact_phone);
  v_owner_name text := pg_catalog.btrim(p_owner_full_name); v_owner_phone text := pg_catalog.btrim(p_owner_phone);
  v_modules text[]; v_key text;
BEGIN
  -- Enforced release gate, not a comment or browser-only condition.
  -- Do not remove until all owner decisions, durable S08 and isolated tests
  -- are implemented in a separately approved replacement version.
  RAISE EXCEPTION 'REGISTRATION_NOT_AUTHORIZED' USING ERRCODE='42501';
  IF v_actor IS NULL THEN RAISE EXCEPTION 'ACCOUNT_NOT_VERIFIED' USING ERRCODE='42501'; END IF;
  IF p_creation_key IS NULL THEN RAISE EXCEPTION 'INVALID_REGISTRATION_INPUT' USING ERRCODE='22023'; END IF;
  -- Same-key callers serialize; hash collisions never grant access.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('erp:create:'||p_creation_key::text,0));
  -- Fresh authoritative verification after waits. No user metadata authorization.
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.email IS NOT NULL AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL AND NOT u.is_anonymous AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.clock_timestamp())) THEN RAISE EXCEPTION 'ACCOUNT_NOT_VERIFIED' USING ERRCODE='42501'; END IF;
  SELECT t.* INTO v_tenant FROM public.tenants t WHERE t.creation_key=p_creation_key FOR UPDATE;
  IF FOUND THEN
    -- Revalidate identity after tenant lock and current replay authorization.
    IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.email IS NOT NULL AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL AND NOT u.is_anonymous AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.clock_timestamp())) OR v_tenant.created_by IS DISTINCT FROM v_actor OR NOT public.p2_has_org_permission(v_tenant.id,'organization.view') THEN RAISE EXCEPTION 'ORGANIZATION_REQUEST_UNAVAILABLE' USING ERRCODE='42501'; END IF;
    SELECT r.* INTO v_registration FROM public.organization_registrations r WHERE r.tenant_id=v_tenant.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'REGISTRATION_STATE_UNAVAILABLE' USING ERRCODE='42501'; END IF;
    RETURN QUERY SELECT v_tenant.id,v_tenant.name,v_tenant.slug::text,v_registration.package_key,
      ARRAY(SELECT m.module_key FROM public.organization_registration_modules m WHERE m.tenant_id=v_tenant.id ORDER BY m.module_key),
      v_registration.registration_status,v_registration.approval_status,true;
    RETURN; -- No payload equivalence claim; no changed fields, profile or audit.
  END IF;
  IF v_name IS NULL OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 120
    OR p_slug IS NULL OR pg_catalog.char_length(p_slug) NOT BETWEEN 3 AND 50 OR p_slug !~ '^[a-z0-9](-?[a-z0-9])+$'
    OR p_country IS NULL OR p_currency IS NULL OR p_timezone IS NULL OR pg_catalog.char_length(p_timezone) NOT BETWEEN 1 AND 100
    OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names z WHERE z.name=p_timezone)
    OR v_email IS NULL OR pg_catalog.char_length(v_email) NOT BETWEEN 3 AND 254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    OR v_phone IS NULL OR v_phone !~ '^[+0-9() .-]{3,40}$'
    OR v_owner_name IS NULL OR pg_catalog.char_length(v_owner_name) NOT BETWEEN 2 AND 120
    OR v_owner_phone IS NULL OR v_owner_phone !~ '^[+0-9() .-]{3,40}$'
    OR p_organization_type IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_organization_type)) NOT BETWEEN 2 AND 120
    OR p_city IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_city)) NOT BETWEEN 1 AND 120
    OR p_business_address IS NULL OR pg_catalog.char_length(pg_catalog.btrim(p_business_address)) NOT BETWEEN 1 AND 500
    OR (p_website IS NOT NULL AND (pg_catalog.char_length(p_website)>2048 OR p_website !~ '^https?://[^[:space:]@]+$'))
    OR p_module_keys IS NULL OR pg_catalog.cardinality(p_module_keys)=0 OR pg_catalog.array_ndims(p_module_keys) IS DISTINCT FROM 1
    OR EXISTS (SELECT 1 FROM pg_catalog.unnest(p_module_keys) k WHERE k IS NULL)
    OR pg_catalog.cardinality(p_module_keys) <> (SELECT count(DISTINCT k) FROM pg_catalog.unnest(p_module_keys) k)
    THEN RAISE EXCEPTION 'INVALID_REGISTRATION_INPUT' USING ERRCODE='22023'; END IF;
  -- Versioned approved catalogue membership, not caller-supplied authority.
  -- These empty catalogues also fail closed until an approved seed migration.
  PERFORM 1 FROM public.registration_country_codes c WHERE c.code=p_country AND c.selectable AND c.classification='country' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_COUNTRY_SELECTION' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.registration_currency_codes c WHERE c.code=p_currency AND c.selectable AND c.classification='active_business_currency' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_CURRENCY_SELECTION' USING ERRCODE='22023'; END IF;
  SELECT pg_catalog.array_agg(k ORDER BY k) INTO v_modules FROM pg_catalog.unnest(p_module_keys) k;
  PERFORM 1 FROM public.registration_package_choices c WHERE c.key=p_package_key AND c.selectable FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_PACKAGE_SELECTION' USING ERRCODE='22023'; END IF;
  FOREACH v_key IN ARRAY v_modules LOOP
    PERFORM 1 FROM public.registration_module_choices c WHERE c.key=v_key AND c.selectable FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_MODULE_SELECTION' USING ERRCODE='22023'; END IF;
  END LOOP;
  -- Serialize same-account new submissions before any profile/tenant writes.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('erp:profile:'||v_actor::text,0));
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.email IS NOT NULL AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL AND NOT u.is_anonymous AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.clock_timestamp())) THEN RAISE EXCEPTION 'ACCOUNT_NOT_VERIFIED' USING ERRCODE='42501'; END IF;
  -- Narrow P4-boundary amendment: insert absent profile only, no generic updater.
  -- Existing profile, theme, last tenant and contact fields are never overwritten.
  INSERT INTO public.profiles(id,full_name,phone) VALUES(v_actor,v_owner_name,v_owner_phone) ON CONFLICT (id) DO NOTHING;
  PERFORM 1 FROM public.profiles p WHERE p.id=v_actor FOR UPDATE;
  -- Existing profiles must already supply complete Owner details; don't silently
  -- discard requested changes or overwrite approved existing personal data.
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_actor AND p.full_name IS NOT NULL AND pg_catalog.char_length(pg_catalog.btrim(p.full_name)) BETWEEN 2 AND 120 AND p.phone IS NOT NULL AND p.phone ~ '^[+0-9() .-]{3,40}$') THEN RAISE EXCEPTION 'PROFILE_DETAILS_REQUIRED' USING ERRCODE='22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_actor AND p.full_name=v_owner_name AND p.phone=v_owner_phone) THEN RAISE EXCEPTION 'PROFILE_DETAILS_CONFLICT' USING ERRCODE='22023'; END IF;
  SELECT r.id INTO STRICT v_owner FROM public.roles r WHERE r.tenant_id IS NULL AND r.key='owner' AND r.is_system AND r.scope='organization' AND r.rank=100 FOR SHARE;
  -- UNREACHABLE active-workspace alternative only: pending access and
  -- Enterprise behavior NOT decided. Explicit status documents V1 semantics;
  -- a no-access/inquiry-only decision requires a different reviewed body.
  INSERT INTO public.tenants(name,slug,country,timezone,default_currency,contact_email,contact_phone,created_by,creation_key,status)
  VALUES(v_name,p_slug,p_country,p_timezone,p_currency,v_email,v_phone,v_actor,p_creation_key,'active') RETURNING * INTO v_tenant;
  INSERT INTO public.memberships(tenant_id,user_id,role_id,status,joined_at) VALUES(v_tenant.id,v_actor,v_owner,'active',pg_catalog.now());
  INSERT INTO public.organization_registrations(tenant_id,package_key,organization_type,city,business_address,website)
  VALUES(v_tenant.id,p_package_key,pg_catalog.btrim(p_organization_type),pg_catalog.btrim(p_city),pg_catalog.btrim(p_business_address),p_website) RETURNING * INTO v_registration;
  INSERT INTO public.organization_registration_modules(tenant_id,module_key) SELECT v_tenant.id,k FROM pg_catalog.unnest(v_modules) k;
  -- Fresh count/counter assertion, no direct counter writes or branch creation.
  IF (SELECT t.active_owner_count FROM public.tenants t WHERE t.id=v_tenant.id)<>1 OR (SELECT count(*) FROM public.memberships m WHERE m.tenant_id=v_tenant.id AND m.status='active' AND m.role_id=v_owner)<>1 THEN RAISE EXCEPTION 'OWNER_INITIALIZATION_FAILED' USING ERRCODE='23514'; END IF;
  IF (SELECT count(*) FROM public.audit_logs a WHERE a.tenant_id=v_tenant.id)<>3
    OR (SELECT count(*) FROM public.audit_logs a WHERE a.tenant_id=v_tenant.id AND a.actor_id=v_actor AND a.action='tenant.created' AND a.entity_type='tenant' AND a.entity_id=v_tenant.id AND a.metadata='{}'::jsonb)<>1
    OR (SELECT count(*) FROM public.audit_logs a WHERE a.tenant_id=v_tenant.id AND a.actor_id=v_actor AND a.action='membership.created' AND a.entity_type='membership')<>1
    OR (SELECT count(*) FROM public.audit_logs a WHERE a.tenant_id=v_tenant.id AND a.actor_id=v_actor AND a.action='registration.submitted' AND a.entity_type='organization_registration' AND a.entity_id=v_tenant.id AND a.metadata='{}'::jsonb AND a.ip IS NULL)<>1 THEN RAISE EXCEPTION 'REGISTRATION_AUDIT_FAILED' USING ERRCODE='23514'; END IF;
  IF NOT public.p2_has_org_permission(v_tenant.id,'organization.view') THEN RAISE EXCEPTION 'ORGANIZATION_ACCESS_FAILED' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT v_tenant.id,v_tenant.name,v_tenant.slug::text,v_registration.package_key,v_modules,v_registration.registration_status,v_registration.approval_status,false;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'ORGANIZATION_CONFLICT' USING ERRCODE='23505';
END;
$create$;

ALTER TABLE public.registration_package_choices OWNER TO postgres;
ALTER TABLE public.registration_module_choices OWNER TO postgres;
ALTER TABLE public.organization_registrations OWNER TO postgres;
ALTER TABLE public.organization_registration_modules OWNER TO postgres;
ALTER FUNCTION public.p3_guard_registration_snapshot() OWNER TO postgres;
ALTER FUNCTION public.p3_audit_registration() OWNER TO postgres;
ALTER FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],text) FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE public.organization_registrations IS 'Immutable submitted request pending approval; no entitlements/subscriptions activated. Future approval lifecycle separately reviewed.';
COMMENT ON TABLE public.organization_registration_modules IS 'Requested capabilities only, not enabled modules or package allocation.';
COMMENT ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],text) IS 'Verified fixed registration command; minimal absent profile only; atomic organization/Owner/request/audit; unchanged authorized replay. UNCONDITIONALLY DISABLED and no application EXECUTE. All owner/S08/runner/runtime gates unresolved.';
-- Revoke PUBLIC/default function rights on every newly introduced function.
-- Re-check effective grants after object ownership/default ACL application.
DO $post_acl$
DECLARE r record; v_role text; v_priv text;
BEGIN
  FOR r IN SELECT c.oid,c.relname,c.relowner,c.relacl FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=ANY(ARRAY['registration_package_choices','registration_module_choices','registration_country_codes','registration_currency_codes','organization_registrations','organization_registration_modules']) LOOP
    FOREACH v_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      FOREACH v_priv IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
        IF pg_catalog.has_table_privilege(v_role,r.oid,v_priv) THEN RAISE EXCEPTION 'New table ACL drift'; END IF;
      END LOOP;
      IF pg_catalog.has_any_column_privilege(v_role,r.oid,'INSERT') OR pg_catalog.has_any_column_privilege(v_role,r.oid,'UPDATE') OR pg_catalog.has_any_column_privilege(v_role,r.oid,'REFERENCES') THEN RAISE EXCEPTION 'New column write grant'; END IF;
      IF v_role='service_role' AND pg_catalog.has_any_column_privilege(v_role,r.oid,'SELECT') THEN RAISE EXCEPTION 'Service read path forbidden'; END IF;
      IF v_role='anon' AND r.relname IN ('organization_registrations','organization_registration_modules') AND pg_catalog.has_any_column_privilege(v_role,r.oid,'SELECT') THEN RAISE EXCEPTION 'Anonymous private read path'; END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(r.relacl,pg_catalog.acldefault('r',r.relowner))) a WHERE a.grantee=0) THEN RAISE EXCEPTION 'PUBLIC new table grant'; END IF;
  END LOOP;
  FOR r IN SELECT p.oid,p.proowner,p.proacl,p.proconfig,p.prosecdef,p.proname FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname LIKE 'p3_%' OR p.proname='create_organization') LOOP
    IF pg_catalog.pg_get_userbyid(r.proowner)<>'postgres' OR r.proconfig<>ARRAY['search_path=""'] THEN RAISE EXCEPTION 'New function owner/path drift'; END IF;
    FOREACH v_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      IF pg_catalog.has_function_privilege(v_role,r.oid,'EXECUTE') THEN RAISE EXCEPTION 'Registration command/helper exposed'; END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(r.proacl,pg_catalog.acldefault('f',r.proowner))) a WHERE a.grantee=0) THEN RAISE EXCEPTION 'PUBLIC new function grant'; END IF;
  END LOOP;
END;
$post_acl$;
-- No opening GRANT, approval workflow, abuse implementation, code seed,
-- Auth change, P1/P2 alteration or application connection is contained here.

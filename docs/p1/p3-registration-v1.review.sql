-- UNAPPLIED P3 REVIEW V1. Dev ojozmvvdpjmvsxmpgrul only.
-- PREPARATION IS NOT EXECUTION AUTHORIZATION. Preserve the earlier draft.
-- Review candidate, NOT READY TO EXPOSE: S08 durable abuse controls and numeric
-- request/retry budgets remain owner decisions. No payment/subscription/entitlement activation.
-- Execute through separately approved atomic migration mechanism, as postgres.
-- Proposed technical input bounds below are review choices, NOT commercial limits.
-- Package/module catalog rows are request vocabulary only, not release promises.
-- Registration approval is fixed pending; no approval endpoint is authorized.

DO $preflight$
DECLARE v_name text;
BEGIN
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'Reviewed postgres identity required'; END IF;
  IF pg_catalog.to_regnamespace('extensions') IS NULL THEN RAISE EXCEPTION 'extensions missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='citext' AND n.nspname='extensions') THEN RAISE EXCEPTION 'Expected installed citext missing'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='create_organization') THEN RAISE EXCEPTION 'Existing creation command requires separate review'; END IF;
  FOREACH v_name IN ARRAY ARRAY['tenants','profiles','memberships','roles','audit_logs'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=v_name AND c.relkind='r' AND c.relrowsecurity AND NOT c.relforcerowsecurity AND pg_catalog.pg_get_userbyid(c.relowner)='postgres') THEN RAISE EXCEPTION 'Foundation prerequisite missing: %',v_name; END IF;
  END LOOP;
  IF pg_catalog.to_regprocedure('public.p2_has_org_permission(uuid,text)') IS NULL OR pg_catalog.to_regprocedure('public.p2_check_owner_invariant()') IS NULL OR pg_catalog.to_regprocedure('public.p2_sync_active_owner()') IS NULL OR pg_catalog.to_regprocedure('public.p2_audit_tenant()') IS NULL OR pg_catalog.to_regprocedure('public.p2_audit_membership()') IS NULL THEN RAISE EXCEPTION 'P2 dependencies missing'; END IF;
  IF (SELECT count(*) FROM public.roles WHERE tenant_id IS NULL AND key='owner' AND is_system AND scope='organization' AND rank=100) <> 1 THEN RAISE EXCEPTION 'Owner catalog drift'; END IF;
END;
$preflight$;
SET LOCAL search_path = pg_catalog, public, extensions;

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
  key text PRIMARY KEY, name text NOT NULL, selectable boolean NOT NULL DEFAULT true,
  CHECK (key ~ '^[a-z][a-z0-9_]{1,49}$')
);
REVOKE ALL ON public.registration_module_choices FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT (key,name,selectable) ON public.registration_module_choices TO anon,authenticated;
ALTER TABLE public.registration_module_choices ENABLE ROW LEVEL SECURITY;
CREATE POLICY registration_modules_public_read ON public.registration_module_choices FOR SELECT TO anon,authenticated USING (selectable);

-- Exact package names confirmed by owner. Enterprise is inquiry-only.
INSERT INTO public.registration_package_choices(key,name,offering_kind) VALUES
 ('starter','Starter','standard'),('growth','Growth','standard'),
 ('business','Business','standard'),('enterprise','Enterprise','enterprise_inquiry');
-- Source: original Product Blueprint v1 section 3. No priority/availability,
-- package allocations, add-ons, prices, quotas or dependencies are inferred.
INSERT INTO public.registration_module_choices(key,name) VALUES
 ('platform_foundation','Platform foundation'),('crm_admissions','CRM & admissions'),
 ('course_program_management','Course & program management'),('scheduling_booking','Scheduling & booking'),
 ('learner_management','Learner management'),('fees_payment_tracking','Fees & payment tracking'),
 ('attendance','Attendance'),('operational_dashboards','Operational dashboards'),
 ('notifications','Notifications'),('assessment_certificates','Assessment & certificates'),
 ('corporate_training','Corporate training'),('customer_support','Customer support'),
 ('accounting','Accounting'),('hr_payroll','HR & payroll'),
 ('procurement_inventory','Procurement & inventory'),('advanced_analytics','Advanced analytics'),
 ('ai_channel_automation','AI & channel automation'),('saas_commercial_console','SaaS commercial console');

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
  -- ISO SNAPSHOT inserted unchanged from earlier review draft below.
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
  -- Existing profiles must already supply complete Owner details; don't silently
  -- discard requested changes or overwrite approved existing personal data.
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_actor AND p.full_name IS NOT NULL AND pg_catalog.char_length(pg_catalog.btrim(p.full_name)) BETWEEN 2 AND 120 AND p.phone IS NOT NULL AND p.phone ~ '^[+0-9() .-]{3,40}$') THEN RAISE EXCEPTION 'PROFILE_DETAILS_REQUIRED' USING ERRCODE='22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_actor AND p.full_name=v_owner_name AND p.phone=v_owner_phone) THEN RAISE EXCEPTION 'PROFILE_DETAILS_CONFLICT' USING ERRCODE='22023'; END IF;
  SELECT r.id INTO STRICT v_owner FROM public.roles r WHERE r.tenant_id IS NULL AND r.key='owner' AND r.is_system AND r.scope='organization' AND r.rank=100 FOR SHARE;
  INSERT INTO public.tenants(name,slug,country,timezone,default_currency,contact_email,contact_phone,created_by,creation_key)
  VALUES(v_name,p_slug,p_country,p_timezone,p_currency,v_email,v_phone,v_actor,p_creation_key) RETURNING * INTO v_tenant;
  INSERT INTO public.memberships(tenant_id,user_id,role_id,status,joined_at) VALUES(v_tenant.id,v_actor,v_owner,'active',pg_catalog.now());
  INSERT INTO public.organization_registrations(tenant_id,package_key,organization_type,city,business_address,website)
  VALUES(v_tenant.id,p_package_key,pg_catalog.btrim(p_organization_type),pg_catalog.btrim(p_city),pg_catalog.btrim(p_business_address),p_website) RETURNING * INTO v_registration;
  INSERT INTO public.organization_registration_modules(tenant_id,module_key) SELECT v_tenant.id,k FROM pg_catalog.unnest(v_modules) k;
  -- Fresh count/counter assertion, no direct counter writes or branch creation.
  IF (SELECT t.active_owner_count FROM public.tenants t WHERE t.id=v_tenant.id)<>1 OR (SELECT count(*) FROM public.memberships m WHERE m.tenant_id=v_tenant.id AND m.status='active' AND m.role_id=v_owner)<>1 THEN RAISE EXCEPTION 'OWNER_INITIALIZATION_FAILED' USING ERRCODE='23514'; END IF;
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
GRANT EXECUTE ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],text) TO authenticated;
COMMENT ON TABLE public.organization_registrations IS 'Immutable submitted request pending approval; no entitlements/subscriptions activated. Future approval lifecycle separately reviewed.';
COMMENT ON TABLE public.organization_registration_modules IS 'Requested capabilities only, not enabled modules or package allocation.';
COMMENT ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],text) IS 'Verified fixed registration command; minimal absent profile only; atomic organization/Owner/request/audit; unchanged authorized replay. S08 exposure gate remains unresolved.';
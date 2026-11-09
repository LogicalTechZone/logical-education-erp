-- UNAPPLIED REVIEW DRAFT: Logical Education ERP M1 organization creation.
-- Dev only: ojozmvvdpjmvsxmpgrul. Separate exact-SQL approval required.
-- No new tables, profile initializer, policies, direct DML or service_role grants.
-- Snapshot: pycountry 24.6.1 (Debian iso-codes-derived ISO datasets), not a
-- claim of a live licensed ISO feed or current 2026 catalog completeness.
-- Wheel SHA256: f1a4fb391cd7214f8eefd39556d740adcc233c778a27f8942c8dca351d6ce06f
-- 249 ISO 3166-1 country codes; 181 ISO 4217 codes including special units.
-- No country-to-currency mapping or legal-tender guarantee is implied.
-- Existing reviewed postgres owner deliberately bypasses RLS inside this
-- fixed command; caller authorization is explicit. Ordinary reads retain RLS.
-- No modification of managed Auth objects. Read-only identity lookup only.

DO $preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Reviewed postgres execution identity required';
  END IF;
  IF pg_catalog.to_regprocedure('public.create_organization(uuid,text,text,text,text,text,text,text)') IS NOT NULL THEN
    RAISE EXCEPTION 'Organization operation already exists; inspect before applying';
  END IF;
  IF pg_catalog.to_regprocedure('public.p2_current_user_is_verified()') IS NULL
     OR pg_catalog.to_regprocedure('public.p2_has_org_permission(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'P2 dependencies missing';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('tenants','memberships','profiles','roles','audit_logs')
      AND (pg_catalog.pg_get_userbyid(c.relowner)<>'postgres' OR NOT c.relrowsecurity OR c.relforcerowsecurity)
  ) THEN RAISE EXCEPTION 'Unexpected foundation ownership or RLS'; END IF;
  IF (SELECT count(*) FROM public.roles r WHERE r.tenant_id IS NULL AND r.key='owner'
      AND r.is_system AND r.scope='organization' AND r.rank=100) <> 1 THEN
    RAISE EXCEPTION 'Global Owner catalog drift';
  END IF;
END;
$preflight$;

CREATE FUNCTION public.create_organization(
  p_creation_key uuid, p_name text, p_slug text, p_country text,
  p_timezone text, p_currency text, p_contact_email text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL
) RETURNS TABLE (organization_id uuid, organization_name text, organization_slug text, replayed boolean)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $create$
DECLARE
  v_actor uuid := auth.uid();
  v_tenant public.tenants%ROWTYPE;
  v_owner uuid;
  v_name text := pg_catalog.btrim(p_name);
  v_email text := NULLIF(pg_catalog.btrim(p_contact_email),'');
  v_phone text := NULLIF(pg_catalog.btrim(p_contact_phone),'');
BEGIN
  -- The database, not a frontend email or role check, establishes identity.
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=v_actor AND u.email IS NOT NULL
      AND u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
      AND NOT u.is_anonymous AND (u.banned_until IS NULL OR u.banned_until <= pg_catalog.now())
  ) THEN RAISE EXCEPTION 'ACCOUNT_NOT_VERIFIED' USING ERRCODE='42501'; END IF;
  IF p_creation_key IS NULL THEN
    RAISE EXCEPTION 'INVALID_ORGANIZATION_INPUT' USING ERRCODE='22023';
  END IF;

  -- Global key locking serializes same-key submissions including foreign creators.
  -- Hash collisions only serialize unrelated requests; they never authorize access.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('erp:create:' || p_creation_key::text,0));
  SELECT t.* INTO v_tenant FROM public.tenants t WHERE t.creation_key=p_creation_key FOR UPDATE;
  IF FOUND THEN
    IF v_tenant.created_by IS DISTINCT FROM v_actor
       OR NOT public.p2_has_org_permission(v_tenant.id,'organization.view') THEN
      RAISE EXCEPTION 'ORGANIZATION_REQUEST_UNAVAILABLE' USING ERRCODE='42501';
    END IF;
    -- No changed fields are applied and no original-payload equivalence asserted.
    RETURN QUERY SELECT v_tenant.id,v_tenant.name,v_tenant.slug::text,true;
    RETURN;
  END IF;

  -- Controlled profile prerequisite; never silently initialize a profile here.
  PERFORM 1 FROM public.profiles p WHERE p.id=v_actor FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_REQUIRED' USING ERRCODE='42501'; END IF;
  IF v_name IS NULL OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 120
     OR p_slug IS NULL OR pg_catalog.char_length(p_slug) NOT BETWEEN 3 AND 50
     OR p_slug !~ '^[a-z0-9](-?[a-z0-9])+$'
     OR p_country IS NULL OR p_currency IS NULL
     OR p_timezone IS NULL OR pg_catalog.char_length(p_timezone) NOT BETWEEN 1 AND 100
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names z WHERE z.name=p_timezone)
     OR (v_email IS NOT NULL AND (pg_catalog.char_length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'))
     OR (v_phone IS NOT NULL AND (pg_catalog.char_length(v_phone)>40 OR v_phone !~ '^[+0-9() .-]{3,40}$')) THEN
    RAISE EXCEPTION 'INVALID_ORGANIZATION_INPUT' USING ERRCODE='22023';
  END IF;
  IF NOT (p_country = ANY (ARRAY['AD','AE','AF','AG','AI','AL','AM','AO','AQ','AR','AS','AT','AU','AW','AX','AZ','BA','BB','BD','BE','BF','BG','BH','BI','BJ','BL','BM','BN','BO','BQ','BR','BS','BT','BV','BW','BY','BZ','CA','CC','CD','CF','CG','CH','CI','CK','CL','CM','CN','CO','CR','CU','CV','CW','CX','CY','CZ','DE','DJ','DK','DM','DO','DZ','EC','EE','EG','EH','ER','ES','ET','FI','FJ','FK','FM','FO','FR','GA','GB','GD','GE','GF','GG','GH','GI','GL','GM','GN','GP','GQ','GR','GS','GT','GU','GW','GY','HK','HM','HN','HR','HT','HU','ID','IE','IL','IM','IN','IO','IQ','IR','IS','IT','JE','JM','JO','JP','KE','KG','KH','KI','KM','KN','KP','KR','KW','KY','KZ','LA','LB','LC','LI','LK','LR','LS','LT','LU','LV','LY','MA','MC','MD','ME','MF','MG','MH','MK','ML','MM','MN','MO','MP','MQ','MR','MS','MT','MU','MV','MW','MX','MY','MZ','NA','NC','NE','NF','NG','NI','NL','NO','NP','NR','NU','NZ','OM','PA','PE','PF','PG','PH','PK','PL','PM','PN','PR','PS','PT','PW','PY','QA','RE','RO','RS','RU','RW','SA','SB','SC','SD','SE','SG','SH','SI','SJ','SK','SL','SM','SN','SO','SR','SS','ST','SV','SX','SY','SZ','TC','TD','TF','TG','TH','TJ','TK','TL','TM','TN','TO','TR','TT','TV','TW','TZ','UA','UG','UM','US','UY','UZ','VA','VC','VE','VG','VI','VN','VU','WF','WS','YE','YT','ZA','ZM','ZW']::text[]))
     OR NOT (p_currency = ANY (ARRAY['AED','AFN','ALL','AMD','ANG','AOA','ARS','AUD','AWG','AZN','BAM','BBD','BDT','BGN','BHD','BIF','BMD','BND','BOB','BOV','BRL','BSD','BTN','BWP','BYN','BZD','CAD','CDF','CHE','CHF','CHW','CLF','CLP','CNY','COP','COU','CRC','CUC','CUP','CVE','CZK','DJF','DKK','DOP','DZD','EGP','ERN','ETB','EUR','FJD','FKP','GBP','GEL','GHS','GIP','GMD','GNF','GTQ','GYD','HKD','HNL','HRK','HTG','HUF','IDR','ILS','INR','IQD','IRR','ISK','JMD','JOD','JPY','KES','KGS','KHR','KMF','KPW','KRW','KWD','KYD','KZT','LAK','LBP','LKR','LRD','LSL','LYD','MAD','MDL','MGA','MKD','MMK','MNT','MOP','MRU','MUR','MVR','MWK','MXN','MXV','MYR','MZN','NAD','NGN','NIO','NOK','NPR','NZD','OMR','PAB','PEN','PGK','PHP','PKR','PLN','PYG','QAR','RON','RSD','RUB','RWF','SAR','SBD','SCR','SDG','SEK','SGD','SHP','SLE','SLL','SOS','SRD','SSP','STN','SVC','SYP','SZL','THB','TJS','TMT','TND','TOP','TRY','TTD','TWD','TZS','UAH','UGX','USD','USN','UYI','UYU','UYW','UZS','VED','VES','VND','VUV','WST','XAF','XAG','XAU','XBA','XBB','XBC','XBD','XCD','XDR','XOF','XPD','XPF','XPT','XSU','XTS','XUA','XXX','YER','ZAR','ZMW','ZWL']::text[])) THEN
    RAISE EXCEPTION 'INVALID_ORGANIZATION_INPUT' USING ERRCODE='22023';
  END IF;

  SELECT r.id INTO STRICT v_owner FROM public.roles r
    WHERE r.tenant_id IS NULL AND r.key='owner' AND r.is_system
      AND r.scope='organization' AND r.rank=100 FOR SHARE;
  BEGIN
    INSERT INTO public.tenants(name,slug,country,timezone,default_currency,contact_email,contact_phone,created_by,creation_key)
    VALUES(v_name,p_slug,p_country,p_timezone,p_currency,v_email,v_phone,v_actor,p_creation_key)
    RETURNING * INTO v_tenant;
    -- No direct counter update and no branch assignment for organization Owner.
    INSERT INTO public.memberships(tenant_id,user_id,role_id,status,joined_at)
    VALUES(v_tenant.id,v_actor,v_owner,'active',pg_catalog.now());
    -- Existing P2 triggers produce tenant/membership audit and counter updates.
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'ORGANIZATION_CONFLICT' USING ERRCODE='23505';
  END;
  IF NOT public.p2_has_org_permission(v_tenant.id,'organization.view') THEN
    RAISE EXCEPTION 'ORGANIZATION_ACCESS_FAILED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT v_tenant.id,v_tenant.name,v_tenant.slug::text,false;
END;
$create$;

ALTER FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text) TO authenticated;
COMMENT ON FUNCTION public.create_organization(uuid,text,text,text,text,text,text,text) IS
'Fixed verified-user command; initialized profile required; atomic tenant and initial Owner via P2 triggers. Same-creator authorized key replay returns existing unchanged. ISO-derived snapshot pycountry 24.6.1. No original payload equivalence guarantee.';

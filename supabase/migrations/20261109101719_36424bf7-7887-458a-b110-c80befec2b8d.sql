CREATE OR REPLACE FUNCTION public.p2_check_owner_invariant()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_status public.tenant_status; v_stored integer; v_actual integer;
BEGIN
  IF TG_TABLE_NAME = 'tenants' THEN
    IF TG_OP = 'DELETE' THEN
      v_tenant_id := OLD.id;
    ELSE
      v_tenant_id := NEW.id;
    END IF;
  ELSE
    IF TG_OP = 'DELETE' THEN
      v_tenant_id := OLD.tenant_id;
    ELSE
      v_tenant_id := NEW.tenant_id;
    END IF;
  END IF;
  SELECT t.status, t.active_owner_count INTO v_status, v_stored
    FROM public.tenants t WHERE t.id = v_tenant_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  SELECT count(*) INTO v_actual
    FROM public.memberships m JOIN public.roles r ON r.id = m.role_id
    WHERE m.tenant_id = v_tenant_id AND m.status = 'active'
      AND r.tenant_id IS NULL AND r.is_system AND r.key = 'owner'
      AND r.scope = 'organization' AND r.rank = 100;
  IF v_stored <> v_actual THEN
    RAISE EXCEPTION 'Stored Owner count does not match active Owner memberships' USING ERRCODE = '23514';
  END IF;
  IF v_status = 'active' AND v_actual < 1 THEN
    RAISE EXCEPTION 'Active tenant requires at least one active Owner' USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.p2_check_owner_invariant() FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON FUNCTION public.p2_check_owner_invariant() IS
  'Private deferred Owner invariant. Uses table-specific record fields, requires stored=actual for every tenant and at least one active Owner for active tenants.';

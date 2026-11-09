-- Logical Education ERP / M1 P2 / security primitives
-- Target: dedicated Dev Supabase project ojozmvvdpjmvsxmpgrul only.
-- Read-only application access, private audit/domain writers, branch invariants,
-- and concurrency-safe active Owner accounting. No business RPC or profile write.

DO $preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'P2 security definers must be owned by the reviewed postgres owner, not %', current_user;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
      AND (pg_catalog.pg_get_userbyid(c.relowner) <> 'postgres' OR c.relforcerowsecurity)
  ) THEN
    RAISE EXCEPTION 'Unexpected P1 table ownership or FORCE RLS state';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r') <> 12 THEN
    RAISE EXCEPTION 'P2 requires the exact twelve-table P1 baseline';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname = 'public') <> 0 THEN
    RAISE EXCEPTION 'P2 requires zero pre-existing public policies';
  END IF;
  IF (SELECT count(*) FROM public.roles) <> 5
     OR (SELECT count(*) FROM public.permissions) <> 14
     OR (SELECT count(*) FROM public.role_permissions) <> 37 THEN
    RAISE EXCEPTION 'P1 authorization catalog drift detected';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_attribute a
      JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'auth' AND c.relname = 'users'
        AND a.attname IN ('id','email','email_confirmed_at','banned_until','deleted_at','is_anonymous')
        AND NOT a.attisdropped) <> 6 THEN
    RAISE EXCEPTION 'Required Auth verification representation is unavailable';
  END IF;
END;
$preflight$;

REVOKE SELECT ON public.tenants FROM authenticated;
GRANT SELECT (id, name, slug, country, timezone, default_currency,
  contact_email, contact_phone, status, created_at, updated_at)
  ON public.tenants TO authenticated;

CREATE FUNCTION public.p2_private_user_is_verified(p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user_id
      AND u.email IS NOT NULL
      AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until <= pg_catalog.now())
      AND u.deleted_at IS NULL
      AND NOT u.is_anonymous
  );
$$;

CREATE FUNCTION public.p2_current_user_is_verified()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_private_user_is_verified(auth.uid());
$$;

CREATE FUNCTION public.p2_is_active_member(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_current_user_is_verified() AND EXISTS (
    SELECT 1
    FROM public.memberships m
    JOIN public.tenants t ON t.id = m.tenant_id AND t.status = 'active'
    JOIN public.roles r ON r.id = m.role_id
      AND (r.tenant_id IS NULL OR r.tenant_id = m.tenant_id)
      AND (r.tenant_id IS NOT NULL OR r.is_system)
    WHERE m.tenant_id = p_tenant_id
      AND m.user_id = auth.uid()
      AND m.status = 'active'
      AND CASE r.scope
        WHEN 'organization' THEN NOT EXISTS (
          SELECT 1 FROM public.membership_branches mb WHERE mb.membership_id = m.id
        )
        WHEN 'branch' THEN EXISTS (
          SELECT 1 FROM public.membership_branches mb
          JOIN public.branches b ON b.tenant_id = mb.tenant_id AND b.id = mb.branch_id
          WHERE mb.membership_id = m.id AND b.status = 'active'
        )
        ELSE false
      END
  );
$$;

CREATE FUNCTION public.p2_has_org_permission(p_tenant_id uuid, p_permission_key text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_current_user_is_verified() AND EXISTS (
    SELECT 1
    FROM public.memberships m
    JOIN public.tenants t ON t.id = m.tenant_id AND t.status = 'active'
    JOIN public.roles r ON r.id = m.role_id
      AND r.scope = 'organization'
      AND (r.tenant_id IS NULL OR r.tenant_id = m.tenant_id)
      AND (r.tenant_id IS NOT NULL OR r.is_system)
    JOIN public.role_permissions rp ON rp.role_id = r.id
      AND rp.permission_key = p_permission_key
    WHERE m.tenant_id = p_tenant_id
      AND m.user_id = auth.uid()
      AND m.status = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM public.membership_branches mb WHERE mb.membership_id = m.id
      )
  );
$$;

CREATE FUNCTION public.p2_has_tenant_permission(p_tenant_id uuid, p_permission_key text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_current_user_is_verified() AND EXISTS (
    SELECT 1
    FROM public.memberships m
    JOIN public.tenants t ON t.id = m.tenant_id AND t.status = 'active'
    JOIN public.roles r ON r.id = m.role_id
      AND (r.tenant_id IS NULL OR r.tenant_id = m.tenant_id)
      AND (r.tenant_id IS NOT NULL OR r.is_system)
    JOIN public.role_permissions rp ON rp.role_id = r.id
      AND rp.permission_key = p_permission_key
    WHERE m.tenant_id = p_tenant_id
      AND m.user_id = auth.uid()
      AND m.status = 'active'
      AND CASE r.scope
        WHEN 'organization' THEN NOT EXISTS (
          SELECT 1 FROM public.membership_branches mb WHERE mb.membership_id = m.id
        )
        WHEN 'branch' THEN EXISTS (
          SELECT 1 FROM public.membership_branches mb
          JOIN public.branches b ON b.tenant_id = mb.tenant_id AND b.id = mb.branch_id
          WHERE mb.membership_id = m.id AND b.status = 'active'
        )
        ELSE false
      END
  );
$$;

CREATE FUNCTION public.p2_has_branch_permission(
  p_tenant_id uuid, p_branch_id uuid, p_permission_key text
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_current_user_is_verified() AND EXISTS (
    SELECT 1
    FROM public.branches b
    JOIN public.tenants t ON t.id = b.tenant_id AND t.status = 'active'
    JOIN public.memberships m ON m.tenant_id = b.tenant_id
      AND m.user_id = auth.uid() AND m.status = 'active'
    JOIN public.roles r ON r.id = m.role_id
      AND (r.tenant_id IS NULL OR r.tenant_id = m.tenant_id)
      AND (r.tenant_id IS NOT NULL OR r.is_system)
    JOIN public.role_permissions rp ON rp.role_id = r.id
      AND rp.permission_key = p_permission_key
    WHERE b.tenant_id = p_tenant_id
      AND b.id = p_branch_id
      AND b.status = 'active'
      AND CASE r.scope
        WHEN 'organization' THEN NOT EXISTS (
          SELECT 1 FROM public.membership_branches mb WHERE mb.membership_id = m.id
        )
        WHEN 'branch' THEN EXISTS (
          SELECT 1 FROM public.membership_branches mb
          WHERE mb.membership_id = m.id AND mb.branch_id = b.id
        )
        ELSE false
      END
  );
$$;

CREATE FUNCTION public.p2_has_any_permission(p_permission_key text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE public.p2_has_tenant_permission(t.id, p_permission_key)
  );
$$;

CREATE FUNCTION public.p2_can_view_role(p_role_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid;
BEGIN
  SELECT r.tenant_id INTO v_tenant_id FROM public.roles r WHERE r.id = p_role_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  IF v_tenant_id IS NULL THEN
    RETURN public.p2_has_any_permission('role.view');
  END IF;
  RETURN public.p2_has_tenant_permission(v_tenant_id, 'role.view');
END;
$$;

CREATE FUNCTION public.p2_can_view_membership(p_membership_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_user_id uuid;
BEGIN
  SELECT m.tenant_id, m.user_id INTO v_tenant_id, v_user_id
    FROM public.memberships m WHERE m.id = p_membership_id;
  IF NOT FOUND OR NOT public.p2_is_active_member(v_tenant_id) THEN
    RETURN false;
  END IF;
  IF v_user_id = auth.uid() OR public.p2_has_org_permission(v_tenant_id, 'user.view') THEN
    RETURN true;
  END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.memberships target
    JOIN public.roles target_role ON target_role.id = target.role_id
      AND target_role.scope = 'branch'
    JOIN public.membership_branches mb ON mb.membership_id = target.id
    WHERE target.id = p_membership_id
      AND public.p2_has_branch_permission(target.tenant_id, mb.branch_id, 'user.view')
  );
END;
$$;

CREATE FUNCTION public.p2_can_view_invitation(p_invitation_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_scope public.role_scope;
BEGIN
  SELECT i.tenant_id, r.scope INTO v_tenant_id, v_scope
    FROM public.invitations i JOIN public.roles r ON r.id = i.role_id
    WHERE i.id = p_invitation_id;
  IF NOT FOUND OR NOT public.p2_is_active_member(v_tenant_id) THEN
    RETURN false;
  END IF;
  IF public.p2_has_org_permission(v_tenant_id, 'user.view') THEN
    RETURN true;
  END IF;
  IF v_scope <> 'branch' THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
      SELECT 1 FROM public.invitation_branches ib WHERE ib.invitation_id = p_invitation_id
    ) AND NOT EXISTS (
      SELECT 1 FROM public.invitation_branches ib
      WHERE ib.invitation_id = p_invitation_id
        AND NOT public.p2_has_branch_permission(v_tenant_id, ib.branch_id, 'user.view')
    );
END;
$$;

CREATE FUNCTION public.p2_is_platform_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.p2_current_user_is_verified() AND EXISTS (
    SELECT 1 FROM public.platform_admins pa WHERE pa.user_id = auth.uid()
  );
$$;

CREATE FUNCTION public.p2_private_validate_membership_branches(p_membership_id uuid)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_status public.membership_status; v_scope public.role_scope;
BEGIN
  SELECT m.status, r.scope INTO v_status, v_scope
    FROM public.memberships m JOIN public.roles r ON r.id = m.role_id
    WHERE m.id = p_membership_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF v_scope = 'organization' AND EXISTS (
    SELECT 1 FROM public.membership_branches mb WHERE mb.membership_id = p_membership_id
  ) THEN
    RAISE EXCEPTION 'Organization memberships cannot have branch links' USING ERRCODE = '23514';
  END IF;
  IF v_status = 'active' AND v_scope = 'branch' AND NOT EXISTS (
    SELECT 1 FROM public.membership_branches mb
    JOIN public.branches b ON b.tenant_id = mb.tenant_id AND b.id = mb.branch_id
    WHERE mb.membership_id = p_membership_id AND b.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Active branch membership requires an active assigned branch' USING ERRCODE = '23514';
  END IF;
END;
$$;

CREATE FUNCTION public.p2_private_validate_invitation_branches(
  p_invitation_id uuid, p_require_active boolean
)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_status public.invitation_status; v_scope public.role_scope;
BEGIN
  SELECT i.status, r.scope INTO v_status, v_scope
    FROM public.invitations i JOIN public.roles r ON r.id = i.role_id
    WHERE i.id = p_invitation_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF v_scope = 'organization' AND EXISTS (
    SELECT 1 FROM public.invitation_branches ib WHERE ib.invitation_id = p_invitation_id
  ) THEN
    RAISE EXCEPTION 'Organization invitations cannot have branch links' USING ERRCODE = '23514';
  END IF;
  IF v_status = 'pending' AND v_scope = 'branch' THEN
    IF NOT EXISTS (SELECT 1 FROM public.invitation_branches ib WHERE ib.invitation_id = p_invitation_id) THEN
      RAISE EXCEPTION 'Pending branch invitation requires offered branches' USING ERRCODE = '23514';
    END IF;
    IF p_require_active AND EXISTS (
      SELECT 1 FROM public.invitation_branches ib
      JOIN public.branches b ON b.tenant_id = ib.tenant_id AND b.id = ib.branch_id
      WHERE ib.invitation_id = p_invitation_id AND b.status <> 'active'
    ) THEN
      RAISE EXCEPTION 'New pending branch invitation requires only active branches' USING ERRCODE = '23514';
    END IF;
  END IF;
END;
$$;

CREATE FUNCTION public.p2_lock_branch_tenant()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid;
BEGIN
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  PERFORM 1 FROM public.tenants t WHERE t.id = v_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referenced tenant does not exist' USING ERRCODE = '23503';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.p2_guard_new_branch_link()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_scope public.role_scope; v_status text; v_branch_status public.record_status;
BEGIN
  SELECT b.status INTO v_branch_status FROM public.branches b
    WHERE b.tenant_id = NEW.tenant_id AND b.id = NEW.branch_id;
  IF v_branch_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'New branch links require an active same-tenant branch' USING ERRCODE = '23514';
  END IF;
  IF TG_TABLE_NAME = 'membership_branches' THEN
    SELECT r.scope, m.status::text INTO v_scope, v_status
      FROM public.memberships m JOIN public.roles r ON r.id = m.role_id
      WHERE m.tenant_id = NEW.tenant_id AND m.id = NEW.membership_id;
  ELSE
    SELECT r.scope, i.status::text INTO v_scope, v_status
      FROM public.invitations i JOIN public.roles r ON r.id = i.role_id
      WHERE i.tenant_id = NEW.tenant_id AND i.id = NEW.invitation_id;
    IF v_status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'Branch links can only be added to pending invitations' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF v_scope IS DISTINCT FROM 'branch' THEN
    RAISE EXCEPTION 'Only branch-scope rows can receive branch links' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.p2_validate_branch_sets()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid; v_membership_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'memberships' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
    PERFORM public.p2_private_validate_membership_branches(v_id);
  ELSIF TG_TABLE_NAME = 'membership_branches' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.membership_id ELSE NEW.membership_id END;
    PERFORM public.p2_private_validate_membership_branches(v_id);
  ELSIF TG_TABLE_NAME = 'invitations' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
    PERFORM public.p2_private_validate_invitation_branches(v_id,
      TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status <> 'pending' AND NEW.status = 'pending'));
  ELSIF TG_TABLE_NAME = 'invitation_branches' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.invitation_id ELSE NEW.invitation_id END;
    PERFORM public.p2_private_validate_invitation_branches(v_id, false);
  ELSIF TG_TABLE_NAME = 'branches' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
    FOR v_membership_id IN
      SELECT mb.membership_id FROM public.membership_branches mb WHERE mb.branch_id = v_id
    LOOP
      PERFORM public.p2_private_validate_membership_branches(v_membership_id);
    END LOOP;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER branches_00_tenant_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public.branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_lock_branch_tenant();
CREATE TRIGGER invitations_00_tenant_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.p2_lock_branch_tenant();
CREATE TRIGGER membership_branches_00_tenant_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public.membership_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_lock_branch_tenant();
CREATE TRIGGER invitation_branches_00_tenant_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public.invitation_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_lock_branch_tenant();
CREATE TRIGGER membership_branches_new_link_guard
  BEFORE INSERT OR UPDATE ON public.membership_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_new_branch_link();
CREATE TRIGGER invitation_branches_new_link_guard
  BEFORE INSERT OR UPDATE ON public.invitation_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_new_branch_link();
CREATE CONSTRAINT TRIGGER memberships_branch_set_validation
  AFTER INSERT OR UPDATE OR DELETE ON public.memberships
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_validate_branch_sets();
CREATE CONSTRAINT TRIGGER membership_branches_set_validation
  AFTER INSERT OR UPDATE OR DELETE ON public.membership_branches
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_validate_branch_sets();
CREATE CONSTRAINT TRIGGER invitations_branch_set_validation
  AFTER INSERT OR UPDATE OR DELETE ON public.invitations
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_validate_branch_sets();
CREATE CONSTRAINT TRIGGER invitation_branches_set_validation
  AFTER INSERT OR UPDATE OR DELETE ON public.invitation_branches
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_validate_branch_sets();
CREATE CONSTRAINT TRIGGER branches_membership_set_validation
  AFTER UPDATE OF status ON public.branches
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_validate_branch_sets();

CREATE FUNCTION public.p2_prevent_last_owner_loss()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_tenant_status public.tenant_status;
  v_old_owner boolean := false; v_new_owner boolean := false; v_actual integer;
BEGIN
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  SELECT t.status INTO v_tenant_status FROM public.tenants t WHERE t.id = v_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referenced tenant does not exist' USING ERRCODE = '23503';
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = OLD.role_id AND r.tenant_id IS NULL AND r.is_system
        AND r.key = 'owner' AND r.scope = 'organization' AND r.rank = 100
    ) INTO v_old_owner;
    v_old_owner := v_old_owner AND OLD.status = 'active';
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = NEW.role_id AND r.tenant_id IS NULL AND r.is_system
        AND r.key = 'owner' AND r.scope = 'organization' AND r.rank = 100
    ) INTO v_new_owner;
    v_new_owner := v_new_owner AND NEW.status = 'active';
  END IF;
  IF v_tenant_status = 'active' AND v_old_owner AND NOT v_new_owner THEN
    SELECT count(*) INTO v_actual
      FROM public.memberships m JOIN public.roles r ON r.id = m.role_id
      WHERE m.tenant_id = v_tenant_id AND m.status = 'active'
        AND r.tenant_id IS NULL AND r.is_system AND r.key = 'owner'
        AND r.scope = 'organization' AND r.rank = 100;
    IF v_actual <= 1 THEN
      RAISE EXCEPTION 'The last active Owner cannot be removed or demoted' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.p2_sync_active_owner()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_old_owner boolean := false; v_new_owner boolean := false; v_delta integer;
BEGIN
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = OLD.role_id AND r.tenant_id IS NULL AND r.is_system
        AND r.key = 'owner' AND r.scope = 'organization' AND r.rank = 100
    ) AND OLD.status = 'active' INTO v_old_owner;
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = NEW.role_id AND r.tenant_id IS NULL AND r.is_system
        AND r.key = 'owner' AND r.scope = 'organization' AND r.rank = 100
    ) AND NEW.status = 'active' INTO v_new_owner;
  END IF;
  v_delta := (CASE WHEN v_new_owner THEN 1 ELSE 0 END) - (CASE WHEN v_old_owner THEN 1 ELSE 0 END);
  IF v_delta <> 0 THEN
    UPDATE public.tenants t SET active_owner_count = t.active_owner_count + v_delta
      WHERE t.id = v_tenant_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_guard_owner_counter()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.active_owner_count <> 0 THEN
      RAISE EXCEPTION 'Initial Owner counter must be zero' USING ERRCODE = '23514';
    END IF;
  ELSIF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'Owner counter is maintained only by membership transitions' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.p2_check_owner_invariant()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid; v_status public.tenant_status; v_stored integer; v_actual integer;
BEGIN
  v_tenant_id := CASE WHEN TG_TABLE_NAME = 'tenants'
    THEN CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END
    ELSE CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END
  END;
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

CREATE TRIGGER memberships_owner_transition_lock
  BEFORE INSERT OR UPDATE OR DELETE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.p2_prevent_last_owner_loss();
CREATE TRIGGER memberships_owner_counter_sync
  AFTER INSERT OR UPDATE OF role_id, status OR DELETE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.p2_sync_active_owner();
CREATE TRIGGER tenants_owner_counter_guard
  BEFORE INSERT OR UPDATE OF active_owner_count ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_owner_counter();
CREATE CONSTRAINT TRIGGER memberships_owner_invariant
  AFTER INSERT OR UPDATE OF role_id, status OR DELETE ON public.memberships
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_check_owner_invariant();
CREATE CONSTRAINT TRIGGER tenants_owner_invariant
  AFTER INSERT OR UPDATE OF status, active_owner_count ON public.tenants
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.p2_check_owner_invariant();

CREATE FUNCTION public.p2_append_audit(
  p_tenant_id uuid, p_action text, p_entity_type text, p_entity_id uuid, p_metadata jsonb
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_allowed text[]; v_expected_entity text; v_changed_allowed text[];
  v_update_actions text[] := ARRAY['tenant.updated','branch.updated','membership.updated','invitation.updated'];
BEGIN
  v_expected_entity := CASE p_action
    WHEN 'tenant.created' THEN 'tenant' WHEN 'tenant.updated' THEN 'tenant' WHEN 'tenant.deleted' THEN 'tenant'
    WHEN 'branch.created' THEN 'branch' WHEN 'branch.updated' THEN 'branch' WHEN 'branch.deleted' THEN 'branch'
    WHEN 'membership.created' THEN 'membership' WHEN 'membership.updated' THEN 'membership' WHEN 'membership.deleted' THEN 'membership'
    WHEN 'membership_branch.added' THEN 'membership_branch' WHEN 'membership_branch.removed' THEN 'membership_branch'
    WHEN 'invitation.created' THEN 'invitation' WHEN 'invitation.updated' THEN 'invitation' WHEN 'invitation.deleted' THEN 'invitation'
    WHEN 'invitation_branch.added' THEN 'invitation_branch' WHEN 'invitation_branch.removed' THEN 'invitation_branch'
    ELSE NULL
  END;
  v_allowed := CASE p_action
    WHEN 'tenant.created' THEN ARRAY[]::text[] WHEN 'tenant.updated' THEN ARRAY['changed_fields'] WHEN 'tenant.deleted' THEN ARRAY[]::text[]
    WHEN 'branch.created' THEN ARRAY[]::text[] WHEN 'branch.updated' THEN ARRAY['changed_fields'] WHEN 'branch.deleted' THEN ARRAY[]::text[]
    WHEN 'membership.created' THEN ARRAY['user_id','role_id','status']
    WHEN 'membership.updated' THEN ARRAY['changed_fields','old_role_id','new_role_id','old_status','new_status']
    WHEN 'membership.deleted' THEN ARRAY['user_id','role_id','status']
    WHEN 'membership_branch.added' THEN ARRAY['membership_id','branch_id']
    WHEN 'membership_branch.removed' THEN ARRAY['membership_id','branch_id']
    WHEN 'invitation.created' THEN ARRAY['role_id','status']
    WHEN 'invitation.updated' THEN ARRAY['changed_fields','old_status','new_status']
    WHEN 'invitation.deleted' THEN ARRAY['role_id','status']
    WHEN 'invitation_branch.added' THEN ARRAY['invitation_id','branch_id']
    WHEN 'invitation_branch.removed' THEN ARRAY['invitation_id','branch_id']
    ELSE NULL
  END;
  IF v_allowed IS NULL OR p_metadata IS NULL OR pg_catalog.jsonb_typeof(p_metadata) <> 'object' THEN
    RAISE EXCEPTION 'Unapproved audit event or metadata' USING ERRCODE = '23514';
  END IF;
  IF auth.uid() IS NULL THEN
    p_metadata := p_metadata || pg_catalog.jsonb_build_object('event_source', 'system');
  ELSIF p_metadata ? 'event_source' THEN
    RAISE EXCEPTION 'Authenticated events cannot supply a system marker' USING ERRCODE = '23514';
  END IF;
  v_allowed := v_allowed || ARRAY['event_source'];
  IF EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_object_keys(p_metadata) k WHERE NOT k = ANY(v_allowed)
  ) THEN
    RAISE EXCEPTION 'Unapproved audit metadata key' USING ERRCODE = '23514';
  END IF;
  IF p_entity_type IS DISTINCT FROM v_expected_entity THEN
    RAISE EXCEPTION 'Audit action and entity type disagree' USING ERRCODE = '23514';
  END IF;
  IF p_action = ANY(v_update_actions) THEN
    IF NOT (p_metadata ? 'changed_fields') OR pg_catalog.jsonb_typeof(p_metadata -> 'changed_fields') <> 'array' THEN
      RAISE EXCEPTION 'Updated events require a changed-field array' USING ERRCODE = '23514';
    END IF;
    v_changed_allowed := CASE p_action
      WHEN 'tenant.updated' THEN ARRAY['name','country','timezone','default_currency','contact_email','contact_phone','status','settings']
      WHEN 'branch.updated' THEN ARRAY['name','code','address_line1','address_line2','city','state','postal_code','country','phone','email','timezone','status']
      WHEN 'membership.updated' THEN ARRAY['role_id','status','invited_by','joined_at']
      WHEN 'invitation.updated' THEN ARRAY['status','accepted_by','accepted_at']
      ELSE ARRAY[]::text[]
    END;
    IF EXISTS (
      SELECT 1 FROM pg_catalog.jsonb_array_elements_text(p_metadata -> 'changed_fields') f
      WHERE NOT f = ANY(v_changed_allowed)
    ) THEN
      RAISE EXCEPTION 'Unapproved changed-field name' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF p_action IN ('membership.created','membership.deleted') AND NOT (
    p_metadata ? 'user_id' AND p_metadata ? 'role_id' AND p_metadata ? 'status'
    AND pg_catalog.jsonb_typeof(p_metadata -> 'status') = 'string'
    AND p_metadata ->> 'status' = ANY(ARRAY['active','invited','suspended','removed'])
  ) THEN
    RAISE EXCEPTION 'Invalid membership audit fields' USING ERRCODE = '23514';
  END IF;
  IF p_action = 'membership.updated' AND NOT (
    p_metadata ? 'old_role_id' AND p_metadata ? 'new_role_id' AND p_metadata ? 'old_status' AND p_metadata ? 'new_status'
    AND p_metadata ->> 'old_status' = ANY(ARRAY['active','invited','suspended','removed'])
    AND p_metadata ->> 'new_status' = ANY(ARRAY['active','invited','suspended','removed'])
  ) THEN
    RAISE EXCEPTION 'Invalid membership transition audit fields' USING ERRCODE = '23514';
  END IF;
  IF p_action IN ('invitation.created','invitation.deleted') AND NOT (
    p_metadata ? 'role_id' AND p_metadata ? 'status'
    AND p_metadata ->> 'status' = ANY(ARRAY['pending','accepted','revoked','expired'])
  ) THEN
    RAISE EXCEPTION 'Invalid invitation audit fields' USING ERRCODE = '23514';
  END IF;
  IF p_action = 'invitation.updated' AND NOT (
    p_metadata ? 'old_status' AND p_metadata ? 'new_status'
    AND p_metadata ->> 'old_status' = ANY(ARRAY['pending','accepted','revoked','expired'])
    AND p_metadata ->> 'new_status' = ANY(ARRAY['pending','accepted','revoked','expired'])
  ) THEN
    RAISE EXCEPTION 'Invalid invitation transition audit fields' USING ERRCODE = '23514';
  END IF;
  IF p_action IN ('membership_branch.added','membership_branch.removed') AND NOT (
    p_metadata ? 'membership_id' AND p_metadata ? 'branch_id'
  ) THEN
    RAISE EXCEPTION 'Invalid membership-branch audit fields' USING ERRCODE = '23514';
  END IF;
  IF p_action IN ('invitation_branch.added','invitation_branch.removed') AND NOT (
    p_metadata ? 'invitation_id' AND p_metadata ? 'branch_id'
  ) THEN
    RAISE EXCEPTION 'Invalid invitation-branch audit fields' USING ERRCODE = '23514';
  END IF;
  INSERT INTO public.audit_logs (tenant_id, actor_id, action, entity_type, entity_id, metadata, ip)
  VALUES (p_tenant_id, auth.uid(), p_action, p_entity_type, p_entity_id, p_metadata, NULL);
END;
$$;

CREATE FUNCTION public.p2_audit_tenant()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_id uuid; v_metadata jsonb := '{}'::jsonb;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_catalog.to_jsonb(OLD) - 'updated_at' - 'active_owner_count'
     = pg_catalog.to_jsonb(NEW) - 'updated_at' - 'active_owner_count' THEN
    RETURN NULL;
  END IF;
  v_action := CASE TG_OP WHEN 'INSERT' THEN 'tenant.created' WHEN 'UPDATE' THEN 'tenant.updated' ELSE 'tenant.deleted' END;
  v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(pg_catalog.jsonb_agg(k), '[]'::jsonb) INTO v_metadata
      FROM pg_catalog.jsonb_object_keys(pg_catalog.to_jsonb(NEW) - 'updated_at' - 'active_owner_count') k
      WHERE (pg_catalog.to_jsonb(OLD) -> k) IS DISTINCT FROM (pg_catalog.to_jsonb(NEW) -> k);
    v_metadata := pg_catalog.jsonb_build_object('changed_fields', v_metadata);
  END IF;
  PERFORM public.p2_append_audit(v_id, v_action, 'tenant', v_id, v_metadata);
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_audit_branch()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_tenant_id uuid; v_id uuid; v_metadata jsonb := '{}'::jsonb;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_catalog.to_jsonb(OLD) - 'updated_at' = pg_catalog.to_jsonb(NEW) - 'updated_at' THEN
    RETURN NULL;
  END IF;
  v_action := CASE TG_OP WHEN 'INSERT' THEN 'branch.created' WHEN 'UPDATE' THEN 'branch.updated' ELSE 'branch.deleted' END;
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(pg_catalog.jsonb_agg(k), '[]'::jsonb) INTO v_metadata
      FROM pg_catalog.jsonb_object_keys(pg_catalog.to_jsonb(NEW) - 'updated_at') k
      WHERE (pg_catalog.to_jsonb(OLD) -> k) IS DISTINCT FROM (pg_catalog.to_jsonb(NEW) -> k);
    v_metadata := pg_catalog.jsonb_build_object('changed_fields', v_metadata);
  END IF;
  PERFORM public.p2_append_audit(v_tenant_id, v_action, 'branch', v_id, v_metadata);
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_audit_membership()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_tenant_id uuid; v_id uuid; v_metadata jsonb;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_catalog.to_jsonb(OLD) - 'updated_at' = pg_catalog.to_jsonb(NEW) - 'updated_at' THEN
    RETURN NULL;
  END IF;
  v_action := CASE TG_OP WHEN 'INSERT' THEN 'membership.created' WHEN 'UPDATE' THEN 'membership.updated' ELSE 'membership.deleted' END;
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  IF TG_OP = 'INSERT' THEN
    v_metadata := pg_catalog.jsonb_build_object('user_id', NEW.user_id, 'role_id', NEW.role_id, 'status', NEW.status);
  ELSIF TG_OP = 'DELETE' THEN
    v_metadata := pg_catalog.jsonb_build_object('user_id', OLD.user_id, 'role_id', OLD.role_id, 'status', OLD.status);
  ELSE
    SELECT pg_catalog.jsonb_build_object(
      'changed_fields', COALESCE(pg_catalog.jsonb_agg(k), '[]'::jsonb),
      'old_role_id', OLD.role_id, 'new_role_id', NEW.role_id,
      'old_status', OLD.status, 'new_status', NEW.status
    ) INTO v_metadata
    FROM pg_catalog.jsonb_object_keys(pg_catalog.to_jsonb(NEW) - 'updated_at') k
    WHERE (pg_catalog.to_jsonb(OLD) -> k) IS DISTINCT FROM (pg_catalog.to_jsonb(NEW) -> k);
  END IF;
  PERFORM public.p2_append_audit(v_tenant_id, v_action, 'membership', v_id, v_metadata);
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_audit_membership_branch()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_tenant_id uuid; v_membership_id uuid; v_branch_id uuid;
BEGIN
  v_action := CASE WHEN TG_OP = 'INSERT' THEN 'membership_branch.added' ELSE 'membership_branch.removed' END;
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  v_membership_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.membership_id ELSE NEW.membership_id END;
  v_branch_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.branch_id ELSE NEW.branch_id END;
  PERFORM public.p2_append_audit(v_tenant_id, v_action, 'membership_branch', v_membership_id,
    pg_catalog.jsonb_build_object('membership_id', v_membership_id, 'branch_id', v_branch_id));
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_audit_invitation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_tenant_id uuid; v_id uuid; v_metadata jsonb;
BEGIN
  IF TG_OP = 'UPDATE' AND pg_catalog.to_jsonb(OLD) - 'updated_at' = pg_catalog.to_jsonb(NEW) - 'updated_at' THEN
    RETURN NULL;
  END IF;
  v_action := CASE TG_OP WHEN 'INSERT' THEN 'invitation.created' WHEN 'UPDATE' THEN 'invitation.updated' ELSE 'invitation.deleted' END;
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  IF TG_OP = 'INSERT' THEN
    v_metadata := pg_catalog.jsonb_build_object('role_id', NEW.role_id, 'status', NEW.status);
  ELSIF TG_OP = 'DELETE' THEN
    v_metadata := pg_catalog.jsonb_build_object('role_id', OLD.role_id, 'status', OLD.status);
  ELSE
    SELECT pg_catalog.jsonb_build_object(
      'changed_fields', COALESCE(pg_catalog.jsonb_agg(k), '[]'::jsonb),
      'old_status', OLD.status, 'new_status', NEW.status
    ) INTO v_metadata
    FROM pg_catalog.jsonb_object_keys(pg_catalog.to_jsonb(NEW) - 'updated_at') k
    WHERE (pg_catalog.to_jsonb(OLD) -> k) IS DISTINCT FROM (pg_catalog.to_jsonb(NEW) -> k);
  END IF;
  PERFORM public.p2_append_audit(v_tenant_id, v_action, 'invitation', v_id, v_metadata);
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.p2_audit_invitation_branch()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_action text; v_tenant_id uuid; v_invitation_id uuid; v_branch_id uuid;
BEGIN
  v_action := CASE WHEN TG_OP = 'INSERT' THEN 'invitation_branch.added' ELSE 'invitation_branch.removed' END;
  v_tenant_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tenant_id ELSE NEW.tenant_id END;
  v_invitation_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.invitation_id ELSE NEW.invitation_id END;
  v_branch_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.branch_id ELSE NEW.branch_id END;
  PERFORM public.p2_append_audit(v_tenant_id, v_action, 'invitation_branch', v_invitation_id,
    pg_catalog.jsonb_build_object('invitation_id', v_invitation_id, 'branch_id', v_branch_id));
  RETURN NULL;
END;
$$;

CREATE TRIGGER tenants_audit AFTER INSERT OR UPDATE OR DELETE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_tenant();
CREATE TRIGGER branches_audit AFTER INSERT OR UPDATE OR DELETE ON public.branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_branch();
CREATE TRIGGER memberships_audit AFTER INSERT OR UPDATE OR DELETE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_membership();
CREATE TRIGGER membership_branches_audit AFTER INSERT OR DELETE ON public.membership_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_membership_branch();
CREATE TRIGGER invitations_audit AFTER INSERT OR UPDATE OR DELETE ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_invitation();
CREATE TRIGGER invitation_branches_audit AFTER INSERT OR DELETE ON public.invitation_branches
  FOR EACH ROW EXECUTE FUNCTION public.p2_audit_invitation_branch();

CREATE FUNCTION public.p2_guard_audit_immutable()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Audit entries are immutable' USING ERRCODE = '23514';
END;
$$;
CREATE FUNCTION public.p2_guard_audit_truncate()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Audit entries cannot be truncated' USING ERRCODE = '23514';
END;
$$;
CREATE TRIGGER audit_logs_immutable BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_audit_immutable();
CREATE TRIGGER audit_logs_truncate_guard BEFORE TRUNCATE ON public.audit_logs
  FOR EACH STATEMENT EXECUTE FUNCTION public.p2_guard_audit_truncate();

CREATE FUNCTION public.p2_guard_system_catalog()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'permissions' THEN
    RAISE EXCEPTION 'Permission catalog is migration-controlled' USING ERRCODE = '23514';
  END IF;
  IF TG_OP IN ('UPDATE','DELETE') THEN
    IF TG_TABLE_NAME = 'roles' THEN
      v_tenant_id := OLD.tenant_id;
    ELSE
      SELECT r.tenant_id INTO v_tenant_id FROM public.roles r WHERE r.id = OLD.role_id;
    END IF;
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'Existing global system catalog rows are migration-controlled' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF TG_OP IN ('INSERT','UPDATE') THEN
    v_tenant_id := NULL;
    IF TG_TABLE_NAME = 'roles' THEN
      v_tenant_id := NEW.tenant_id;
    ELSE
      SELECT r.tenant_id INTO v_tenant_id FROM public.roles r WHERE r.id = NEW.role_id;
    END IF;
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'New global system catalog rows are migration-controlled' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;
CREATE FUNCTION public.p2_guard_system_catalog_truncate()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Authorization catalogs cannot be truncated' USING ERRCODE = '23514';
END;
$$;
CREATE TRIGGER roles_system_catalog_guard BEFORE INSERT OR UPDATE OR DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_system_catalog();
CREATE TRIGGER permissions_system_catalog_guard BEFORE INSERT OR UPDATE OR DELETE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_system_catalog();
CREATE TRIGGER role_permissions_system_catalog_guard BEFORE INSERT OR UPDATE OR DELETE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.p2_guard_system_catalog();
CREATE TRIGGER roles_system_catalog_truncate_guard BEFORE TRUNCATE ON public.roles
  FOR EACH STATEMENT EXECUTE FUNCTION public.p2_guard_system_catalog_truncate();
CREATE TRIGGER permissions_system_catalog_truncate_guard BEFORE TRUNCATE ON public.permissions
  FOR EACH STATEMENT EXECUTE FUNCTION public.p2_guard_system_catalog_truncate();
CREATE TRIGGER role_permissions_system_catalog_truncate_guard BEFORE TRUNCATE ON public.role_permissions
  FOR EACH STATEMENT EXECUTE FUNCTION public.p2_guard_system_catalog_truncate();

CREATE POLICY tenants_select_member ON public.tenants FOR SELECT TO authenticated
  USING (public.p2_has_tenant_permission(id, 'organization.view'));
CREATE POLICY branches_select_scoped ON public.branches FOR SELECT TO authenticated
  USING (public.p2_has_branch_permission(tenant_id, id, 'branch.view'));
CREATE POLICY profiles_select_self ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid());
CREATE POLICY roles_select_catalog ON public.roles FOR SELECT TO authenticated
  USING (public.p2_can_view_role(id));
CREATE POLICY permissions_select_catalog ON public.permissions FOR SELECT TO authenticated
  USING (public.p2_has_any_permission('role.view'));
CREATE POLICY role_permissions_select_scoped ON public.role_permissions FOR SELECT TO authenticated
  USING (public.p2_can_view_role(role_id));
CREATE POLICY memberships_select_scoped ON public.memberships FOR SELECT TO authenticated
  USING (public.p2_can_view_membership(id));
CREATE POLICY membership_branches_select_scoped ON public.membership_branches FOR SELECT TO authenticated
  USING (public.p2_can_view_membership(membership_id)
    AND public.p2_has_branch_permission(tenant_id, branch_id, 'branch.view'));
CREATE POLICY invitations_select_scoped ON public.invitations FOR SELECT TO authenticated
  USING (public.p2_can_view_invitation(id));
CREATE POLICY invitation_branches_select_scoped ON public.invitation_branches FOR SELECT TO authenticated
  USING (public.p2_can_view_invitation(invitation_id)
    AND public.p2_has_branch_permission(tenant_id, branch_id, 'branch.view'));
CREATE POLICY audit_logs_select_organization ON public.audit_logs FOR SELECT TO authenticated
  USING (tenant_id IS NOT NULL AND public.p2_has_org_permission(tenant_id, 'audit.view'));
CREATE POLICY platform_admins_select_self ON public.platform_admins FOR SELECT TO authenticated
  USING (public.p2_current_user_is_verified() AND user_id = auth.uid());

REVOKE ALL ON FUNCTION public.p2_private_user_is_verified(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_private_validate_membership_branches(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_private_validate_invitation_branches(uuid,boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_lock_branch_tenant() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_new_branch_link() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_validate_branch_sets() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_prevent_last_owner_loss() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_sync_active_owner() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_owner_counter() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_check_owner_invariant() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_append_audit(uuid,text,text,uuid,jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_tenant() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_branch() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_membership() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_membership_branch() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_invitation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_audit_invitation_branch() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_audit_immutable() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_audit_truncate() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_system_catalog() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.p2_guard_system_catalog_truncate() FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.p2_current_user_is_verified() FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_is_active_member(uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_has_org_permission(uuid,text) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_has_tenant_permission(uuid,text) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_has_branch_permission(uuid,uuid,text) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_has_any_permission(text) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_can_view_role(uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_can_view_membership(uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_can_view_invitation(uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_is_platform_admin() FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.p2_current_user_is_verified() FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_is_active_member(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_has_org_permission(uuid,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_has_tenant_permission(uuid,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_has_branch_permission(uuid,uuid,text) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_has_any_permission(text) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_can_view_role(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_can_view_membership(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_can_view_invitation(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.p2_is_platform_admin() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.p2_current_user_is_verified() TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_is_active_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_has_org_permission(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_has_tenant_permission(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_has_branch_permission(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_has_any_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_can_view_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_can_view_membership(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_can_view_invitation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.p2_is_platform_admin() TO authenticated;

COMMENT ON FUNCTION public.p2_append_audit(uuid,text,text,uuid,jsonb) IS
  'Private fixed row-event writer. Actions: tenant/branch/membership/invitation created,updated,deleted; membership_branch and invitation_branch added,removed. Metadata is restricted to changed field names and explicitly allowlisted UUID/status values; null actors are marked event_source=system; counter-only tenant updates emit no event.';
COMMENT ON COLUMN public.tenants.active_owner_count IS
  'Maintained solely by p2_sync_active_owner after tenant-serialized membership transitions. Deferred invariant requires stored=actual for every tenant and actual>=1 for active tenants.';

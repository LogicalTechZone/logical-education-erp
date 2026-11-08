-- Logical Education ERP / M1 P1 / FINAL REVIEW DRAFT v1
-- Target: dedicated Dev Supabase project ojozmvvdpjmvsxmpgrul ONLY.
-- NOT APPLIED. Execute only via the Supabase migration tool after review approval.
-- P1 creates schema, catalog seeds and structural integrity. P2 owns access
-- policies, audit triggers, profile lifecycle and concurrency-safe Owner guards.
-- Until P2/P3: no application DML grants, no policies, no authenticated RPCs.
-- No tenant, branch, profile, membership, invitation or platform-admin seed rows.
-- Execute as one migration transaction; intentionally fail on existing objects.

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

CREATE TYPE public.tenant_status AS ENUM ('active', 'suspended', 'archived');
CREATE TYPE public.record_status AS ENUM ('active', 'inactive');
CREATE TYPE public.membership_status AS ENUM ('active', 'invited', 'suspended', 'removed');
CREATE TYPE public.invitation_status AS ENUM ('pending', 'accepted', 'revoked', 'expired');
CREATE TYPE public.role_scope AS ENUM ('organization', 'branch');

CREATE TABLE public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug extensions.citext NOT NULL UNIQUE,
  country character(2) NOT NULL,
  timezone text NOT NULL,
  default_currency character(3) NOT NULL,
  contact_email extensions.citext,
  contact_phone text,
  status public.tenant_status NOT NULL DEFAULT 'active',
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid NOT NULL,
  creation_key uuid NOT NULL UNIQUE,
  active_owner_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.tenants TO authenticated;
GRANT ALL ON public.tenants TO service_role;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  name text NOT NULL,
  code text NOT NULL,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country character(2) NOT NULL,
  phone text,
  email extensions.citext,
  timezone text NOT NULL,
  status public.record_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (tenant_id, id)
);
GRANT SELECT ON public.branches TO authenticated;
GRANT ALL ON public.branches TO service_role;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  avatar_url text,
  phone text,
  theme_preference text NOT NULL DEFAULT 'light',
  last_tenant_id uuid REFERENCES public.tenants(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE RESTRICT,
  key text NOT NULL,
  name text NOT NULL,
  description text,
  scope public.role_scope NOT NULL,
  is_system boolean NOT NULL DEFAULT false,
  rank integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, key),
  UNIQUE (tenant_id, id)
);
GRANT SELECT ON public.roles TO authenticated;
GRANT ALL ON public.roles TO service_role;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX roles_system_key_unique ON public.roles(key) WHERE tenant_id IS NULL;

CREATE TABLE public.permissions (
  key text PRIMARY KEY,
  module text NOT NULL,
  action text NOT NULL,
  description text NOT NULL
);
GRANT SELECT ON public.permissions TO authenticated;
GRANT ALL ON public.permissions TO service_role;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.role_permissions (
  role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_key text NOT NULL REFERENCES public.permissions(key) ON DELETE RESTRICT,
  PRIMARY KEY (role_id, permission_key)
);
GRANT SELECT ON public.role_permissions TO authenticated;
GRANT ALL ON public.role_permissions TO service_role;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  status public.membership_status NOT NULL DEFAULT 'invited',
  invited_by uuid,
  joined_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id),
  UNIQUE (tenant_id, id)
);
GRANT SELECT ON public.memberships TO authenticated;
GRANT ALL ON public.memberships TO service_role;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.membership_branches (
  tenant_id uuid NOT NULL,
  membership_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  PRIMARY KEY (membership_id, branch_id),
  FOREIGN KEY (tenant_id, membership_id)
    REFERENCES public.memberships(tenant_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE RESTRICT
);
GRANT SELECT ON public.membership_branches TO authenticated;
GRANT ALL ON public.membership_branches TO service_role;
ALTER TABLE public.membership_branches ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
  email extensions.citext NOT NULL,
  role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  token_hash text NOT NULL UNIQUE,
  status public.invitation_status NOT NULL DEFAULT 'pending',
  invited_by uuid NOT NULL,
  inviter_membership_id uuid NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_by uuid,
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, inviter_membership_id)
    REFERENCES public.memberships(tenant_id, id) ON DELETE RESTRICT
);
-- Deliberately no table-level authenticated SELECT: token_hash is never selectable.
GRANT SELECT (id, tenant_id, email, role_id, status, invited_by,
  inviter_membership_id, expires_at, accepted_by, accepted_at, created_at, updated_at)
  ON public.invitations TO authenticated;
GRANT ALL ON public.invitations TO service_role;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX invitations_pending_email_unique
  ON public.invitations(tenant_id, email) WHERE status = 'pending';

CREATE TABLE public.invitation_branches (
  tenant_id uuid NOT NULL,
  invitation_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  PRIMARY KEY (invitation_id, branch_id),
  FOREIGN KEY (tenant_id, invitation_id)
    REFERENCES public.invitations(tenant_id, id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id, branch_id)
    REFERENCES public.branches(tenant_id, id) ON DELETE RESTRICT
);
GRANT SELECT ON public.invitation_branches TO authenticated;
GRANT ALL ON public.invitation_branches TO service_role;
ALTER TABLE public.invitation_branches ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE RESTRICT,
  actor_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.audit_logs TO authenticated;
-- Least privilege: append/read only, including privileged application client.
GRANT SELECT, INSERT ON public.audit_logs TO service_role;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
GRANT USAGE, SELECT ON SEQUENCE public.audit_logs_id_seq TO service_role;

CREATE TABLE public.platform_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  granted_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.platform_admins TO authenticated;
GRANT ALL ON public.platform_admins TO service_role;
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
-- No seed here. P9 controlled bootstrap resolves the verified account for
-- logicaltechzoneofficial@gmail.com to its authenticated immutable user UUID.

-- FK traversal / tenant filtering / dashboard and audit indexes.
CREATE INDEX branches_tenant_status_idx ON public.branches(tenant_id, status);
CREATE INDEX profiles_last_tenant_idx ON public.profiles(last_tenant_id);
CREATE INDEX roles_tenant_idx ON public.roles(tenant_id);
CREATE INDEX role_permissions_permission_idx ON public.role_permissions(permission_key);
CREATE INDEX memberships_user_tenant_status_idx ON public.memberships(user_id, tenant_id, status);
CREATE INDEX memberships_tenant_status_idx ON public.memberships(tenant_id, status);
CREATE INDEX memberships_role_idx ON public.memberships(role_id);
CREATE INDEX membership_branches_tenant_branch_idx ON public.membership_branches(tenant_id, branch_id);
CREATE INDEX membership_branches_tenant_member_idx ON public.membership_branches(tenant_id, membership_id);
CREATE INDEX invitations_tenant_status_expiry_idx ON public.invitations(tenant_id, status, expires_at);
CREATE INDEX invitations_role_idx ON public.invitations(role_id);
CREATE INDEX invitations_inviter_idx ON public.invitations(tenant_id, inviter_membership_id);
CREATE INDEX invitation_branches_tenant_branch_idx ON public.invitation_branches(tenant_id, branch_id);
CREATE INDEX invitation_branches_tenant_invite_idx ON public.invitation_branches(tenant_id, invitation_id);
CREATE INDEX audit_logs_tenant_created_idx ON public.audit_logs(tenant_id, created_at DESC);
CREATE INDEX audit_logs_entity_idx ON public.audit_logs(entity_type, entity_id);

-- Structural identity guard: no reassignment of IDs, tenancy or grant identity.
-- Invoker function does not read privileged data. Trigger invocation remains
-- possible after EXECUTE revocation; clients cannot call trigger functions.
CREATE FUNCTION public.p1_guard_identity() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE column_name text;
BEGIN
  FOREACH column_name IN ARRAY TG_ARGV LOOP
    IF (to_jsonb(NEW) -> column_name) IS DISTINCT FROM (to_jsonb(OLD) -> column_name) THEN
      RAISE EXCEPTION 'Immutable identity column: %', column_name USING ERRCODE = '23514';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.p1_guard_identity() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER tenants_identity_guard BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','slug','created_by','creation_key','created_at');
CREATE TRIGGER branches_identity_guard BEFORE UPDATE ON public.branches
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','tenant_id','created_at');
CREATE TRIGGER profiles_identity_guard BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','created_at');
CREATE TRIGGER roles_identity_guard BEFORE UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','tenant_id','key','scope','is_system','rank','created_at');
CREATE TRIGGER memberships_identity_guard BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','tenant_id','user_id','created_at');
CREATE TRIGGER membership_branches_identity_guard BEFORE UPDATE ON public.membership_branches
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('tenant_id','membership_id','branch_id');
CREATE TRIGGER invitations_identity_guard BEFORE UPDATE ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('id','tenant_id','email','role_id','token_hash','invited_by','inviter_membership_id','expires_at','created_at');
CREATE TRIGGER invitation_branches_identity_guard BEFORE UPDATE ON public.invitation_branches
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('tenant_id','invitation_id','branch_id');
CREATE TRIGGER platform_admins_identity_guard BEFORE UPDATE ON public.platform_admins
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('user_id','granted_by','created_at');
CREATE TRIGGER role_permissions_identity_guard BEFORE UPDATE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('role_id','permission_key');
CREATE TRIGGER permissions_identity_guard BEFORE UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.p1_guard_identity('key','module','action');

-- Validation triggers, not volatile CHECK constraints.
CREATE FUNCTION public.p1_validate_fields() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_TABLE_NAME IN ('tenants', 'branches') THEN
    IF char_length(btrim(NEW.name)) NOT BETWEEN 2 AND 120 THEN
      RAISE EXCEPTION 'Name must be 2-120 characters' USING ERRCODE = '23514';
    END IF;
    IF NEW.country::text !~ '^[A-Z]{2}$' THEN
      RAISE EXCEPTION 'Country must be a two-letter uppercase code' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names z WHERE z.name = NEW.timezone) THEN
      RAISE EXCEPTION 'Invalid IANA timezone' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF TG_TABLE_NAME = 'tenants' THEN
    IF char_length(NEW.slug::text) NOT BETWEEN 3 AND 50 OR NEW.slug::text !~ '^[a-z0-9](-?[a-z0-9])+$' THEN
      RAISE EXCEPTION 'Invalid organization slug' USING ERRCODE = '23514';
    END IF;
    IF NEW.default_currency::text !~ '^[A-Z]{3}$' OR jsonb_typeof(NEW.settings) <> 'object' OR NEW.active_owner_count < 0 THEN
      RAISE EXCEPTION 'Invalid tenant currency, settings or counter' USING ERRCODE = '23514';
    END IF;
  ELSIF TG_TABLE_NAME = 'branches' THEN
    IF NEW.code !~ '^[A-Z0-9-]{1,20}$' THEN
      RAISE EXCEPTION 'Invalid branch code' USING ERRCODE = '23514';
    END IF;
  ELSIF TG_TABLE_NAME = 'profiles' THEN
    IF NEW.theme_preference NOT IN ('light', 'dark') THEN
      RAISE EXCEPTION 'Theme must be light or dark' USING ERRCODE = '23514';
    END IF;
  ELSIF TG_TABLE_NAME = 'roles' THEN
    IF NEW.is_system IS DISTINCT FROM (NEW.tenant_id IS NULL)
      OR NEW.key !~ '^[a-z][a-z0-9_]{1,49}$'
      OR char_length(btrim(NEW.name)) NOT BETWEEN 2 AND 120
      OR NEW.rank NOT BETWEEN 1 AND 100 THEN
      RAISE EXCEPTION 'Invalid role identity or rank' USING ERRCODE = '23514';
    END IF;
    IF NEW.tenant_id IS NOT NULL AND (NEW.key IN ('owner','organization_admin','branch_manager','staff','read_only') OR NEW.rank >= 100) THEN
      RAISE EXCEPTION 'Reserved system role identity' USING ERRCODE = '23514';
    END IF;
    IF NEW.tenant_id IS NULL AND NOT (
      (NEW.key = 'owner' AND NEW.scope = 'organization' AND NEW.rank = 100) OR
      (NEW.key = 'organization_admin' AND NEW.scope = 'organization' AND NEW.rank = 80) OR
      (NEW.key = 'branch_manager' AND NEW.scope = 'branch' AND NEW.rank = 50) OR
      (NEW.key = 'staff' AND NEW.scope = 'branch' AND NEW.rank = 20) OR
      (NEW.key = 'read_only' AND NEW.scope = 'branch' AND NEW.rank = 10)
    ) THEN
      RAISE EXCEPTION 'Unrecognized system role semantics' USING ERRCODE = '23514';
    END IF;
  ELSIF TG_TABLE_NAME = 'permissions' THEN
    IF NEW.key <> NEW.module || '.' || NEW.action OR NEW.key !~ '^[a-z_]+\.[a-z_]+$' THEN
      RAISE EXCEPTION 'Invalid permission key' USING ERRCODE = '23514';
    END IF;
  ELSIF TG_TABLE_NAME = 'invitations' THEN
    IF NEW.token_hash !~ '^[0-9a-f]{64}$' OR NEW.email::text !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
      RAISE EXCEPTION 'Invalid invitation email or token hash' USING ERRCODE = '23514';
    END IF;
    IF NEW.expires_at <= NEW.created_at THEN
      RAISE EXCEPTION 'Invitation expiry must follow creation' USING ERRCODE = '23514';
    END IF;
    IF (NEW.status = 'accepted' AND (NEW.accepted_by IS NULL OR NEW.accepted_at IS NULL))
      OR (NEW.status <> 'accepted' AND (NEW.accepted_by IS NOT NULL OR NEW.accepted_at IS NOT NULL)) THEN
      RAISE EXCEPTION 'Invalid invitation acceptance fields' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.p1_validate_fields() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER tenants_field_validation BEFORE INSERT OR UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();
CREATE TRIGGER branches_field_validation BEFORE INSERT OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();
CREATE TRIGGER profiles_field_validation BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();
CREATE TRIGGER roles_field_validation BEFORE INSERT OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();
CREATE TRIGGER permissions_field_validation BEFORE INSERT OR UPDATE ON public.permissions FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();
CREATE TRIGGER invitations_field_validation BEFORE INSERT OR UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.p1_validate_fields();

-- A plain FK cannot enforce same-tenant role assignments with NULL global roles.
-- Only this trigger reads roles under definer privilege, for integrity not auth.
-- Fixed search_path, qualified reads, row-share lock, no client EXECUTE grant.
CREATE FUNCTION public.p1_validate_role_assignment() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE role_tenant uuid; role_is_system boolean;
BEGIN
  SELECT r.tenant_id, r.is_system INTO role_tenant, role_is_system
    FROM public.roles r WHERE r.id = NEW.role_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referenced role does not exist' USING ERRCODE = '23503';
  END IF;
  IF NOT ((role_tenant IS NULL AND role_is_system) OR role_tenant = NEW.tenant_id) THEN
    RAISE EXCEPTION 'Cross-tenant role assignment rejected' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.p1_validate_role_assignment() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER memberships_role_integrity BEFORE INSERT OR UPDATE OF role_id, tenant_id ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.p1_validate_role_assignment();
CREATE TRIGGER invitations_role_integrity BEFORE INSERT OR UPDATE OF role_id, tenant_id ON public.invitations
  FOR EACH ROW EXECUTE FUNCTION public.p1_validate_role_assignment();

CREATE FUNCTION public.p1_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.p1_touch_updated_at() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER tenants_touch BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();
CREATE TRIGGER branches_touch BEFORE UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();
CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();
CREATE TRIGGER roles_touch BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();
CREATE TRIGGER memberships_touch BEFORE UPDATE ON public.memberships FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();
CREATE TRIGGER invitations_touch BEFORE UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.p1_touch_updated_at();

-- Real fixed authorization catalogs; NOT dummy tenant/business data.
INSERT INTO public.roles (key, name, description, scope, is_system, rank) VALUES
 ('owner','Owner','Organization owner','organization',true,100),
 ('organization_admin','Organization Admin','Organization administrator','organization',true,80),
 ('branch_manager','Branch Manager','Assigned branch manager','branch',true,50),
 ('staff','Staff','Assigned branch staff','branch',true,20),
 ('read_only','Read Only','Assigned branch viewer','branch',true,10);

INSERT INTO public.permissions (key, module, action, description) VALUES
 ('organization.view','organization','view','View organization'),
 ('organization.update','organization','update','Update organization'),
 ('branch.view','branch','view','View permitted branches'),
 ('branch.create','branch','create','Create branch'),
 ('branch.update','branch','update','Update permitted branch'),
 ('branch.delete','branch','delete','Reserved: branch deletion, not enabled in M1'),
 ('user.view','user','view','View permitted members'),
 ('user.invite','user','invite','Invite within assignable scope'),
 ('user.update','user','update','Update permitted memberships'),
 ('role.view','role','view','View permitted roles'),
 ('role.manage','role','manage','Reserved: custom role management, not enabled in M1'),
 ('settings.view','settings','view','View permitted settings'),
 ('settings.update','settings','update','Update organization settings'),
 ('audit.view','audit','view','View organization audit');

INSERT INTO public.role_permissions (role_id, permission_key)
SELECT r.id, p.key FROM public.roles r CROSS JOIN public.permissions p
WHERE r.tenant_id IS NULL AND (
  r.key = 'owner' OR
  (r.key = 'organization_admin' AND p.key NOT IN ('branch.delete','role.manage')) OR
  (r.key = 'branch_manager' AND p.key IN ('organization.view','branch.view','branch.update','user.view','user.invite','role.view','settings.view')) OR
  (r.key IN ('staff','read_only') AND p.key IN ('organization.view','branch.view'))
);

COMMENT ON TABLE public.platform_admins IS 'Separate platform authority; controlled verified-account bootstrap deferred to P9.';
COMMENT ON COLUMN public.tenants.active_owner_count IS 'Reserved internal counter; P2 atomic Owner invariant guards not installed in P1. No business provisioning permitted yet.';
COMMENT ON TABLE public.invitations IS 'Copyable token link; branch scopes in invitation_branches. Authorization, expiry-at-use and acceptance RPCs deferred to P3.';
COMMENT ON TABLE public.role_permissions IS 'Custom role isolation policies deferred to P2. P1 RLS denies all authenticated reads.';
COMMENT ON TABLE public.audit_logs IS 'Append-only application grants. Database audit writers and immutable audit guard deferred to P2.';

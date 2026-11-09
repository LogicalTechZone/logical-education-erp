import { queryOptions } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';

export const workspaceOptions = () => queryOptions({
  queryKey: ['erp', 'workspace'],
  queryFn: async () => {
    const { data, error } = await supabase.from('tenants').select('id,name,slug,country,timezone,default_currency,contact_email,contact_phone,status,created_at,updated_at').order('name');
    if (error) throw error;
    return data;
  },
});
export const dashboardOptions = (tenantId: string | undefined) => queryOptions({
  queryKey: ['erp', 'dashboard', tenantId],
  queryFn: async () => {
    if (!tenantId) return null;
    const [branches, members, invitations, activity] = await Promise.all([
      supabase.from('branches').select('id,name,code,status').eq('tenant_id', tenantId),
      supabase.from('memberships').select('id,status').eq('tenant_id', tenantId).eq('status', 'active'),
      supabase.from('invitations').select('id,status').eq('tenant_id', tenantId).eq('status', 'pending'),
      supabase.from('audit_logs').select('id,action,entity_type,created_at').eq('tenant_id', tenantId).order('created_at', { ascending: false }).limit(6),
    ]);
    return { branches, members, invitations, activity };
  },
});
export const profileOptions = (userId: string | undefined) => queryOptions({
  queryKey: ['erp', 'profile', userId],
  queryFn: async () => {
    if (!userId) return null;
    const { data, error } = await supabase.from('profiles').select('id,full_name,avatar_url,phone,theme_preference').eq('id', userId).maybeSingle();
    if (error) throw error;
    return data;
  },
});

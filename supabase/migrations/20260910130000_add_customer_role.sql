-- Add customer support to tickets and sessions
ALTER TABLE public.tickets ADD COLUMN customer_username text;

-- Add role to sessions
ALTER TABLE public.ittrs_sessions ADD COLUMN role text NOT NULL DEFAULT 'admin';
ALTER TABLE public.ittrs_sessions ADD COLUMN username text;

-- Drop and recreate the session creation function to include role and username
DROP FUNCTION IF EXISTS public.ittrs_create_session(text, bigint, bigint);
CREATE FUNCTION public.ittrs_create_session(p_hash text, p_expires bigint, p_now bigint, p_role text DEFAULT 'admin', p_username text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.ittrs_sessions WHERE expires_at <= p_now;
  INSERT INTO public.ittrs_sessions(token_hash, expires_at, role, username) VALUES(p_hash, p_expires, p_role, p_username);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ittrs_create_session(text, bigint, bigint, text, text) TO service_role;

-- Create RPC for customer dashboard
CREATE FUNCTION public.ittrs_customer_dashboard(p_username text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'tickets', (
      SELECT COALESCE(jsonb_agg(t ORDER BY t.created_at DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.tickets WHERE customer_username = p_username ORDER BY created_at DESC LIMIT 100) t
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.ittrs_customer_dashboard(text) TO service_role;

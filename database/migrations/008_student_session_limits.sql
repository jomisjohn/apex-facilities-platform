BEGIN;

CREATE OR REPLACE FUNCTION public.apex_apply_student_session_limits(target_role name)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF target_role::text !~ '^apex_u_[a-z0-9]{8,24}$' THEN
        RAISE EXCEPTION 'Student session limits require an opaque Apex student role.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = target_role) THEN
        RAISE EXCEPTION 'Student role does not exist.';
    END IF;

    EXECUTE format('ALTER ROLE %I CONNECTION LIMIT 2', target_role);
    EXECUTE format('ALTER ROLE %I SET statement_timeout = %L', target_role, '60s');
    EXECUTE format('ALTER ROLE %I SET idle_in_transaction_session_timeout = %L', target_role, '60s');
END
$$;

COMMENT ON FUNCTION public.apex_apply_student_session_limits(name) IS
    'Administrator-only measured capacity guard: two sessions and 60-second statement/idle-transaction limits per Apex student login.';
REVOKE ALL ON FUNCTION public.apex_apply_student_session_limits(name) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apex_apply_student_session_limits(name) FROM apex_shared_reader, apex_workspace_member;

DO $$
DECLARE
    student_role name;
BEGIN
    FOR student_role IN
        SELECT DISTINCT login_role
        FROM public.apex_workspace_registry
        WHERE active
    LOOP
        PERFORM public.apex_apply_student_session_limits(student_role);
    END LOOP;
END
$$;

CREATE OR REPLACE FUNCTION public.apex_provision_workspace(
    requested_course_code text,
    requested_enrollment_alias text,
    initial_password text
)
RETURNS name
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    course_slug text;
    student_role name;
    workspace_name name;
BEGIN
    IF requested_enrollment_alias !~ '^[a-z0-9]{8,24}$' THEN
        RAISE EXCEPTION 'Enrollment alias must contain 8-24 lowercase ASCII letters or digits.';
    END IF;

    course_slug := CASE requested_course_code
        WHEN 'AIDA 1141' THEN 'aida1141'
        WHEN 'AIDA 1145' THEN 'aida1145'
        WHEN 'AIDA 2154' THEN 'aida2154'
        WHEN 'AIDA 2156' THEN 'aida2156'
        WHEN 'AIDA 2362' THEN 'aida2362'
        ELSE NULL
    END;
    IF course_slug IS NULL THEN
        RAISE EXCEPTION 'Course is not registered for Apex workspace provisioning.';
    END IF;

    student_role := ('apex_u_' || requested_enrollment_alias)::name;
    workspace_name := ('ws_' || course_slug || '_' || requested_enrollment_alias)::name;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = student_role) THEN
        IF initial_password IS NULL OR length(initial_password) < 16 THEN
            RAISE EXCEPTION 'A new student login requires an initial password of at least 16 characters.';
        END IF;
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', student_role, initial_password);
    END IF;

    EXECUTE format('GRANT apex_shared_reader, apex_workspace_member TO %I', student_role);
    PERFORM public.apex_apply_student_session_limits(student_role);

    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = workspace_name) THEN
        EXECUTE format('CREATE SCHEMA %I AUTHORIZATION %I', workspace_name, student_role);
        EXECUTE format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', workspace_name);
    ELSE
        IF NOT EXISTS (
            SELECT 1
            FROM pg_namespace AS namespace
            JOIN pg_roles AS owner_role ON owner_role.oid = namespace.nspowner
            WHERE namespace.nspname = workspace_name
              AND owner_role.rolname = student_role
        ) THEN
            RAISE EXCEPTION 'Existing workspace has an unexpected owner.';
        END IF;
    END IF;

    INSERT INTO public.apex_workspace_registry (
        workspace_schema, login_role, course_code, enrollment_alias
    ) VALUES (
        workspace_name, student_role, requested_course_code, requested_enrollment_alias
    )
    ON CONFLICT (workspace_schema) DO UPDATE SET active = true;

    RETURN workspace_name;
END
$$;

REVOKE ALL ON FUNCTION public.apex_provision_workspace(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apex_provision_workspace(text, text, text) FROM apex_shared_reader, apex_workspace_member;

COMMIT;

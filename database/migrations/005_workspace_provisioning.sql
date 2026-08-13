BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apex_platform_owner') THEN
        CREATE ROLE apex_platform_owner NOLOGIN;
    END IF;
END
$$;

CREATE TABLE public.apex_workspace_registry (
    workspace_schema name PRIMARY KEY,
    login_role name NOT NULL,
    course_code text NOT NULL CHECK (course_code IN ('AIDA 1141', 'AIDA 1145', 'AIDA 2154', 'AIDA 2156', 'AIDA 2362')),
    enrollment_alias text NOT NULL CHECK (enrollment_alias ~ '^[a-z0-9]{8,24}$'),
    provisioned_at timestamptz NOT NULL DEFAULT now(),
    active boolean NOT NULL DEFAULT true,
    UNIQUE (login_role, course_code),
    UNIQUE (course_code, enrollment_alias)
);

COMMENT ON TABLE public.apex_workspace_registry IS
    'Private administrative mapping of opaque enrollment aliases to database roles and course workspace schemas; never expose it to student roles.';

REVOKE ALL ON public.apex_workspace_registry FROM PUBLIC;
REVOKE ALL ON public.apex_workspace_registry FROM apex_shared_reader, apex_workspace_member;

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
    )
    VALUES (
        workspace_name, student_role, requested_course_code, requested_enrollment_alias
    )
    ON CONFLICT (workspace_schema) DO UPDATE
    SET active = true;

    RETURN workspace_name;
END
$$;

COMMENT ON FUNCTION public.apex_provision_workspace(text, text, text) IS
    'Administrator-only provisioning for one login per opaque student alias and one isolated schema per registered course enrollment.';

REVOKE ALL ON FUNCTION public.apex_provision_workspace(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apex_provision_workspace(text, text, text) FROM apex_shared_reader, apex_workspace_member;

COMMIT;

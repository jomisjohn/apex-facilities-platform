BEGIN;

WITH approved_lab_catalog (
    lab_number, package_title, learning_purpose, dataset_codes
) AS (
    VALUES
        (1, 'Apex Service-Readiness Contract Before Code', 'Frame a service-readiness data product, define its contract, risks, evidence, and acceptance tests before implementation.', ARRAY['APX-FACILITIES-V1','APX-CRM-V1','APX-READINESS-V1']),
        (2, 'Relational Model for Facilities Operations', 'Design a constrained relational model for connected facility, contract, readiness, and service records.', ARRAY['APX-FACILITIES-V1','APX-CRM-V1','APX-READINESS-V1','APX-OPERATIONS-V1']),
        (3, 'Restartable Multi-Source Service Ingestion', 'Build a repeatable ingestion that combines versioned operational, workforce, and facility sources without duplicating accepted records.', ARRAY['APX-FACILITIES-V1','APX-OPERATIONS-V1','APX-WORKFORCE-V1']),
        (4, 'Defensible Cleaning of Facilities Data', 'Profile, document, and repair facilities data-quality issues while preserving raw evidence and transformation lineage.', ARRAY['APX-FACILITIES-V1','APX-OPERATIONS-V1','APX-QUALITY-V1','APX-SUPPLY-V1']),
        (5, 'Reproducible Daily Operations Pipeline', 'Create an observable daily pipeline for readiness, service, workforce, and quality records with rerun and failure controls.', ARRAY['APX-READINESS-V1','APX-OPERATIONS-V1','APX-WORKFORCE-V1','APX-QUALITY-V1']),
        (6, 'End-to-End Analysis-Ready Delivery', 'Deliver tested, documented analytical outputs that connect operations, quality, assets, and cost data.', ARRAY['APX-OPERATIONS-V1','APX-QUALITY-V1','APX-ASSETS-V1','APX-FINANCE-V1']),
        (7, 'Dimensional Model for Facility Operations', 'Design and populate reusable dimensions and facts for facility performance analysis.', ARRAY['APX-FACILITIES-V1','APX-CRM-V1','APX-OPERATIONS-V1','APX-WORKFORCE-V1','APX-QUALITY-V1','APX-ASSETS-V1','APX-SUPPLY-V1','APX-FINANCE-V1']),
        (8, 'Responsible Client-Portal Analytics', 'Serve governed client-facing measures with defined meaning, privacy limits, freshness, and responsible interpretation.', ARRAY['APX-CRM-V1','APX-OPERATIONS-V1','APX-QUALITY-V1','APX-FINANCE-V1','APX-INSIGHTS-V1']),
        (9, 'Schema-Break Incident and Recovery', 'Detect a breaking schema change, contain its impact, recover service, and produce tested release evidence.', ARRAY['APX-FACILITIES-V1','APX-OPERATIONS-V1','APX-ASSETS-V1','APX-FINANCE-V1']),
        (10, 'Governance, Lineage, and Release Evidence', 'Publish a governed data product with traceable sources, lineage, quality controls, release evidence, and limitations.', ARRAY['APX-FACILITIES-V1','APX-CRM-V1','APX-READINESS-V1','APX-OPERATIONS-V1','APX-WORKFORCE-V1','APX-QUALITY-V1','APX-ASSETS-V1','APX-SUPPLY-V1','APX-FINANCE-V1','APX-INSIGHTS-V1','APX-SPATIAL-V1','APX-RESEARCH-V1'])
), resolved AS (
    SELECT
        approved.lab_number,
        approved.package_title,
        approved.learning_purpose,
        array_agg(catalog.dataset_id ORDER BY codes.ordinality)::bigint[] AS dataset_ids
    FROM approved_lab_catalog AS approved
    CROSS JOIN LATERAL unnest(approved.dataset_codes) WITH ORDINALITY AS codes(dataset_code, ordinality)
    JOIN shared_research.dataset_catalog AS catalog USING (dataset_code)
    GROUP BY approved.lab_number, approved.package_title, approved.learning_purpose
)
UPDATE shared_research.data_packages AS package
SET
    package_title = resolved.package_title,
    learning_purpose = resolved.learning_purpose,
    dataset_ids = resolved.dataset_ids
FROM resolved
WHERE package.course_code = 'AIDA 1145'
  AND package.lab_number = resolved.lab_number;

DO $$
BEGIN
    IF (SELECT count(*) FROM shared_research.data_packages WHERE course_code = 'AIDA 1145') <> 10 THEN
        RAISE EXCEPTION 'AIDA 1145 must have exactly ten registered lab packages.';
    END IF;
END
$$;

COMMIT;

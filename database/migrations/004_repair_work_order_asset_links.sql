BEGIN;

-- Never infer a related identity value from insertion order. Resolve each work
-- order to a deterministic asset that is owned by the same facility.
WITH ranked_assets AS (
    SELECT
        asset_id,
        facility_id,
        row_number() OVER (PARTITION BY facility_id ORDER BY asset_code, asset_id) AS asset_position
    FROM shared_assets.assets
), resolved AS (
    SELECT
        w.work_order_id,
        a.asset_id
    FROM shared_operations.work_orders AS w
    JOIN ranked_assets AS a
      ON a.facility_id = w.facility_id
     AND a.asset_position = ((w.work_order_id - 1) % 10) + 1
)
UPDATE shared_operations.work_orders AS w
SET asset_id = resolved.asset_id
FROM resolved
WHERE resolved.work_order_id = w.work_order_id
  AND w.asset_id IS DISTINCT FROM resolved.asset_id;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM shared_operations.work_orders AS w
        JOIN shared_assets.assets AS a USING (asset_id)
        WHERE w.facility_id <> a.facility_id
    ) THEN
        RAISE EXCEPTION 'Work-order asset repair did not preserve facility ownership.';
    END IF;
END
$$;

COMMIT;

# How the Apex data platform works

Apex is a fictional, AI- and data-analytics-enabled facilities maintenance management platform. You will use one connected facilities database instead of unrelated data files for every lab. This helps you practise how professional applications combine information from several parts of an organization.

## Your database access

- One PostgreSQL/PostGIS database: `apex_facilities`.
- Twelve connected shared domain schemas.
- You can query shared domain data but cannot change it.
- You receive one PostgreSQL login.
- Each course enrollment gives you a separate writable workspace schema.
- Your course applications and assessed work remain separated by course.
- Lab packages may reuse connected data, so you can study how your earlier work supports later tasks.

## Data domains

1. Facilities and clients
2. CRM and contracts
3. Readiness and mobilization
4. Cleaning and service operations
5. Workforce and scheduling
6. Quality and inspections
7. Assets and maintenance
8. Inventory and vendors
9. Estimating, costing and finance
10. Customer insights and trends
11. GIS and territories
12. Research and market analytics

The main dependency path is:

`facilities and clients -> contracts -> readiness and service operations -> workforce, quality and finance -> insights`

Assets, inventory, spatial records and research datasets connect to this path where they support a facility, service activity or analysis. PostgreSQL foreign keys preserve the record-level relationships.

## How you work with Apex

- Explore tables and test SQL in DBeaver Community.
- Write Python and Streamlit features in VS Code.
- Run Streamlit locally in your browser.
- Read common records from the shared schemas.
- Save required lab tables and outputs only in your course workspace.
- Use the supplied CSV or Parquet fallback when a lab cannot reach PostgreSQL.

When DBeaver and Streamlit use the same database, committed changes in your workspace are available to both after you refresh or rerun the relevant query.

## How the platform grows safely

Numbered database migrations add shared tables and relationships in a repeatable order. Existing migrations remain unchanged as platform history; new changes are added through a later migration and validated before release. Student-created tables do not become shared platform migrations.

For a table-by-table domain guide, dependency map and workspace workflow, read [Apex data platform](data-platform.md).

## How your data is protected

- Apex enterprise records are synthetic and designed to work together.
- Open datasets include their source, licence, version, attribution and quality notes.
- Data you import stays in your course workspace unless your instructor explicitly approves another location.
- Shared packages are reviewed before you use them.
- Shared schemas do not store your personal information, submissions, grades or feedback.

# Architecture decisions

## Stable platform boundary

- One PostgreSQL/PostGIS database: `apex_facilities`.
- Twelve connected shared domain schemas.
- Shared domain data is read-only for students.
- One PostgreSQL login per student.
- One writable workspace schema per student/course enrollment.
- Separate course applications may share the design system and database, but course outcomes, assessments and student work remain isolated.
- Approximately 60 lab-ready data packages may be added over time; they are not 60 separate databases or necessarily 60 external datasets.

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

## Data governance

- Core enterprise records are synthetic and relationally consistent.
- Every external dataset requires recorded provenance, licence, version, attribution, permitted uses, and quality/bias notes.
- Raw student imports remain in course-scoped workspace schemas.
- Only instructor-reviewed datasets become shared packages.
- No student information, submissions, grades, or confidential external data is stored in shared schemas.


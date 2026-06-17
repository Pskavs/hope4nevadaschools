{{
  config(
    materialized = 'incremental',
    unique_key = 'enrollment_id',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    cluster_by = ['school_year', 'school_id'],
    tags = ['marts', 'core', 'facts', 'incremental'],
    contract = {'enforced': true}
  )
}}

/*
  fct_enrollment_trends
  ─────────────────────
  Incremental fact table capturing enrollment by school, year, grade, gender,
  and ethnicity.

  Incremental logic:
    - On full refresh: loads all rows from stg_enrollment.
    - On incremental run: loads only rows where school_year equals the
      current school year (new annual drop) OR any row whose _loaded_at
      is more recent than the latest value already in the table.

  cluster_by school_year + school_id keeps Snowflake micro-partition pruning
  efficient for typical time-range queries.
*/

with

enrollment as (
    select * from {{ ref('stg_enrollment') }}

    {% if is_incremental() %}
    -- Only process new or updated records
    where school_year = {{ var('current_school_year')[:4] | int }}
       or _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

schools as (
    select school_id, school_name, grade_band, is_title1, ward
    from {{ ref('dim_schools') }}
),

joined as (

    select
        -- Grain key
        e.enrollment_id,

        -- Foreign keys
        e.school_id,
        e.school_year,

        -- Denormalised school attributes (avoid extra join at query time)
        s.school_name,
        s.grade_band,
        s.is_title1,
        s.ward,

        -- Enrollment dimensions
        e.grade,
        e.gender,
        e.ethnicity,
        e.student_count,

        -- YoY helpers (populated via lag in downstream analysis models)
        -- Left here as NULLs so contract stays stable; compute in analyses/
        null::int                                   as prior_year_count,
        null::float                                 as yoy_pct_change,

        -- Metadata
        e._loaded_at,
        current_timestamp()                         as dbt_updated_at

    from enrollment e
    left join schools s
        on e.school_id = s.school_id

)

select * from joined

{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'dimensions']
  )
}}

/*
  dim_schools
  ───────────
  Derives a school dimension from the enrollment seed data.
  Uses the most recent school name for each organization code.
*/

with enrollment as (
    select * from {{ ref('stg_enrollment') }}
),

latest_names as (
    select distinct
        school_id,
        first_value(school_name) over (
            partition by school_id
            order by school_year desc
        )                               as school_name
    from enrollment
),

final as (
    select
        school_id,
        school_name,
        current_timestamp()             as dbt_updated_at
    from latest_names
)

select * from final
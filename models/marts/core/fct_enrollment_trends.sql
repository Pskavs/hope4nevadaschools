{{
  config(
    materialized = 'incremental',
    unique_key = ['school_id', 'school_year'],
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    cluster_by = ['school_year', 'school_id'],
    tags = ['marts', 'core', 'facts', 'incremental']
  )
}}

with

enrollment as (
    select * from {{ ref('stg_enrollment') }}
    {% if is_incremental() %}
    where school_year = {{ var('current_school_year')[:4] | int }}
    {% endif %}
),

schools as (
    select school_id, school_name
    from {{ ref('dim_schools') }}
),

joined as (
    select
        e.school_id,
        e.school_year,
        s.school_name,
        e.total_enrolled,
        e.num_hispanic,
        e.num_black,
        e.num_white,
        e.num_asian,
        e.num_am_indian,
        e.num_pacific_islander,
        e.num_two_or_more,
        e.num_male,
        e.num_female,
        e.num_iep,
        e.num_ell,
        e.num_frl,
        e.num_homeless,
        e.num_foster,
        e.num_military,
        current_timestamp()     as dbt_updated_at
    from enrollment e
    left join schools s
        on e.school_id = s.school_id
)

select * from joined
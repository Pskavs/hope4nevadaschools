{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'facts']
  )
}}

with

schools as (
    select school_id, school_name, region
    from {{ ref('dim_schools') }}
),

enrollment_agg as (
    select
        school_id,
        school_year,
        sum(total_enrolled)     as total_enrollment
    from {{ ref('stg_enrollment') }}
    group by 1, 2
),

attendance as (
    select
        school_id,
        school_year,
        chronic_absenteeism_rate,
        absenteeism_tier
    from {{ ref('stg_attendance') }}
),

assessment as (
    select
        school_id,
        school_year,
        math_pct_proficient,
        ela_pct_proficient,
        math_suppressed,
        ela_suppressed
    from {{ ref('stg_assessment_scores') }}
),

final as (
    select
        s.school_id,
        at.school_year,
        s.school_name,
        s.region,
        e.total_enrollment,
        at.chronic_absenteeism_rate,
        at.absenteeism_tier,
        asmnt.ela_pct_proficient,
        asmnt.ela_suppressed,
        asmnt.math_pct_proficient,
        asmnt.math_suppressed,
        current_timestamp()     as dbt_updated_at
    from schools s
    inner join attendance at    on s.school_id = at.school_id
    left  join enrollment_agg e on s.school_id = e.school_id
                               and at.school_year = e.school_year
    left  join assessment asmnt on s.school_id = asmnt.school_id
                               and at.school_year = asmnt.school_year
)

select * from final
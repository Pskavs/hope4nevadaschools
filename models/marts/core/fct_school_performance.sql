{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'facts'],
    contract = {'enforced': true}
  )
}}

/*
  fct_school_performance
  ──────────────────────
  One row per school + school_year combining:
    - Total enrollment (All Students)
    - Chronic absenteeism rate
    - ELA and Math proficiency rates (All Students subgroup, SBAC only)

  Designed for school-level dashboard / scorecard use cases.
  Suppressed assessment cells are preserved as NULL.
*/

with

schools as (
    select school_id, school_name, grade_band, is_title1, ward
    from {{ ref('dim_schools') }}
),

enrollment_agg as (
    select
        school_id,
        school_year,
        sum(student_count)  as total_enrollment
    from {{ ref('stg_enrollment') }}
    group by 1, 2
),

attendance as (
    select
        school_id,
        school_year,
        chronic_absenteeism_rate,
        ada_rate,
        absenteeism_tier
    from {{ ref('stg_attendance') }}
),

-- Pivot ELA / Math proficiency for All Students, SBAC only
ela as (
    select
        school_id,
        school_year,
        proficiency_rate    as ela_proficiency_rate,
        is_suppressed       as ela_suppressed
    from {{ ref('stg_assessment_scores') }}
    where subject = 'ELA'
      and subgroup = 'All Students'
      and assessment_type = 'SBAC'
),

math as (
    select
        school_id,
        school_year,
        proficiency_rate    as math_proficiency_rate,
        is_suppressed       as math_suppressed
    from {{ ref('stg_assessment_scores') }}
    where subject = 'Math'
      and subgroup = 'All Students'
      and assessment_type = 'SBAC'
),

final as (

    select
        -- Keys
        s.school_id,
        a.school_year,
        s.school_name,
        s.grade_band,
        s.is_title1,
        s.ward,

        -- Enrollment
        e.total_enrollment,

        -- Attendance
        at.chronic_absenteeism_rate,
        at.ada_rate,
        at.absenteeism_tier,

        -- Assessment
        ela.ela_proficiency_rate,
        ela.ela_suppressed,
        math.math_proficiency_rate,
        math.math_suppressed,

        -- Composite performance score (0–100): simple average of available rates
        -- NULL if both are suppressed
        round(
            (coalesce(ela.ela_proficiency_rate, 0) + coalesce(math.math_proficiency_rate, 0))
            / nullif(
                (case when not ela.ela_suppressed  then 1 else 0 end
               + case when not math.math_suppressed then 1 else 0 end),
                0
            ),
            2
        )                                               as composite_proficiency_rate,

        -- Metadata
        current_timestamp()                             as dbt_updated_at

    from schools s
    inner join attendance at  on s.school_id = at.school_id
    left  join enrollment_agg e
                              on s.school_id = e.school_id
                             and at.school_year = e.school_year
    left  join ela            on s.school_id = ela.school_id
                             and at.school_year = ela.school_year
    left  join math           on s.school_id = math.school_id
                             and at.school_year = math.school_year

)

select * from final

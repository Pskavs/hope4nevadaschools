{{
    config(
        materialized = 'table',
        tags = ['marts', 'core', 'facts']
    )
}}

/*
  fct_school_improvement_yoy
  ───────────────────────────
  One row per school per year with YoY proficiency changes.
  Grain: school x year.
*/

with assessment as (
    select
        school_id,
        school_name,
        school_year,
        case when not ela_suppressed then ela_pct_proficient end as ela_pct,
        case when not math_suppressed then math_pct_proficient end as math_pct
    from {{ ref('stg_assessment_scores') }}
),

yoy as (
    select
        school_id,
        school_name,
        school_year,
        ela_pct,
        math_pct,
        lag(ela_pct) over (partition by school_id order by school_year) as ela_prior,
        lag(math_pct) over (partition by school_id order by school_year) as math_prior,
        round(ela_pct - lag(ela_pct) over (partition by school_id order by school_year), 1) as ela_yoy_change,
        round(math_pct - lag(math_pct) over (partition by school_id order by school_year), 1) as math_yoy_change,
        round(
            (coalesce(ela_pct, 0) + coalesce(math_pct, 0))
            / nullif(
                (case when ela_pct is not null then 1 else 0 end
               + case when math_pct is not null then 1 else 0 end),
                0
            ), 1
        ) as composite_pct
    from assessment
),

yoy_with_composite as (
    select
        *,
        round(composite_pct - lag(composite_pct) over (partition by school_id order by school_year), 1) as composite_yoy_change,
        case
            when ela_pct > lag(ela_pct) over (partition by school_id order by school_year) then 'Up'
            when ela_pct < lag(ela_pct) over (partition by school_id order by school_year) then 'Down'
            when ela_pct = lag(ela_pct) over (partition by school_id order by school_year) then 'Flat'
            else null
        end as ela_direction,
        case
            when math_pct > lag(math_pct) over (partition by school_id order by school_year) then 'Up'
            when math_pct < lag(math_pct) over (partition by school_id order by school_year) then 'Down'
            when math_pct = lag(math_pct) over (partition by school_id order by school_year) then 'Flat'
            else null
        end as math_direction
    from yoy
),

final as (
    select
        y.school_id,
        d.school_name,
        d.region,
        y.school_year,
        y.ela_pct,
        y.ela_prior as ela_prior_year,
        y.ela_yoy_change,
        y.ela_direction,
        y.math_pct,
        y.math_prior as math_prior_year,
        y.math_yoy_change,
        y.math_direction,
        y.composite_pct,
        y.composite_yoy_change
    from yoy_with_composite y
    inner join {{ ref('dim_schools') }} d on y.school_id = d.school_id
    where y.school_year is not null
)

select * from final
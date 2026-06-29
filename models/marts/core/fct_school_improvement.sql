{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'facts']
  )
}}

/*
  fct_school_improvement
  ──────────────────────
  Tracks school-level ELA and Math proficiency improvement.
  Captures three dimensions of growth:
    1. Overall change (first year to latest year)
    2. Consistency (how many years improved vs declined)
    3. Peak growth (biggest single year-over-year jump)
*/

with assessment as (
    select
        school_id,
        school_name,
        school_year,
        case when not ela_suppressed then ela_pct_proficient end     as ela_pct,
        case when not math_suppressed then math_pct_proficient end   as math_pct
    from {{ ref('stg_assessment_scores') }}
),

-- Year over year changes for each school
yoy as (
    select
        school_id,
        school_name,
        school_year,
        ela_pct,
        math_pct,

        -- Prior year values
        lag(ela_pct) over (
            partition by school_id order by school_year
        )                                                           as ela_prior,
        lag(math_pct) over (
            partition by school_id order by school_year
        )                                                           as math_prior,

        -- YoY changes
        round(ela_pct - lag(ela_pct) over (
            partition by school_id order by school_year
        ), 1)                                                       as ela_yoy_change,

        round(math_pct - lag(math_pct) over (
            partition by school_id order by school_year
        ), 1)                                                       as math_yoy_change,

        round(
            (
                coalesce(ela_pct, 0) + coalesce(math_pct, 0)
            ) / nullif(
                (case when ela_pct is not null then 1 else 0 end
               + case when math_pct is not null then 1 else 0 end),
                0
            ), 1
        )                                                           as composite_pct

    from assessment
),

yoy_with_composite as (
    select
        *,
        round(composite_pct - lag(composite_pct) over (
            partition by school_id order by school_year
        ), 1)                                                       as composite_yoy_change
    from yoy
),

-- First and latest non-null values per school
-- First and latest year per school
first_last_years as (
    select
        school_id,
        min(case when ela_pct is not null then school_year end)     as ela_first_year,
        max(case when ela_pct is not null then school_year end)     as ela_latest_year,
        min(case when math_pct is not null then school_year end)    as math_first_year,
        max(case when math_pct is not null then school_year end)    as math_latest_year
    from yoy_with_composite
    group by 1
),

-- First and latest proficiency values per school
first_last as (
    select
        fly.school_id,
        fly.ela_first_year,
        fly.ela_latest_year,
        fly.math_first_year,
        fly.math_latest_year,
        e_first.ela_pct as ela_first_pct,
        e_latest.ela_pct as ela_latest_pct,
        m_first.math_pct as math_first_pct,
        m_latest.math_pct as math_latest_pct
    from first_last_years fly
    left join yoy_with_composite e_first
        on fly.school_id = e_first.school_id
        and fly.ela_first_year = e_first.school_year
    left join yoy_with_composite e_latest
        on fly.school_id = e_latest.school_id
        and fly.ela_latest_year = e_latest.school_year
    left join yoy_with_composite m_first
        on fly.school_id = m_first.school_id
        and fly.math_first_year = m_first.school_year
    left join yoy_with_composite m_latest
        on fly.school_id = m_latest.school_id
        and fly.math_latest_year = m_latest.school_year
),

first_last_deduped as (
    select distinct
        school_id,
        ela_first_year,
        ela_latest_year,
        ela_first_pct,
        ela_latest_pct,
        math_first_year,
        math_latest_year,
        math_first_pct,
        math_latest_pct
    from first_last
),

-- Aggregate consistency and peak metrics
agg as (
    select
        school_id,

        -- Consistency: years improving vs declining
        sum(case when ela_yoy_change > 0 then 1 else 0 end) as ela_years_improved,
        sum(case when ela_yoy_change < 0 then 1 else 0 end) as ela_years_declined,
        sum(case when math_yoy_change > 0 then 1 else 0 end) as math_years_improved,
        sum(case when math_yoy_change < 0 then 1 else 0 end) as math_years_declined,
        sum(case when composite_yoy_change > 0 then 1 else 0 end) as composite_years_improved,
        sum(case when composite_yoy_change < 0 then 1 else 0 end) as composite_years_declined,

        -- Peak single-year growth
        max(ela_yoy_change) as ela_peak_yoy,
        max(math_yoy_change) as math_peak_yoy,
        max(composite_yoy_change) as composite_peak_yoy,

        -- Total years with data
        count(ela_yoy_change) as ela_years_measured,
        count(math_yoy_change) as math_years_measured

    from yoy_with_composite
    where school_year > {{ var('start_year') }}
    group by 1
),

combined as (
    select
        fl.school_id,
        d.school_name,
        d.region,

        -- Overall change
        fl.ela_first_year,
        fl.ela_latest_year,
        fl.ela_first_pct,
        fl.ela_latest_pct,
        round(fl.ela_latest_pct - fl.ela_first_pct, 1)             as ela_overall_change,

        fl.math_first_year,
        fl.math_latest_year,
        fl.math_first_pct,
        fl.math_latest_pct,
        round(fl.math_latest_pct - fl.math_first_pct, 1)           as math_overall_change,

        round(
            (coalesce(fl.ela_latest_pct - fl.ela_first_pct, 0)
           + coalesce(fl.math_latest_pct - fl.math_first_pct, 0))
            / nullif(
                (case when fl.ela_latest_pct is not null and fl.ela_first_pct is not null then 1 else 0 end
               + case when fl.math_latest_pct is not null and fl.math_first_pct is not null then 1 else 0 end),
                0
            ), 1
        ) as composite_overall_change,

        -- Consistency
        agg.ela_years_improved,
        agg.ela_years_declined,
        agg.ela_years_measured,
        agg.math_years_improved,
        agg.math_years_declined,
        agg.math_years_measured,
        agg.composite_years_improved,
        agg.composite_years_declined,

        -- Peak YoY
        agg.ela_peak_yoy,
        agg.math_peak_yoy,
        agg.composite_peak_yoy,

        -- Consistency score
        round(
            agg.composite_years_improved::float
            / nullif(agg.composite_years_improved + agg.composite_years_declined, 0),
            2
        ) as consistency_score,
        -- Improvement score: weighted combination of consistency and magnitude
        -- Consistency weighted 60% (are they improving regularly?)
        -- Overall change weighted 40% (how much are they improving?)
        round(
            (
                round(
                    agg.composite_years_improved::float
                    / nullif(agg.composite_years_improved + agg.composite_years_declined, 0),
                    2
                ) * 0.6
            )
            +
            (
                (coalesce(fl.ela_latest_pct - fl.ela_first_pct, 0)
               + coalesce(fl.math_latest_pct - fl.math_first_pct, 0))
                / nullif(
                    (case when fl.ela_latest_pct is not null and fl.ela_first_pct is not null then 1 else 0 end
                   + case when fl.math_latest_pct is not null and fl.math_first_pct is not null then 1 else 0 end),
                    0
                )
                / 20.0 * 0.4
            ),
            3
        ) as improvement_score

    from first_last fl
    inner join agg on fl.school_id = agg.school_id
    inner join {{ ref('dim_schools') }} d on fl.school_id = d.school_id
    where fl.ela_first_pct is not null
      and fl.math_first_pct is not null
      and fl.ela_latest_pct is not null
      and fl.math_latest_pct is not null
),

ranked as (
    -- this ranks the schools based on ela, math, and composite overall change, consistency, and peak growth.
    select
        *,
        -- Overall change ranks
        rank() over (order by ela_overall_change desc nulls last) as ela_overall_rank,
        rank() over (order by math_overall_change desc nulls last) as math_overall_rank,
        rank() over (order by composite_overall_change desc nulls last) as composite_overall_rank,

        -- Consistency ranks
        rank() over (order by consistency_score desc nulls last) as consistency_rank,

        -- Peak growth ranks
        rank() over (order by ela_peak_yoy desc nulls last) as ela_peak_rank,
        rank() over (order by math_peak_yoy desc nulls last) as math_peak_rank,
        rank() over (order by composite_peak_yoy desc nulls last) as composite_peak_rank,

        -- Improvement category based on consistency + overall change
        case
            when consistency_score >= 0.75 and composite_overall_change >= 5  then 'Consistently Improving'
            when consistency_score >= 0.75 then 'Consistent but Flat'
            when composite_overall_change >= 10 then 'Big Gains'
            when composite_overall_change >= 0 then 'Mixed Progress'
            else 'Needs Attention'
        end as improvement_category,

        rank() over (
            order by improvement_score desc nulls last
        )  as overall_improvement_rank,

        rank() over (
            partition by region
            order by improvement_score desc nulls last
        ) as regional_improvement_rank

    from combined
)

select * from ranked
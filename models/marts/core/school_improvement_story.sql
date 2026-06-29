/*
  ═══════════════════════════════════════════════════════════════════
  CCSD School Improvement Story
  Written by: Christian Paskevicius
  Former CCSD 3rd Grade Teacher | Analytics Engineer

  A principal in the east valley and a principal in Summerlin are
  not playing the same game. This analysis compares schools within
  their own regions. 
  ═══════════════════════════════════════════════════════════════════
*/

-- ─────────────────────────────────────────────────────────────────
-- Chapter 1: Year-Over-Year Trends by Region
-- How each school moved each year — the full picture.
-- ─────────────────────────────────────────────────────────────────

select
    region,
    school_name,
    school_year,
    ela_pct,
    ela_prior_year,
    ela_yoy_change,
    ela_direction,
    math_pct,
    math_prior_year,
    math_yoy_change,
    math_direction,
    composite_pct,
    composite_yoy_change
from {{ ref('fct_school_improvement_yoy') }}
where region not in ('Alternative', 'Charter')
order by region, school_name, school_year;


-- ─────────────────────────────────────────────────────────────────
-- Chapter 2: Most Consistently Improving Schools by Region
-- Schools that went up more years than they went down.
-- Ranked within their region 
-- ─────────────────────────────────────────────────────────────────

with consistency as (
    select
        region,
        school_name,
        count(school_year) as total_years,
        sum(case when composite_yoy_change > 0 then 1 else 0 end) as years_up,
        sum(case when composite_yoy_change < 0 then 1 else 0 end) as years_down,
        sum(case when composite_yoy_change = 0 then 1 else 0 end) as years_flat,
        round(avg(ela_yoy_change), 1) as avg_ela_yoy,
        round(avg(math_yoy_change), 1) as avg_math_yoy,
        round(avg(composite_yoy_change), 1) as avg_composite_yoy,
        round(
            sum(case when composite_yoy_change > 0 then 1 else 0 end)::float
            / nullif(
                sum(case when composite_yoy_change is not null then 1 else 0 end),
                0
            ), 2
        ) as consistency_score
    from {{ ref('fct_school_improvement_yoy') }}
    where region not in ('Alternative', 'Charter')
      and composite_yoy_change is not null
    group by 1, 2
),

ranked as (
    select
        *,
        rank() over (
            partition by region
            order by consistency_score desc, avg_composite_yoy desc
        ) as regional_rank
    from consistency
)

select
    region,
    regional_rank,
    school_name,
    total_years,
    years_up,
    years_down,
    avg_ela_yoy,
    avg_math_yoy,
    avg_composite_yoy,
    consistency_score
from ranked
where regional_rank <= 5
order by region, regional_rank;


-- ─────────────────────────────────────────────────────────────────
-- Chapter 3: The Transformation Network
-- Schools serving the highest-need students in CCSD.
-- Growth here means more than growth anywhere else.
-- ─────────────────────────────────────────────────────────────────

select
    school_name,
    school_year,
    ela_pct,
    ela_yoy_change,
    ela_direction,
    math_pct,
    math_yoy_change,
    math_direction,
    composite_pct,
    composite_yoy_change
from {{ ref('fct_school_improvement_yoy') }}
where region = 'Transformation Network'
order by school_name, school_year;


-- ─────────────────────────────────────────────────────────────────
-- Chapter 4: Best Single Year Jumps by Region
-- Sometimes a school has a breakthrough year.
-- This surfaces who had the biggest single-year gain
-- and when it happened — useful for understanding what worked.
-- ─────────────────────────────────────────────────────────────────

with peak_years as (
    select
        region,
        school_name,
        school_year,
        ela_yoy_change,
        math_yoy_change,
        composite_yoy_change,
        rank() over (
            partition by region
            order by composite_yoy_change desc nulls last
        ) as peak_rank
    from {{ ref('fct_school_improvement_yoy') }}
    where region not in ('Alternative', 'Charter')
      and composite_yoy_change is not null
)

select
    region,
    school_name,
    school_year as breakthrough_year,
    ela_yoy_change as ela_gain,
    math_yoy_change as math_gain,
    composite_yoy_change as composite_gain
from peak_years
where peak_rank <= 3
order by region, peak_rank;


-- ─────────────────────────────────────────────────────────────────
-- Chapter 5: Schools That Need Support
-- More years down than up. Not for ranking —
-- for resourcing. These schools deserve attention, not blame.
-- ─────────────────────────────────────────────────────────────────

with trajectory as (
    select
        region,
        school_name,
        sum(case when composite_yoy_change > 0 then 1 else 0 end) as years_up,
        sum(case when composite_yoy_change < 0 then 1 else 0 end) as years_down,
        round(avg(composite_yoy_change), 1) as avg_composite_yoy,
        round(avg(ela_yoy_change), 1) as avg_ela_yoy,
        round(avg(math_yoy_change), 1) as avg_math_yoy
    from {{ ref('fct_school_improvement_yoy') }}
    where region not in ('Alternative', 'Charter')
      and composite_yoy_change is not null
    group by 1, 2
)

select
    region,
    school_name,
    years_up,
    years_down,
    avg_composite_yoy,
    avg_ela_yoy,
    avg_math_yoy
from trajectory
where years_down > years_up
order by region, avg_composite_yoy asc;
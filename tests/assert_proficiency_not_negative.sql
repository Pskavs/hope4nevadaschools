/*
  Fails if there is any proficiency_rate that is less than 0 or greater than 100. This is a data integrity test to ensure that all proficiency rates are within the valid range of 0 to 100.
*/

select
    school_id,
    school_year,
    math_pct_proficient,
    ela_pct_proficient
from {{ ref('stg_assessment_scores') }}
where (
    (not math_suppressed and (math_pct_proficient < 0 or math_pct_proficient > 100))
    or
    (not ela_suppressed and (ela_pct_proficient < 0 or ela_pct_proficient > 100))
)

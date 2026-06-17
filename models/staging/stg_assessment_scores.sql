{{ config(materialized='view', tags=['staging', 'assessment']) }}

with source as (
    select * from {{ source('ccsd_seeds', 'ccsd_assessment_3rd_8th_grade') }}
),

cleaned as (
    select
        -- Keys
        organization_code                                           as school_id,
        school_name,
        left(trim(school_year), 4)::int                             as school_year,

        -- Enrollment during testing
        try_to_number(num_students_enrolled)                        as num_students_enrolled,

        -- Math
        try_to_number(math_num_tested)                              as math_num_tested,
        try_to_number(math_pct_proficient)                          as math_pct_proficient,
        try_to_number(math_pct_emergent)                            as math_pct_emergent,
        try_to_number(math_pct_approaches)                          as math_pct_approaches,
        try_to_number(math_pct_meets)                               as math_pct_meets,
        try_to_number(math_pct_exceeds)                             as math_pct_exceeds,

        -- ELA
        try_to_number(ela_num_tested)                               as ela_num_tested,
        try_to_number(ela_pct_proficient)                           as ela_pct_proficient,
        try_to_number(ela_pct_emergent)                             as ela_pct_emergent,
        try_to_number(ela_pct_approaches)                           as ela_pct_approaches,
        try_to_number(ela_pct_meets)                                as ela_pct_meets,
        try_to_number(ela_pct_exceeds)                              as ela_pct_exceeds,

        -- Suppression flags
        (math_pct_proficient is null
            or math_pct_proficient in ('<5', '>95'))                as math_suppressed,
        (ela_pct_proficient is null
            or ela_pct_proficient in ('<5', '>95'))                 as ela_suppressed

    from source
    where left(trim(school_year), 4)::int >= {{ var('start_year') }}
)

select * from cleaned
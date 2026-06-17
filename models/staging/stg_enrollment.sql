{{ config(materialized='view', tags=['staging', 'enrollment']) }}

with source as (
    select * from {{ source('ccsd_seeds', 'ccsd_demographic') }}
),

-- Have to clean the data as some of the enrollment numbers are non-numeric (such as <5, >95, etc.)
cleaned as (
    select
        -- Keys
        organization_code                                           as school_id,
        school_name,
        left(trim(accountability_year), 4)::int                     as school_year,

        -- Enrollment
        try_to_number(num_enrolled)                                 as total_enrolled,

        -- Race/Ethnicity
        try_to_number(num_hispanic)                                 as num_hispanic,
        try_to_number(num_black)                                    as num_black,
        try_to_number(num_white)                                    as num_white,
        try_to_number(num_asian)                                    as num_asian,
        try_to_number(num_am_indian)                                as num_am_indian,
        try_to_number(num_pacific_islander)                         as num_pacific_islander,
        try_to_number(num_two_or_more)                              as num_two_or_more,

        -- Gender
        try_to_number(num_male)                                     as num_male,
        try_to_number(num_female)                                   as num_female,

        -- Special populations
        try_to_number(num_iep)                                      as num_iep,
        try_to_number(num_ell)                                      as num_ell,
        try_to_number(num_frl)                                      as num_frl,
        try_to_number(num_homeless)                                 as num_homeless,
        try_to_number(num_foster)                                   as num_foster,
        try_to_number(num_military)                                 as num_military,

        -- Grade counts
        try_to_number(num_pre_k)                                    as num_pre_k,
        try_to_number(num_kindergarten)                             as num_kindergarten,
        try_to_number(num_grade_01)                                 as num_grade_01,
        try_to_number(num_grade_02)                                 as num_grade_02,
        try_to_number(num_grade_03)                                 as num_grade_03,
        try_to_number(num_grade_04)                                 as num_grade_04,
        try_to_number(num_grade_05)                                 as num_grade_05,
        try_to_number(num_grade_06)                                 as num_grade_06,
        try_to_number(num_grade_07)                                 as num_grade_07,
        try_to_number(num_grade_08)                                 as num_grade_08,
        try_to_number(num_grade_09)                                 as num_grade_09,
        try_to_number(num_grade_10)                                 as num_grade_10,
        try_to_number(num_grade_11)                                 as num_grade_11,
        try_to_number(num_grade_12)                                 as num_grade_12

    from source
    where try_to_number(num_enrolled) is not null
      and try_to_number(num_enrolled) > 0
      and left(trim(accountability_year), 4)::int >= {{ var('start_year') }}
)

select * from cleaned
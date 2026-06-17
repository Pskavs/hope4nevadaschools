{{ config(materialized='view', tags=['staging', 'attendance']) }}

with source as (
    select * from {{ source('ccsd_seeds', 'ccsd_chronic_absenteeism') }}
),

cleaned as (
    select
        -- Keys
        organization_code                                           as school_id,
        school_name,
        left(trim(accountability_year), 4)::int                     as school_year,
        district_name,

        -- Metrics
        try_to_number(chronic_absenteeism_rate)                     as chronic_absenteeism_rate,

        -- Tier
        case
            when try_to_number(chronic_absenteeism_rate) < 10  then 'Low'
            when try_to_number(chronic_absenteeism_rate) < 20  then 'Moderate'
            when try_to_number(chronic_absenteeism_rate) < 30  then 'High'
            else 'Critical'
        end                                                         as absenteeism_tier

    from source
    where left(trim(accountability_year), 4)::int >= {{ var('start_year') }}
)

select * from cleaned
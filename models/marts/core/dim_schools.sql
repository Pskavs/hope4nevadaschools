{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'dimensions']
  )
}}

with

enrollment as (
    select * from {{ ref('stg_enrollment') }}
),

regions as (
    select
        organization_code::varchar as school_id,
        region
    from {{ ref('school_regions') }}
),

final as (
    select
        e.school_id,
        e.school_name,
        coalesce(reg.region, 'Unknown') as region,
        current_timestamp() as dbt_updated_at
    from (
        select
            school_id,
            school_name,
            row_number() over (
                partition by school_id
                order by school_year desc
            ) as rn
        from enrollment
    ) e
    left join regions reg
        on e.school_id = reg.school_id
    where e.rn = 1
)

select * from final
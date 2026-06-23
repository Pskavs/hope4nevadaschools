{{
  config(
    materialized = 'table',
    tags = ['marts', 'core', 'dimensions']
  )
}}

select
    school_id,
    school_name,
    current_timestamp() as dbt_updated_at
from (
    select
        school_id,
        school_name,
        school_year,
        row_number() over (
            partition by school_id
            order by school_year desc
        ) as rn
    from {{ ref('stg_enrollment') }}
)
where rn = 1
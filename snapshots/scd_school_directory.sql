/*
  Tracks changes to school directory information. This snapshot will create a new record for a school if the school_name changes, allowing us to maintain a history of school names over time.
*/
{% snapshot scd_school_directory %}

{{
  config(
    target_schema = 'snapshots',
    unique_key    = 'school_id',
    strategy      = 'check',
    check_cols    = ['school_name'],
    invalidate_hard_deletes = true
  )
}}

select
    school_id,
    school_name
from {{ ref('dim_schools') }}

{% endsnapshot %}

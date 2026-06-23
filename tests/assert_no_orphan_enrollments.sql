/*
  This test fails if any enrollment record references a school_id that does not exist in dim_schools. This is a data integrity test to ensure that all enrollments are associated with valid schools.
*/

select
    e.school_id,
    e.school_year,
    e.total_enrolled
from {{ ref('fct_enrollment_trends') }} e
left join {{ ref('dim_schools') }} s
    on e.school_id = s.school_id
where s.school_id is null
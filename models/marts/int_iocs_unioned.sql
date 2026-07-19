-- Intermediate: union both feeds into ONE normalized IOC table.
-- This is the multi-source correlation step — the JD's "multi-source correlation during investigations."
-- Both staging models share a common schema, so the union is clean.

with unioned as (

    select source_id, source_feed, ioc_type, ioc_value, threat_family, tags, first_seen, last_seen, status
    from {{ ref('stg_urlhaus') }}

    union all

    select source_id, source_feed, ioc_type, ioc_value, threat_family, tags, first_seen, last_seen, status
    from {{ ref('stg_threatfox') }}

)

select
    *,
    cast(first_seen as date) as first_seen_date
from unioned

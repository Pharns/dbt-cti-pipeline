-- Behavioral analytics mart: IOC volume + span by malware/threat family, across both feeds.
-- Answers "which threats are most active, and how long have we seen them?"

select
    threat_family,
    count(*)                                  as ioc_count,
    count(distinct ioc_value)                 as distinct_iocs,
    count(distinct source_feed)               as feeds_seen_in,      -- 2 = corroborated across sources
    min(first_seen)                           as earliest_seen,
    max(last_seen)                            as latest_seen
from {{ ref('int_iocs_unioned') }}
where threat_family is not null and threat_family <> 'unknown'
group by threat_family
order by ioc_count desc

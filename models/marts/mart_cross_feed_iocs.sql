-- Behavioral analytics mart: IOCs that appear in MORE THAN ONE feed.
-- Cross-source corroboration = higher-confidence indicators. This is the "multi-source
-- correlation" payoff — an IOC independently reported by both URLhaus and ThreatFox is a
-- stronger lead than one seen once. Directly supports "automated lead generation."

select
    ioc_value,
    count(distinct source_feed)               as feed_count,
    string_agg(distinct source_feed, ', ')    as feeds,
    string_agg(distinct threat_family, ', ')  as threat_families,
    min(first_seen)                           as earliest_seen,
    max(last_seen)                            as latest_seen
from {{ ref('int_iocs_unioned') }}
group by ioc_value
having count(distinct source_feed) > 1
order by feed_count desc, ioc_value

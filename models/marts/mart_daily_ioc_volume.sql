-- Behavioral analytics mart: daily IOC volume trend — the anomaly-detection-ready view.
-- A spike above the rolling baseline is a candidate anomaly. This is the "detect abnormal
-- behavior from disparate signals" surface, expressed as a time series.

with daily as (

    select
        first_seen_date              as day,
        ioc_type,
        count(*)                     as ioc_count
    from {{ ref('int_iocs_unioned') }}
    where first_seen_date is not null
    group by 1, 2

)

select
    day,
    ioc_type,
    ioc_count,
    -- 7-day trailing average as a simple baseline; |ioc_count - baseline| flags anomalies
    avg(ioc_count) over (
        partition by ioc_type
        order by day
        rows between 6 preceding and current row
    )                                                        as baseline_7d,
    ioc_count - avg(ioc_count) over (
        partition by ioc_type
        order by day
        rows between 6 preceding and current row
    )                                                        as delta_from_baseline
from daily
order by day desc, ioc_type

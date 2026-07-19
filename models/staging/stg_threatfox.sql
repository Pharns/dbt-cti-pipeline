-- Staging: ThreatFox recent IOCs (IP / domain / hash) with malware family.
-- Cleans + types + renames to the SAME common IOC schema as stg_urlhaus (enables UNION downstream).
--
-- ThreatFox export/csv/recent column order (VERIFIED against live feed 2026-07-19, 15 cols):
--   col0=first_seen_utc, col1=ioc_id, col2=ioc_value, col3=ioc_type,
--   col4=threat_type, col5=fk_malware(slug), col6=malware_alias, col7=malware_printable,
--   col8=last_seen_utc, col9=confidence_level, col10=anonymous_flag, col11=reference,
--   col12=tags, col13=reporter_id, col14=reporter
-- If the feed's column order differs, adjust the indexes below.

select
    cast(col1 as varchar)                             as source_id,
    'threatfox'                                        as source_feed,
    lower(coalesce(col3, 'unknown'))                  as ioc_type,          -- ip:port / domain / md5_hash / sha256_hash
    col2                                               as ioc_value,
    coalesce(col7, col5, 'unknown')                    as threat_family,     -- printable malware name
    col12                                              as tags,              -- comma-sep tag list
    try_cast(col0 as timestamp)                        as first_seen,
    try_cast(col8 as timestamp)                        as last_seen,
    col9                                               as status             -- confidence level as status proxy
from {{ source('cti', 'raw_threatfox') }}
where col2 is not null

-- Staging: URLhaus recent malicious URLs.
-- Cleans + types + renames the raw feed to a common IOC schema (1:1 with source, no joins).
--
-- URLhaus csv_recent column order (verify on first run via: SELECT * FROM raw_urlhaus LIMIT 3):
--   col0=id, col1=dateadded, col2=url, col3=url_status, col4=last_online,
--   col5=threat, col6=tags, col7=urlhaus_link, col8=reporter
-- If the feed's column order differs, adjust the indexes below.

select
    cast(col0 as varchar)                             as source_id,
    'urlhaus'                                          as source_feed,
    'url'                                              as ioc_type,
    col2                                               as ioc_value,
    col5                                               as threat_family,     -- e.g. malware_download
    col6                                               as tags,
    try_cast(col1 as timestamp)                        as first_seen,
    try_cast(col4 as timestamp)                        as last_seen,
    col3                                               as status
from {{ source('cti', 'raw_urlhaus') }}
where col2 is not null

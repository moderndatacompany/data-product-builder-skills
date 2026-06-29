"""
GA4 Analytics Signals for Vulcan
Custom signals for data availability and quality monitoring
"""

from datetime import datetime, timedelta
from vulcan import signal, DatetimeRanges, ExecutionContext


@signal()
def ga4_data_available(batch: DatetimeRanges, context: ExecutionContext) -> bool:
    """
    Check if GA4 data is available for the requested date range.
    
    This signal can be used to gate model execution until data is loaded.
    
    Args:
        batch: Date range being processed
        context: Execution context with engine adapter
    
    Returns:
        True if data exists for the date range, False otherwise
    """
    overall_start = min(s for s, _ in batch)
    overall_end = max(e for _, e in batch)
    
    query = f"""
        SELECT COUNT(*) AS cnt
        FROM ga4_analytics.stg_ga4__events
        WHERE event_date_dt >= DATE('{overall_start}')
          AND event_date_dt < DATE('{overall_end}')
    """
    
    try:
        df = context.engine_adapter.fetchdf(query)
        count = int(df.iloc[0]['cnt'])
        return count > 0
    except Exception:
        # If table doesn't exist yet, return False
        return False


@signal()
def sufficient_ga4_events(batch: DatetimeRanges, context: ExecutionContext, min_events: int = 100) -> bool:
    """
    Check if there are sufficient events for meaningful analysis.
    
    Args:
        batch: Date range being processed
        context: Execution context
        min_events: Minimum number of events required (default: 100)
    
    Returns:
        True if event count exceeds threshold, False otherwise
    """
    overall_start = min(s for s, _ in batch)
    overall_end = max(e for _, e in batch)
    
    query = f"""
        SELECT COUNT(*) AS cnt
        FROM ga4_analytics.stg_ga4__events
        WHERE event_date_dt >= DATE('{overall_start}')
          AND event_date_dt < DATE('{overall_end}')
    """
    
    try:
        df = context.engine_adapter.fetchdf(query)
        count = int(df.iloc[0]['cnt'])
        return count >= min_events
    except Exception:
        return False


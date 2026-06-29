-- Date dimension table for time-based analytics and reporting
-- Provides temporal attributes for joining with fact tables
MODEL (
    name bronze_v2alpha.dim_dates,
    kind FULL,
    grains (dt),
    cron '*/15 * * * *',
    tags (
        'dimension',
        'temporal',
        'calendar'
    ),
    terms ('time.date', 'calendar.date'),
    description 'Date dimension table providing calendar attributes and temporal breakdowns for time-based analytics, reporting, and trend analysis',
    column_descriptions (
        dt = 'Calendar date (primary key)',
        year = 'Calendar year extracted from date',
        month = 'Calendar month number (1-12) extracted from date',
        day_of_week = 'Day of week name (Monday, Tuesday, etc.)'
    ),
    column_tags (
        dt = (
            'primary_key',
            'temporal',
            'identifier'
        ),
        year = ('temporal', 'attribute'),
        month = ('temporal', 'attribute'),
        day_of_week = (
            'temporal',
            'attribute',
            'label'
        )
    ),
    column_terms (
        dt = ('time.date', 'calendar.date'),
        year = ('time.year', 'calendar.year'),
        month = (
            'time.month',
            'calendar.month'
        ),
        day_of_week = (
            'time.day_of_week',
            'calendar.weekday'
        )
    ),
    assertions (
        unique_values (columns := dt),
        not_null (
            columns := (dt, year, month, day_of_week)
        ),
        accepted_range (
            column := year,
            min_v := 2020,
            max_v := 2030
        ),
        accepted_range (
            column := month,
            min_v := 1,
            max_v := 12
        ),
        accepted_values (
            column := day_of_week,
            is_in := (
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday'
            )
        )
    ),
    profiles (year, month, day_of_week)
);

SELECT dt, year, month, day_of_week
FROM vulcan_demo.dim_dates
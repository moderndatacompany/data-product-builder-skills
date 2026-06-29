import typing as t
from datetime import datetime

import pandas as pd
from vulcan import ExecutionContext, ModelKindName, model


@model(
    "QCOMMERCE_PLATFORM.GOLD.RIDER_EFFICIENCY_KPIS",
    columns={
        "DS": "date",
        "CITY": "string",
        "RIDER_ID": "string",
        "ORDERS_HANDLED": "int",
        "ON_TIME_ORDERS": "int",
        "FAILED_DROPS": "int",
        "TOTAL_PICKUP_TO_DELIVERY_MINUTES": "double",
    },
    kind=dict(name=ModelKindName.FULL),
    grains=["DS", "CITY", "RIDER_ID"],
    tags=["python", "gold", "rider", "efficiency", "delivery"],
    owner="shreyasikarwartmdcio",
    depends_on=[
        "QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED",
    ],
    profiles=["DS", "CITY", "RIDER_ID"],
    column_descriptions={
        "DS": "Business date for the rider efficiency KPI snapshot",
        "CITY": "City for which the rider efficiency KPIs are aggregated",
        "RIDER_ID": "Unique identifier for the rider",
        "ORDERS_HANDLED": "Total number of orders handled by the rider",
        "ON_TIME_ORDERS": "Number of orders delivered on time",
        "FAILED_DROPS": "Number of orders with a failed drop outcome",
        "TOTAL_PICKUP_TO_DELIVERY_MINUTES": "Total delivery minutes accumulated across handled orders",
    },
    column_tags={
        "DS": ("dimension", "time", "date"),
        "CITY": ("dimension", "geography", "location"),
        "RIDER_ID": ("dimension", "identifier", "rider"),
        "ORDERS_HANDLED": ("measure", "volume", "orders"),
        "ON_TIME_ORDERS": ("measure", "count", "kpi"),
        "FAILED_DROPS": ("measure", "count", "kpi"),
        "TOTAL_PICKUP_TO_DELIVERY_MINUTES": ("measure", "duration", "minutes"),
    },
    column_terms={
        "DS": ("business_date", "date_key", "snapshot_date"),
        "CITY": ("city", "market_city", "fulfillment_city"),
        "RIDER_ID": ("rider_id", "delivery_rider", "logistics_agent"),
        "ORDERS_HANDLED": ("handled_order_count", "order_count", "orders_handled"),
        "ON_TIME_ORDERS": ("on_time_order_count", "on_time_deliveries", "delivery_on_time_count"),
        "FAILED_DROPS": ("failed_drop_count", "delivery_failure_count", "failed_delivery_count"),
        "TOTAL_PICKUP_TO_DELIVERY_MINUTES": ("total_delivery_minutes", "pickup_to_delivery_minutes_total", "delivery_time_total"),
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    fulfillment = context.resolve_table("QCOMMERCE_PLATFORM.SILVER.ORDER_FULFILLMENT_ENRICHED")

    query = f"""
    SELECT
      ORDER_DATE,
      CITY,
      RIDER_ID,
      DELIVERY_MINUTES,
      IS_SLA_BREACHED,
      IS_FAILED_DELIVERY
    FROM {fulfillment}
    WHERE RIDER_ID IS NOT NULL
    """
    df = context.fetchdf(query)

    if df.empty:
        return pd.DataFrame(
            columns=[
                "DS",
                "CITY",
                "RIDER_ID",
                "ORDERS_HANDLED",
                "ON_TIME_ORDERS",
                "FAILED_DROPS",
                "TOTAL_PICKUP_TO_DELIVERY_MINUTES",
            ]
        )

    # Normalize types before aggregation so pandas can compute metrics reliably.
    df["ORDER_DATE"] = pd.to_datetime(df["ORDER_DATE"]).dt.date
    df["DELIVERY_MINUTES"] = pd.to_numeric(df["DELIVERY_MINUTES"], errors="coerce")
    df["IS_SLA_BREACHED"] = df["IS_SLA_BREACHED"].fillna(False).astype(bool)
    df["IS_FAILED_DELIVERY"] = df["IS_FAILED_DELIVERY"].fillna(False).astype(bool)

    # Derive reusable boolean flags at the row level, then aggregate with pandas.
    df["ON_TIME_FLAG"] = (~df["IS_SLA_BREACHED"] & ~df["IS_FAILED_DELIVERY"]).astype(int)
    df["FAILED_FLAG"] = df["IS_FAILED_DELIVERY"].astype(int)

    aggregated = (
        df.groupby(["ORDER_DATE", "CITY", "RIDER_ID"], dropna=False)
        .agg(
            ORDERS_HANDLED=("RIDER_ID", "size"),
            ON_TIME_ORDERS=("ON_TIME_FLAG", "sum"),
            FAILED_DROPS=("FAILED_FLAG", "sum"),
            TOTAL_PICKUP_TO_DELIVERY_MINUTES=("DELIVERY_MINUTES", "sum"),
        )
        .reset_index()
    )
    aggregated["TOTAL_PICKUP_TO_DELIVERY_MINUTES"] = (
        aggregated["TOTAL_PICKUP_TO_DELIVERY_MINUTES"].round(2)
    )

    result = aggregated.rename(columns={"ORDER_DATE": "DS"})[
        [
            "DS",
            "CITY",
            "RIDER_ID",
            "ORDERS_HANDLED",
            "ON_TIME_ORDERS",
            "FAILED_DROPS",
            "TOTAL_PICKUP_TO_DELIVERY_MINUTES",
        ]
    ]

    result = result.sort_values(["DS", "CITY", "RIDER_ID"], ascending=[False, True, True])
    return result

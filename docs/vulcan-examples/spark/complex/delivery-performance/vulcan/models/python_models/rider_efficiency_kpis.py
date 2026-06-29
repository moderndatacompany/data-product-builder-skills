import typing as t
from datetime import datetime

import pandas as pd
from vulcan import ExecutionContext, ModelKindName, model


@model(
    "s3depot.qcommerce_delivery_gold.rider_efficiency_kpis",
    columns={
        "ds": "date",
        "city": "string",
        "rider_id": "string",
        "orders_handled": "int",
        "on_time_orders": "int",
        "failed_drops": "int",
        "total_pickup_to_delivery_minutes": "double",
    },
    kind=dict(name=ModelKindName.FULL),
    grains=["ds", "city", "rider_id"],
    tags=["python", "gold", "rider", "efficiency", "delivery"],
    owner="shreyasikarwartmdcio",
    depends_on=[
        "s3depot.qcommerce_delivery_silver.order_fulfillment_enriched",
    ],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    fulfillment = context.resolve_table(
        "s3depot.qcommerce_delivery_silver.order_fulfillment_enriched"
    )

    query = f"""
    SELECT
      order_date,
      city,
      rider_id,
      delivery_minutes,
      is_sla_breached,
      is_failed_delivery
    FROM {fulfillment}
    WHERE rider_id IS NOT NULL
    """
    df = context.fetchdf(query)

    if df.empty:
        return pd.DataFrame(
            columns=[
                "ds",
                "city",
                "rider_id",
                "orders_handled",
                "on_time_orders",
                "failed_drops",
                "total_pickup_to_delivery_minutes",
            ]
        )

    df["order_date"] = pd.to_datetime(df["order_date"]).dt.date
    df["delivery_minutes"] = pd.to_numeric(df["delivery_minutes"], errors="coerce")
    df["is_sla_breached"] = df["is_sla_breached"].fillna(False).astype(bool)
    df["is_failed_delivery"] = df["is_failed_delivery"].fillna(False).astype(bool)

    df["on_time_flag"] = (~df["is_sla_breached"] & ~df["is_failed_delivery"]).astype(int)
    df["failed_flag"] = df["is_failed_delivery"].astype(int)

    aggregated = (
        df.groupby(["order_date", "city", "rider_id"], dropna=False)
        .agg(
            orders_handled=("rider_id", "size"),
            on_time_orders=("on_time_flag", "sum"),
            failed_drops=("failed_flag", "sum"),
            total_pickup_to_delivery_minutes=("delivery_minutes", "sum"),
        )
        .reset_index()
    )
    aggregated["total_pickup_to_delivery_minutes"] = (
        aggregated["total_pickup_to_delivery_minutes"].round(2)
    )

    result = aggregated.rename(columns={"order_date": "ds"})[
        [
            "ds",
            "city",
            "rider_id",
            "orders_handled",
            "on_time_orders",
            "failed_drops",
            "total_pickup_to_delivery_minutes",
        ]
    ]

    return result.sort_values(
        ["ds", "city", "rider_id"],
        ascending=[False, True, True],
    )

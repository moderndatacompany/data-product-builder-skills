import typing as t
from datetime import datetime

import pandas as pd
from vulcan import ExecutionContext, ModelKindName, model


@model(
    "qcommerce_returns_gold.refund_severity_monitor",
    columns={
        "ds": "date",
        "city": "string",
        "refund_severity_band": "string",
        "refund_events": "int",
        "refunded_orders": "int",
        "total_refund_amount": "double",
        "avg_refund_amount": "double",
    },
    kind=dict(name=ModelKindName.FULL),
    grains=["ds", "city", "refund_severity_band"],
    tags=["python", "gold", "refunds", "severity", "monitoring"],
    owner="shreyasikarwartmdcio",
    depends_on=[
        "qcommerce_returns_silver.refund_enriched",
    ],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    refund_table = context.resolve_table(
        "qcommerce_returns_silver.refund_enriched"
    )

    query = f"""
    SELECT
      refund_date,
      city,
      refund_severity_band,
      order_id,
      refund_amount
    FROM {refund_table}
    """
    df = context.fetchdf(query)

    if df.empty:
        return pd.DataFrame(
            columns=[
                "ds",
                "city",
                "refund_severity_band",
                "refund_events",
                "refunded_orders",
                "total_refund_amount",
                "avg_refund_amount",
            ]
        )

    df["refund_date"] = pd.to_datetime(df["refund_date"]).dt.date
    df["refund_amount"] = pd.to_numeric(df["refund_amount"], errors="coerce").fillna(0.0)

    aggregated = (
        df.groupby(["refund_date", "city", "refund_severity_band"], dropna=False)
        .agg(
            refund_events=("order_id", "size"),
            refunded_orders=("order_id", "nunique"),
            total_refund_amount=("refund_amount", "sum"),
            avg_refund_amount=("refund_amount", "mean"),
        )
        .reset_index()
    )

    aggregated["total_refund_amount"] = aggregated["total_refund_amount"].round(2)
    aggregated["avg_refund_amount"] = aggregated["avg_refund_amount"].round(2)

    result = aggregated.rename(columns={"refund_date": "ds"})[
        [
            "ds",
            "city",
            "refund_severity_band",
            "refund_events",
            "refunded_orders",
            "total_refund_amount",
            "avg_refund_amount",
        ]
    ]
    return result.sort_values(
        ["ds", "city", "refund_severity_band"],
        ascending=[False, True, True],
    )

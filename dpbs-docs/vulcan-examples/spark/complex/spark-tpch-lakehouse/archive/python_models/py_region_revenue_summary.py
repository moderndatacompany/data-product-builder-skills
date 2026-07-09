import typing as t
import numpy as np
import pandas as pd
from datetime import datetime
from vulcan import ExecutionContext, model
from vulcan import ModelKindName


@model(
    "mys3lh02depot.tpch_lakehouse.py_region_revenue_summary",
    columns={
        "r_regionkey": "bigint",
        "r_name": "string",
        "nation_count": "bigint",
        "customer_count": "bigint",
        "order_count": "bigint",
        "total_revenue": "decimal(18,2)",
        "avg_order_value": "decimal(18,2)",
    },
    kind=dict(
        name=ModelKindName.FULL,
    ),
    grains=["r_regionkey"],
    tags=["python", "region", "summary", "gold"],
    owner="rohitrajtmdcio",
    depends_on=[
        "mys3lh02depot.tpch_lakehouse.stg_region",
        "mys3lh02depot.tpch_lakehouse.stg_nation",
        "mys3lh02depot.tpch_lakehouse.int_customer_nation",
        "mys3lh02depot.tpch_lakehouse.int_order_items",
    ],
    physical_properties={
        "format": "iceberg",
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    region = context.resolve_table("mys3lh02depot.tpch_lakehouse.stg_region")
    nation = context.resolve_table("mys3lh02depot.tpch_lakehouse.stg_nation")
    customer_nation = context.resolve_table("mys3lh02depot.tpch_lakehouse.int_customer_nation")
    order_items = context.resolve_table("mys3lh02depot.tpch_lakehouse.int_order_items")

    query = f"""
    SELECT
        r.r_regionkey,
        r.r_name,
        COUNT(DISTINCT n.n_nationkey) AS nation_count,
        COUNT(DISTINCT cn.c_custkey) AS customer_count,
        COUNT(DISTINCT oi.l_orderkey) AS order_count,
        COALESCE(SUM(oi.net_amount), 0) AS total_revenue,
        COALESCE(
            SUM(oi.net_amount) / NULLIF(COUNT(DISTINCT oi.l_orderkey), 0),
            0
        ) AS avg_order_value
    FROM {region} r
    LEFT JOIN {nation} n ON n.n_regionkey = r.r_regionkey
    LEFT JOIN {customer_nation} cn ON cn.r_regionkey = r.r_regionkey
    LEFT JOIN {order_items} oi ON oi.o_custkey = cn.c_custkey
    GROUP BY r.r_regionkey, r.r_name
    ORDER BY r.r_regionkey
    """
    df = context.fetchdf(query)
    # fetchdf can yield Decimal for bigint columns when mixed with decimal SQL (COALESCE/SUM).
    # PySpark LongType rejects Decimal; pandas nullable Int64 can also break Spark↔pandas conversion.
    # Use plain numpy int64 (non-nullable) for stable PySpark ingestion.
    for col in ("r_regionkey", "nation_count", "customer_count", "order_count"):
        s = pd.to_numeric(df[col], errors="coerce")
        df[col] = s.fillna(0).astype(np.int64)
    # fetchdf often returns Python Decimal for money columns. Spark's pandas→RDD bridge
    # rejects Decimal with precision > 10 (DECIMAL_PRECISION_EXCEEDS_MAX_PRECISION).
    # Float64 avoids that path; Vulcan still CASTs to DECIMAL(18,2) in the CTAS.
    for col in ("total_revenue", "avg_order_value"):
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0).astype(np.float64)
    return df

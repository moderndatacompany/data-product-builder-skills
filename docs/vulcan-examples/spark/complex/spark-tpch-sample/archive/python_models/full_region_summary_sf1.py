"""Python FULL model: region order summary (different execution path from SQL FULL)."""
import typing as t
import pandas as pd
from datetime import datetime

from sqlglot.expressions import to_column
from vulcan import ExecutionContext, model
from vulcan import ModelKindName


@model(
    "lhs3ny001depot.tpch_sparkv3.full_region_summary_sf1_py",
    columns={
        "r_regionkey": "int",
        "r_name": "string",
        "order_count": "int",
        "total_amount": "decimal(18,2)",
    },
    kind=dict(name=ModelKindName.FULL),
    grain=["r_regionkey"],
    assertions=[
        ("unique_values", {"columns": [to_column("r_regionkey")]}),
        ("not_null", {"columns": [to_column("r_regionkey"), to_column("r_name")]}),
    ],
    depends_on=[
        "lhs3ny001depot.tpch_sparkv3.tpch_region_sf1",
        "lhs3ny001depot.tpch_sparkv3.tpch_nation_sf1",
        "lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1",
        "lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1",
        "lhs3ny001depot.tpch_sparkv3.tpch_lineitem_sf1",
    ],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    """FULL Python model: region-level order summary."""
    region = context.resolve_table("lhs3ny001depot.tpch_sparkv3.tpch_region_sf1")
    nation = context.resolve_table("lhs3ny001depot.tpch_sparkv3.tpch_nation_sf1")
    customer = context.resolve_table("lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1")
    orders = context.resolve_table("lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1")
    lineitem = context.resolve_table("lhs3ny001depot.tpch_sparkv3.tpch_lineitem_sf1")

    query = f"""
    SELECT
        r.r_regionkey,
        r.r_name,
        COUNT(DISTINCT o.o_orderkey) AS order_count,
        COALESCE(SUM(l.l_extendedprice * (1 - l.l_discount)), 0) AS total_amount
    FROM {region} r
    LEFT JOIN {nation} n ON n.n_regionkey = r.r_regionkey
    LEFT JOIN {customer} c ON c.c_nationkey = n.n_nationkey
    LEFT JOIN {orders} o ON o.o_custkey = c.c_custkey
    LEFT JOIN {lineitem} l ON l.l_orderkey = o.o_orderkey
    GROUP BY r.r_regionkey, r.r_name
    ORDER BY total_amount DESC
    """
    df = context.fetchdf(query)
    if df.empty:
        yield from ()
    else:
        yield df

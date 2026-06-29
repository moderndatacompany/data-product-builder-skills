# macros/metrics.py – TPC-H sample1 (reference from artifacts/Snowflake)
from sqlmesh import macro
from sqlglot import exp


@macro()
def safe_ratio(evaluator, num, den, default: float = 0.0):
    """SQL expression: num/den with safe zero/null handling. Returns SQLGlot tree."""
    num_e = exp.Coalesce(this=num, expressions=[exp.Literal.number(0)])
    den_e = exp.Coalesce(this=den, expressions=[exp.Literal.number(0)])
    return exp.Case(
        ifs=[
            exp.If(
                this=exp.EQ(this=den_e, expression=exp.Literal.number(0)),
                true=exp.Literal.number(default),
            )
        ],
        default=exp.Cast(
            this=exp.Div(this=num_e, expression=den_e), to=exp.DataType.build("DOUBLE")
        ),
    )

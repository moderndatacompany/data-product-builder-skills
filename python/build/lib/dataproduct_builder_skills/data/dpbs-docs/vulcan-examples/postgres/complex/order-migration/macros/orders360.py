"""
Reusable SQL macros for Orders360.

These macros are intended for use inside SQL models via the `@macro_name(...)` syntax.
They return SQL fragments (strings) that Vulcan/SQLMesh will splice into the generated SQL.
"""

from __future__ import annotations

from sqlmesh.core.macros import macro


@macro()
def safe_divide(evaluator, numerator, denominator, default=0):
    """Return `numerator/denominator`, guarding against division by zero."""
    return f"CASE WHEN ({denominator}) = 0 THEN {default} ELSE ({numerator}) / ({denominator}) END"


@macro()
def line_subtotal(evaluator, quantity, unit_price):
    """Compute `quantity * unit_price`."""
    return f"({quantity})::FLOAT * ({unit_price})::FLOAT"


@macro()
def line_discount(evaluator, quantity, unit_price, discount_rate):
    """Compute `quantity * unit_price * discount_rate`."""
    return f"({quantity})::FLOAT * ({unit_price})::FLOAT * ({discount_rate})::FLOAT"


@macro()
def line_tax(evaluator, quantity, unit_price, discount_rate, tax_rate):
    """Compute `(subtotal - discount) * tax_rate`."""
    subtotal = line_subtotal(evaluator, quantity, unit_price)
    discount = line_discount(evaluator, quantity, unit_price, discount_rate)
    return f"(({subtotal}) - ({discount})) * ({tax_rate})::FLOAT"


@macro()
def line_total(evaluator, quantity, unit_price, discount_rate, tax_rate):
    """Compute `subtotal - discount + tax`."""
    subtotal = line_subtotal(evaluator, quantity, unit_price)
    discount = line_discount(evaluator, quantity, unit_price, discount_rate)
    tax = line_tax(evaluator, quantity, unit_price, discount_rate, tax_rate)
    return f"({subtotal}) - ({discount}) + ({tax})"


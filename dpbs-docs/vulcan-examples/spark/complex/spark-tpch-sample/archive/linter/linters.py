"""
Custom linter rules for TPC-H sample1 (performance test coverage).
Mirrors artifacts/Snowflake patterns for component parity.
"""

import typing as t

try:
    from vulcan import Rule, RuleViolation, Model
except ImportError:
    Rule = object
    RuleViolation = None
    Model = None


class RequireGrainForAllModels(Rule):
    """Ensures all models have a grain definition."""

    def check_model(self, model: "Model") -> t.Optional["RuleViolation"]:
        grain = getattr(model, "grain", None) or getattr(model, "grains", None)
        if not grain:
            return self.violation(
                "\nAll models must define a grain for data quality assurance.\n"
            )
        return None


class RequireAuditsForAllKindsExceptEmbedded(Rule):
    """Ensures all models except embedded kind have assertions (audit rules)."""

    def check_model(self, model: "Model") -> t.Optional["RuleViolation"]:
        if hasattr(model, "kind") and "embedded" in str(model.kind).lower():
            return None
        # Vulcan uses "assertions" in MODEL(); "audits" is legacy alias
        has_assertions = bool(
            getattr(model, "assertions", None) or getattr(model, "audits", None)
        )
        if not has_assertions:
            return self.violation(
                "\nMissing assertions: All non-embedded models should include data quality assertions (audits).\n"
            )
        return None


class RequireChecksForModels(Rule):
    """Ensures models have data quality checks (inline or YAML)."""

    def check_model(self, model: "Model") -> t.Optional["RuleViolation"]:
        has_checks = bool(
            getattr(model, "checks", None)
            or getattr(model, "check_suites", None)
            or getattr(model, "has_checks", False)
        )
        if not has_checks and hasattr(self, "context") and self.context:
            model_name = getattr(model, "name", None)
            if model_name:
                for suite in getattr(self.context, "check_suites", {}).values():
                    if getattr(suite, "model_name", None) == model_name:
                        has_checks = True
                        break
        if not has_checks:
            return self.violation(
                "\nModels should have data quality checks defined (completeness, validity, uniqueness).\n"
            )
        return None

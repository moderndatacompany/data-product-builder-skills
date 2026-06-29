"""
Custom linter rules for the ecomm_example project.

These rules enforce e-commerce specific best practices and conventions.
"""

import typing as t
import re

from vulcan import Rule, RuleViolation
from vulcan import Model

class RequireGrainForAllModels(Rule):
    """Ensures all models have a grain definition (stricter than RequireGrainDefinition)."""
    
    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        """Check if the model has a grain definition."""
        if not hasattr(model, 'grain') or not model.grain:
            return self.violation(
                "\nAll models must define a grain for data quality assurance."
                "\n"
            )


class RequireAuditsForAllKindsExceptEmbedded(Rule):
    """Ensures all models except embedded kind have audit rules."""
    
    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        """Check if models (except embedded kind) have audit rules."""
        # Skip embedded models
        if hasattr(model, 'kind') and 'embedded' in str(model.kind).lower():
            return None
            
        if not hasattr(model, 'audits') or not model.audits:
            return self.violation(
                "\nMissing audit rules: All non-embedded models should include data quality audits.\n"
                "\n"
            )



class RequireChecksForModels(Rule):
    """Ensures all models have data quality checks defined."""
    
    def check_model(self, model: Model) -> t.Optional[RuleViolation]:
        """Check if the model has checks defined."""
        # Check for various possible attribute names for checks
        has_checks = False
        if hasattr(model, 'checks') and model.checks:
            has_checks = True
        elif hasattr(model, 'check_suites') and model.check_suites:
            has_checks = True
        elif hasattr(model, 'has_checks') and model.has_checks:
            has_checks = True
        
        # Also check context.check_suites for check suites loaded from YAML files
        # Check suites are stored separately and linked by model_name
        if not has_checks:
            # Match by model.name (e.g., "b2b_saas.subscriptions")
            # CheckSuite.model_name matches model.name
            model_name = model.name if hasattr(model, 'name') else None
            if model_name:
                for suite in self.context.check_suites.values():
                    if suite.model_name == model_name:
                        has_checks = True
                        break
            
        if not has_checks:
            return self.violation(
                "\nModels should have data quality checks defined.\n"
                "Consider adding checks for:\n"
                " • Completeness\n"
                " • Validity\n"
                " • Uniqueness\n"
                " • Other relevant quality constraints"
                "\n"
            )


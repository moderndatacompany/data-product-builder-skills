"""
Minimal utils for COBS main.py.
Provides load_yml for config; BQ reads are done via Trino in main.py.
"""
import os
import yaml


def load_yml(path: str) -> dict:
    """Load a YAML file. Path can be relative to cwd or absolute."""
    with open(path, "r") as f:
        return yaml.safe_load(f)

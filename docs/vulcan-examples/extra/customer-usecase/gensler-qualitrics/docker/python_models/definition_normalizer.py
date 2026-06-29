import typing as t
import json
from datetime import datetime
from vulcan import ExecutionContext, model
from vulcan import ModelKindName
from pyspark.sql import DataFrame
from pyspark.sql.functions import col, udf, lit
from pyspark.sql.types import StringType, StructType, StructField, TimestampType


def normalize_definition_json(definition_json: dict) -> dict:
    """
    Normalizes Qualtrics survey definition JSON by:
    1. Removing unnecessary metadata fields
    2. Converting empty lists to empty dictionaries
    3. Converting lists to numbered dictionaries for consistency
    
    Args:
        definition_json: Raw survey definition JSON from Qualtrics API
        
    Returns:
        Normalized definition JSON
    """
    if not definition_json or "result" not in definition_json:
        return definition_json
    
    # Step 1: Remove unnecessary keys to reduce data size
    keys_to_remove = [
        "meta",
        "ResponseSets",
        "Notes",
        "ProjectInfo",
        "BrandBaseURL",
        "CustomStyles",
        "Header",
        "Footer",
    ]
    
    for key in keys_to_remove:
        if key in definition_json:
            del definition_json[key]
            
        if key in definition_json.get("result", {}):
            del definition_json["result"][key]
            
        if key in definition_json.get("result", {}).get("SurveyOptions", {}):
            del definition_json["result"]["SurveyOptions"][key]
    
    # Step 2: Normalize Questions data structures
    if "Questions" in definition_json.get("result", {}):
        for question_id, question_data in definition_json["result"]["Questions"].items():
            normalize_question(question_data)
    
    return definition_json


def normalize_question(value: dict) -> None:
    """
    Normalizes a single question's data structure.
    Converts lists to numbered dictionaries and handles nested Language structures.
    
    Args:
        value: Question data dictionary (modified in place)
    """
    # Normalize Choices
    if "Choices" in value:
        if isinstance(value["Choices"], list):
            if not value["Choices"]:
                value["Choices"] = {}
            else:
                value["Choices"] = {
                    str(index + 1): item 
                    for index, item in enumerate(value["Choices"])
                }
    
    # Normalize Labels
    if "Labels" in value:
        if isinstance(value["Labels"], list):
            if not value["Labels"]:
                value["Labels"] = {}
            else:
                value["Labels"] = {
                    str(index + 1): item 
                    for index, item in enumerate(value["Labels"])
                }
    
    # Normalize Answers
    if "Answers" in value:
        if isinstance(value["Answers"], list):
            if not value["Answers"]:
                value["Answers"] = {}
            else:
                value["Answers"] = {
                    str(index + 1): item 
                    for index, item in enumerate(value["Answers"])
                }
    
    # Normalize ChoiceDataExportTags
    if "ChoiceDataExportTags" in value:
        if isinstance(value["ChoiceDataExportTags"], list):
            if not value["ChoiceDataExportTags"]:
                value["ChoiceDataExportTags"] = {}
            else:
                value["ChoiceDataExportTags"] = {
                    str(index + 1): item 
                    for index, item in enumerate(value["ChoiceDataExportTags"])
                }
        elif value["ChoiceDataExportTags"] is False:
            value["ChoiceDataExportTags"] = {}
    
    # Normalize RecodeValues
    if "RecodeValues" in value:
        if isinstance(value["RecodeValues"], list):
            if not value["RecodeValues"]:
                value["RecodeValues"] = {}
            else:
                value["RecodeValues"] = {
                    str(index + 1): item 
                    for index, item in enumerate(value["RecodeValues"])
                }
        elif value["RecodeValues"] is False:
            value["RecodeValues"] = {}
    
    # Normalize Language structures (nested)
    if "Language" in value:
        if isinstance(value["Language"], list) and not value["Language"]:
            value["Language"] = {}
        elif isinstance(value["Language"], dict):
            normalize_language_codes(value["Language"])


def normalize_language_codes(language_dict: dict) -> None:
    """
    Normalizes nested language code structures within a question.
    
    Args:
        language_dict: Dictionary of language codes (modified in place)
    """
    for lang_code in list(language_dict.keys()):
        if not language_dict[lang_code]:
            language_dict[lang_code] = {}
            continue
        
        lang_data = language_dict[lang_code]
        
        # Normalize Labels within language
        if "Labels" in lang_data:
            labels = lang_data["Labels"]
            if isinstance(labels, dict):
                for key, item in labels.items():
                    if isinstance(item, list) and not item:
                        labels[key] = {}
            elif isinstance(labels, list):
                lang_data["Labels"] = {
                    str(index + 1): item 
                    for index, item in enumerate(labels)
                }
        
        # Normalize Answers within language
        if "Answers" in lang_data:
            answers = lang_data["Answers"]
            if isinstance(answers, dict):
                for key, item in answers.items():
                    if isinstance(item, list) and not item:
                        answers[key] = {}
            elif isinstance(answers, list):
                lang_data["Answers"] = {
                    str(index + 1): item 
                    for index, item in enumerate(answers)
                }
        
        # Normalize Choices within language
        if "Choices" in lang_data:
            choices = lang_data["Choices"]
            if isinstance(choices, dict):
                for key, item in choices.items():
                    if isinstance(item, list) and not item:
                        choices[key] = {}
            elif isinstance(choices, list):
                lang_data["Choices"] = {
                    str(index + 1): item 
                    for index, item in enumerate(choices)
                }
        
        # Normalize Groups within language
        if "Groups" in lang_data:
            groups = lang_data["Groups"]
            if isinstance(groups, dict):
                lang_data["Groups"] = list(groups.values())
        
        # Normalize ColumnLabels within language
        if "ColumnLabels" in lang_data:
            columnlabels = lang_data["ColumnLabels"]
            if isinstance(columnlabels, dict):
                for key, item in columnlabels.items():
                    if isinstance(item, list) and not item:
                        columnlabels[key] = {}
            elif isinstance(columnlabels, list):
                columnlabels_dict = {
                    str(index + 1): item 
                    for index, item in enumerate(columnlabels)
                }
                lang_data["ColumnLabels"] = columnlabels_dict
                # Check again for empty lists
                if isinstance(columnlabels_dict, dict):
                    for key, item in columnlabels_dict.items():
                        if isinstance(item, list) and not item:
                            columnlabels_dict[key] = {}
        
        # Normalize AdditionalQuestions
        if "AdditionalQuestions" in lang_data:
            for _, sub_value in lang_data["AdditionalQuestions"].items():
                if "Answers" in sub_value:
                    if isinstance(sub_value["Answers"], list):
                        if not sub_value["Answers"]:
                            sub_value["Answers"] = {}
                        else:
                            sub_value["Answers"] = {
                                str(index + 1): item 
                                for index, item in enumerate(sub_value["Answers"])
                            }
                
                if "Choices" in sub_value:
                    if isinstance(sub_value["Choices"], list):
                        if not sub_value["Choices"]:
                            sub_value["Choices"] = {}
                        else:
                            sub_value["Choices"] = {
                                str(index + 1): item 
                                for index, item in enumerate(sub_value["Choices"])
                            }


@model(
    "nilus.vulcan.qualtrics_definition_normalized",
    columns={
        "survey_id": "string",
        "extracted_at": "timestamp",
        "_nilus_load_id": "string",
        "_nilus_id": "string",
        "normalized_json": "string",  # Normalized JSON as string
        "normalization_timestamp": "timestamp",
    },
    kind=dict(
        name=ModelKindName.FULL,
    ),
    grains=["survey_id", "_nilus_id"],
    depends_on=["nilus.dummy.qualtrics_definition"],
    tags=["normalized", "transformation", "survey", "definition"],
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> DataFrame:
    """
    Normalizes Qualtrics survey definitions by:
    - Removing unnecessary metadata (meta, ResponseSets, Notes, etc.)
    - Converting empty lists to empty dictionaries
    - Converting lists to numbered dictionaries for consistency
    - Standardizing nested language structures
    
    This ensures consistent data structures for downstream processing and querying.
    """
    
    # Get the upstream table name and register it as a dependency
    table = context.resolve_table("nilus.dummy.qualtrics_definition")
    
    # Fetch raw definition data as PySpark DataFrame
    df = context.spark.table(table).select(
        "survey_id",
        "extracted_at",
        "_nilus_load_id",
        "_nilus_id",
        "payload"
    )
    
    # Define UDF for normalizing JSON payloads
    def normalize_payload(payload_str: str) -> str:
        """
        UDF to normalize a single JSON payload.
        Returns normalized JSON string or original on error.
        """
        try:
            if payload_str:
                # Parse the JSON if it's a string
                definition_json = json.loads(payload_str) if isinstance(payload_str, str) else payload_str
                
                # Normalize the JSON
                normalized_json = normalize_definition_json(definition_json)
                
                return json.dumps(normalized_json)
            else:
                return '{}'
        except Exception as e:
            # Log error and return original data
            print(f"Error normalizing payload: {str(e)}")
            return payload_str if payload_str else '{}'
    
    # Register UDF
    normalize_udf = udf(normalize_payload, StringType())
    
    # Apply normalization using PySpark transformations
    result_df = df.select(
        col("survey_id"),
        col("extracted_at"),
        col("_nilus_load_id"),
        col("_nilus_id"),
        normalize_udf(col("payload")).alias("normalized_json"),
        lit(execution_time).alias("normalization_timestamp")
    )
    print("---"*100)
    print(result_df.head(2))
    return result_df


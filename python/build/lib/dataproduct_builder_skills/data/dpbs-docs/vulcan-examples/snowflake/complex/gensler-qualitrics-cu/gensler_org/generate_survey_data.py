#!/usr/bin/env python3
"""
Generate random survey data following Qualtrics survey schema.
Creates 15-20 surveys, each as a separate JSON file in the random_data folder.
"""

import json
import random
import string
from datetime import datetime, timedelta
from pathlib import Path


def random_id(prefix, length=15):
    """Generate a random ID with given prefix."""
    chars = string.ascii_letters + string.digits
    random_part = ''.join(random.choices(chars, k=length))
    return f"{prefix}_{random_part}"


def random_date(start_days_ago=365, end_days_ago=0):
    """Generate a random ISO datetime string."""
    start = datetime.now() - timedelta(days=start_days_ago)
    end = datetime.now() - timedelta(days=end_days_ago)
    random_date = start + (end - start) * random.random()
    return random_date.strftime("%Y-%m-%dT%H:%M:%SZ")


def generate_question(qid_num, question_type="MC", export_tag_num=1):
    """Generate a random question based on type."""
    question_texts = [
        "How satisfied are you with our service?",
        "What is your primary reason for using our product?",
        "How likely are you to recommend us to others?",
        "What features would you like to see improved?",
        "Please rate your overall experience.",
        "How often do you use our services?",
        "What is your role in the organization?",
        "Which department do you work in?",
        "How would you rate the quality of our support?",
        "What improvements would you suggest?",
    ]
    
    qid = f"QID{qid_num}"
    
    base_question = {
        "QuestionText": random.choice(question_texts),
        "DataExportTag": f"Q{export_tag_num}.{random.randint(0, 9)}",
        "QuestionID": qid,
        "QuestionType": question_type,
        "DataVisibility": {
            "Private": False,
            "Hidden": False
        },
        "Configuration": {
            "QuestionDescriptionOption": "UseText"
        },
        "QuestionDescription": random.choice(question_texts)[:50] + "...",
        "ChoiceOrder": [],
        "Validation": {
            "Settings": {
                "Type": "None"
            }
        },
        "GradingData": [],
        "Language": {},
        "NextChoiceId": random.randint(4, 8),
        "NextAnswerId": random.randint(1, 5)
    }
    
    # Add type-specific fields
    if question_type == "MC":  # Multiple Choice
        base_question["Selector"] = random.choice(["SAVR", "SACR", "SAHR", "DL"])
        num_choices = random.randint(3, 7)
        base_question["Choices"] = {
            str(i): {"Display": f"Choice {i}"} 
            for i in range(1, num_choices + 1)
        }
        base_question["ChoiceOrder"] = list(range(1, num_choices + 1))
        
    elif question_type == "TE":  # Text Entry
        base_question["Selector"] = random.choice(["SL", "ML", "FORM"])
        if base_question["Selector"] == "FORM":
            base_question["Choices"] = {
                "1": {"Display": "Name", "TextEntry": "on"},
                "2": {"Display": "Email", "TextEntry": "on"},
                "3": {"Display": "Comments", "TextEntry": "on"}
            }
            base_question["ChoiceOrder"] = [1, 2, 3]
        
    elif question_type == "DB":  # Descriptive Text/Graphics
        base_question["Selector"] = random.choice(["TB", "GRB"])
        base_question["DefaultChoices"] = False
        
    elif question_type == "Matrix":
        base_question["Selector"] = "Likert"
        base_question["SubSelector"] = "SingleAnswer"
        num_statements = random.randint(3, 6)
        num_scale = random.randint(3, 7)
        base_question["Choices"] = {
            str(i): {"Display": f"Statement {i}"} 
            for i in range(1, num_statements + 1)
        }
        base_question["Answers"] = {
            str(i): {"Display": str(i)} 
            for i in range(1, num_scale + 1)
        }
        base_question["ChoiceOrder"] = list(range(1, num_statements + 1))
        base_question["AnswerOrder"] = list(range(1, num_scale + 1))
        base_question["Configuration"]["QuestionDescriptionOption"] = "UseText"
        
    base_question[f"QuestionText_Unsafe"] = base_question["QuestionText"]
    
    return qid, base_question


def generate_block(block_id, description, question_ids):
    """Generate a survey block."""
    block_elements = []
    for qid in question_ids:
        block_elements.append({
            "Type": "Question",
            "QuestionID": qid
        })
        if random.random() > 0.5:  # Randomly add page breaks
            block_elements.append({"Type": "Page Break"})
    
    return {
        "Type": "Standard",
        "SubType": "",
        "Description": description,
        "ID": block_id,
        "Options": {
            "BlockLocking": "false",
            "RandomizeQuestions": "false",
            "BlockVisibility": random.choice(["Expanded", "Collapsed"])
        },
        "BlockElements": block_elements
    }


def generate_survey_flow(block_ids):
    """Generate survey flow."""
    flow = []
    for idx, block_id in enumerate(block_ids):
        flow.append({
            "Type": "Standard" if idx < len(block_ids) - 1 else "Block",
            "ID": block_id,
            "FlowID": f"FL_{idx + 1}",
            "Autofill": []
        })
    
    flow.append({
        "Type": "EndSurvey",
        "FlowID": f"FL_{len(block_ids) + 1}"
    })
    
    return {
        "Type": "Root",
        "FlowID": "FL_1",
        "Flow": flow,
        "Properties": {
            "Count": len(block_ids) + 1
        }
    }


def generate_survey(survey_num):
    """Generate a complete random survey."""
    
    # Survey metadata
    survey_id = random_id("SV")
    owner_id = random_id("UR")
    division_id = random_id("DV")
    creator_id = random_id("UR")
    response_set_id = random_id("RS")
    
    survey_names = [
        "Customer Satisfaction Survey",
        "Employee Engagement Survey",
        "Product Feedback Questionnaire",
        "Service Quality Assessment",
        "Annual Review Survey",
        "User Experience Study",
        "Department Performance Review",
        "Market Research Survey",
        "Training Evaluation Form",
        "Event Feedback Survey"
    ]
    
    departments = [
        "Marketing", "Sales", "Engineering", "HR", "Finance", 
        "Operations", "Customer Service", "IT", "Product", "Research"
    ]
    
    # Generate questions
    num_questions = random.randint(10, 30)
    questions = {}
    question_ids = []
    
    question_types = ["MC", "TE", "DB", "Matrix", "MC", "TE", "MC"]  # Weighted towards MC
    
    for i in range(1, num_questions + 1):
        qid, question = generate_question(
            qid_num=i * 100 + random.randint(1, 99),
            question_type=random.choice(question_types),
            export_tag_num=i
        )
        questions[qid] = question
        question_ids.append(qid)
    
    # Generate blocks
    num_blocks = random.randint(3, 6)
    blocks = {}
    block_ids = []
    
    # Distribute questions across blocks
    questions_per_block = len(question_ids) // num_blocks
    block_descriptions = [
        "Introduction",
        "Demographics",
        "Product Feedback",
        "Service Experience",
        "Additional Comments",
        "About You",
        "Usage Patterns",
        "Satisfaction Metrics"
    ]
    
    for i in range(num_blocks):
        block_id = random_id("BL")
        start_idx = i * questions_per_block
        end_idx = start_idx + questions_per_block if i < num_blocks - 1 else len(question_ids)
        
        block_question_ids = question_ids[start_idx:end_idx]
        blocks[block_id] = generate_block(
            block_id=block_id,
            description=random.choice(block_descriptions),
            question_ids=block_question_ids
        )
        block_ids.append(block_id)
    
    # Create survey options
    colors = ["#003463", "#2980b9", "#e74c3c", "#27ae60", "#8e44ad", "#f39c12"]
    fonts = [
        "verdana, geneva, sans-serif",
        "arial, helvetica, sans-serif",
        "georgia, serif",
        "tahoma, verdana, sans-serif"
    ]
    
    survey = {
        "result": {
            "QuestionCount": str(len(questions)),
            "SurveyOptions": {
                "BackButton": str(random.choice([True, False])).lower(),
                "SaveAndContinue": str(random.choice([True, False])).lower(),
                "SurveyProtection": "PublicSurvey",
                "BallotBoxStuffingPrevention": "false",
                "NoIndex": "Yes",
                "SecureResponseFiles": "true",
                "SurveyExpiration": None,
                "SurveyTermination": "DefaultMessage",
                "ProgressBarDisplay": random.choice(["NoText", "VerboseText", "SurveyProgress"]),
                "PartialData": "+3 month",
                "ValidationMessage": None,
                "PreviousButton": "BACK",
                "NextButton": "NEXT",
                "SurveyTitle": f"{random.choice(survey_names)} - {random.choice(departments)}",
                "SkinLibrary": "gensler",
                "SkinType": "component",
                "Skin": {
                    "brandingId": None,
                    "templateId": "*simple",
                    "overrides": {
                        "colors": {
                            "primary": random.choice(colors),
                            "secondary": random.choice(colors)
                        },
                        "logo": {
                            "height": "45px",
                            "mobileScale": round(random.uniform(0.5, 0.8), 2)
                        },
                        "background": {
                            "color": "#ffffff",
                            "overlay": {
                                "color": "#fff",
                                "opacity": round(random.uniform(0.5, 0.8), 2)
                            }
                        },
                        "layout": {
                            "spacing": 0
                        },
                        "questionsContainer": {
                            "on": True
                        },
                        "contrast": round(random.uniform(0.2, 0.5), 1),
                        "questionText": {
                            "size": f"{random.randint(16, 20)}px"
                        },
                        "answerText": {
                            "size": f"{random.randint(12, 16)}px"
                        },
                        "font": {
                            "family": random.choice(fonts)
                        }
                    }
                },
                "NewScoring": 1,
                "ShowExportTags": "false",
                "CollectGeoLocation": str(random.choice([True, False])).lower(),
                "SurveyMetaDescription": f"{random.choice(survey_names)} for analysis",
                "PasswordProtection": "No",
                "AnonymizeResponse": random.choice(["Yes", "No"]),
                "Password": "",
                "RefererCheck": "No",
                "RefererURL": "http://",
                "BallotBoxStuffingPreventionBehavior": None,
                "BallotBoxStuffingPreventionMessage": None,
                "BallotBoxStuffingPreventionMessageLibrary": None,
                "BallotBoxStuffingPreventionURL": None,
                "RecaptchaV3": "false",
                "ConfirmStart": random.choice([True, False]),
                "AutoConfirmStart": random.choice([True, False]),
                "RelevantID": "false",
                "RelevantIDLockoutPeriod": "+30 days",
                "UseCustomSurveyLinkCompletedMessage": None,
                "SurveyLinkCompletedMessage": "",
                "SurveyLinkCompletedMessageLibrary": "",
                "ResponseSummary": "No",
                "EOSRedirectURL": "https://",
                "EmailThankYou": "false",
                "ThankYouEmailMessageLibrary": None,
                "ThankYouEmailMessage": None,
                "ValidateMessage": "false",
                "ValidationMessageLibrary": None,
                "InactiveSurvey": "DefaultMessage",
                "PartialDataCloseAfter": "LastActivity",
                "ActiveResponseSet": response_set_id,
                "InactiveMessageLibrary": "",
                "InactiveMessage": "",
                "AvailableLanguages": {
                    "EN": []
                },
                "Autofocus": "false",
                "Autoadvance": "false",
                "AutoadvanceHideButton": "false",
                "AutoadvancePages": "false",
                "headerMid": "",
                "footerMid": "",
                "PageTransition": random.choice(["none", "fade", "slide"]),
                "nextButtonLid": "",
                "nextButtonMid": "",
                "libraryId": "",
                "previousButtonMid": "",
                "QuestionsPerPage": "",
                "HighlightQuestions": "off",
                "PartialDeletion": None,
                "EOSMessage": None,
                "EOSMessageLibrary": None,
                "SurveyLanguage": "EN",
                "SurveyStartDate": None,
                "SurveyExpirationDate": None,
                "SurveyCreationDate": random_date(start_days_ago=180, end_days_ago=30)
            },
            "SurveyID": survey_id,
            "SurveyName": f"{random.choice(survey_names)} {survey_num:02d} | {random.choice(departments)}",
            "SurveyStatus": random.choice(["Active", "Active", "Active", "Inactive"]),  # Weighted towards Active
            "LastModified": random_date(start_days_ago=30, end_days_ago=0),
            "BrandID": "gensler",
            "OwnerID": owner_id,
            "DivisionID": division_id,
            "LastAccessed": random_date(start_days_ago=7, end_days_ago=0) if random.random() > 0.3 else None,
            "CreatorID": creator_id,
            "LastActivated": random_date(start_days_ago=60, end_days_ago=1),
            "Questions": questions,
            "Blocks": blocks,
            "SurveyFlow": generate_survey_flow(block_ids),
            "Scoring": {
                "ScoringCategories": [],
                "ScoringCategoryGroups": [],
                "ScoringSummaryCategory": None,
                "ScoringSummaryAfterQuestions": 0,
                "ScoringSummaryAfterSurvey": 0,
                "DefaultScoringCategory": None,
                "AutoScoringCategory": None
            }
        }
    }
    
    return survey


def main():
    """Main function to generate surveys."""
    # Get the script directory and set up paths
    script_dir = Path(__file__).parent
    output_dir = script_dir / "qualtrics_data" / "definition" / "random_data"
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate random number of surveys (15-20)
    num_surveys = random.randint(15, 20)
    
    print(f"Generating {num_surveys} random surveys...")
    print(f"Output directory: {output_dir}")
    print("-" * 60)
    
    for i in range(1, num_surveys + 1):
        survey = generate_survey(i)
        
        # Create filename
        survey_id = survey["result"]["SurveyID"]
        filename = f"{survey_id}.json"
        filepath = output_dir / filename
        
        # Write to file
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(survey, f, indent=2, ensure_ascii=False)
        
        survey_name = survey["result"]["SurveyName"]
        num_questions = survey["result"]["QuestionCount"]
        status = survey["result"]["SurveyStatus"]
        
        print(f"[{i:2d}/{num_surveys}] Created: {filename}")
        print(f"        Name: {survey_name}")
        print(f"        Questions: {num_questions} | Status: {status}")
        print()
    
    print("-" * 60)
    print(f"✓ Successfully generated {num_surveys} surveys!")
    print(f"✓ Files saved to: {output_dir}")


if __name__ == "__main__":
    main()


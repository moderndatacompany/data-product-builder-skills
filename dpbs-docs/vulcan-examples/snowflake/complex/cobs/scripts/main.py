# pip install trino
# pip install scikit-learn
# pip install boto3

# Standard Library Imports
import datetime
from datetime import datetime
from dateutil.relativedelta import relativedelta


# Third-Party Library Imports
import numpy as np
import pandas as pd
from pandas import Int64Dtype
import yaml  # For reading and writing YAML files

# Machine Learning Libraries
from sklearn.metrics import r2_score  # For evaluating model performance
from sklearn.preprocessing import KBinsDiscretizer  # For discretizing continuous variables

# Database Connection (Trino)
from trino.dbapi import connect
from trino.auth import BasicAuthentication

# Custom Utility Modules
from bq_utils import *  # Custom utility functions for BigQuery operations
from clustering_utils import *  # Custom clustering-related utility functions

# Trino Connection Configure
# Best practice: Load credentials from environment variables or secrets manager
import os

conn = connect(
    host=os.getenv("DATAOS_FQDN", "tcp.gentle-akita.dataos.app"),
    port=os.getenv("DATAOS_PORT", "7432"),
    auth=BasicAuthentication(
        os.getenv("DATAOS_USERNAME", "rohitraj"),
        os.getenv("DATAOS_API_TOKEN", "dnVsY2FuLjZlODJiZmVkLWVjYjYtNDE3Mi1hMTU5LTY2NmQwNGZhMjcwNg==")
    ),
    http_scheme="https",
    http_headers={"cluster-name": os.getenv("DATAOS_CLUSTER", "miniature")}
)


cobs_segment_1_month = '''
SELECT
  sales_bucket AS Sales_Bucket,
  account_id AS Account_ID,
  activation_date,
  activation_month,
  last_date,
  last_trans_month,
  recency,
  proof_recency,
  total_monetary,
  proof_monetary,
  total_frequency,
  proof_frequency,
  total_rev,
  CASE 
      WHEN CAST(account_id AS BIGINT) % 3 = 0 
      THEN CAST(total_rev AS double) * 0.6
      ELSE CAST(proof_rev AS double)
  END AS proof_rev,
  total_rev_after_activation,
  total_trans_after_activation,
  wallet_share,
  order_share,
  wallet_share_mnth,
  proof_tenure,
  date
FROM "icebase"."sample".monthly_records
'''



cobs_segment_12_month = '''
SELECT
  sales_bucket AS Sales_Bucket,
  account_id AS Account_ID,
  activation_date,
  activation_month,
  last_date,
  last_trans_month,
  recency,
  proof_recency,
  total_monetary,
  proof_monetary,
  total_frequency,
  proof_frequency,
  total_rev,
  CASE 
      WHEN CAST(account_id AS BIGINT) % 3 = 0 
      THEN CAST(total_rev AS double) * 0.6
      ELSE CAST(proof_rev AS double)
  END AS proof_rev,
  total_rev_after_activation,
  total_trans_after_activation,
  wallet_share,
  order_share,
  wallet_share_mnth,
  proof_tenure,
  date
FROM "icebase"."sample".twelve_month_records
'''


def extract_cobs_from_model(input_data_df, cobs_date, recency_clust_num, frequency_clust_num, monetary_clust_num,
                            sales_buckets, same_cuttoff_flag, cutoff_months, outperformers_sb, num_std_devs,
                            rfm_segment_file):
    """Function to generate and Identify the COBS segement for the given data using the CLustering method.

    Parameters
    ----------
    input_data_df :  pd.DataFrame()
        Input RFM data read from BQ.
    cobs_date : str
        Date for which Cobs segment for customer has to be fetched.
    recency_clust_num : int
        Number of Cluster to be created using proof recency feature.
    frequency_clust_num : int
        Number of Cluster to be created using proof frequency feature.
    monetary_clust_num : int
        Number of Cluster to be created using wallet share feature.
    sales_buckets : list
        sales bucket list.
    same_cuttoff_flag : bool
        Flag mentioning using same cutoff month for all sales buckets or not.
    cutoff_months : list/int
        Single cutoff month value used for all Sales if same_cuttoff_flag is True or reading list of Cutoff months for each sales buckets.
    outperformers_sb : list
        List of Outperformer sales bucket (Max Sales buckets).
    num_std_devs : int
        Number of standard devation used to decide the outliers, to find outperformers segment.
    rfm_segment_file : str
        File containing SQL query to fecth data from table to generate COBS segment.

    Returns
    -------
     pd.DataFrame()
    """

    # Extracting the Cobs segment for the all the customer
    print("Extracting Cobs segment using cluster model")
    if same_cuttoff_flag:
        cutoff_month = cutoff_months

    # Getting scores for each of R, F, & W & cobs segments
    latest_date = datetime.strftime(datetime.strptime(cobs_date, "%Y-%m-%d"), "%Y%m")
    input_data_df["activation_month"] = pd.to_numeric(input_data_df["activation_month"], errors="coerce").astype("Int64") 
    numeric_cols = [
        "proof_rev",
        "total_rev",
        "total_monetary",
        "proof_monetary",
        "total_frequency",
        "proof_frequency",
        "total_trans_after_activation",
        "total_rev_after_activation",
        "wallet_share",
        "order_share",
        "wallet_share_mnth",
        "recency",
        "proof_recency",
        "proof_tenure",
    ]

    for col in numeric_cols:
        if col in input_data_df.columns:
            input_data_df[col] = pd.to_numeric(
                input_data_df[col], errors="coerce"
            )

    input_data_df["segment"] = np.nan
    for sb in sales_buckets:
        # print(sb)
        # Cutoff date for each sales bucket - customers activated after this period are classified as 'Newly Activated'

        if not same_cuttoff_flag:
            cutoff_month = cutoff_months[sb]

        actvtn_cutoff_date = (
                datetime.strptime(latest_date, "%Y%m") - relativedelta(months=cutoff_month)
        ).strftime("%Y%m")
        actvtn_cutoff_date = int(actvtn_cutoff_date)

        recency_clusts = build_cluster_model(
            # input_data_df.query(
            #     f"Sales_Bucket=='{sb}' & activation_month < '{actvtn_cutoff_date}' & proof_rev > 0"
            # )
            input_data_df[
                (input_data_df['Sales_Bucket'] == sb) & (input_data_df['activation_month'] < actvtn_cutoff_date) & (
                            input_data_df['proof_rev'] > 0)],
            "proof_recency",
            recency_clust_num,
            reverse_order=True,
        )

        frequency_clusts = build_cluster_model(
            # input_data_df.query(
            #     f"Sales_Bucket=='{sb}' & activation_month < '{actvtn_cutoff_date}' & proof_rev > 0"
            # ),
            input_data_df[
                (input_data_df['Sales_Bucket'] == sb) & (input_data_df['activation_month'] < actvtn_cutoff_date) & (
                            input_data_df['proof_rev'] > 0)],

            "proof_frequency",
            frequency_clust_num,
        )

        wallet_clusts = build_cluster_model(
            # input_data_df.query(
            #     f"Sales_Bucket=='{sb}' & activation_month < '{actvtn_cutoff_date}' & proof_rev > 0"
            # ),
            input_data_df[
                (input_data_df['Sales_Bucket'] == sb) & (input_data_df['activation_month'] < actvtn_cutoff_date) & (
                            input_data_df['proof_rev'] > 0)],

            "wallet_share",
            monetary_clust_num,
        )

        # Getting metric scores
        sb_act_flag = (
                    (input_data_df["Sales_Bucket"] == sb) & (input_data_df["activation_month"] < actvtn_cutoff_date) & (
                        input_data_df["proof_rev"] > 0))
        input_data_df.loc[sb_act_flag, "recency_score"] = recency_clusts
        input_data_df.loc[sb_act_flag, "frequency_score"] = frequency_clusts
        input_data_df.loc[sb_act_flag, "wallet_score"] = wallet_clusts

        # Defining 'Newly Activated' segment for each sales bucket
        input_data_df.loc[
            (input_data_df["Sales_Bucket"] == sb)
            & (input_data_df["activation_month"] >= actvtn_cutoff_date),
            "segment",
        ] = "Newly Activated"

        # Defining extreme-frequency segment
    input_data_df = define_outperformer_segement(input_data_df=input_data_df,
                                                 outperformers_sb=outperformers_sb,
                                                 num_std_devs=num_std_devs)

    # Defining Lapsed segment
    input_data_df.loc[(input_data_df["proof_rev"] == 0) & input_data_df["segment"].isna(), "segment"] = "Lapsed"

    # Getting main segments
    cobs_segment_df = get_main_segment(rfm_segment_file, input_data_df)

    # Sorting data and imputing monthly wallet share
    cobs_segment_df = sort_imputing_data(cobs_segment_df)

    return cobs_segment_df


def find_dropping_accounts(cobs_seg_12mon, cobs_seg_1mon, segment_value_dict, dropping_label='Dropping'):
    """Function to identify the Dropping segement by comparing 1month data with 12 months segment data by using the wallet share score.

    Parameters
    ----------
    cobs_seg_12mon : pd.DataFrame()
        Cobs segment data generate by considering last 12 months data
    cobs_seg_1mon : _t pd.DataFrame()
        Cobs segment data generate by considering 1 months data
    segment_value_dict : dict
        Dictionary of Cobs segment and respective ranking as values.
    dropping_label : str, optional
        Label to be added as the Dropping segment, by default 'Dropping'

    Returns
    -------
    pd.DataFrame()
        Cobs data after creating the flag to mention the drop in wallet share for each accounts.
    """

    # Merging base data & 1-month data
    cobs_segment_df = cobs_seg_12mon.merge(
        cobs_seg_1mon[
            [
                "Account_ID",
                "date",
                "segment",
                "wallet_share",
                "wallet_score",
                "proof_recency",
                "recency_score",
                "proof_frequency",
                "frequency_score",
            ]
        ],
        how="left",
        on=["Account_ID", "date"],
        suffixes=("", "_1mo"),
    )

    # Scoring the final segment and 1-month segment
    cobs_segment_df["segment_value"] = cobs_segment_df.segment.map(segment_value_dict)
    cobs_segment_df["segment_value_1mo"] = cobs_segment_df["segment_1mo"].map(
        segment_value_dict
    )
    cobs_segment_df["segment_value_diff"] = (
            cobs_segment_df["segment_value"] - cobs_segment_df["segment_value_1mo"]
    )

    # Condition to warn of immediate wallet-share dropping within the month
    dropping_cond = (
            (cobs_segment_df["wallet_score"] - cobs_segment_df["wallet_score_1mo"] >= 2)
            & (cobs_segment_df["segment_value_diff"] >= 5)
            & (cobs_segment_df["segment_value"] >= 6)
            & (cobs_segment_df["Sales_Bucket"] >= "5. 100K-200K")
    )
    cobs_segment_df["dropping"] = dropping_cond

    # Re-naming condition when dropping flag is true
    cobs_segment_df.loc[dropping_cond, "segment"] = dropping_label
    return cobs_segment_df


def select_and_process_data_before_save(cobs_segment_df, drop_columns_list, output_columns_list, column_rename_dict):
    """Function to create the final version of output data by selecting only important features.

    Parameters
    ----------
    cobs_segment_df : pd.DataFrame()
        Final output dataframe with Cobs segments and extra features.
    drop_columns_list : list
        List of features to be dropped (Calculated features).
    output_columns_list : list
        List of important features to be added in the final output data.
    column_rename_dict : dict
        Dictionary of correct naming for the important features which are selected.

    Returns
    -------
    _d.DataFrame
        Output dataframe after removing unnecessary features.
    """

    # dropping calculated columns.
    cobs_segment_df.drop(columns=drop_columns_list, inplace=True)

    #  filling na for interger feature to 0
    num_columns = cobs_segment_df.select_dtypes(np.number).columns
    cobs_segment_df[num_columns] = cobs_segment_df[num_columns].fillna(0)

    cobs_segment_df["segment"] = cobs_segment_df["segment"].fillna("Lapsed")

    cobs_segment_df = cobs_segment_df[output_columns_list].rename(
        columns=column_rename_dict,
    )
    cobs_segment_df["R12 Non Proof Rev"] = (
            cobs_segment_df["R12 Total Rev"] - cobs_segment_df["R12 Proof Rev"]
    )
    cobs_segment_df["R12 Non Proof Invoices"] = (
            cobs_segment_df["R12 Total Invoices"] - cobs_segment_df["R12 Proof Invoices"]
    )

    cobs_segment_df.columns = [col.replace(" ", "_") for col in cobs_segment_df.columns]
    return cobs_segment_df


def get_cobs_segment(conf):
    """Main Cobs function.
    Operation Done in this function.
    1. Read data.
    2. Create cluster using model.
    3. Get Cobs segments.
    4. Map outperformers, Lapsing and Dropping Segments.
    5. Clean final output data before saving to BQ.
    6. Save output data to BQ tabel.

    Parameters
    ----------
    conf : Dict
        Dictionary of configuration file data, containing all the required parameters generate the Cobs segment.
    """

    # Reading Parameter from the Config file data.
    cobs_date = conf["cobs_date"]  # Date for which Cobs segment to be extracted.
    rfm_sql_file = conf["rfm_data_sql_file"]  # SQL query file.
    num_months = conf["num_months"]  # Months to be considered for segmentation.
    single_month = conf["sel_num_month"]  # 1 month segmentation.
    recency_clust_num = conf["recency_clust_num"]  # Number of Cluster to be created using proof recency feature.
    frequency_clust_num = conf["frequency_clust_num"]  # Number of Cluster to be created using proof frequency feature.
    monetary_clust_num = conf["monetary_clust_num"]  # Number of Cluster to be created using wallet share feature.
    sales_buckets = conf["sales_buckets"]  # sales bucket list.
    same_cuttoff_flag = conf[
        "same_cutoff_month_flag"]  # Flag mentioning using same cutoff month for all sales buckets or not.
    dropping_label = conf["dropping_label"]  # Lable for dropping segment.
    drop_columns_list = conf["drop_columns"]  # List of columns to be dropped before saving data.
    output_columns_list = conf["output_columns"]  # List of features requried in final output.
    column_rename_dict = conf["rename_dict"]  # Dictionary to rename features of output.
    rfm_segment_file = conf['rfm_segment_file']  # File for Segment mapping.
    outperformers_sb = conf['outperformers_sales_buckets']  # list of outperformer Sales bucket
    num_std_devs = conf['num_std_devs']  # Number of Standrad deviation used to find out outliers.
    segment_value_dict = conf['segment_value_dict']

    if same_cuttoff_flag:
        cutoff_months = conf["same_cutoff_month"]  # Reading single cutoff month value used for all Sales buckets.
    else:
        cutoff_months = conf["cutoff_months"]  # Reading Cutoff list for sales buckets.

    # extract_cobs_segment for 12 months data
    # Read RFM inputdata from the BQ.

    print("*" * 50)
    print("Extracting Cobs segement for 12 months data")
    print("Data Reading...")

    # input_data_df = get_raw_rfm_data_from_bq(
    #                                         rfm_sql_file=rfm_sql_file,
    #                                         split_date=cobs_date,
    #                                         num_months=num_months,
    #                                     )

    cur = conn.cursor()
    cur.execute(cobs_segment_12_month)
    rows = cur.fetchall()
    cols = [c[0] for c in cur.description]  # first element is column name
    input_data_df = pd.DataFrame(rows, columns=cols)
    # latest_date = datetime.strftime(datetime.strptime(cobs_date, "%Y-%m-%d"), "%Y%m")
    # input_data["date"] = datetime.strftime(str(cobs_date) - relativedelta(months=1), "%Y-%m-%d")

    # Extract Cobs segment
    cobs_seg_12mon = extract_cobs_from_model(input_data_df=input_data_df,
                                             cobs_date=cobs_date,
                                             recency_clust_num=recency_clust_num,
                                             frequency_clust_num=frequency_clust_num,
                                             monetary_clust_num=monetary_clust_num,
                                             sales_buckets=sales_buckets,
                                             same_cuttoff_flag=same_cuttoff_flag,
                                             cutoff_months=cutoff_months,
                                             rfm_segment_file=rfm_segment_file,
                                             outperformers_sb=outperformers_sb,
                                             num_std_devs=num_std_devs)

    # Extracting 1 month data.
    # Read RFM inputdata from the BQ.
    print("*" * 50)
    print("Extracting Cobs segement for 1 months data")
    print("Data Reading...")
    num_months = conf["sel_num_month"]
    # input_data_df = get_raw_rfm_data_from_bq(
    #                                         rfm_sql_file=rfm_sql_file,
    #                                         split_date=cobs_date,
    #                                         num_months=single_month,
    # )

    cur = conn.cursor()
    cur.execute(cobs_segment_1_month)
    rows = cur.fetchall()
    cols = [c[0] for c in cur.description]
    input_data_df = pd.DataFrame(rows, columns=cols)
    # input_data["date"] = datetime.strftime(str(cobs_date) - relativedelta(months=1), "%Y-%m-%d")

    # Extract Cobs segment
    cobs_seg_1mon = extract_cobs_from_model(input_data_df=input_data_df,
                                            cobs_date=cobs_date,
                                            recency_clust_num=recency_clust_num,
                                            frequency_clust_num=frequency_clust_num,
                                            monetary_clust_num=monetary_clust_num,
                                            sales_buckets=sales_buckets,
                                            same_cuttoff_flag=same_cuttoff_flag,
                                            cutoff_months=cutoff_months,
                                            rfm_segment_file=rfm_segment_file,
                                            outperformers_sb=outperformers_sb,
                                            num_std_devs=num_std_devs
                                            )

    print("Finding Dropping segment")
    cobs_segment_df = find_dropping_accounts(cobs_seg_12mon=cobs_seg_12mon,
                                             cobs_seg_1mon=cobs_seg_1mon,
                                             dropping_label=dropping_label,
                                             segment_value_dict=segment_value_dict
                                             )

    print("Selecting and cleaning finalized feature befores saving data")
    cobs_segment_df = select_and_process_data_before_save(cobs_segment_df=cobs_segment_df,
                                                          drop_columns_list=drop_columns_list,
                                                          output_columns_list=output_columns_list,
                                                          column_rename_dict=column_rename_dict
                                                          )
    cobs_segment_df.to_csv('segment_result.csv', index=False)
    
    #  Add s3 secrete to write data on it
    print("Saving Data...")

    return cobs_segment_df


from io import StringIO
# Main function call
if __name__ == "__main__":
    conf = load_yml("config.yml")
    df = get_cobs_segment(conf)
print(df)
csv_buffer = StringIO()
df.to_csv(csv_buffer, index=False)


import boto3
# Set up AWS credentials and S3 client
session = boto3.Session(
    aws_access_key_id='',
    aws_secret_access_key=' '
)
s3_client = session.client('s3')
bucket_name = 'sgws-dataos'
file_key = 'rfm_segment/rfm_segment_data.csv'  # Replace with the desired file key
# local_file_path = 'path/to/your/local/file.txt'  # Replace with the actual local file path
# Upload the local file to the bucket
# with open(local_file_path, 'rb') as f:
s3_client.put_object(Bucket=bucket_name, Key=file_key, Body=csv_buffer.getvalue())
print(f" has been uploaded to {bucket_name}/{file_key}.")
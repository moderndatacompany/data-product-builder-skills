from sklearn.metrics import r2_score
from sklearn.preprocessing import KBinsDiscretizer
import pandas as pd

def build_cluster_model(input_data, colname, clust_num, reverse_order=False, method="quantile"):
    """Function to build/create the KbinsDiscretizer clustering model.

    Parameters
    ----------
    input_data : pd.DataFrame()
        RFM data with Account information.
    colname : str
        Feature on which Clusters to be created.
    clust_num : int
        Number of Cluster to create.
    reverse_order : bool, optional
        _description_, by default False.
    method : str, optional
        Method used to build KbinsDiscretizer clustering, by default "quantile"

    Returns
    -------
    pd.series()
        Series of cluster assigned for each index.
    """
    clust = KBinsDiscretizer(n_bins=clust_num, strategy="quantile", encode="ordinal")
    clust_result = clust.fit_transform(input_data[colname].values.reshape(-1, 1)).T[0]

    if reverse_order:
        clust_result = clust_num - clust_result
        result = pd.Series(clust_result, index=input_data.index)
        result.loc[input_data[colname].isin(clust.bin_edges_[0][1:-1])] += 1
    else:
        result = pd.Series(clust_result, index=input_data.index) + 1
        result.loc[input_data[colname].isin(clust.bin_edges_[0][1:-1])] += -1

    return result

def define_outperformer_segement(input_data_df, outperformers_sb, num_std_devs):
    """Indentify and mark outperformer segment based on the Sales bucket and proof frequency.

    Parameters
    ----------
    input_data_df : pd.DataFrame()
        Data after extracting clusters from the model.
    outperformers_sb : list
        List of Outperformer sales bucket (Max Sales buckets)
    num_std_devs : int
        Number of standard devation used to decide the outliers, to find outperformers segment.

    Returns
    -------
    pd.DataFrame()
    """
  
    ext_freq_seg = input_data_df.merge(
        input_data_df.groupby("Sales_Bucket")["proof_frequency"]
        .agg(
            [
                "mean",
                "std",
            ]
        )
        .astype("float")
        .reset_index(),
        how="left",
        on=["Sales_Bucket"],
    ).query(f"proof_frequency > mean + {num_std_devs}*std")

    # outlier_stats = ext_freq_seg.groupby("Sales_Bucket")["proof_frequency"].describe().join(input_data.groupby("Sales_Bucket")[["Account_ID"]].nunique()) # not used
    input_data_df.loc[
        input_data_df["Account_ID"].isin(ext_freq_seg["Account_ID"].values)
        & (input_data_df["Sales_Bucket"].isin(outperformers_sb)),
        "segment",
    ] = "Outperformers"
    return input_data_df

def sort_imputing_data(cobs_segment_df):
    cobs_segment_df.sort_values(
        by=[
            "Account_ID",
            "date",
        ],
        inplace=True,
    )
    cobs_segment_df["wallet_share_mnth"].fillna(0, inplace=True)
    return cobs_segment_df


def get_main_segment(rfm_segment_file, input_data_df):
    # Read the mapping file (already in long format)
    segments = pd.read_csv(rfm_segment_file)

    # Make sure the score columns are integers
    segments = segments.astype(
        {
            "recency_score": int,
            "frequency_score": int,
            "wallet_score": int,
        }
    )

    # Merge R/F/W scores from the model with the segment mapping
    cobs_segment_df = input_data_df.merge(
        segments,
        how="left",
        on=["Sales_Bucket", "recency_score", "frequency_score", "wallet_score"],
        suffixes=("", "_mapping"),
    )

    # If you had a default segment column earlier, you could handle it here.
    # Since your CSV already has the final 'segment' per combination, we don't need 'segment_default' logic.

    return cobs_segment_df

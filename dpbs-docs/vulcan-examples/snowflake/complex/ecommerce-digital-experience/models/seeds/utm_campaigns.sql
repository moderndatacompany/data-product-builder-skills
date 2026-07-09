MODEL (
  name ECOMMERCE_PLATFORM.SEED.UTM_CAMPAIGNS,
  kind SEED (
    path '../../seeds/utm_campaigns.csv'
  ),
  columns (
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(100),
    channel VARCHAR(50),
    source VARCHAR(50),
    medium VARCHAR(50),
    campaign_start_date DATE,
    campaign_end_date DATE,
    campaign_budget_usd DECIMAL(10,2)
  ),
  grain CAMPAIGN_ID,
  owner 'shreyasikarwartmdcio',
  profiles (CAMPAIGN_ID, CAMPAIGN_NAME),
  tags ('reference-data', 'campaigns', 'marketing', 'seed-data', 'ecommerce'),
  terms ('utm_parameters', 'campaign_tracking', 'traffic_sources'),
  description 'Marketing campaign taxonomy with UTM parameters for traffic source attribution and campaign performance tracking across digital channels. Contains 15 campaigns spanning Paid Search, Email, Organic, Social, Direct, Referral, and Display channels.',
  
  column_descriptions (
    CAMPAIGN_ID = 'Unique campaign identifier (UTM-001 through UTM-015) - Primary key for campaign lookup and attribution',
    CAMPAIGN_NAME = 'Human-readable campaign name for business reporting and dashboards',
    CHANNEL = 'Marketing channel category: Paid Search, Email, Organic, Social, Direct, Referral, Display',
    SOURCE = 'Traffic source platform: Google Ads, Bing Ads, Email, LinkedIn, Direct, Partner Sites',
    MEDIUM = 'Traffic medium type: CPC, Organic, Email, Social, None, Referral, Display',
    CAMPAIGN_START_DATE = 'Campaign launch date',
    CAMPAIGN_END_DATE = 'Campaign end date',
    CAMPAIGN_BUDGET_USD = 'Campaign budget allocation in USD'
  ),
  
  column_tags (
    CAMPAIGN_ID = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key'),
    CAMPAIGN_NAME = ('display-name', 'business-name', 'reference-data', 'descriptive'),
    CHANNEL = ('category', 'marketing', 'classification'),
    SOURCE = ('source', 'marketing', 'attribution'),
    MEDIUM = ('medium', 'marketing', 'attribution'),
    CAMPAIGN_START_DATE = ('temporal', 'campaign', 'start-date'),
    CAMPAIGN_END_DATE = ('temporal', 'campaign', 'end-date'),
    CAMPAIGN_BUDGET_USD = ('budget', 'financial', 'campaign')
  ),
  
  column_terms (
    CAMPAIGN_ID = ('campaign_id', 'utm_campaign_id', 'campaign_code'),
    CAMPAIGN_NAME = ('campaign_name', 'campaign_label', 'campaign_title'),
    CHANNEL = ('marketing_channel', 'channel_category', 'traffic_channel'),
    SOURCE = ('traffic_source', 'utm_source', 'source_platform'),
    MEDIUM = ('traffic_medium', 'utm_medium', 'medium_type'),
    CAMPAIGN_START_DATE = ('start_date', 'campaign_start', 'launch_date'),
    CAMPAIGN_END_DATE = ('end_date', 'campaign_end', 'expiry_date'),
    CAMPAIGN_BUDGET_USD = ('budget', 'campaign_spend', 'budget_allocation')
  )
);


MODEL (
  name LENOVO.USDK.OS_FAMILY,
  kind FULL,
  grain OS_VERSION,
  owner 'shreyasikarwartmdcio',
  profiles (OS_VERSION, OS_FAMILY),
  tags ('reference-data', 'dimension', 'windows', 'os-mapping', 'version-lookup', 'static-data'),
  terms ('os_mapping', 'reference_data', 'windows_versions'),
  description 'Reference table mapping Windows OS version numbers to human-readable release names. Covers Windows 10 (1507-22H2) and Windows 11 (21H2-25H2) releases. Used for OS version analysis and lifecycle tracking.',
  column_descriptions (
    OS_VERSION = 'Windows OS build version number in format X.X.XXXXX (e.g., 10.0.19041 for Windows 10 2004, 10.0.22621 for Windows 11 22H2) - Primary key',
    OS_FAMILY = 'Human-readable Windows release name (e.g., "Windows 10 2004", "Windows 11 22H2") corresponding to the version number'
  ),
  column_tags (
    OS_VERSION = ('primary-key', 'grain', 'version-number', 'identifier', 'build-number'),
    OS_FAMILY = ('display-name', 'release-name', 'marketing-name', 'dimension')
  ),
  column_terms (
    OS_VERSION = ('version_number', 'build_version', 'os_build'),
    OS_FAMILY = ('family_name', 'release_name', 'os_release')
  )
);

/* Windows OS version to family name mapping */
SELECT
  *
FROM (VALUES
  ('10.0.10240', 'Windows 10 1507'),
  ('10.0.10586', 'Windows 10 1511'),
  ('10.0.14393', 'Windows 10 1607'),
  ('10.0.15063', 'Windows 10 1703'),
  ('10.0.16299', 'Windows 10 1709'),
  ('10.0.17134', 'Windows 10 1803'),
  ('10.0.17763', 'Windows 10 1809'),
  ('10.0.18362', 'Windows 10 1903'),
  ('10.0.18363', 'Windows 10 1909'),
  ('10.0.19041', 'Windows 10 2004'),
  ('10.0.19042', 'Windows 10 20H2'),
  ('10.0.19043', 'Windows 10 21H1'),
  ('10.0.19044', 'Windows 10 21H2'),
  ('10.0.19045', 'Windows 10 22H2'),
  ('10.0.22000', 'Windows 11 21H2'),
  ('10.0.22621', 'Windows 11 22H2'),
  ('10.0.22631', 'Windows 11 23H2'),
  ('10.0.26100', 'Windows 11 24H2'),
  ('10.0.26200', 'Windows 11 25H2')) AS t(os_version, os_family)
ORDER BY
  os_version
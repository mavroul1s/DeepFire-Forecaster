# Burned Area Mapping

## Task Definition

Given a temporal stack of VIIRS satellite imagery, predict a binary mask of
pixels that have been burned at any point during the fire event. Labels are
stored in band 8 of the VIIRS_Day GeoTIFF.

## Label Encoding (Key Finding)

The paper does not document how BA labels are encoded. Our audit determined:

- Band 8 finite values range from 2,119 to 908,660 (likely Julian day codes or
  fire perimeter IDs from the MCD64A1 MODIS product).
- 100% of finite pixels are burned pixels. There are no finite non-burn values.
- The correct label extraction is `(~np.isnan(band8)).astype(float)`.
- A value threshold (e.g., >= 7 as used for AF) would also work numerically
  for this dataset but is misleading and not the correct semantic operation.

## Data Splits

| Split | Total fires | Usable after audit | Excluded |
|-------|------------|-------------------|----------|
| Train | 138 | 89 | 49 (band 8 all-NaN) |
| Val | 13 | 8 | 5 (band 8 all-NaN) |
| Test (US_2021) | 24 | -- | -- |

The BA test set is the 24 US_2021 fires, which are entirely distinct from
the 17 named fires used as the AF test set.

See `docs/BA_LABEL_AUDIT_REPORT.md` for the full per-fire breakdown.

## Status

Label audit is complete and reported. Model development for this task is
deferred; the audit findings and label encoding discovery are reported as
a standalone data-quality contribution in the paper.

## Notebooks

| Notebook | Purpose |
|----------|---------|
| `diagnostics/ba_label_audit.ipynb` | Full audit of all BA labels across all splits |

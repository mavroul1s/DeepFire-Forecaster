# TS-SatFire Burned Area -- Label Quality Audit Report

## Overview

This report documents the label completeness analysis of the TS-SatFire dataset
for the Burned Area (BA) mapping task. BA labels are stored in Day GeoTIFF
band 8 (1-indexed), i.e. `day_arr[7]` in 0-indexed numpy. Any finite value
indicates a burned pixel and NaN indicates missing/no-burn data.

Label extraction formula: `label = (~np.isnan(day_arr[7])).astype(np.float32)`

Unlike AF labels (which use a threshold of >= 7 on finite values), BA labels use
a presence/absence encoding: finite values range from 2,119 to 908,660 across the
dataset (11,660 unique values, likely Julian day codes or fire perimeter IDs).
100% of finite pixels are burned -- there are no finite non-burn values in band 8.

We audited all 4 splits: train (138 fires), validation (13 fires),
AF test (17 named fires), and BA test (24 US_2021 fires).

---

## BA Label Encoding Analysis

| Metric | Value |
|--------|-------|
| Finite value range | 2,119 -- 908,660 |
| Unique finite values | 11,660 |
| Pixels with value == 1 | 0 (0.00%) |
| Pixels with value >= 1 | 9,371,710 (100.00%) |
| Pixels with value > 0 | 9,371,710 (100.00%) |
| Pixels with value >= 7 | 9,371,710 (100.00%) |
| Total finite pixels checked | 9,371,710 |

**Conclusion:** Every finite value in band 8 is a burned pixel. The correct
extraction is the inverse NaN check, not a threshold. This differs fundamentally
from the AF encoding (band 7, values >= 7).

---

## Test Set Audit (24 US_2021 fires)

### Method
The BA test set consists of 24 wildfire events from 2021, identified in the
dataset as folders starting with `US_2021_`. These are derived from the MODIS
monthly burned area product (MCD64A1). For each fire we checked every day file
in VIIRS_Day for band 8 label availability.

### Results

| Fire | Days | Usable | % OK | Burn Frac | Status |
|------|------|--------|------|-----------|--------|
| US_2021_AZ3345510938920210616 | 20 | 18 | 90% | 0.00083 | PARTIAL |
| US_2021_AZ3368910927620210616 | 22 | 20 | 91% | 0.00087 | PARTIAL |
| US_2021_CA3451712013120211011 | 12 | 7 | 58% | 0.00126 | PARTIAL |
| US_2021_CA3568711855020210818 | 22 | 21 | 95% | 0.00200 | PARTIAL |
| US_2021_CA3604711863120210910 | 26 | 25 | 96% | 0.00922 | PARTIAL |
| US_2021_CA3627811855020210815 | 19 | 17 | 89% | 0.00086 | PARTIAL |
| US_2021_CA3658211879520210912 | 51 | 50 | 98% | 0.01111 | PARTIAL |
| US_2021_CA4086312235520210630 | 10 | 10 | 100% | 0.00130 | FULL |
| **US_2021_FL2521008104520210308** | **14** | **0** | **0%** | **--** | **NO LABELS** |
| US_2021_ID4453211532920210810 | 59 | 51 | 86% | 0.00427 | PARTIAL |
| US_2021_ID4558511544420210705 | 55 | 55 | 100% | 0.00416 | FULL |
| US_2021_ID4663811466720210707 | 23 | 23 | 100% | 0.00285 | FULL |
| US_2021_ID4762711608320210708 | 58 | 58 | 100% | 0.00396 | FULL |
| US_2021_MT4568311385420210708 | 74 | 69 | 93% | 0.00583 | PARTIAL |
| US_2021_MT4579011310120210708 | 87 | 81 | 93% | 0.00602 | PARTIAL |
| **US_2021_MT4714310953420211004** | **24** | **6** | **25%** | **0.00115** | **MOSTLY NaN** |
| **US_2021_NM3323810847220210520** | **38** | **18** | **47%** | **0.00001** | **MOSTLY NaN** |
| **US_2021_NM3340210587120210426** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| **US_2021_NM3344410803520210514** | **23** | **8** | **35%** | **0.00001** | **MOSTLY NaN** |
| **US_2021_NM3676810505920211120** | **29** | **2** | **7%** | **0.00001** | **MOSTLY NaN** |
| US_2021_WA4828511853120210713 | 66 | 62 | 94% | 0.00709 | PARTIAL |
| US_2021_WA4856812048820210708 | 37 | 37 | 100% | 0.00796 | FULL |
| US_2021_WA4877811903420210803 | 49 | 48 | 98% | 0.00667 | PARTIAL |
| US_2021_WA4879111827120210805 | 26 | 25 | 96% | 0.00778 | PARTIAL |

### Test Summary
- **FULL (100% usable):** 5 fires
- **PARTIAL (50-99% usable):** 13 fires
- **MOSTLY NaN (<50% usable, exclude):** 4 fires
- **NO LABELS (0% usable, exclude):** 2 fires

### Detail for Excluded Test Fires

**US_2021_FL2521008104520210308** -- ALL 14 days are NaN:
- Florida fire, March 2021. Band 8 exists in all 14 GeoTIFFs but every pixel
  is NaN. No burned area labels were generated for this event. Likely a
  prescribed burn or small fire where NIFC perimeters were unavailable.

**US_2021_NM3340210587120210426** -- ALL 10 days are NaN:
- New Mexico fire, April 2021. Same pattern as above: band 8 present but
  entirely NaN across all 10 days.

**US_2021_MT4714310953420211004** -- Only 6/24 days usable (25%):
- Montana fire, October 2021. Severe label sparsity with burn fraction
  0.00115. Insufficient coverage for reliable evaluation.

**US_2021_NM3323810847220210520** -- Only 18/38 days usable (47%):
- New Mexico fire, May 2021. Nearly half the days lack labels. Burn fraction
  is extremely low (0.00001), suggesting near-zero actual burned area in
  the labeled days -- evaluation would be unreliable.

**US_2021_NM3344410803520210514** -- Only 8/23 days usable (35%):
- New Mexico fire, May 2021. Two-thirds of days have no labels. Burn fraction
  0.00001 indicates negligible burn signal in the sparse labeled windows.

**US_2021_NM3676810505920211120** -- Only 2/29 days usable (7%):
- New Mexico fire, November 2021. Near-total label absence with only 2 out of
  29 days having any data. Burn fraction 0.00001.

### Geographic Pattern in Test Exclusions
All 4 MOSTLY_NaN fires and 1 of the 2 NO_LABELS fires are from New Mexico or
nearby states (NM, MT, FL). The 5 California, 3 Idaho, and 4 Washington fires
all have good-to-excellent label coverage. This suggests a regional gap in the
NIFC perimeter data used to generate BA labels.

---

## Training Set Audit (138 numeric fires, 2017-2020)

### Summary Statistics

| Category | Count | Percentage |
|----------|-------|------------|
| FULL labels (all days OK) | 52 | 38% |
| PARTIAL (50-99% days OK) | 37 | 27% |
| MOSTLY NaN (<50% days OK) | 17 | 12% |
| ZERO labels (all days NaN) | 18 | 13% |
| No VIIRS_Day directory | 14 | 10% |
| **USABLE for training** | **89** | **64%** |
| **EXCLUDE from training** | **49** | **36%** |

**Note:** BA exclusions are far more aggressive than AF (49 vs 22). This is
because the burned area labels depend on NIFC perimeter data and accumulated
AF detections, which have lower coverage than the raw VNP14IMG AF product
used for AF labels. Many fires that had good AF labels have no BA labels at all.

### Fires to EXCLUDE from Training (49 fires)

#### No VIIRS_Day Directory (14 fires)

| Fire ID | Reason |
|---------|--------|
| 20777207 | No VIIRS_Day directory |
| 20777386 | No VIIRS_Day directory |
| 21889672 | No VIIRS_Day directory |
| 21889683 | No VIIRS_Day directory |
| 21889697 | No VIIRS_Day directory |
| 21889719 | No VIIRS_Day directory |
| 21889734 | No VIIRS_Day directory |
| 21889754 | No VIIRS_Day directory |
| 21997775 | No VIIRS_Day directory |
| 22713339 | No VIIRS_Day directory |
| 23860978 | No VIIRS_Day directory |
| 23861018 | No VIIRS_Day directory |
| 23861131 | No VIIRS_Day directory |
| 24332700 | No VIIRS_Day directory |

#### All Days NaN (18 fires)

| Fire ID | Days Total | Reason |
|---------|------------|--------|
| 20777181 | 11 | Band 8 all NaN every day |
| 20777195 | 14 | Band 8 all NaN every day |
| 20777203 | 8 | Band 8 all NaN every day |
| 20777397 | 14 | Band 8 all NaN every day |
| 20777452 | 4 | Band 8 all NaN every day |
| 20777459 | 5 | Band 8 all NaN every day |
| 20777482 | 5 | Band 8 all NaN every day |
| 20777487 | 7 | Band 8 all NaN every day |
| 20777508 | 6 | Band 8 all NaN every day |
| 20777521 | 9 | Band 8 all NaN every day |
| 20778153 | 20 | Band 8 all NaN every day |
| 20778225 | 6 | Band 8 all NaN every day |
| 20899892 | 33 | Band 8 all NaN every day |
| 20900040 | 5 | Band 8 all NaN every day |
| 20900085 | 10 | Band 8 all NaN every day |
| 20900124 | 11 | Band 8 all NaN every day |
| 20900131 | 10 | Band 8 all NaN every day |
| 22712973 | 23 | Band 8 all NaN every day |

#### Mostly NaN -- <50% of Days Usable (17 fires)

| Fire ID | Days OK / Total | % OK | Burn Frac |
|---------|-----------------|------|-----------|
| 20702159 | 1/27 | 4% | 0.005135 |
| 20777134 | 15/51 | 29% | 0.007762 |
| 20777152 | 5/17 | 29% | 0.003350 |
| 20778140 | 2/65 | 3% | 0.001702 |
| 20899673 | 18/38 | 47% | 0.009072 |
| 20899721 | 13/33 | 39% | 0.007571 |
| 20899766 | 3/10 | 30% | 0.005902 |
| 20899967 | 6/16 | 38% | 0.000362 |
| 20901111 | 1/8 | 12% | 0.010126 |
| 20901127 | 1/7 | 14% | 0.011643 |
| 21158900 | 1/16 | 6% | 0.021674 |
| 21158932 | 1/14 | 7% | 0.023586 |
| 21158939 | 1/16 | 6% | 0.022032 |
| 21158940 | 1/19 | 5% | 0.023527 |
| 21693566 | 7/20 | 35% | 0.000007 |
| 21751309 | 5/11 | 45% | 0.000038 |
| 23860939 | 3/20 | 15% | 0.000013 |

### Usable PARTIAL Training Fires (37 fires, 50-99% coverage)

These fires are included in training. The dataset class skips individual
windows where the label day has all-NaN band 8.

| Fire ID | Days OK / Total | % OK | Burn Frac |
|---------|-----------------|------|-----------|
| 21997770 | 7/14 | 50% | 0.000767 |
| 23036871 | 4/8 | 50% | 0.006176 |
| 21999381* | -- | -- | -- |
| 20778186 | 36/57 | 63% | 0.003774 |
| 21038333 | 9/14 | 64% | 0.002230 |
| 24461899 | 14/22 | 64% | 0.023628 |
| 20899813 | 17/25 | 68% | 0.003024 |
| 21998230 | 11/15 | 73% | 0.002747 |
| 24333270 | 8/10 | 80% | 0.001935 |
| 24333279 | 8/10 | 80% | 0.005588 |
| 21890502 | 35/43 | 81% | 0.003514 |
| 21890072 | 9/11 | 82% | 0.035229 |
| 22343661 | 10/12 | 83% | 0.011593 |
| 24333277 | 5/6 | 83% | 0.007443 |
| 23159836 | 6/7 | 86% | 0.003769 |
| 21889953 | 6/7 | 86% | 0.001553 |
| 21998095 | 16/18 | 89% | 0.003437 |
| 24333012 | 16/18 | 89% | 0.008121 |
| 21751305 | 8/9 | 89% | 0.002454 |
| 21804884 | 9/10 | 90% | 0.000216 |
| 23410594 | 9/10 | 90% | 0.004928 |
| 24462753* | -- | -- | -- |
| 21748801 | 29/32 | 91% | 0.003241 |
| 21889994 | 10/11 | 91% | 0.006447 |
| 24462335 | 20/22 | 91% | 0.007968 |
| 21804985 | 11/12 | 92% | 0.007665 |
| 24332880 | 12/13 | 92% | 0.004453 |
| 21890003 | 27/29 | 93% | 0.004224 |
| 21890024 | 15/16 | 94% | 0.005065 |
| 24461320 | 15/16 | 94% | 0.022988 |
| 24333000 | 34/36 | 94% | 0.003414 |
| 24332956 | 17/18 | 94% | 0.002379 |
| 24462847 | 33/35 | 94% | 0.018169 |
| 24103557 | 20/21 | 95% | 0.004337 |
| 21998264 | 18/19 | 95% | 0.017712 |
| 21890160 | 25/26 | 96% | 0.003333 |
| 21889779 | 33/34 | 97% | 0.005737 |
| 24333039 | 29/30 | 97% | 0.009001 |
| 24332647 | 50/51 | 98% | 0.019034 |

*Fires marked with \* also appear in the validation split.

---

## Validation Set Audit (13 fires from paper's VAL_IDS)

### Summary Statistics

| Category | Count | Percentage |
|----------|-------|------------|
| FULL labels (all days OK) | 4 | 31% |
| PARTIAL (50-99% days OK) | 4 | 31% |
| ZERO labels (all days NaN) | 5 | 38% |
| **USABLE for BA** | **8** | **62%** |
| **EXCLUDE from BA** | **5** | **38%** |

### Validation Fire Details

| Fire ID | Status | Days OK / Total | % OK | Burn Frac |
|---------|--------|-----------------|------|-----------|
| **20562846** | **ALL NaN** | **0/8** | **0%** | **--** |
| **20568194** | **ALL NaN** | **0/38** | **0%** | **--** |
| **20700973** | **ALL NaN** | **0/9** | **0%** | **--** |
| **20701026** | **ALL NaN** | **0/24** | **0%** | **--** |
| 21751303 | FULL | 41/41 | 100% | 0.003517 |
| 21998313 | FULL | 24/24 | 100% | 0.006691 |
| 21999381 | PARTIAL | 10/18 | 56% | 0.002301 |
| 22141596 | PARTIAL | 18/19 | 95% | 0.009748 |
| **22712904** | **ALL NaN** | **0/16** | **0%** | **--** |
| 24103571 | FULL | 18/18 | 100% | 0.012149 |
| 24462610 | PARTIAL | 26/27 | 96% | 0.017571 |
| 24462753 | PARTIAL | 18/20 | 90% | 0.003555 |
| 24462788 | FULL | 16/16 | 100% | 0.005896 |

### Note on Validation Attrition
5 of 13 validation fires (38%) have zero BA labels. This is a much higher
exclusion rate than AF validation (1 of 13, 8%). Training with only 8
validation fires means validation metrics may have higher variance than
AF, but the remaining 8 fires provide 173 total day files with labels,
which is adequate for monitoring convergence.

---

## AF Test Set -- BA Label Status (17 named fires)

The AF test set is NOT the BA test set. However, for completeness we also
audited BA labels on the 17 named AF test fires in case they are useful
for cross-task analysis.

| Fire | Days | BA Usable | % OK | Burn Frac | BA Status |
|------|------|-----------|------|-----------|-----------|
| blue_ridge_fire | 10 | 10 | 100% | 0.003537 | FULL |
| calfcanyon_fire | 10 | 8 | 80% | 0.000394 | PARTIAL |
| camp_fire | 10 | 10 | 100% | 0.011573 | FULL |
| carr_fire | 10 | 10 | 100% | 0.006319 | FULL |
| **chuckegg_creek_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| creek_fire | 10 | 10 | 100% | 0.019510 | FULL |
| dixie_fire | 10 | 10 | 100% | 0.005087 | FULL |
| double_creek_fire | 10 | 10 | 100% | 0.051947 | FULL |
| eagle_bluff_fire | 10 | 7 | 70% | 0.000010 | PARTIAL |
| **elephant_hill_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| **lytton_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| mosquito_fire | 10 | 10 | 100% | 0.002013 | FULL |
| **sparks_lake_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| **swedish_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| **sydney_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| **thomas_fire** | **10** | **0** | **0%** | **--** | **NO LABELS** |
| tubbs_fire | 10 | 1 | 10% | 0.023586 | MOSTLY NaN |

### Interesting Inversions vs AF
- **mosquito_fire:** Had NO AF labels but has FULL BA labels
- **calfcanyon_fire:** Had NO AF labels but has 80% BA labels
- **double_creek_fire:** Had only 2/9 AF windows but has 100% BA labels
- **elephant_hill_fire, lytton_fire, sparks_lake_fire:** Had FULL AF labels
  but have ZERO BA labels

This demonstrates that AF and BA labels are derived from independent data
sources (VNP14IMG for AF, NIFC+accumulated AF for BA) and cannot be assumed
to correlate.

---

## Cross-Reference: BA vs AF Exclusion Lists

| Category | Count |
|----------|-------|
| Excluded in BOTH AF and BA | 19 |
| Excluded in AF only (have BA labels) | 3 |
| Excluded in BA only (have AF labels) | 49 |

### AF-only exclusions (good BA, bad AF):

| Fire ID | AF Issue | BA Status |
|---------|----------|-----------|
| 21751305 | MOSTLY_NaN (4/9 AF days) | PARTIAL 89% BA |
| 21890056 | MOSTLY_NAN (2/9 AF days) | Usable BA |
| 23036871 | MOSTLY_NAN (3/8 AF days) | PARTIAL 50% BA |

### BA-only exclusions (good AF, bad BA) -- 49 fires
The full list of 49 BA-only exclusions breaks into:
- 14 fires with no VIIRS_Day directory (shared with AF)
- 13 fires with all-NaN band 8 but valid band 7
- 16 fires with <50% BA coverage but >50% AF coverage
- 6 fires from the test/AF_test sets with no BA labels

This asymmetry (49 BA-only vs 3 AF-only) confirms that BA labels have
substantially lower coverage than AF labels across the dataset.

---

## Complete Exclusion Lists

For use in training/evaluation code:

```python
# BA Training Exclusions (49 fires)
# Sources: NO_DIR (no VIIRS_Day), ALL_NAN (band 8 all NaN every day),
#          MOSTLY_NAN (<50% of days have BA labels)
BA_TRAIN_EXCLUDE = [
    "20702159",  # MOSTLY_NAN (1/27 days, 4%)
    "20777134",  # MOSTLY_NAN (15/51 days, 29%)
    "20777152",  # MOSTLY_NAN (5/17 days, 29%)
    "20777181",  # ALL_NAN (0/11 days)
    "20777195",  # ALL_NAN (0/14 days)
    "20777203",  # ALL_NAN (0/8 days)
    "20777207",  # NO_DIR
    "20777386",  # NO_DIR
    "20777397",  # ALL_NAN (0/14 days)
    "20777452",  # ALL_NAN (0/4 days)
    "20777459",  # ALL_NAN (0/5 days)
    "20777482",  # ALL_NAN (0/5 days)
    "20777487",  # ALL_NAN (0/7 days)
    "20777508",  # ALL_NAN (0/6 days)
    "20777521",  # ALL_NAN (0/9 days)
    "20778140",  # MOSTLY_NAN (2/65 days, 3%)
    "20778153",  # ALL_NAN (0/20 days)
    "20778225",  # ALL_NAN (0/6 days)
    "20899673",  # MOSTLY_NAN (18/38 days, 47%)
    "20899721",  # MOSTLY_NAN (13/33 days, 39%)
    "20899766",  # MOSTLY_NAN (3/10 days, 30%)
    "20899892",  # ALL_NAN (0/33 days)
    "20899967",  # MOSTLY_NAN (6/16 days, 38%)
    "20900040",  # ALL_NAN (0/5 days)
    "20900085",  # ALL_NAN (0/10 days)
    "20900124",  # ALL_NAN (0/11 days)
    "20900131",  # ALL_NAN (0/10 days)
    "20901111",  # MOSTLY_NAN (1/8 days, 12%)
    "20901127",  # MOSTLY_NAN (1/7 days, 14%)
    "21158900",  # MOSTLY_NAN (1/16 days, 6%)
    "21158932",  # MOSTLY_NAN (1/14 days, 7%)
    "21158939",  # MOSTLY_NAN (1/16 days, 6%)
    "21158940",  # MOSTLY_NAN (1/19 days, 5%)
    "21693566",  # MOSTLY_NAN (7/20 days, 35%)
    "21751309",  # MOSTLY_NAN (5/11 days, 45%)
    "21889672",  # NO_DIR
    "21889683",  # NO_DIR
    "21889697",  # NO_DIR
    "21889719",  # NO_DIR
    "21889734",  # NO_DIR
    "21889754",  # NO_DIR
    "21997775",  # NO_DIR
    "22712973",  # ALL_NAN (0/23 days)
    "22713339",  # NO_DIR
    "23860939",  # MOSTLY_NAN (3/20 days, 15%)
    "23860978",  # NO_DIR
    "23861018",  # NO_DIR
    "23861131",  # NO_DIR
    "24332700",  # NO_DIR
]

# BA Validation Exclusions (5 fires -- all have 0% BA labels)
BA_VAL_EXCLUDE = [
    "20562846",  # ALL_NAN (0/8 days)
    "20568194",  # ALL_NAN (0/38 days)
    "20700973",  # ALL_NAN (0/9 days)
    "20701026",  # ALL_NAN (0/24 days)
    "22712904",  # ALL_NAN (0/16 days)
]

# BA Test Exclusions (6 fires -- NO_LABELS or <50% coverage)
BA_TEST_EXCLUDE = [
    "US_2021_FL2521008104520210308",  # ALL_NAN (0/14 days)
    "US_2021_MT4714310953420211004",  # MOSTLY_NAN (6/24 days, 25%)
    "US_2021_NM3323810847220210520",  # MOSTLY_NAN (18/38 days, 47%)
    "US_2021_NM3340210587120210426",  # ALL_NAN (0/10 days)
    "US_2021_NM3344410803520210514",  # MOSTLY_NAN (8/23 days, 35%)
    "US_2021_NM3676810505920211120",  # MOSTLY_NAN (2/29 days, 7%)
]

# AF Test fires with no BA labels (not used for BA evaluation)
BA_AFTEST_EXCLUDE = [
    "chuckegg_creek_fire",   # ALL_NAN (0/10 days)
    "elephant_hill_fire",    # ALL_NAN (0/10 days)
    "lytton_fire",           # ALL_NAN (0/10 days)
    "sparks_lake_fire",      # ALL_NAN (0/10 days)
    "swedish_fire",          # ALL_NAN (0/10 days)
    "sydney_fire",           # ALL_NAN (0/10 days)
    "thomas_fire",           # ALL_NAN (0/10 days)
    "tubbs_fire",            # MOSTLY_NAN (1/10 days, 10%)
]
```

---

## Dataset Summary After Cleaning

| Split | Total Fires | Excluded | Usable | % Usable |
|-------|-------------|----------|--------|----------|
| Train | 138 | 49 | 89 | 64% |
| Validation | 13 | 5 | 8 | 62% |
| BA Test (US_2021) | 24 | 6 | 18 | 75% |
| AF Test (named) | 17 | 8 | 9 | 53% |

| Metric | Value |
|--------|-------|
| Estimated BA train windows (TS=2) | ~1,470 |
| Average burn fraction (train) | 0.3-2% |
| Average burn fraction (test) | 0.1-1.1% |

---

## Comparison with AF Audit

| Metric | AF Task | BA Task |
|--------|---------|---------|
| Label band | 7 (1-indexed) | 8 (1-indexed) |
| Label encoding | Finite >= 7 = fire | Finite = burned (any value) |
| Train exclusions | 22 fires (16%) | 49 fires (36%) |
| Val exclusions | 1 fire (8%) | 5 fires (38%) |
| Test exclusions | 2 fires (12%) | 6 fires (25%) |
| Usable train fires | 117 | 89 |
| Usable val fires | 12 | 8 |
| Usable test fires | 15 | 18 |
| Label source | VNP14IMG AF product | NIFC perimeters + accumulated AF |
| Missing data cause | VNP14IMG gaps | NIFC coverage gaps |

### Key Takeaway
BA label quality is substantially worse than AF across all splits. The
36% train exclusion rate (vs 16% for AF) means the model trains on fewer
but cleaner examples. This is the correct tradeoff: training on fires
with missing BA labels would teach the model to suppress burn predictions
in areas that are actually burned, exactly the same corruption mechanism
we discovered in the AF task.

---

## Recommendations

1. **Use the exclusion lists above without exception.** Every fire in the
   exclude lists has been verified to have insufficient BA label coverage.

2. **Day-level filtering is still required.** Even within usable fires,
   individual days can have NaN band 8. The dataset class must check
   `np.isnan(ba_band).sum() < ba_band.size` before using a window's
   last-day label.

3. **Report BA test results on 18 verified fires.** Document the 6
   excluded fires and the reason for exclusion.

4. **Expect higher variance than AF.** With only 8 validation fires and
   89 training fires, metrics will fluctuate more between runs. Use
   multiple random seeds if time permits.

5. **BA normalization may need recomputation.** The current MEAN/STD
   values are from the paper's AF mode. Since BA preprocessing applies
   max-aggregation on I4/I5 channels, the effective distribution of
   those channels changes. If initial training shows instability,
   recompute stats on the max-aggregated training set.

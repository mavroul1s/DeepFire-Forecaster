# Audit Findings — Addendum 2: FP exclusion criterion and AF label coverage

Source: `fp_criterion_kaggle.ipynb`, run on the TS-SatFire Kaggle release.
Raw outputs: `fp_progression_measure.csv`, `fp_criterion_search.json`,
`af_test_label_coverage.csv`, `fp_f1_vs_crop.csv`, `fig_fp_f1_vs_crop.png`.

Supersedes Section 5.1 of `AUDIT_FINDINGS.md`, which was based on cumulative
burned area rather than the progression increment.

---

## 1. The stated exclusion criterion is definitively wrong

Manuscript Section 4.3 excludes eight test fires "whose burned-area fraction
inside the 256 × 256 crop is below 0.001 %". Measured mean per-window
progression fraction for those eight:

| Fire | Usable windows | Windows with any progression | Mean progression per window |
|---|---|---|---|
| FL-2521 | 0 | 0 | undefined |
| NM-3340 | 0 | 0 | undefined |
| NM-3676 | 0 | 0 | undefined |
| NM-3344 | 1 | 0 | 0.0000 % |
| NM-3323 | 8 | 1 | 0.0004 % |
| AZ-3368 | 16 | 12 | **0.0539 %** |
| AZ-3345 | 14 | 12 | **0.0606 %** |
| MT-4714 | 4 | 2 | **0.2663 %** |

Three fires exceed the stated threshold by 50× to 260×. The claim in Section 7
that the two Arizona fires have "zero measurable progression signal within the
center crop" is also false: each has twelve windows carrying progression pixels,
with a peak window fraction of 0.81 %.

**This sentence must be rewritten regardless of which option below is chosen.**

## 2. A two-part rule reproduces the list exactly — but it is post-hoc

No single tested criterion selects the eight. A union of two does, exactly:

- **Rule A**: fewer than 3 windows containing any progression pixels
  → FL-2521, NM-3340, NM-3676, NM-3344, NM-3323, MT-4714 (6 fires)
- **Rule B**: mean per-window progression fraction < 0.1 %
  → NM-3344, NM-3323, AZ-3368, AZ-3345 (4 fires)
- **A ∪ B** = the manuscript's eight, with no extras and none missing.

This was found by searching for a rule that fits the list, not by deriving the
list from a rule. Presenting it as the original criterion would be dishonest,
and a reviewer comparing two thresholds that happen to isolate exactly our
exclusions is entitled to be suspicious.

## 3. The real problem: the exclusion boundary is not monotone

MT-4714 was excluded, yet **seven fires that were kept have less progression
signal than it**:

| Kept fire | Mean progression | vs. excluded MT-4714 (0.2663 %) |
|---|---|---|
| CA-3627 | 0.1082 % | 2.5× less |
| CA-4086 | 0.1167 % | 2.3× less |
| WA-4877 | 0.1347 % | 2.0× less |
| ID-4762 | 0.1490 % | 1.8× less |
| CA-3451 | 0.2219 % | 1.2× less |
| CA-3604 | 0.2274 % | 1.2× less |
| ID-4663 | 0.2573 % | 1.03× less |

Also note CA-3568 (kept, 0.2664 %) and MT-4714 (excluded, 0.2663 %) are
indistinguishable.

Any reviewer who reproduces this table will conclude that fires were removed on
grounds other than the stated one. Given that CA-4086 (F1 = 0.007) and
WA-4879 (F1 = 0.153) were *retained* despite weak signal, the exclusions do not
appear to have been chosen to flatter the aggregate — but the paper cannot
currently demonstrate that, and that is the problem.

## 4. Recommended resolution

**Preferred: report all 24 test fires as the headline number.**

Rationale:
- Reviewer 3 asked for results on the complete official test set anyway.
- It removes the exclusion question entirely rather than defending it.
- The protocol evaluation (E1) already computes all 24, so it costs nothing.
- It converts a vulnerability into compliance with a reviewer request.

Then present, as supporting analysis:
1. A per-fire table for all 24 with progression fraction, usable windows, crop
   truncation, and F1 — so readers can see exactly which fires carry signal.
2. A sensitivity curve: aggregate F1 as a function of a single stated exclusion
   threshold, showing the result is stable rather than threshold-dependent.
3. The crop-truncation analysis (Section 5 below) as the explanation for the
   weak fires, replacing the current speculative text.

**Acceptable alternative:** adopt Rule A alone (fewer than 3 windows with any
progression), which excludes 6 fires and retains the two Arizona fires. This is
a single defensible sentence, is monotone in a meaningful quantity, and requires
only re-aggregating the FP results over 18 fires instead of 16. It does need
FP predictions for AZ-3345 and AZ-3368, which E1 produces since it evaluates all
24.

**Not recommended:** keeping the current 16-fire aggregate with the two-part
rule from Section 2 presented as if it were the original criterion.

## 5. Crop truncation confirmed against the correct label

Recomputed against progression pixels rather than cumulative burn:

- Pearson r = **−0.588**
- Spearman ρ = **−0.685**, p = **0.0034** (n = 16)

Slightly weaker than the cumulative-burn figures reported in Addendum 1
(r = −0.650, ρ = −0.759) but still significant, and this is the correct measure
because it matches the label the model is scored on. **Use −0.588 / −0.685 in
the paper, not the earlier numbers.**

Figure `fig_fp_f1_vs_crop.png` is ready for Section 6.3.

Progression pixels falling outside the 256 × 256 crop range from 0.0 %
(MT-4714) to 100 % (NM-3344), with several of the poorest performers above 80 %:
WA-4877 84.4 %, ID-4762 83.8 %, CA-4086 73.8 %, CA-3627 67.4 %.

---

## 6. AF test label coverage

All 17 AF test fires have exactly 10 days. Coverage:

| Fire | Days labelled | AF positive pixels | Note |
|---|---|---|---|
| mosquito | 0 / 10 | 0 | excluded in manuscript, correct |
| calfcanyon | 0 / 10 | 0 | excluded in manuscript, correct |
| **double_creek** | **3 / 10** | 992 | **retained; reported F1 = 0.850** |
| eagle_bluff | 5 / 10 | 602 | retained; borderline |
| chuckegg_creek | 8 / 10 | 20 171 | retained |
| swedish | 9 / 10 | 4 133 | retained |
| sparks_lake | 9 / 10 | 9 547 | retained |
| all others (10 fires) | 10 / 10 | 1 477 – 29 676 | retained |

### 6.1 double_creek_fire needs disclosure

It is scored on **3 of its 10 days**, and separately, **70.3 % of its AF-positive
pixels fall outside the evaluation crop** (Addendum 1). It contributes a per-fire
F1 of 0.850 to the 15-fire aggregate on the basis of three partially-visible days.

**Action:** disclose in Section 4.1, and report the 15-fire aggregate both with
and without it so the reader can see the effect. Do not silently drop it.

### 6.2 eagle_bluff_fire is small but valid

5 of 10 days labelled, only 602 positive pixels — the smallest AF signal in the
test set after blue_ridge (1 477). It sits exactly on the 50 % criterion
boundary. Retaining it is fine; note the small support when discussing per-fire
variance.

### 6.3 blue_ridge_fire is corroborated

1 477 positive pixels, the second-smallest count, and the lowest per-fire F1
(0.746). The manuscript's explanation (faint, often single-pixel signal) is
consistent with the measurement. This passage needs no change.

---

## 7. Updated action list

| # | Action | Blocked? |
|---|---|---|
| 1 | Rewrite Section 4.3 and Section 7 exclusion text; the "< 0.001 %" claim is false | No |
| 2 | Decide: report all 24 (preferred) or adopt Rule A with 18 | No — decision needed |
| 3 | Disclose double_creek_fire's 3/10-day labelling; report the aggregate with and without it | Partly — needs per-fire F1, already available |
| 4 | Use ρ = −0.685, p = 0.0034 in Section 6.3; insert `fig_fp_f1_vs_crop.png` | No |
| 5 | Replace the "stochastic ember activity" explanation with the crop-truncation analysis | No |
| 6 | Build the per-fire table for all 24 test fires | Blocked on E1 |
| 7 | Re-aggregate FP over the chosen fire set | Blocked on E1 |

E1 (the protocol evaluation) is now the only thing standing between us and a
complete results section. It needs the two checkpoints and `fp_stats.npz`
attached as a Kaggle dataset.
